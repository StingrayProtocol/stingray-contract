/// The reserve module holds the coins of a certain type for a given lending market. 
module suilend::reserve {
    // === Imports ===
    use std::type_name::{Self, TypeName};
    use sui::dynamic_field::{Self};
    use sui::balance::{Self, Balance, Supply};
    use sui::tx_context::{TxContext};
    use sui::object::{Self, UID, ID};
    use suilend::cell::{Self, Cell};
    use std::option::{Self};
    use sui::event::{Self};
    use suilend::oracles::{Self};
    use suilend::decimal::{Decimal, Self, add, sub, mul, div, eq, floor, pow, le, ceil, min, max, saturating_sub};
    use sui::clock::{Self, Clock};
    use sui::coin::{Self, CoinMetadata};
    use sui::math::{Self};
    use suilend_pyth::price_identifier::{PriceIdentifier};
    use suilend_pyth::price_info::{PriceInfoObject};
    use suilend::reserve_config::{
        Self, 
        ReserveConfig, 
        calculate_apr, 
        calculate_supply_apr,
        deposit_limit, 
        deposit_limit_usd, 
        borrow_limit, 
        borrow_limit_usd, 
        borrow_fee,
        protocol_liquidation_fee,
        spread_fee,
        liquidation_bonus
    };
    use suilend::liquidity_mining::{Self, PoolRewardManager};

    #[test_only]
    use sui::test_scenario::{Self};

    #[test_only]
    use std::vector::{Self};

    // === Friends ===
    friend suilend::lending_market;
    friend suilend::obligation;

    // === Errors ===
    const EPriceStale: u64 = 0;
    const EPriceIdentifierMismatch: u64 = 1;
    const EDepositLimitExceeded: u64 = 2;
    const EBorrowLimitExceeded: u64 = 3;
    const EInvalidPrice: u64 = 4;
    const EMinAvailableAmountViolated: u64 = 5;
    const EInvalidRepayBalance: u64 = 6;

    // === Constants ===
    const PRICE_STALENESS_THRESHOLD_S: u64 = 0;
    // to prevent certain rounding bug attacks, we make sure that X amount of the underlying token amount
    // can never be withdrawn or borrowed.
    const MIN_AVAILABLE_AMOUNT: u64 = 100; 

    // === Structs ===
    struct Reserve<phantom P> has key, store {
        id: UID,
        lending_market_id: ID,
        // array index in lending market's reserve array
        array_index: u64,
        coin_type: TypeName,

        config: Cell<ReserveConfig>,
        mint_decimals: u8,

        // oracles
        price_identifier: PriceIdentifier,

        price: Decimal,
        smoothed_price: Decimal,
        price_last_update_timestamp_s: u64,

        available_amount: u64,
        ctoken_supply: u64,
        borrowed_amount: Decimal,

        cumulative_borrow_rate: Decimal,
        interest_last_update_timestamp_s: u64,

        unclaimed_spread_fees: Decimal,

        /// unused
        attributed_borrow_value: Decimal,

        deposits_pool_reward_manager: PoolRewardManager,
        borrows_pool_reward_manager: PoolRewardManager,
    }

    /// Interest bearing token on the underlying Coin<T>. The ctoken can be redeemed for 
    /// the underlying token + any interest earned.
    struct CToken<phantom P, phantom T> has drop {}

    // === Dynamic Field Keys ===
    struct BalanceKey has copy, drop, store {}

    /// Balances are stored in a dynamic field to avoid typing the Reserve with CoinType
    struct Balances<phantom P, phantom T> has store {
        available_amount: Balance<T>,
        ctoken_supply: Supply<CToken<P, T>>,
        fees: Balance<T>,
        ctoken_fees: Balance<CToken<P, T>>,
        deposited_ctokens: Balance<CToken<P, T>>
    }

    // === Events ===
    struct InterestUpdateEvent has drop, copy {
        lending_market_id: address,
        coin_type: TypeName,
        reserve_id: address,
        cumulative_borrow_rate: Decimal,
        available_amount: u64,
        borrowed_amount: Decimal,
        unclaimed_spread_fees: Decimal,
        ctoken_supply: u64,

        // data for sui
        borrow_interest_paid: Decimal,
        spread_fee: Decimal,
        supply_interest_earned: Decimal,
        borrow_interest_paid_usd_estimate: Decimal,
        protocol_fee_usd_estimate: Decimal,
        supply_interest_earned_usd_estimate: Decimal,
    }

    struct ReserveAssetDataEvent has drop, copy {
        lending_market_id: address,
        coin_type: TypeName,
        reserve_id: address,
        available_amount: Decimal,
        supply_amount: Decimal,
        borrowed_amount: Decimal,
        available_amount_usd_estimate: Decimal,
        supply_amount_usd_estimate: Decimal,
        borrowed_amount_usd_estimate: Decimal,
        borrow_apr: Decimal,
        supply_apr: Decimal,

        ctoken_supply: u64,
        cumulative_borrow_rate: Decimal,
        price: Decimal,
        smoothed_price: Decimal,
        price_last_update_timestamp_s: u64,
    }


    // === Constructor ===
    public(friend) fun create_reserve<P, T>(
        lending_market_id: ID,
        config: ReserveConfig, 
        array_index: u64,
        coin_metadata: &CoinMetadata<T>,
        price_info_obj: &PriceInfoObject, 
        clock: &Clock, 
        ctx: &mut TxContext
    ): Reserve<P> {

        let (price_decimal, smoothed_price_decimal, price_identifier) = oracles::get_pyth_price_and_identifier(price_info_obj, clock);
        assert!(option::is_some(&price_decimal), EInvalidPrice);

        let reserve = Reserve {
            id: object::new(ctx),
            lending_market_id,
            array_index,
            coin_type: type_name::get<T>(),
            config: cell::new(config),
            mint_decimals: coin::get_decimals(coin_metadata),
            price_identifier,
            price: option::extract(&mut price_decimal),
            smoothed_price: smoothed_price_decimal,
            price_last_update_timestamp_s: clock::timestamp_ms(clock) / 1000,
            available_amount: 0,
            ctoken_supply: 0,
            borrowed_amount: decimal::from(0),
            cumulative_borrow_rate: decimal::from(1),
            interest_last_update_timestamp_s: clock::timestamp_ms(clock) / 1000,
            unclaimed_spread_fees: decimal::from(0),
            attributed_borrow_value: decimal::from(0),
            deposits_pool_reward_manager: liquidity_mining::new_pool_reward_manager(ctx),
            borrows_pool_reward_manager: liquidity_mining::new_pool_reward_manager(ctx)
        };

        dynamic_field::add(
            &mut reserve.id,
            BalanceKey {},
            Balances<P, T> {
                available_amount: balance::zero<T>(),
                ctoken_supply: balance::create_supply(CToken<P, T> {}),
                fees: balance::zero<T>(),
                ctoken_fees: balance::zero<CToken<P, T>>(),
                deposited_ctokens: balance::zero<CToken<P, T>>()
            }
        );

        reserve
    }

    // === Public-View Functions ===

    public fun price_identifier<P>(reserve: &Reserve<P>): &PriceIdentifier {
        &reserve.price_identifier
    }
    
    public fun borrows_pool_reward_manager<P>(reserve: &Reserve<P>): &PoolRewardManager {
        &reserve.borrows_pool_reward_manager
    }

    public fun deposits_pool_reward_manager<P>(reserve: &Reserve<P>): &PoolRewardManager {
        &reserve.deposits_pool_reward_manager
    }

    public fun array_index<P>(reserve: &Reserve<P>): u64 {
        reserve.array_index
    }

    public fun available_amount<P>(reserve: &Reserve<P>): u64 {
        reserve.available_amount
    }

    public fun borrowed_amount<P>(reserve: &Reserve<P>): Decimal {
        reserve.borrowed_amount
    }

    public fun coin_type<P>(reserve: &Reserve<P>): TypeName {
        reserve.coin_type
    }

    // make sure we are using the latest published price on sui
    public fun assert_price_is_fresh<P>(reserve: &Reserve<P>, clock: &Clock) {
        let cur_time_s = clock::timestamp_ms(clock) / 1000;
        assert!(
            cur_time_s - reserve.price_last_update_timestamp_s <= PRICE_STALENESS_THRESHOLD_S, 
            EPriceStale
        );
    }

    // if SUI = $1, this returns decimal::from(1).
    public fun price<P>(reserve: &Reserve<P>): Decimal {
        reserve.price
    }

    public fun price_lower_bound<P>(reserve: &Reserve<P>): Decimal {
        min(reserve.price, reserve.smoothed_price)
    }

    public fun price_upper_bound<P>(reserve: &Reserve<P>): Decimal {
        max(reserve.price, reserve.smoothed_price)
    }

    public fun market_value<P>(
        reserve: &Reserve<P>, 
        liquidity_amount: Decimal
    ): Decimal {
        div(
            mul(
                price(reserve),
                liquidity_amount
            ),
            decimal::from(math::pow(10, reserve.mint_decimals))
        )
    }

    public fun market_value_lower_bound<P>(
        reserve: &Reserve<P>, 
        liquidity_amount: Decimal
    ): Decimal {
        div(
            mul(
                price_lower_bound(reserve),
                liquidity_amount
            ),
            decimal::from(math::pow(10, reserve.mint_decimals))
        )
    }

    public fun market_value_upper_bound<P>(
        reserve: &Reserve<P>, 
        liquidity_amount: Decimal
    ): Decimal {
        div(
            mul(
                price_upper_bound(reserve),
                liquidity_amount
            ),
            decimal::from(math::pow(10, reserve.mint_decimals))
        )
    }

    public fun ctoken_market_value<P>(
        reserve: &Reserve<P>, 
        ctoken_amount: u64
    ): Decimal {
        // TODO should i floor here?
        let liquidity_amount = mul(
            decimal::from(ctoken_amount),
            ctoken_ratio(reserve)
        );

        market_value(reserve, liquidity_amount)
    }

    public fun ctoken_market_value_lower_bound<P>(
        reserve: &Reserve<P>, 
        ctoken_amount: u64
    ): Decimal {
        // TODO should i floor here?
        let liquidity_amount = mul(
            decimal::from(ctoken_amount),
            ctoken_ratio(reserve)
        );

        market_value_lower_bound(reserve, liquidity_amount)
    }

    public fun ctoken_market_value_upper_bound<P>(
        reserve: &Reserve<P>, 
        ctoken_amount: u64
    ): Decimal {
        // TODO should i floor here?
        let liquidity_amount = mul(
            decimal::from(ctoken_amount),
            ctoken_ratio(reserve)
        );

        market_value_upper_bound(reserve, liquidity_amount)
    }

    // eg how much sui can i get for 1000 USDC
    public fun usd_to_token_amount_lower_bound<P>(
        reserve: &Reserve<P>, 
        usd_amount: Decimal
    ): Decimal {
        div(
            mul(
                decimal::from(math::pow(10, reserve.mint_decimals)),
                usd_amount
            ),
            price_upper_bound(reserve)
        )
    }

    public fun usd_to_token_amount_upper_bound<P>(
        reserve: &Reserve<P>, 
        usd_amount: Decimal
    ): Decimal {
        div(
            mul(
                decimal::from(math::pow(10, reserve.mint_decimals)),
                usd_amount
            ),
            price_lower_bound(reserve)
        )
    }


    public fun cumulative_borrow_rate<P>(reserve: &Reserve<P>): Decimal {
        reserve.cumulative_borrow_rate
    }

    public fun total_supply<P>(reserve: &Reserve<P>): Decimal {
        sub(
            add(
                decimal::from(reserve.available_amount),
                reserve.borrowed_amount
            ),
            reserve.unclaimed_spread_fees
        )
    }

    public fun calculate_utilization_rate<P>(reserve: &Reserve<P>): Decimal {
        let total_supply_excluding_fees = add(
            decimal::from(reserve.available_amount),
            reserve.borrowed_amount
        );

        if (eq(total_supply_excluding_fees, decimal::from(0))) {
            decimal::from(0)
        }
        else {
            div(reserve.borrowed_amount, total_supply_excluding_fees)
        }
    }

    // always greater than or equal to one
    public fun ctoken_ratio<P>(reserve: &Reserve<P>): Decimal {
        let total_supply = total_supply(reserve);

        // this branch is only used once -- when the reserve is first initialized and has 
        // zero deposits. after that, borrows and redemptions won't let the ctoken supply fall 
        // below MIN_AVAILABLE_AMOUNT
        if (reserve.ctoken_supply == 0) {
            decimal::from(1)
        }
        else {
            div(
                total_supply,
                decimal::from(reserve.ctoken_supply)
            )
        }
    }

    public fun config<P>(reserve: &Reserve<P>): &ReserveConfig {
        cell::get(&reserve.config)
    }

    public fun calculate_borrow_fee<P>(
        reserve: &Reserve<P>,
        borrow_amount: u64
    ): u64 {
        ceil(mul(decimal::from(borrow_amount), borrow_fee(config(reserve))))
    }

    // maximum amount that can be borrowed from the reserve. does not account for fees!
    public fun max_borrow_amount<P>(reserve: &Reserve<P>): u64 {
        floor(min(
            saturating_sub(
                decimal::from(reserve.available_amount),
                decimal::from(MIN_AVAILABLE_AMOUNT)
            ),
            min(
                // borrow limit
                saturating_sub(
                    decimal::from(borrow_limit(config(reserve))),
                    reserve.borrowed_amount
                ),
                // usd borrow limit
                usd_to_token_amount_lower_bound(
                    reserve,
                    saturating_sub(
                        decimal::from(borrow_limit_usd(config(reserve))),
                        market_value_upper_bound(reserve, reserve.borrowed_amount)
                    )
                )
            )
        ))
    }

    // calculates the maximum amount of ctokens that can be redeemed
    public fun max_redeem_amount<P>(reserve: &Reserve<P>): u64 {
        floor(div(
            sub(
                decimal::from(reserve.available_amount),
                decimal::from(MIN_AVAILABLE_AMOUNT)
            ),
            ctoken_ratio(reserve)
        ))
    }

    // === Public-Mutative Functions
    public(friend) fun deposits_pool_reward_manager_mut<P>(reserve: &mut Reserve<P>): &mut PoolRewardManager {
        &mut reserve.deposits_pool_reward_manager
    }

    public(friend) fun borrows_pool_reward_manager_mut<P>(reserve: &mut Reserve<P>): &mut PoolRewardManager {
        &mut reserve.borrows_pool_reward_manager
    }

    public(friend) fun deduct_liquidation_fee<P, T>(
        reserve: &mut Reserve<P>,
        ctokens: &mut Balance<CToken<P, T>>,
    ): (u64, u64) {
        let bonus = liquidation_bonus(config(reserve));
        let protocol_liquidation_fee = protocol_liquidation_fee(config(reserve));
        let take_rate = div(
            protocol_liquidation_fee,
            add(add(decimal::from(1), bonus), protocol_liquidation_fee)
        );
        let protocol_fee_amount = ceil(mul(take_rate, decimal::from(balance::value(ctokens))));

        let balances: &mut Balances<P, T> = dynamic_field::borrow_mut(&mut reserve.id, BalanceKey {});
        balance::join(&mut balances.ctoken_fees, balance::split(ctokens, protocol_fee_amount));

        let bonus_rate = div(
            bonus,
            add(add(decimal::from(1), bonus), protocol_liquidation_fee)
        );
        let liquidator_bonus_amount = ceil(mul(bonus_rate, decimal::from(balance::value(ctokens))));

        (protocol_fee_amount, liquidator_bonus_amount)
    }

    public(friend) fun update_reserve_config<P>(
        reserve: &mut Reserve<P>, 
        config: ReserveConfig, 
    ) {
        let old = cell::set(&mut reserve.config, config);
        reserve_config::destroy(old);
    }

    public(friend) fun update_price<P>(
        reserve: &mut Reserve<P>, 
        clock: &Clock,
        price_info_obj: &PriceInfoObject
    ) {
        let (price_decimal, ema_price_decimal, price_identifier) = oracles::get_pyth_price_and_identifier(price_info_obj, clock);
        assert!(price_identifier == reserve.price_identifier, EPriceIdentifierMismatch);
        assert!(option::is_some(&price_decimal), EInvalidPrice);

        reserve.price = option::extract(&mut price_decimal);
        reserve.smoothed_price = ema_price_decimal;
        reserve.price_last_update_timestamp_s = clock::timestamp_ms(clock) / 1000;
    }

    /// Compound interest, debt. Interest is compounded every second.
    public(friend) fun compound_interest<P>(reserve: &mut Reserve<P>, clock: &Clock) {
        let cur_time_s = clock::timestamp_ms(clock) / 1000;
        let time_elapsed_s = cur_time_s - reserve.interest_last_update_timestamp_s;
        if (time_elapsed_s == 0) {
            return
        };

        // I(t + n) = I(t) * (1 + apr()/SECONDS_IN_YEAR) ^ n
        let utilization_rate = calculate_utilization_rate(reserve);
        let compounded_borrow_rate = pow(
            add(
                decimal::from(1),
                div(
                    calculate_apr(config(reserve), utilization_rate),
                    decimal::from(365 * 24 * 60 * 60)
                )
            ),
            time_elapsed_s
        );

        reserve.cumulative_borrow_rate = mul(
            reserve.cumulative_borrow_rate,
            compounded_borrow_rate
        );

        let net_new_debt = mul(
            reserve.borrowed_amount,
            sub(compounded_borrow_rate, decimal::from(1))
        );

        let spread_fee = mul(net_new_debt, spread_fee(config(reserve)));

        reserve.unclaimed_spread_fees = add(
            reserve.unclaimed_spread_fees,
            spread_fee
        );

        reserve.borrowed_amount = add(
            reserve.borrowed_amount,
            net_new_debt 
        );

        reserve.interest_last_update_timestamp_s = cur_time_s;

        event::emit(InterestUpdateEvent {
            lending_market_id: object::id_to_address(&reserve.lending_market_id),
            coin_type: reserve.coin_type,
            reserve_id: object::uid_to_address(&reserve.id),
            cumulative_borrow_rate: reserve.cumulative_borrow_rate,
            available_amount: reserve.available_amount,
            borrowed_amount: reserve.borrowed_amount,
            unclaimed_spread_fees: reserve.unclaimed_spread_fees,
            ctoken_supply: reserve.ctoken_supply,

            borrow_interest_paid: net_new_debt,
            spread_fee: spread_fee,
            supply_interest_earned: sub(net_new_debt, spread_fee),
            borrow_interest_paid_usd_estimate: market_value(reserve, net_new_debt),
            protocol_fee_usd_estimate: market_value(reserve, spread_fee),
            supply_interest_earned_usd_estimate: market_value(reserve, sub(net_new_debt, spread_fee)),
        });
    }

    public(friend) fun claim_fees<P, T>(reserve: &mut Reserve<P>): (Balance<CToken<P, T>>, Balance<T>) {
        let balances: &mut Balances<P, T> = dynamic_field::borrow_mut(&mut reserve.id, BalanceKey {});
        let fees = balance::withdraw_all(&mut balances.fees);
        let ctoken_fees = balance::withdraw_all(&mut balances.ctoken_fees);

        // spread fees
        if (reserve.available_amount >= MIN_AVAILABLE_AMOUNT) {
            let claimable_spread_fees = floor(min(
                reserve.unclaimed_spread_fees,
                decimal::from(reserve.available_amount - MIN_AVAILABLE_AMOUNT)
            ));

            let spread_fees = balance::split(&mut balances.available_amount, claimable_spread_fees);

            reserve.unclaimed_spread_fees = sub(
                reserve.unclaimed_spread_fees, 
                decimal::from(balance::value(&spread_fees))
            );
            reserve.available_amount = reserve.available_amount - balance::value(&spread_fees);

            balance::join(&mut fees, spread_fees);
        };

        (ctoken_fees, fees)
    }

    public(friend) fun deposit_liquidity_and_mint_ctokens<P, T>(
        reserve: &mut Reserve<P>, 
        liquidity: Balance<T>, 
    ): Balance<CToken<P, T>> {
        let ctoken_ratio = ctoken_ratio(reserve);

        let new_ctokens = floor(div(
            decimal::from(balance::value(&liquidity)),
            ctoken_ratio
        ));

        reserve.available_amount = reserve.available_amount + balance::value(&liquidity);
        reserve.ctoken_supply = reserve.ctoken_supply + new_ctokens;

        let total_supply = total_supply(reserve);
        assert!(
            le(total_supply, decimal::from(deposit_limit(config(reserve)))), 
            EDepositLimitExceeded
        );

        let total_supply_usd = market_value_upper_bound(reserve, total_supply);
        assert!(
            le(total_supply_usd, decimal::from(deposit_limit_usd(config(reserve)))), 
            EDepositLimitExceeded
        );

        log_reserve_data(reserve);
        let balances: &mut Balances<P, T> = dynamic_field::borrow_mut(
            &mut reserve.id, 
            BalanceKey {}
        );

        balance::join(&mut balances.available_amount, liquidity);
        balance::increase_supply(&mut balances.ctoken_supply, new_ctokens)
    }

    public(friend) fun redeem_ctokens<P, T>(
        reserve: &mut Reserve<P>, 
        ctokens: Balance<CToken<P, T>>
    ): Balance<T> {
        let ctoken_ratio = ctoken_ratio(reserve);
        let liquidity_amount = floor(mul(
            decimal::from(balance::value(&ctokens)),
            ctoken_ratio
        ));

        reserve.available_amount = reserve.available_amount - liquidity_amount;
        reserve.ctoken_supply = reserve.ctoken_supply - balance::value(&ctokens);

        assert!(
            reserve.available_amount >= MIN_AVAILABLE_AMOUNT && reserve.ctoken_supply >= MIN_AVAILABLE_AMOUNT, 
            EMinAvailableAmountViolated
        );

        log_reserve_data(reserve);
        let balances: &mut Balances<P, T> = dynamic_field::borrow_mut(
            &mut reserve.id, 
            BalanceKey {}
        );

        balance::decrease_supply(&mut balances.ctoken_supply, ctokens);
        balance::split(&mut balances.available_amount, liquidity_amount)
    }

    /// Borrow tokens from the reserve. A fee is charged on the borrowed amount
    public(friend) fun borrow_liquidity<P, T>(
        reserve: &mut Reserve<P>, 
        amount: u64
    ): (Balance<T>, u64) {
        let borrow_fee = calculate_borrow_fee(reserve, amount);
        let borrow_amount_with_fees = amount + borrow_fee;

        reserve.available_amount = reserve.available_amount - borrow_amount_with_fees;
        reserve.borrowed_amount = add(reserve.borrowed_amount, decimal::from(borrow_amount_with_fees));

        assert!(
            le(reserve.borrowed_amount, decimal::from(borrow_limit(config(reserve)))), 
            EBorrowLimitExceeded 
        );

        let borrowed_amount = reserve.borrowed_amount;
        assert!(
            le(
                market_value_upper_bound(reserve, borrowed_amount), 
                decimal::from(borrow_limit_usd(config(reserve)))
            ), 
            EBorrowLimitExceeded
        );

        assert!(
            reserve.available_amount >= MIN_AVAILABLE_AMOUNT && reserve.ctoken_supply >= MIN_AVAILABLE_AMOUNT,
            EMinAvailableAmountViolated
        );

        log_reserve_data(reserve);
        let balances: &mut Balances<P, T> = dynamic_field::borrow_mut(
            &mut reserve.id, 
            BalanceKey {}
        );

        let receive_balance = balance::split(&mut balances.available_amount, borrow_amount_with_fees);
        let fee_balance = balance::split(&mut receive_balance, borrow_fee);
        balance::join(&mut balances.fees, fee_balance);

        (receive_balance, borrow_amount_with_fees)
    }

    public(friend) fun repay_liquidity<P, T>(
        reserve: &mut Reserve<P>, 
        liquidity: Balance<T>,
        settle_amount: Decimal
    ) {
        assert!(balance::value(&liquidity) == ceil(settle_amount), EInvalidRepayBalance);

        reserve.available_amount = reserve.available_amount + balance::value(&liquidity);
        reserve.borrowed_amount = saturating_sub(
            reserve.borrowed_amount, 
            settle_amount
        );

        log_reserve_data(reserve);
        let balances: &mut Balances<P, T> = dynamic_field::borrow_mut(&mut reserve.id, BalanceKey {});
        balance::join(&mut balances.available_amount, liquidity);
    }

    public(friend) fun forgive_debt<P>(
        reserve: &mut Reserve<P>, 
        forgive_amount: Decimal
    ) {
        reserve.borrowed_amount = saturating_sub(
            reserve.borrowed_amount, 
            forgive_amount
        );

        log_reserve_data(reserve);
    }

    public(friend) fun deposit_ctokens<P, T>(
        reserve: &mut Reserve<P>, 
        ctokens: Balance<CToken<P, T>>
    ) {
        log_reserve_data(reserve);
        let balances: &mut Balances<P, T> = dynamic_field::borrow_mut(&mut reserve.id, BalanceKey {});
        balance::join(&mut balances.deposited_ctokens, ctokens);
    }

    public(friend) fun withdraw_ctokens<P, T>(
        reserve: &mut Reserve<P>, 
        amount: u64
    ): Balance<CToken<P, T>> {
        log_reserve_data(reserve);
        let balances: &mut Balances<P, T> = dynamic_field::borrow_mut(&mut reserve.id, BalanceKey {});
        balance::split(&mut balances.deposited_ctokens, amount)
    }

    public(friend) fun change_price_feed<P>(
        reserve: &mut Reserve<P>,
        price_info_obj: &PriceInfoObject,
        clock: &Clock,
    ){
        let (_, _, price_identifier) = oracles::get_pyth_price_and_identifier(price_info_obj, clock);
        reserve.price_identifier = price_identifier;
    }

    // === Private Functions ===
    fun log_reserve_data<P>(reserve: &Reserve<P>){
        let available_amount_decimal = decimal::from(reserve.available_amount);
        let supply_amount = total_supply(reserve);
        let cur_util = calculate_utilization_rate(reserve);
        let borrow_apr = calculate_apr(config(reserve), cur_util);
        let supply_apr = calculate_supply_apr(config(reserve), cur_util, borrow_apr);

        event::emit(ReserveAssetDataEvent {
            lending_market_id: object::id_to_address(&reserve.lending_market_id),
            coin_type: reserve.coin_type,
            reserve_id: object::uid_to_address(&reserve.id),
            available_amount: available_amount_decimal,
            supply_amount: supply_amount,
            borrowed_amount: reserve.borrowed_amount,
            available_amount_usd_estimate: market_value(reserve, available_amount_decimal),
            supply_amount_usd_estimate: market_value(reserve, supply_amount),
            borrowed_amount_usd_estimate: market_value(reserve, reserve.borrowed_amount),
            borrow_apr: borrow_apr,
            supply_apr: supply_apr,

            ctoken_supply: reserve.ctoken_supply,
            cumulative_borrow_rate: reserve.cumulative_borrow_rate,
            price: reserve.price,
            smoothed_price: reserve.smoothed_price,
            price_last_update_timestamp_s: reserve.price_last_update_timestamp_s,
        });
    }

    // === Test Functions ===
    #[test_only]
    public fun update_price_for_testing<P>(
        reserve: &mut Reserve<P>, 
        clock: &Clock,
        price_decimal: Decimal,
        smoothed_price_decimal: Decimal
    ) {
        reserve.price = price_decimal;
        reserve.smoothed_price = smoothed_price_decimal;
        reserve.price_last_update_timestamp_s = clock::timestamp_ms(clock) / 1000;
    }

    #[test_only]
    use suilend_pyth::price_identifier::{Self};

    #[test_only]
    fun example_price_identifier(): PriceIdentifier {
        let v = vector::empty();
        let i = 0;
        while (i < 32) {
            vector::push_back(&mut v, i);
            i = i + 1;
        };

        price_identifier::from_byte_vec(v)
    }

    #[test]
    fun test_accessors() {
        use suilend::test_usdc::{TEST_USDC};
        use suilend::reserve_config::{default_reserve_config};

        let owner = @0x26;
        let scenario = test_scenario::begin(owner);

        let id = object::new(test_scenario::ctx(&mut scenario));

        let reserve = Reserve<TEST_USDC> {
            id: object::new(test_scenario::ctx(&mut scenario)),
            lending_market_id: object::uid_to_inner(&id),
            array_index: 0,
            coin_type: type_name::get<TEST_USDC>(),
            config: cell::new(default_reserve_config()),
            mint_decimals: 9,
            price_identifier: example_price_identifier(),
            price: decimal::from(1),
            smoothed_price: decimal::from(2),
            price_last_update_timestamp_s: 0,
            available_amount: 500,
            ctoken_supply: 200,
            borrowed_amount: decimal::from(500),
            cumulative_borrow_rate: decimal::from(1),
            interest_last_update_timestamp_s: 0,
            unclaimed_spread_fees: decimal::from(0),
            attributed_borrow_value: decimal::from(0),
            deposits_pool_reward_manager: liquidity_mining::new_pool_reward_manager(test_scenario::ctx(&mut scenario)),
            borrows_pool_reward_manager: liquidity_mining::new_pool_reward_manager(test_scenario::ctx(&mut scenario))
        };

        assert!(market_value(&reserve, decimal::from(10_000_000_000)) == decimal::from(10), 0);
        assert!(ctoken_market_value(&reserve, 10_000_000_000) == decimal::from(50), 0);
        assert!(cumulative_borrow_rate(&reserve) == decimal::from(1), 0);
        assert!(total_supply(&reserve) == decimal::from(1000), 0);
        assert!(calculate_utilization_rate(&reserve) == decimal::from_percent(50), 0);
        assert!(ctoken_ratio(&reserve) == decimal::from(5), 0);

        sui::test_utils::destroy(id);
        sui::test_utils::destroy(reserve);
        test_scenario::end(scenario);
    }

    #[test]
    fun test_compound_interest() {
        use suilend::test_usdc::{TEST_USDC};
        use sui::test_scenario::{Self};
        use suilend::reserve_config::{default_reserve_config};

        let owner = @0x26;
        let scenario = test_scenario::begin(owner);
        let lending_market_id = object::new(test_scenario::ctx(&mut scenario));

        let reserve = Reserve<TEST_USDC> {
            id: object::new(test_scenario::ctx(&mut scenario)),
            lending_market_id: object::uid_to_inner(&lending_market_id),
            array_index: 0,
            coin_type: type_name::get<TEST_USDC>(),
            config: cell::new({
                let config = default_reserve_config();
                let builder = reserve_config::from(&config, test_scenario::ctx(&mut scenario));
                reserve_config::set_spread_fee_bps(&mut builder, 2_000);
                reserve_config::set_interest_rate_utils(&mut builder, {
                    let v = vector::empty();
                    vector::push_back(&mut v, 0);
                    vector::push_back(&mut v, 100);
                    v
                });
                reserve_config::set_interest_rate_aprs(&mut builder, {
                    let v = vector::empty();
                    vector::push_back(&mut v, 0);
                    vector::push_back(&mut v, 3153600000);
                    v
                });

                sui::test_utils::destroy(config);
                reserve_config::build(builder, test_scenario::ctx(&mut scenario))
            }),
            mint_decimals: 9,
            price_identifier: example_price_identifier(),
            price: decimal::from(1),
            smoothed_price: decimal::from(1),
            price_last_update_timestamp_s: 0,
            available_amount: 500,
            ctoken_supply: 200,
            borrowed_amount: decimal::from(500),
            cumulative_borrow_rate: decimal::from(1),
            interest_last_update_timestamp_s: 0,
            unclaimed_spread_fees: decimal::from(0),
            attributed_borrow_value: decimal::from(0),
            deposits_pool_reward_manager: liquidity_mining::new_pool_reward_manager(test_scenario::ctx(&mut scenario)),
            borrows_pool_reward_manager: liquidity_mining::new_pool_reward_manager(test_scenario::ctx(&mut scenario))
        };

        let clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));
        clock::set_for_testing(&mut clock, 1000); 

        compound_interest(&mut reserve, &clock);

        assert!(cumulative_borrow_rate(&reserve) == decimal::from_bps(10_050), 0);
        assert!(reserve.borrowed_amount == add(decimal::from(500), decimal::from_percent(250)), 0);
        assert!(reserve.unclaimed_spread_fees == decimal::from_percent(50), 0);
        assert!(ctoken_ratio(&reserve) == decimal::from_percent_u64(501), 0);
        assert!(reserve.interest_last_update_timestamp_s == 1, 0);


        // test idempotency

        compound_interest(&mut reserve, &clock);

        assert!(cumulative_borrow_rate(&reserve) == decimal::from_bps(10_050), 0);
        assert!(reserve.borrowed_amount == add(decimal::from(500), decimal::from_percent(250)), 0);
        assert!(reserve.unclaimed_spread_fees == decimal::from_percent(50), 0);
        assert!(reserve.interest_last_update_timestamp_s == 1, 0);

        sui::test_utils::destroy(lending_market_id);
        sui::test_utils::destroy(clock);
        sui::test_utils::destroy(reserve);

        test_scenario::end(scenario);
    }

    #[test_only]
    struct TEST_LM {}

    #[test]
    fun test_deposit_happy() {
        use suilend::test_usdc::{TEST_USDC};
        use sui::test_scenario::{Self};
        use suilend::reserve_config::{default_reserve_config};

        let owner = @0x26;
        let scenario = test_scenario::begin(owner);

        
        let reserve = create_for_testing<TEST_LM, TEST_USDC>(
            default_reserve_config(),
            0,
            6,
            decimal::from(1),
            0,
            500,
            200,
            decimal::from(500),
            decimal::from(1),
            1,
            test_scenario::ctx(&mut scenario)
        );

        let ctokens = deposit_liquidity_and_mint_ctokens<TEST_LM, TEST_USDC>(
            &mut reserve, 
            balance::create_for_testing(1000)
        );

        assert!(balance::value(&ctokens) == 200, 0);
        assert!(reserve.available_amount == 1500, 0);
        assert!(reserve.ctoken_supply == 400, 0);

        let balances: &mut Balances<TEST_LM, TEST_USDC> = dynamic_field::borrow_mut(
            &mut reserve.id, 
            BalanceKey {}
        );

        assert!(balance::value(&balances.available_amount) == 1500, 0);
        assert!(balance::supply_value(&balances.ctoken_supply) == 400, 0);

        sui::test_utils::destroy(reserve);
        sui::test_utils::destroy(ctokens);

        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = EDepositLimitExceeded)]
    fun test_deposit_fail() {
        use suilend::test_usdc::{TEST_USDC};
        use sui::test_scenario::{Self};
        use suilend::reserve_config::{default_reserve_config};

        let owner = @0x26;
        let scenario = test_scenario::begin(owner);

        let reserve = create_for_testing<TEST_LM, TEST_USDC>(
            {
                let config = default_reserve_config();
                let builder = reserve_config::from(&config, test_scenario::ctx(&mut scenario));
                reserve_config::set_deposit_limit(&mut builder, 1000);
                sui::test_utils::destroy(config);

                reserve_config::build(builder, test_scenario::ctx(&mut scenario))
            },
            0,
            6,
            decimal::from(1),
            0,
            500,
            200,
            decimal::from(500),
            decimal::from(1),
            1,
            test_scenario::ctx(&mut scenario)
        );

        let coins = balance::create_for_testing<TEST_USDC>(1);
        let ctokens = deposit_liquidity_and_mint_ctokens(&mut reserve, coins);

        sui::test_utils::destroy(reserve);
        sui::test_utils::destroy(ctokens);
        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = EDepositLimitExceeded)]
    fun test_deposit_fail_usd_limit() {
        use suilend::test_usdc::{TEST_USDC};
        use sui::test_scenario::{Self};
        use suilend::reserve_config::{default_reserve_config};

        let owner = @0x26;
        let scenario = test_scenario::begin(owner);

        let reserve = create_for_testing<TEST_LM, TEST_USDC>(
            {
                let config = default_reserve_config();
                let builder = reserve_config::from(&config, test_scenario::ctx(&mut scenario));
                reserve_config::set_deposit_limit(&mut builder, 18_446_744_073_709_551_615);
                reserve_config::set_deposit_limit_usd(&mut builder, 1);
                sui::test_utils::destroy(config);

                reserve_config::build(builder, test_scenario::ctx(&mut scenario))
            },
            0,
            6,
            decimal::from(1),
            0,
            500_000,
            1_000_000,
            decimal::from(500_000),
            decimal::from(1),
            1,
            test_scenario::ctx(&mut scenario)
        );

        let coins = balance::create_for_testing<TEST_USDC>(1);
        let ctokens = deposit_liquidity_and_mint_ctokens(&mut reserve, coins);

        sui::test_utils::destroy(reserve);
        sui::test_utils::destroy(ctokens);
        test_scenario::end(scenario);
    }

    #[test]
    fun test_redeem_happy() {
        use suilend::test_usdc::{TEST_USDC};
        use sui::test_scenario::{Self};
        use suilend::reserve_config::{default_reserve_config};

        let owner = @0x26;
        let scenario = test_scenario::begin(owner);

        let reserve = create_for_testing<TEST_LM, TEST_USDC>(
            default_reserve_config(),
            0,
            6,
            decimal::from(1),
            0,
            500,
            200,
            decimal::from(500),
            decimal::from(1),
            1,
            test_scenario::ctx(&mut scenario)
        );

        let available_amount_old = reserve.available_amount;
        let ctoken_supply_old = reserve.ctoken_supply;

        let ctokens = balance::create_for_testing(10);
        let tokens = redeem_ctokens<TEST_LM, TEST_USDC>(&mut reserve, ctokens);

        assert!(balance::value(&tokens) == 50, 0);
        assert!(reserve.available_amount == available_amount_old - 50, 0);
        assert!(reserve.ctoken_supply == ctoken_supply_old - 10, 0);

        let balances: &mut Balances<TEST_LM, TEST_USDC> = dynamic_field::borrow_mut(
            &mut reserve.id, 
            BalanceKey {}
        );

        assert!(balance::value(&balances.available_amount) == available_amount_old - 50, 0);
        assert!(balance::supply_value(&balances.ctoken_supply) == ctoken_supply_old - 10, 0);

        sui::test_utils::destroy(reserve);
        sui::test_utils::destroy(tokens);

        test_scenario::end(scenario);
    }

    #[test]
    fun test_borrow_happy() {
        use suilend::test_usdc::{TEST_USDC};
        use sui::test_scenario::{Self};
        use suilend::reserve_config::{default_reserve_config};

        let owner = @0x26;
        let scenario = test_scenario::begin(owner);

        let reserve = create_for_testing<TEST_LM, TEST_USDC>(
            {
                let config = default_reserve_config();
                let builder = reserve_config::from(&config, test_scenario::ctx(&mut scenario));
                reserve_config::set_borrow_fee_bps(&mut builder, 100);
                sui::test_utils::destroy(config);

                reserve_config::build(builder, test_scenario::ctx(&mut scenario))
            },
            0,
            6,
            decimal::from(1),
            0,
            0,
            0,
            decimal::from(0),
            decimal::from(1),
            1,
            test_scenario::ctx(&mut scenario)
        );

        let ctokens = deposit_liquidity_and_mint_ctokens<TEST_LM, TEST_USDC>(
            &mut reserve, 
            balance::create_for_testing(1000)
        );

        let available_amount_old = reserve.available_amount;
        let borrowed_amount_old = reserve.borrowed_amount;

        let (tokens, borrowed_amount_with_fee) = borrow_liquidity<TEST_LM, TEST_USDC>(&mut reserve, 400);
        assert!(balance::value(&tokens) == 400, 0);
        assert!(borrowed_amount_with_fee == 404, 0);

        assert!(reserve.available_amount == available_amount_old - 404, 0);
        assert!(reserve.borrowed_amount == add(borrowed_amount_old, decimal::from(404)), 0);

        let balances: &mut Balances<TEST_LM, TEST_USDC> = dynamic_field::borrow_mut(
            &mut reserve.id, 
            BalanceKey {}
        );

        assert!(balance::value(&balances.available_amount) == available_amount_old - 404, 0);
        assert!(balance::value(&balances.fees) == 4, 0);

        let (ctoken_fees, fees) = claim_fees<TEST_LM, TEST_USDC>(&mut reserve);
        assert!(balance::value(&fees) == 4, 0);
        assert!(balance::value(&ctoken_fees) == 0, 0);

        sui::test_utils::destroy(fees);
        sui::test_utils::destroy(ctoken_fees);
        sui::test_utils::destroy(reserve);
        sui::test_utils::destroy(tokens);
        sui::test_utils::destroy(ctokens);

        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = EBorrowLimitExceeded)]
    fun test_borrow_fail() {
        use suilend::test_usdc::{TEST_USDC};
        use sui::test_scenario::{Self};
        use suilend::reserve_config::{default_reserve_config};

        let owner = @0x26;
        let scenario = test_scenario::begin(owner);

        let reserve = create_for_testing<TEST_LM, TEST_USDC>(
            {
                let config = default_reserve_config();
                let builder = reserve_config::from(&config, test_scenario::ctx(&mut scenario));
                reserve_config::set_borrow_limit(&mut builder, 0);
                sui::test_utils::destroy(config);

                reserve_config::build(builder, test_scenario::ctx(&mut scenario))
            },
            0,
            6,
            decimal::from(1),
            0,
            0,
            0,
            decimal::from(0),
            decimal::from(1),
            1,
            test_scenario::ctx(&mut scenario)
        );

        let ctokens = deposit_liquidity_and_mint_ctokens<TEST_LM, TEST_USDC>(
            &mut reserve, 
            balance::create_for_testing(1000)
        );

        let (tokens, _) = borrow_liquidity<TEST_LM, TEST_USDC>(&mut reserve, 1);

        sui::test_utils::destroy(reserve);
        sui::test_utils::destroy(tokens);
        sui::test_utils::destroy(ctokens);

        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = EBorrowLimitExceeded)]
    fun test_borrow_fail_usd_limit() {
        use suilend::test_usdc::{TEST_USDC};
        use sui::test_scenario::{Self};
        use suilend::reserve_config::{default_reserve_config};

        let owner = @0x26;
        let scenario = test_scenario::begin(owner);

        let reserve = create_for_testing<TEST_LM, TEST_USDC>(
            {
                let config = default_reserve_config();
                let builder = reserve_config::from(&config, test_scenario::ctx(&mut scenario));
                reserve_config::set_borrow_limit_usd(&mut builder, 1);
                sui::test_utils::destroy(config);

                reserve_config::build(builder, test_scenario::ctx(&mut scenario))
            },
            0,
            6,
            decimal::from(1),
            0,
            0,
            0,
            decimal::from(0),
            decimal::from(1),
            1,
            test_scenario::ctx(&mut scenario)
        );

        let ctokens = deposit_liquidity_and_mint_ctokens<TEST_LM, TEST_USDC>(
            &mut reserve, 
            balance::create_for_testing(10_000_000)
        );

        let (tokens, _) = borrow_liquidity<TEST_LM, TEST_USDC>(&mut reserve, 1_000_000 + 1);

        sui::test_utils::destroy(reserve);
        sui::test_utils::destroy(tokens);
        sui::test_utils::destroy(ctokens);

        test_scenario::end(scenario);
    }


    #[test]
    fun test_claim_fees() {
        use suilend::test_usdc::{TEST_USDC};
        use sui::test_scenario::{Self};
        use suilend::reserve_config::{default_reserve_config};

        let owner = @0x26;
        let scenario = test_scenario::begin(owner);
        let clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));

        let reserve = create_for_testing<TEST_LM, TEST_USDC>(
            {
                let config = default_reserve_config();
                let builder = reserve_config::from(&config, test_scenario::ctx(&mut scenario));
                reserve_config::set_deposit_limit(&mut builder, 1000 * 1_000_000);
                reserve_config::set_borrow_limit(&mut builder, 1000 * 1_000_000);
                reserve_config::set_borrow_fee_bps(&mut builder, 0);
                reserve_config::set_spread_fee_bps(&mut builder, 5000);
                reserve_config::set_interest_rate_utils(&mut builder, {
                    let v = vector::empty();
                    vector::push_back(&mut v, 0);
                    vector::push_back(&mut v, 100);
                    v
                });
                reserve_config::set_interest_rate_aprs(&mut builder, {
                    let v = vector::empty();
                    vector::push_back(&mut v, 0);
                    vector::push_back(&mut v, 3153600000);
                    v
                });

                sui::test_utils::destroy(config);

                reserve_config::build(builder, test_scenario::ctx(&mut scenario))
            },
            0,
            6,
            decimal::from(1),
            0,
            0,
            0,
            decimal::from(0),
            decimal::from(1),
            0,
            test_scenario::ctx(&mut scenario)
        );

        let ctokens = deposit_liquidity_and_mint_ctokens<TEST_LM, TEST_USDC>(
            &mut reserve, 
            balance::create_for_testing(100 * 1_000_000)
        );

        let (tokens, _) = borrow_liquidity<TEST_LM, TEST_USDC>(&mut reserve, 50 * 1_000_000);

        clock::set_for_testing(&mut clock, 1000);
        compound_interest(&mut reserve, &clock);

        let old_available_amount = reserve.available_amount;
        let old_unclaimed_spread_fees = reserve.unclaimed_spread_fees;

        let (ctoken_fees, fees) = claim_fees<TEST_LM, TEST_USDC>(&mut reserve);

        // 0.5% interest a second with 50% take rate => 0.25% fee on 50 USDC = 0.125 USDC
        assert!(balance::value(&fees) == 125_000, 0);
        assert!(balance::value(&ctoken_fees) == 0, 0);

        assert!(reserve.available_amount == old_available_amount - 125_000, 0);
        assert!(reserve.unclaimed_spread_fees == sub(old_unclaimed_spread_fees, decimal::from(125_000)), 0);

        let balances: &mut Balances<TEST_LM, TEST_USDC> = dynamic_field::borrow_mut(
            &mut reserve.id, 
            BalanceKey {}
        );
        assert!(balance::value(&balances.available_amount) == old_available_amount - 125_000, 0);

        sui::test_utils::destroy(clock);
        sui::test_utils::destroy(ctoken_fees);
        sui::test_utils::destroy(fees);
        sui::test_utils::destroy(reserve);
        sui::test_utils::destroy(tokens);
        sui::test_utils::destroy(ctokens);

        test_scenario::end(scenario);
    }

    #[test]
    fun test_repay_happy() {
        use suilend::test_usdc::{TEST_USDC};
        use sui::test_scenario::{Self};
        use suilend::reserve_config::{default_reserve_config};

        let owner = @0x26;
        let scenario = test_scenario::begin(owner);

        let reserve = create_for_testing<TEST_LM, TEST_USDC>(
            {
                let config = default_reserve_config();
                let builder = reserve_config::from(&config, test_scenario::ctx(&mut scenario));
                reserve_config::set_borrow_fee_bps(&mut builder, 100);
                sui::test_utils::destroy(config);

                reserve_config::build(builder, test_scenario::ctx(&mut scenario))
            },
            0,
            6,
            decimal::from(1),
            0,
            0,
            0,
            decimal::from(0),
            decimal::from(1),
            1,
            test_scenario::ctx(&mut scenario)
        );

        let ctokens = deposit_liquidity_and_mint_ctokens<TEST_LM, TEST_USDC>(
            &mut reserve, 
            balance::create_for_testing(1000)
        );

        let (tokens, _) = borrow_liquidity<TEST_LM, TEST_USDC>(&mut reserve, 400);

        let available_amount_old = reserve.available_amount;
        let borrowed_amount_old = reserve.borrowed_amount;

        repay_liquidity(&mut reserve, tokens, decimal::from_percent_u64(39_901));

        assert!(reserve.available_amount == available_amount_old + 400, 0);
        assert!(reserve.borrowed_amount == sub(borrowed_amount_old, decimal::from_percent_u64(39_901)), 0);

        let balances: &mut Balances<TEST_LM, TEST_USDC> = dynamic_field::borrow_mut(
            &mut reserve.id, 
            BalanceKey {}
        );
        assert!(balance::value(&balances.available_amount) == available_amount_old + 400, 0);

        sui::test_utils::destroy(reserve);
        sui::test_utils::destroy(ctokens);

        test_scenario::end(scenario);
    }

    #[test_only]
    public fun create_for_testing<P, T>(
        config: ReserveConfig,
        array_index: u64,
        mint_decimals: u8,
        price: Decimal,
        price_last_update_timestamp_s: u64,
        available_amount: u64,
        ctoken_supply: u64,
        borrowed_amount: Decimal,
        cumulative_borrow_rate: Decimal,
        interest_last_update_timestamp_s: u64,
        ctx: &mut TxContext
    ): Reserve<P> {
        let lending_market_id = object::new(ctx);

        let reserve = Reserve<P> {
            id: object::new(ctx),
            lending_market_id: object::uid_to_inner(&lending_market_id),
            array_index,
            coin_type: type_name::get<T>(),
            config: cell::new(config),
            mint_decimals,
            price_identifier: {
                let v = vector::empty();
                let i = 0;
                while (i < 32) {
                    vector::push_back(&mut v, 0);
                    i = i + 1;
                };

                price_identifier::from_byte_vec(v)
            },
            price,
            smoothed_price: price,
            price_last_update_timestamp_s,
            available_amount,
            ctoken_supply,
            borrowed_amount,
            cumulative_borrow_rate,
            interest_last_update_timestamp_s,
            unclaimed_spread_fees: decimal::from(0),
            attributed_borrow_value: decimal::from(0),
            deposits_pool_reward_manager: liquidity_mining::new_pool_reward_manager(ctx),
            borrows_pool_reward_manager: liquidity_mining::new_pool_reward_manager(ctx)
        };

        dynamic_field::add(
            &mut reserve.id,
            BalanceKey {},
            Balances<P, T> {
                available_amount: balance::create_for_testing(available_amount),
                ctoken_supply: {
                    let supply = balance::create_supply(CToken<P, T> {});
                    let tokens = balance::increase_supply(&mut supply, ctoken_supply);
                    sui::test_utils::destroy(tokens);
                    supply
                },
                fees: balance::zero<T>(),
                ctoken_fees: balance::zero<CToken<P, T>>(),
                deposited_ctokens: balance::zero<CToken<P, T>>()
            }
        );

        sui::test_utils::destroy(lending_market_id);

        reserve
    }
}
