module stingray::fund{
    use std::{
        type_name::{Self, TypeName},
        string::{Self, String},  
    };

    use sui::{
        coin::{ Self, Coin},
        balance::{Self, Balance},
        bag::{Self, Bag},
        clock::{Clock},
        event::{Self,},
    };

    use stingray::{
        config::{Self, GlobalConfig, AdminCap},
        trader::{Trader},
        fund_share::{Self, MintRequest, FundShare},
    };

    const VERSION: u64 = 1;
    const MIN_AMOUNT_THRESHOLD:u64 = 100;

    // define constant
    const EOverMaxTraderFee: u64 = 0;
    const ETakeLiquidityNotInFund: u64 = 1;
    const EFundTakeLiquidityNotEnough: u64 = 2;
    const ETakeNonLiquidityNotInFund: u64 = 3;
    const EPutAmountNotSet: u64 = 4;
    const EPutAmountNotMatchedPutBalance:u64 = 5;
    const ENonLiquidityInFund: u64 = 6;
    const EEndTimeNotBiggerThanStartTime:u64 = 7;
    const ETraderNotMatched: u64 = 8;
    const ESettleNotFinished: u64 = 9;
    const EFundHasNonBaseAsset: u64 = 10;
    const EBaseTypeNotMatched: u64 = 11;
    const ENotSettle: u64 = 12;
    const EOverInvestTime: u64 = 13;
    const ENotArrivedInvestTime: u64 = 14;
    const EAssetNotInAssetArray: u64 = 15;
    const ETraderInitBalanceNeedToOverThreshold: u64 = 16;
    const EInitValueOverLimit: u64 = 17;
    const EOverFundLimitAmount: u64 = 18;
    const EOperationTimeNotArrived: u64 = 19;
    const EAlreadySettled: u64 = 20;
    const EInTradingPeriod: u64 = 21;
    const EEmptyArray: u64 = 22;
    const ETraderCanNotDeInvest: u64 = 23;
    const EFundNotMatched: u64 = 24;

    // hot potato 
    public struct Take_1_Liquidity_For_1_Liquidity_Request<phantom TakeCoinType, phantom PutCoinType>{
        fund: ID,
        take_amount: u64,
        put_amount: u64,
    }
    public struct Take_1_Liquidity_For_2_Liquidity_Request<phantom TakeCoinType, phantom PutCoinType1, phantom PutCoinType2>{
        fund: ID,
        take_amount: u64,
        put_amount1: u64,
        put_amount2: u64,
    }
    
    public struct Take_1_Liquidity_For_1_NonLiquidity_Request<phantom TakeCoinType, phantom PutAsset>{
        fund: ID,
        take_amount: u64,
        put_amount: u64,
    }

    public struct Take_2_Liquidity_For_1_NonLiquidity_Request<phantom TakeCoinType1, phantom TakeCoinType2, phantom PutAsset>{
        fund: ID,
        take_amount1: u64,
        take_amount2: u64,
        put_amount: u64,
    }
    
    public struct Take_1_NonLiquidity_For_2_Liquidity_Request<phantom TakeAsset, phantom PutCoinType1, phantom PutCoinType2>{
        fund: ID,
        take_amount: u64,
        put_amount1: u64,
        put_amount2: u64,
    }

    public struct SettleRequest{
        fund: ID,
        settler: address,
        is_finished: bool, 
    }

    public struct InvestRecord has store{
        asset_types: vector<TypeName>,
        assets: Bag
    }

    public struct TimeInfo has store {
        start_time: u64,
        invest_duration: u64,
        end_time: u64, 
    }
    

    public struct Fund<phantom CoinType> has key {
        id: UID,
        name: String,
        description: String,
        fund_img: String,
        trader: ID,
        trader_fee: u64,
        asset: InvestRecord,
        base: u64,
        time: TimeInfo,
        is_arena: bool,
        limit_amount: u64,
        is_settle: bool,
        share_amount: u64,
        after_amount: u64,
        expected_roi: u64,
    }

    public struct SettleResult has copy, drop{
        fund: ID,
        trader: ID,
        is_matched_roi: bool,
    }

    public struct CreatedFund has copy, drop {
        id: ID,
        name: String,
        description: String, 
        fund_img: String,
        trader: ID,
        trader_fee: u64,
        start_time: u64,
        invest_duration: u64,
        end_time: u64,
        limit_amount: u64,
        expected_roi: u64,
    }


    public struct Deinvested has copy, drop{
        remain_share: Option<ID>,
        fund_id: ID,
        investor: address,
        withdraw_invest_amount: u64,
    }

    public struct Settled has copy, drop{
        fund: ID,
        settler: address,
        is_finished: bool,
    }

    public struct TraderClaimed<phantom CoinType> has copy, drop{
        trader: ID,
        receiver: address,
        amount: u64,
    }

    public struct Claimed<phantom CoinType> has copy, drop{
        receiver: address,
        fund: ID,
        shares: vector<ID>,
        amount: u64,
    }

    // create fund
    public fun create<FundCoinType> (
        config: &GlobalConfig,
        name: String,
        description: String,
        fund_img: String, 
        trader: &Trader,
        trader_fee: u64,
        is_arena: bool,
        start_time: u64,
        invest_duration: u64,
        end_time: u64,
        limit_amount: u64,
        expected_roi: u64,
        coin: Coin<FundCoinType>,
        ctx: &mut TxContext,
    ): (Fund<FundCoinType>, MintRequest<FundCoinType>){
        
        let init_amount = coin.value();

        config::assert_if_version_not_matched(config, VERSION);
        assert_if_over_max_trader_fee(config, trader_fee);
        assert_if_init_value_over_limit(limit_amount, &coin);
        assert_if_init_value_not_enough<FundCoinType>(config, limit_amount, &coin);
        assert_if_time_setting_wrong(start_time, end_time);
        //assert_if_over_current_time(start_time, clock);

        let mut type_arr = vector::empty<TypeName>();
        let asset_type = type_name::get<Balance<FundCoinType>>();
        type_arr.push_back(asset_type);

        let mut asset_bag = bag::new(ctx);
        asset_bag.add(asset_type, coin.into_balance());

        let investRecord = InvestRecord{
            asset_types: type_arr,
            assets: asset_bag,
        };

        let fund = Fund<FundCoinType>{
            id: object::new(ctx),
            name,
            description,
            fund_img,
            trader: trader.id(),
            trader_fee,
            asset: investRecord,
            base: init_amount,
            time: TimeInfo{
                start_time,
                invest_duration,
                end_time,
            },
            is_arena,
            limit_amount,
            is_settle: false,
            share_amount: init_amount,
            after_amount: 0,
            expected_roi,
        };

        if (!fund.is_arena){
            event::emit(
                CreatedFund{
                    id: *fund.id.as_inner(),
                    name,
                    description,
                    fund_img,
                    trader: trader.id(),
                    trader_fee,
                    start_time,
                    invest_duration,
                    end_time,
                    limit_amount,
                    expected_roi,
                }
            );
        };

        // take mint share request
        let mut fund_type = string::utf8(b"Common");
        
        if (fund.is_arena){
            fund_type=string::utf8(b"Arena");
        };

        let share_request = fund_share::create_mint_request(
            config,
            *fund.id.as_inner(), 
            true,
            fund.trader, 
            fund_type, 
            init_amount, 
            );

        (fund, share_request)
    }

    public fun to_share_object<FundCoinType>(
        fund: Fund<FundCoinType>,
    ){
        transfer::share_object(fund);
    }

    // invest fund
    public fun invest<FundCoinType>(
        config: &GlobalConfig,
        fund: &mut Fund<FundCoinType>,
        invest_coin: Coin<FundCoinType>,
        clock: &Clock,
    ): MintRequest<FundCoinType>{
        config::assert_if_version_not_matched(config, VERSION);
        assert_if_over_invest_duration(fund, clock);
        assert_if_not_arrived_invest_duration(fund, clock);

        let total_base = fund.asset.assets.borrow<TypeName, Balance<FundCoinType>>(type_name::get<Balance<FundCoinType>>());
        let invest_amount = invest_coin.value();
        fund.base = fund.base + invest_amount;
        
        assert_if_base_over_limit<FundCoinType>(fund, (total_base.value() + invest_amount));

        // put coin into asset bag
        let asset_type = type_name::get<Balance<FundCoinType>>();
        fund.asset.assets.borrow_mut<TypeName, Balance<FundCoinType>>(asset_type).join( invest_coin.into_balance());

        // take mint share request
        let mut fund_type = string::utf8(b"Common");
        
        if (fund.is_arena){
            fund_type=string::utf8(b"Arena");
        };

        fund.share_amount = fund.share_amount + invest_amount;

        fund_share::create_mint_request(
            config,
            *fund.id.as_inner(), 
            false,
            fund.trader, 
            fund_type, 
            invest_amount, 
            )
    }

    // cancel_invest
    #[allow(lint(self_transfer))]
    public fun deinvest<FundCoinType>(
        config: &GlobalConfig,
        fund: &mut Fund<FundCoinType>,
        mut shares: vector<FundShare>,
        amount: u64,
        clock: &Clock,
        ctx: &mut TxContext,
    ){  
        config::assert_if_version_not_matched(config, VERSION);
        
        assert_if_over_invest_duration(fund, clock);
        assert_if_not_arrived_invest_duration(fund, clock);
        assert_if_shares_empty(&shares);

        fund.base = fund.base - amount;
        
        let mut total_share = shares.pop_back();
        let loop_times = shares.length();

        fund.share_amount = fund.share_amount - amount;
        
        let mut current_idx = 0;
        while(current_idx < loop_times){
            let share = shares.pop_back();
            assert_if_deinvest_init_share(&share);
            total_share.join(share);
            current_idx = current_idx + 1;
        };

        let deinvest_share = total_share.split(amount, ctx);  
        
        if (total_share.invest_amount() == 0){
            let burn_request = fund_share::create_burn_request<FundCoinType>(config, *fund.id.as_inner());
            fund_share::burn<FundCoinType>(config, burn_request, total_share);
            
            event::emit (Deinvested{
                remain_share: option::none(),
                fund_id: *fund.id.as_inner(),
                investor: ctx.sender(),
                withdraw_invest_amount: amount,
            });
        }else{
            event::emit (Deinvested{
                remain_share: option::some<ID>(total_share.id()),
                fund_id: *fund.id.as_inner(),
                investor: ctx.sender(),
                withdraw_invest_amount: amount,
            });
            transfer::public_transfer(total_share, ctx.sender());
        };

        let fund_asset = fund.asset.assets.borrow_mut<TypeName, Balance<FundCoinType>>(type_name::get<Balance<FundCoinType>>());
        let to_deinvestor = fund_asset.split(deinvest_share.invest_amount());
        
        transfer::public_transfer(coin::from_balance(to_deinvestor, ctx), ctx.sender());

        let burn_request = fund_share::create_burn_request<FundCoinType>(config, *fund.id.as_inner());
        fund_share::burn<FundCoinType>(config, burn_request, deinvest_share);

        vector::destroy_empty(shares);
    }

    // take asset function , i.e scallop deposit, cetus swap
    public fun take_1_liquidity_for_1_liquidity_by_trader< TakeCoinType, PutCoinType, FundCoinType>(
        config: &GlobalConfig,
        fund: &mut Fund<FundCoinType>,
        trader: &Trader,
        amount: u64,
        clock: &Clock,
    ): (Balance<TakeCoinType>, Take_1_Liquidity_For_1_Liquidity_Request<TakeCoinType, PutCoinType>){

        config::assert_if_version_not_matched(config, VERSION);
        assert_if_trader_not_matched<FundCoinType>(fund, trader);

        take_1_liquidity_for_1_liquidity<TakeCoinType, PutCoinType, FundCoinType>(fund, amount, clock)
        
    }

    public fun take_1_liquidity_for_1_liquidity_over_end_time< TakeCoinType, PutCoinType, FundCoinType>(
        config: &GlobalConfig,
        fund: &mut Fund<FundCoinType>,
        amount: u64,
        clock: &Clock,
    ): (Balance<TakeCoinType>, Take_1_Liquidity_For_1_Liquidity_Request<TakeCoinType, PutCoinType>){
        
        config::assert_if_version_not_matched(config, VERSION);
        assert_if_in_end_time(fund, clock);

        take_1_liquidity_for_1_liquidity<TakeCoinType, PutCoinType, FundCoinType>(fund, amount, clock)
        
    }

    public fun take_1_liquidity_for_2_liquidity_by_trader<TakeCoinType, PutCoinType1, PutCoinType2, FundCoinType>(
        config: &GlobalConfig,
        fund: &mut Fund<FundCoinType>,
        trader: &Trader,
        amount: u64,
        clock: &Clock,
    ): (Balance<TakeCoinType>, Take_1_Liquidity_For_2_Liquidity_Request<TakeCoinType, PutCoinType1, PutCoinType2>){

        config::assert_if_version_not_matched(config, VERSION);     
        assert_if_trader_not_matched<FundCoinType>(fund, trader);
        
        take_1_liquidity_for_2_liquidity<TakeCoinType, PutCoinType1, PutCoinType2, FundCoinType>(fund, amount, clock)
    }

    public fun take_1_liquidity_for_2_liquidity_over_end_time<TakeCoinType, PutCoinType1, PutCoinType2, FundCoinType>(
        config: &GlobalConfig,
        fund: &mut Fund<FundCoinType>,
        amount: u64,
        clock: &Clock,
    ): (Balance<TakeCoinType>, Take_1_Liquidity_For_2_Liquidity_Request<TakeCoinType, PutCoinType1, PutCoinType2>){

        config::assert_if_version_not_matched(config, VERSION);     
        assert_if_in_end_time(fund, clock);
        
        take_1_liquidity_for_2_liquidity<TakeCoinType, PutCoinType1, PutCoinType2, FundCoinType>(fund, amount, clock)
    }
    
    public fun take_1_liquidity_for_1_nonliquidity_by_trader<TakeCoinType, PutAsset: store, FundCoinType>(
        config: &GlobalConfig,
        fund: &mut Fund<FundCoinType>,
        trader: &Trader,
        amount: u64,
        clock: &Clock,
    ): (Balance<TakeCoinType>, Take_1_Liquidity_For_1_NonLiquidity_Request<TakeCoinType, PutAsset>){
        
        config::assert_if_version_not_matched(config, VERSION);
        assert_if_trader_not_matched<FundCoinType>(fund, trader);

        take_1_liquidity_for_1_nonliquidity<TakeCoinType, PutAsset, FundCoinType>(fund, amount, clock)
    }

    public fun take_1_liquidity_for_1_nonliquidity_over_end_time<TakeCoinType, PutAsset: store, FundCoinType>(
        config: &GlobalConfig,
        fund: &mut Fund<FundCoinType>,
        amount: u64,
        clock: &Clock,
    ): (Balance<TakeCoinType>, Take_1_Liquidity_For_1_NonLiquidity_Request<TakeCoinType, PutAsset>){
        
        config::assert_if_version_not_matched(config, VERSION);
        assert_if_in_end_time(fund, clock);

        take_1_liquidity_for_1_nonliquidity<TakeCoinType, PutAsset, FundCoinType>(fund, amount, clock)
    }

    public fun take_2_liquidity_for_1_nonliquidity_by_trader<TakeCoinType1, TakeCoinType2, PutAsset: store, FundCoinType>(
        config: &GlobalConfig,
        fund: &mut Fund<FundCoinType>,
        trader: &Trader,
        amount1: u64,
        amount2: u64,
        clock: &Clock,
    ): (Balance<TakeCoinType1>, Balance<TakeCoinType2>, Take_2_Liquidity_For_1_NonLiquidity_Request<TakeCoinType1, TakeCoinType2, PutAsset>){
        
        config::assert_if_version_not_matched(config, VERSION);
        assert_if_trader_not_matched<FundCoinType>(fund, trader);

        take_2_liquidity_for_1_nonliquidity<TakeCoinType1, TakeCoinType2, PutAsset, FundCoinType>(fund, amount1, amount2,  clock)
    }

    public fun take_2_liquidity_for_1_nonliquidity_over_end_time<TakeCoinType1, TakeCoinType2, PutAsset: store, FundCoinType>(
        config: &GlobalConfig,
        fund: &mut Fund<FundCoinType>,
        amount1: u64,
        amount2: u64,
        clock: &Clock,
    ): (Balance<TakeCoinType1>, Balance<TakeCoinType2>, Take_2_Liquidity_For_1_NonLiquidity_Request<TakeCoinType1, TakeCoinType2, PutAsset>){
        
        config::assert_if_version_not_matched(config, VERSION);
        assert_if_in_end_time(fund, clock);

        take_2_liquidity_for_1_nonliquidity<TakeCoinType1, TakeCoinType2, PutAsset, FundCoinType>(fund, amount1, amount2, clock)
    }

    public fun take_1_nonliquidity_for_2_liquidity_by_trader<TakeAsset: store, PutCoinType1, PutCoinType2, FundCoinType>(
        config: &GlobalConfig,
        fund: &mut Fund<FundCoinType>,
        trader: &Trader,
        clock: &Clock,
    ): (TakeAsset, Take_1_NonLiquidity_For_2_Liquidity_Request<TakeAsset, PutCoinType1, PutCoinType2>){
        
        config::assert_if_version_not_matched(config, VERSION);
        assert_if_trader_not_matched<FundCoinType>(fund, trader);

        take_1_nonliquidity_for_2_liquidity<TakeAsset, PutCoinType1, PutCoinType2, FundCoinType>(fund, clock)
    }

    public fun take_1_nonliquidity_for_2_liquidity_over_end_time<TakeAsset: store, PutCoinType1, PutCoinType2, FundCoinType>(
        config: &GlobalConfig,
        fund: &mut Fund<FundCoinType>,
        clock: &Clock,
    ): (TakeAsset, Take_1_NonLiquidity_For_2_Liquidity_Request<TakeAsset, PutCoinType1, PutCoinType2>){
        
        config::assert_if_version_not_matched(config, VERSION);
        assert_if_in_end_time(fund, clock);

        take_1_nonliquidity_for_2_liquidity<TakeAsset, PutCoinType1, PutCoinType2, FundCoinType>(fund, clock)
    }

    // put asset function 
    public fun put_1_liquidity_for_1_liquidity_by_all< TakeCoinType, PutCoinType, FundCoinType>(
        config: &GlobalConfig,
        fund: &mut Fund<FundCoinType>,
        request: Take_1_Liquidity_For_1_Liquidity_Request<TakeCoinType, PutCoinType>,
        liquidity: Balance<PutCoinType>,
    ){
        
        config::assert_if_version_not_matched(config, VERSION);
        
        put_1_liquidity_for_1_liquidity< TakeCoinType, PutCoinType, FundCoinType>(fund, request, liquidity);

    }

    public fun put_1_liquidity_for_2_liquidity_by_all<TakeCoinType, PutCoinType1, PutCoinType2, FundCoinType>(
        config: &GlobalConfig,
        fund: &mut Fund<FundCoinType>,
        request: Take_1_Liquidity_For_2_Liquidity_Request<TakeCoinType, PutCoinType1, PutCoinType2>,
        liquidity1: Balance<PutCoinType1>,
        liquidity2: Balance<PutCoinType2>,
    ){

        config::assert_if_version_not_matched(config, VERSION);
        
        put_1_liquidity_for_2_liquidity<TakeCoinType, PutCoinType1, PutCoinType2, FundCoinType>(fund, request, liquidity1, liquidity2);
    }

    public fun put_1_liquidity_for_1_nonliquidity_by_all<TakeCoinType, PutAsset: store, FundCoinType>(
        config: &GlobalConfig,
        fund: &mut Fund<FundCoinType>,
        request: Take_1_Liquidity_For_1_NonLiquidity_Request<TakeCoinType, PutAsset>,
        nonliquidity: PutAsset,
    ){
        
        config::assert_if_version_not_matched(config, VERSION);

        put_1_liquidity_for_1_nonliquidity<TakeCoinType, PutAsset, FundCoinType>(fund, request, nonliquidity);
        
    }
    

    public fun put_1_nonliquidity_for_2_liquidity_by_all<TakeAsset: store, PutCoinType1, PutCoinType2, FundCoinType>(
        config: &GlobalConfig,
        fund: &mut Fund<FundCoinType>,
        request: Take_1_NonLiquidity_For_2_Liquidity_Request<TakeAsset, PutCoinType1, PutCoinType2>,
        liquidity1: Balance<PutCoinType1>,
        liquidity2: Balance<PutCoinType2>,
    ){

        config::assert_if_version_not_matched(config, VERSION);
        
        put_1_nonliquidity_for_2_liquidity<TakeAsset, PutCoinType1, PutCoinType2, FundCoinType>(fund, request, liquidity1, liquidity2 );
    }

    public fun check_and_clean<FundCoinType, CoinType>(
        fund: &mut Fund<FundCoinType>,
    ){
        let asset_type = type_name::get<Balance<CoinType>>();

        let (is_contain, idx) = fund.asset.asset_types.index_of(&asset_type);
        if (is_contain){
            let asset_amount = fund.asset.assets.borrow<TypeName, Balance<CoinType>>(asset_type).value();
        
            if (asset_amount <= MIN_AMOUNT_THRESHOLD){
                fund.asset.asset_types.swap_remove(idx);
            };
        };
        
    }

    public fun create_settle_request< FundCoinType>(
        config: &GlobalConfig,
        fund: &mut Fund<FundCoinType>,
        is_finished: bool,
        _share: &FundShare,
        ctx: &TxContext,
    ): SettleRequest{
        
        config::assert_if_version_not_matched(config, VERSION);
        
        SettleRequest{
            fund: *fund.id.as_inner(),
            settler: ctx.sender(),
            is_finished,
        }
    }

    public fun finish_settle_request(
        config: &GlobalConfig,
        settle_request: &mut SettleRequest,
    ){

        config::assert_if_version_not_matched(config, VERSION);
        settle_request.is_finished = true;

    }
    
    public fun settle<FundCoinType>(
        config: &GlobalConfig,
        fund: &mut Fund<FundCoinType>,
        request: SettleRequest, 
        ctx: &mut TxContext,
    ): Coin<FundCoinType>{
        config::assert_if_version_not_matched(config, VERSION);
        assert_if_not_finished(&request);
        assert_if_fund_has_nonbasic_asset(fund);

        let fund_id = *fund.id.as_inner();

        let SettleRequest{
            fund: _,
            settler: _,
            is_finished: _, 
        } = request;

        fund.is_settle = true;
        
        event::emit(
            Settled{
                fund: *fund.id.as_inner(),
                settler: ctx.sender(),
                is_finished: true,
            }
        );
        
        // calculate rewards
        let total_base = fund.asset.assets.borrow<TypeName, Balance<FundCoinType>>(type_name::get<Balance<FundCoinType>>()).value();
        let fund_base = fund.base;
        let expected_base = fund_base * (config.base_percentage() + fund.expected_roi) /config.base_percentage();
        fund.after_amount = total_base;
        if (total_base > fund_base){ // positive rewards
            if ((total_base - fund_base) < config.min_rewards()){ // less than min reward threshold
                pay_platforem_fee(config, fund, (total_base - fund_base), ctx);
                
                if(total_base >= expected_base){
                    event::emit(
                        SettleResult{
                            fund: fund_id,
                            trader: fund.trader(),
                            is_matched_roi: true,
                        }
                    );
                }else{
                    event::emit(
                        SettleResult{
                            fund: fund_id,
                            trader: fund.trader(),
                            is_matched_roi: false,
                        }
                    );
                };

                coin::from_balance<FundCoinType>(balance::zero<FundCoinType>(), ctx)
            }else{
                let total = fund.asset.assets.borrow_mut<TypeName, Balance<FundCoinType>>(type_name::get<Balance<FundCoinType>>());
                let reward_amount = total_base - fund_base;
                let platform_fee = reward_amount * config.platform_fee() / config.base_percentage();
                let to_settler_value = reward_amount *  config.settle_percentage() / config.base_percentage();
                let to_settle_balance = total.split(to_settler_value);
                pay_platforem_fee(config, fund, platform_fee, ctx);

                if(total_base >= expected_base){
                    event::emit(
                        SettleResult{
                            fund: fund_id,
                            trader: fund.trader(),
                            is_matched_roi: true,
                        }
                    );
                }else{
                    event::emit(
                        SettleResult{
                            fund: fund_id,
                            trader: fund.trader(),
                            is_matched_roi: false,
                        }
                    );
                };

                coin::from_balance<FundCoinType>(to_settle_balance, ctx)
            }
        }else{
            event::emit(
            SettleResult{
                fund: fund_id,
                trader: fund.trader(),
                is_matched_roi: false,
                }
            );
            coin::from_balance<FundCoinType>(balance::zero<FundCoinType>(), ctx)
        }

    }

    public fun claim<FundCoinType>(
        config: &GlobalConfig,
        fund: &mut Fund<FundCoinType>,
        mut shares: vector<FundShare>,
        ctx: &mut TxContext,
    ): (Coin<FundCoinType>){

        config::assert_if_version_not_matched(config, VERSION);
        assert_if_not_settle(fund);

        let loop_times = shares.length();
        let mut total_withdraw_share_amount:u64 = 0;
        let mut current_idx = 0;
        let mut share_ids = vector::empty<ID>();

        while(current_idx < loop_times){
            let share = shares.pop_back();
            share_ids.push_back(share.id());
            assert_if_fund_type_not_matched<FundCoinType>(fund, &share);
            total_withdraw_share_amount = total_withdraw_share_amount + share.invest_amount();
            
            let burn_request = fund_share::create_burn_request<FundCoinType>(config, *fund.id.as_inner());
            fund_share::burn<FundCoinType>(config, burn_request, share);

            current_idx = current_idx + 1;
        };

        vector::destroy_empty(shares);
        
        if (fund.after_amount < fund.base ){
            let total_asset = fund.asset.assets.borrow_mut<TypeName, Balance<FundCoinType>>(type_name::get<Balance<FundCoinType>>());
            let withdraw_amount = fund.after_amount * total_withdraw_share_amount / fund.share_amount;

            event::emit(
                Claimed<FundCoinType>{
                    receiver: ctx.sender(),
                    fund: *fund.id.as_inner(),
                    amount: withdraw_amount,
                    shares: share_ids,
                }
            );

            coin::from_balance<FundCoinType>(total_asset.split(withdraw_amount), ctx)
        }else{
            // calculate rewards
            if (fund.after_amount - fund.base >= config.min_rewards()){
                let total_asset = fund.asset.assets.borrow_mut<TypeName, Balance<FundCoinType>>(type_name::get<Balance<FundCoinType>>());
                let platform_fee = (fund.after_amount - fund.base) * config.platform_fee() / config.base_percentage();
                let trader_fee = (fund.after_amount - fund.base) * fund.trader_fee / config.base_percentage();
                let investor_amount = (fund.after_amount - platform_fee - trader_fee) * total_withdraw_share_amount / fund.share_amount;
                let to_investor_balance = total_asset.split<FundCoinType>(investor_amount);

                event::emit(
                    Claimed<FundCoinType>{
                        receiver: ctx.sender(),
                        fund: *fund.id.as_inner(),
                        amount: investor_amount,
                        shares: share_ids,
                    }
                );

                coin::from_balance<FundCoinType>(to_investor_balance, ctx)
            }else{
                let total_asset = fund.asset.assets.borrow_mut<TypeName, Balance<FundCoinType>>(type_name::get<Balance<FundCoinType>>());
                let final_amount = fund.base * total_withdraw_share_amount / fund.share_amount;
                
                event::emit(
                    Claimed<FundCoinType>{
                        receiver: ctx.sender(),
                        fund: *fund.id.as_inner(),
                        amount: final_amount,
                        shares: share_ids,
                    }
                );
                coin::from_balance<FundCoinType>(total_asset.split(final_amount), ctx)
            }
        }
    }
    public fun trader_claim<FundCoinType>(
        config: &GlobalConfig,
        fund: &mut Fund<FundCoinType>,
        trader: &Trader,
        ctx: &mut TxContext,
    ): Coin<FundCoinType>{
        assert_if_trader_not_matched(fund, trader);
        assert_if_not_settle(fund);
        
        if (fund.after_amount >= fund.base ){
            if (fund.after_amount - fund.base >= config.min_rewards()){
                let total_asset = fund.asset.assets.borrow_mut<TypeName, Balance<FundCoinType>>(type_name::get<Balance<FundCoinType>>());
                let trader_amount = ( fund.after_amount - fund.base ) * fund.trader_fee / config.base_percentage();
                let to_trader_balance = total_asset.split<FundCoinType>(trader_amount);
  event::emit(
                    TraderClaimed<FundCoinType>{
                        trader: trader.id(),
                        receiver: ctx.sender(),
                        amount: trader_amount,
                    }
                );
                coin::from_balance<FundCoinType>(to_trader_balance, ctx)
            }else{
                event::emit(
                    TraderClaimed<FundCoinType>{
                        trader: trader.id(),
                        receiver: ctx.sender(),
                        amount: 0,
                    }
                );
                coin::from_balance<FundCoinType>(balance::zero<FundCoinType>(), ctx)
            }
        }else{
            event::emit(
                    TraderClaimed<FundCoinType>{
                        trader: trader.id(),
                        receiver: ctx.sender(),
                        amount: 0,
                    }
            );
            coin::from_balance<FundCoinType>(balance::zero<FundCoinType>(), ctx)
        }
    }

    public fun invest_duration<CoinType>(
        fund: &Fund<CoinType>,
    ):u64{
        fund.time.invest_duration
    }

    public fun trader_fee<CoinType>(
        fund: &Fund<CoinType>,
    ):u64{
        fund.trader_fee
    }

    public fun fund_img<CoinType>(
        fund: &Fund<CoinType>,
    ):String{
        fund.fund_img
    }

    public fun name<CoinType>(
        fund: &Fund<CoinType>,
    ):String{
        fund.name
    }

    public fun description<CoinType>(
        fund: &Fund<CoinType>,
    ):String{
        fund.description
    }

    public fun after_amount<CoinType>(
        fund: &Fund<CoinType>,
    ):u64{
        fund.after_amount
    }

    public fun base<CoinType>(
        fund: &Fund<CoinType>,
    ):u64{
        fund.base
    }

    public fun is_arena<CoinType>(
        fund: &Fund<CoinType>,
    ): bool{
        fund.is_arena
    }

    public fun trader<CoinType>(
        fund: &Fund<CoinType>,
    ): ID{
        fund.trader
    }

    public fun end_time<CoinType>(
        fund: &Fund<CoinType>
    ): u64{
        fund.time.end_time
    }

    public fun start_time<CoinType>(
        fund: &Fund<CoinType>
    ):u64{
        fund.time.start_time
    }

    public fun limit_amount<CoinType>(
        fund: &Fund<CoinType>
    ):u64{
        fund.limit_amount
    }

    public fun expected_roi<CoinType>(
        fund: &Fund<CoinType>
    ):u64{
        fund.expected_roi
    }

    public (package) fun fund_id_of_1l_for_1l_req<TakeCoinType, PutCoinType>(
        request: &Take_1_Liquidity_For_1_Liquidity_Request<TakeCoinType, PutCoinType>,
    ): ID{
        request.fund
    }

    public (package) fun fund_id_of_1l_for_2l_req<TakeCoinType, PutCoinType1, PutCoinType2>(
        request: &Take_1_Liquidity_For_2_Liquidity_Request<TakeCoinType, PutCoinType1, PutCoinType2>,
    ): ID{
        request.fund
    }

    public (package) fun fund_id_of_1l_for_1nl_req<TakeCoinType, PutAsset>(
        request: &Take_1_Liquidity_For_1_NonLiquidity_Request<TakeCoinType, PutAsset>,
    ): ID{
        request.fund
    }


    public (package) fun fund_id_of_1nl_for_2l_req<TakeAsset, PutCoinType1, PutCoinType2>(
        request: &Take_1_NonLiquidity_For_2_Liquidity_Request<TakeAsset, PutCoinType1, PutCoinType2>,
    ): ID{
        request.fund
    }

    public(package) fun id <CoinType>(
        fund: &mut Fund<CoinType>
    ): &mut UID{
        &mut fund.id
    }

    public(package) fun update_time<FundCoinType>(
        fund: &mut Fund<FundCoinType>,
        start_time: u64,
        invest_duration: u64,
        end_time: u64,
    ){
        fund.time.start_time = start_time;
        fund.time.invest_duration = invest_duration;
        fund.time.end_time = end_time;
    }

    public(package) fun update_description<FundCoinType>(
        fund: &mut Fund<FundCoinType>,
        new_description: String,
        trader: &Trader,
    ){
        assert_if_trader_not_matched(fund, trader);
        fund.description = new_description;
    }

    public(package) fun set_is_arena<FundCoinType>(
        fund: &mut Fund<FundCoinType>,
        is_arena: bool,
    ){
        fund.is_arena = is_arena;
    }

    // defi confirm 
    public(package) fun supported_defi_confirm_1l_for_1l<TakeCoinType, PutCoinType>(
        reqeust: &mut Take_1_Liquidity_For_1_Liquidity_Request<TakeCoinType, PutCoinType>,
        put_amount: u64,
    ){
        reqeust.put_amount = put_amount;
    }

    public(package) fun supported_defi_confirm_1l_for_2l<TakeCoinType, PutCoinType1, PutCoinType2 >(
        reqeust: &mut Take_1_Liquidity_For_2_Liquidity_Request<TakeCoinType, PutCoinType1, PutCoinType2>,
        put_amount1: u64,
        put_amount2: u64,
    ){
        reqeust.put_amount1 = put_amount1;
        reqeust.put_amount2 = put_amount2;
    }

    public(package) fun supported_defi_confirm_1l_for_1nl<TakeCoinType, PutAsset: store >(
        reqeust: &mut Take_1_Liquidity_For_1_NonLiquidity_Request<TakeCoinType, PutAsset>,
        put_amount: u64,
    ){
        reqeust.put_amount = put_amount;
    }


    public(package) fun supported_defi_confirm_1nl_for_2l<TakeAsset: store, PutCoinType1, PutCoinType2>(
        request: &mut Take_1_NonLiquidity_For_2_Liquidity_Request<TakeAsset, PutCoinType1, PutCoinType2>,
        put_amount1: u64,
        put_amount2: u64,
    ){
        request.put_amount1 = put_amount1;
        request.put_amount2 = put_amount2;
    }

    public(package) fun supported_defi_confirm_2l_for_1nl<TakeCoinType1, TakeCoinType2, PutAsset>(
        reqeust: &mut Take_2_Liquidity_For_1_NonLiquidity_Request<TakeCoinType1, TakeCoinType2, PutAsset>,
        put_amount: u64,
    ){
        reqeust.put_amount = put_amount;
    }

    fun take_1_liquidity_for_1_liquidity< TakeCoinType, PutCoinType, FundCoinType>(
        fund: &mut Fund<FundCoinType>,
        mut amount: u64,
        clock: &Clock,
    ): (Balance<TakeCoinType>, Take_1_Liquidity_For_1_Liquidity_Request<TakeCoinType, PutCoinType>){
        
        assert_if_take_action_not_available<FundCoinType>(fund, clock);
        assert_if_take_liquidity_not_in_fund<TakeCoinType, FundCoinType>(fund);
        //assert_if_take_amount_not_enough<TakeCoinType, FundCoinType>(fund, amount);
        amount = check_take_amount<TakeCoinType, FundCoinType>(fund, amount);
        assert_if_is_settled(fund);

        let total_balance = fund.asset.assets.borrow_mut<TypeName, Balance<TakeCoinType>>(type_name::get<Balance<TakeCoinType>>());
        let total_value = total_balance.value();
        let take_balance = total_balance.split(amount);
        let take_request = Take_1_Liquidity_For_1_Liquidity_Request<TakeCoinType, PutCoinType>{
            fund: *fund.id().as_inner(),
            take_amount: take_balance.value(),
            put_amount: 0,
        };

        if (amount == total_value){
            let take_asset_type = type_name::get<Balance<TakeCoinType>>();
            let idx = assert_if_not_inclued_in_asset_array(fund, take_asset_type);
            fund.asset.asset_types.swap_remove(idx);
        };

        (take_balance, take_request)
    }

    fun take_1_liquidity_for_2_liquidity<TakeCoinType, PutCoinType1, PutCoinType2, FundCoinType>(
        fund: &mut Fund<FundCoinType>,
        mut amount: u64,
        clock: &Clock,
    ): (Balance<TakeCoinType>, Take_1_Liquidity_For_2_Liquidity_Request<TakeCoinType, PutCoinType1, PutCoinType2>){
        
        assert_if_take_action_not_available<FundCoinType>(fund, clock);
        assert_if_take_liquidity_not_in_fund<TakeCoinType, FundCoinType>(fund);
        // assert_if_take_amount_not_enough<TakeCoinType, FundCoinType>(fund, amount);
        amount = check_take_amount<TakeCoinType, FundCoinType>(fund, amount);
        assert_if_is_settled(fund);

        let total_balance = fund.asset.assets.borrow_mut<TypeName, Balance<TakeCoinType>>(type_name::get<Balance<TakeCoinType>>());
        let total_value = total_balance.value();
        let take_balance = total_balance.split(amount);
        let take_request = Take_1_Liquidity_For_2_Liquidity_Request<TakeCoinType, PutCoinType1, PutCoinType2>{
            fund: *fund.id().as_inner(),
            take_amount: take_balance.value(),
            put_amount1: 0,
            put_amount2: 0,
        };

        if (amount == total_value){
            let take_asset_type = type_name::get<Balance<TakeCoinType>>();
            let idx = assert_if_not_inclued_in_asset_array(fund, take_asset_type);
            fund.asset.asset_types.remove(idx);
        };

        (take_balance, take_request)
    }

    fun take_1_liquidity_for_1_nonliquidity<TakeCoinType, PutAsset: store, FundCoinType>(
        fund: &mut Fund<FundCoinType>,
        mut amount: u64,
        clock: &Clock,
    ): (Balance<TakeCoinType>, Take_1_Liquidity_For_1_NonLiquidity_Request<TakeCoinType, PutAsset>){
        
        assert_if_take_action_not_available<FundCoinType>(fund, clock);
        assert_if_take_liquidity_not_in_fund<TakeCoinType, FundCoinType>(fund);
        //assert_if_take_amount_not_enough<TakeCoinType, FundCoinType>(fund, amount);
        amount = check_take_amount<TakeCoinType, FundCoinType>(fund, amount);
        assert_if_is_settled(fund);

        let total_balance = fund.asset.assets.borrow_mut<TypeName, Balance<TakeCoinType>>(type_name::get<Balance<TakeCoinType>>());
        let total_value = total_balance.value();
        let take_balance = total_balance.split(amount);
        
        let take_request = Take_1_Liquidity_For_1_NonLiquidity_Request<TakeCoinType, PutAsset>{
            fund: *fund.id().as_inner(),
            take_amount: take_balance.value(),
            put_amount: 0,
        };

        if (amount == total_value){
            let take_asset_type = type_name::get<Balance<TakeCoinType>>();
            let idx = assert_if_not_inclued_in_asset_array(fund, take_asset_type);
            fund.asset.asset_types.swap_remove(idx);
        };

        (take_balance, take_request)
    }

    fun take_2_liquidity_for_1_nonliquidity<TakeCoinType1, TakeCoinType2, PutAsset, FundCoinType>(
        fund: &mut Fund<FundCoinType>,
        mut amount1: u64,
        mut amount2: u64,
        clock: &Clock,
    ): (Balance<TakeCoinType1>, Balance<TakeCoinType2>, Take_2_Liquidity_For_1_NonLiquidity_Request<TakeCoinType1, TakeCoinType2, PutAsset>){
        
        assert_if_take_action_not_available<FundCoinType>(fund, clock);
        assert_if_take_liquidity_not_in_fund<TakeCoinType1, FundCoinType>(fund);
        assert_if_take_liquidity_not_in_fund<TakeCoinType2, FundCoinType>(fund);
        // assert_if_take_amount_not_enough<TakeCoinType1, FundCoinType>(fund, amount1);
        // assert_if_take_amount_not_enough<TakeCoinType2, FundCoinType>(fund, amount2);
        amount1 = check_take_amount<TakeCoinType1, FundCoinType>(fund, amount1);
        amount2 = check_take_amount<TakeCoinType2, FundCoinType>(fund, amount2);
        assert_if_is_settled(fund);

        let total_balance1 = fund.asset.assets.borrow_mut<TypeName, Balance<TakeCoinType1>>(type_name::get<Balance<TakeCoinType1>>());
        let total_value1 = total_balance1.value();
        let take_balance1 = total_balance1.split(amount1);

        let total_balance2 = fund.asset.assets.borrow_mut<TypeName, Balance<TakeCoinType2>>(type_name::get<Balance<TakeCoinType2>>());
        let total_value2 = total_balance2.value();
        let take_balance2 = total_balance2.split(amount2);
        
        let take_request = Take_2_Liquidity_For_1_NonLiquidity_Request<TakeCoinType1, TakeCoinType2,  PutAsset>{
            fund: *fund.id().as_inner(),
            take_amount1: take_balance1.value(),
            take_amount2: take_balance2.value(),
            put_amount: 0,
        };

        if (amount1 == total_value1){
            let take_asset_type1 = type_name::get<Balance<TakeCoinType1>>();
            let idx = assert_if_not_inclued_in_asset_array(fund, take_asset_type1);
            fund.asset.asset_types.swap_remove(idx);
        };

        if (amount2 == total_value2){
            let take_asset_type2 = type_name::get<Balance<TakeCoinType2>>();
            let (_, idx) = fund.asset.asset_types.index_of(&take_asset_type2);
            fund.asset.asset_types.swap_remove(idx);
        };

        (take_balance1, take_balance2, take_request)
    }

    fun take_1_nonliquidity_for_2_liquidity<TakeAsset: store, PutCoinType1, PutCoinType2, FundCoinType>(
        fund: &mut Fund<FundCoinType>,
        clock: &Clock,
    ): (TakeAsset, Take_1_NonLiquidity_For_2_Liquidity_Request<TakeAsset, PutCoinType1, PutCoinType2>){

        assert_if_take_action_not_available<FundCoinType>(fund, clock);
        assert_if_take_nonliquidity_not_in_fund<TakeAsset, FundCoinType>(fund);
        assert_if_is_settled(fund);
        
        let asset_type = type_name::get<TakeAsset>();
        let take_asset = fund.asset.assets.remove<TypeName, TakeAsset>(asset_type);

        let idx = assert_if_not_inclued_in_asset_array(fund, asset_type);
        fund.asset.asset_types.swap_remove(idx);
        
        let take_request = Take_1_NonLiquidity_For_2_Liquidity_Request<TakeAsset,PutCoinType1, PutCoinType2>{
            fund: *fund.id().as_inner(),
            take_amount: 1,
            put_amount1: 0,
            put_amount2: 0,
        };

        (take_asset, take_request)
    }

    fun put_1_liquidity_for_1_liquidity< TakeCoinType, PutCoinType, FundCoinType>(
        fund: &mut Fund<FundCoinType>,
        request: Take_1_Liquidity_For_1_Liquidity_Request<TakeCoinType, PutCoinType>,
        liquidity: Balance<PutCoinType>,
    ){
        
        let Take_1_Liquidity_For_1_Liquidity_Request{
            fund:_,
            take_amount: _,
            put_amount,
        } = request;

        assert_if_put_amount_is_zero(put_amount);
        assert_if_put_liquidity_not_equal_to_put_amount(put_amount, liquidity.value());

        let asset_type = type_name::get<Balance<PutCoinType>>();
        let (is_contain, _) = fund.asset.asset_types.index_of(&asset_type);
        if (is_contain){
            let fund_asset = fund.asset.assets.borrow_mut<TypeName, Balance<PutCoinType>>(asset_type);
            fund_asset.join(liquidity);
        }else{
            fund.asset.asset_types.push_back(asset_type);
            if (fund.asset.assets.contains(asset_type)){
                let fund_asset = fund.asset.assets.borrow_mut<TypeName, Balance<PutCoinType>>(asset_type);
                fund_asset.join(liquidity);
            }else{
                fund.asset.assets.add(asset_type, liquidity);
            };
            
        };

    }

    fun put_1_liquidity_for_2_liquidity<TakeCoinType, PutCoinType1, PutCoinType2, FundCoinType>(
        fund: &mut Fund<FundCoinType>,
        request: Take_1_Liquidity_For_2_Liquidity_Request<TakeCoinType, PutCoinType1, PutCoinType2>,
        liquidity1: Balance<PutCoinType1>,
        liquidity2: Balance<PutCoinType2>,
    ){

        let Take_1_Liquidity_For_2_Liquidity_Request{
            fund: _,
            take_amount: _,
            put_amount1,
            put_amount2,
        } = request;

        assert_if_put_amount_is_zero(put_amount1);
        assert_if_put_amount_is_zero(put_amount2);
        assert_if_put_liquidity_not_equal_to_put_amount(put_amount1, liquidity1.value());
        assert_if_put_liquidity_not_equal_to_put_amount(put_amount2, liquidity2.value());

        let asset_type1 = type_name::get<Balance<PutCoinType1>>();
        let asset_type2 = type_name::get<Balance<PutCoinType2>>();
        
        let (is_contain1, _) = fund.asset.asset_types.index_of(&asset_type1);
        if (is_contain1){
            let fund_asset = fund.asset.assets.borrow_mut<TypeName, Balance<PutCoinType1>>(asset_type1);
            fund_asset.join(liquidity1);
        }else{
            fund.asset.asset_types.push_back(asset_type1);
            if (fund.asset.assets.contains(asset_type1)){
                let fund_asset = fund.asset.assets.borrow_mut<TypeName, Balance<PutCoinType1>>(asset_type1);
                fund_asset.join(liquidity1);
            }else{
                fund.asset.assets.add(asset_type1, liquidity1);
            };

        };
     
        let (is_contain2, _) = fund.asset.asset_types.index_of(&asset_type2);
        if (is_contain2){
            let fund_asset = fund.asset.assets.borrow_mut<TypeName, Balance<PutCoinType2>>(asset_type2);
            fund_asset.join(liquidity2);
        }else{
            fund.asset.asset_types.push_back(asset_type2);
            if (fund.asset.assets.contains(asset_type2)){
                let fund_asset = fund.asset.assets.borrow_mut<TypeName, Balance<PutCoinType2>>(asset_type2);
                fund_asset.join(liquidity2);
            }else{
                fund.asset.assets.add(asset_type2, liquidity2);
            };
        };
    }

    fun put_1_liquidity_for_1_nonliquidity<TakeCoinType, PutAsset: store, FundCoinType>(
        fund: &mut Fund<FundCoinType>,
        request: Take_1_Liquidity_For_1_NonLiquidity_Request<TakeCoinType, PutAsset>,
        nonliquidity: PutAsset,
    ){
        
        let Take_1_Liquidity_For_1_NonLiquidity_Request{
            fund:_,
            take_amount: _,
            put_amount,
        } = request;

        assert_if_put_amount_is_zero(put_amount);

        let asset_type = type_name::get<PutAsset>();
        assert_if_nonliquidity_in_asset_bag<PutAsset, FundCoinType>(fund,);
        fund.asset.asset_types.push_back(asset_type);
        fund.asset.assets.add(asset_type, nonliquidity);
    }

    fun put_1_nonliquidity_for_2_liquidity<TakeAsset: store, PutCoinType1, PutCoinType2, FundCoinType>(
        fund: &mut Fund<FundCoinType>,
        request: Take_1_NonLiquidity_For_2_Liquidity_Request<TakeAsset, PutCoinType1, PutCoinType2>,
        liquidity1: Balance<PutCoinType1>,
        liquidity2: Balance<PutCoinType2>,
    ){
        
        let Take_1_NonLiquidity_For_2_Liquidity_Request{
            fund: _,
            take_amount: _,
            put_amount1,
            put_amount2: _,
        } = request;

        // check one of these asset
        assert_if_put_amount_is_zero(put_amount1);
        // assert_if_put_amount_is_zero(put_amount2);
       
        assert_if_put_liquidity_not_equal_to_put_amount(put_amount1, liquidity1.value()); 
        //assert_if_put_liquidity_not_equal_to_put_amount(put_amount2, liquidity2.value());      

        let asset_type1 = type_name::get<Balance<PutCoinType1>>();
        let asset_type2 = type_name::get<Balance<PutCoinType2>>();
        
        let (is_contain1, _) = fund.asset.asset_types.index_of(&asset_type1);
        if (is_contain1){
            let fund_asset = fund.asset.assets.borrow_mut<TypeName, Balance<PutCoinType1>>(asset_type1);
            fund_asset.join(liquidity1);
        }else{
            fund.asset.asset_types.push_back(asset_type1);
            if (fund.asset.assets.contains(asset_type1)){
                let fund_asset = fund.asset.assets.borrow_mut<TypeName, Balance<PutCoinType1>>(asset_type1);
                fund_asset.join(liquidity1);
            }else{
                fund.asset.assets.add(asset_type1, liquidity1);
            };
        };

        let (is_contain2, _) = fund.asset.asset_types.index_of(&asset_type2);
        if (is_contain2){
            let fund_asset = fund.asset.assets.borrow_mut<TypeName, Balance<PutCoinType2>>(asset_type2);
            fund_asset.join(liquidity2);
        }else{
            fund.asset.asset_types.push_back(asset_type2);
            if (fund.asset.assets.contains(asset_type2)){
                let fund_asset = fund.asset.assets.borrow_mut<TypeName, Balance<PutCoinType2>>(asset_type2);
                fund_asset.join(liquidity2);
            }else{
                fund.asset.assets.add(asset_type2, liquidity2);
            };
        };

    }


    fun check_take_amount<TakeCoinType, FundCoinType>(
        fund: &Fund<FundCoinType>,
        amount: u64,
    ): u64{

        let fund_amount = fund.asset.assets.borrow<TypeName, Balance<TakeCoinType>>(type_name::get<Balance<TakeCoinType>>()).value();
        if (amount >= fund_amount){
            fund_amount
        }else{
            amount
        }
    }

    fun assert_if_over_max_trader_fee(
        config: &GlobalConfig,
        input_trader_fee: u64,
    ){
        assert!(config.max_trader_fee() >= input_trader_fee, EOverMaxTraderFee);
    }
    
    fun assert_if_take_liquidity_not_in_fund<TakeCoinType, FundCoinType>(
        fund: &Fund<FundCoinType>
    ){
        assert!(fund.asset.assets.contains(type_name::get<Balance<TakeCoinType>>()), ETakeLiquidityNotInFund);
    }

    fun assert_if_take_nonliquidity_not_in_fund<TakeAsset, FundCoinType>(
        fund: &Fund<FundCoinType>
    ){
        assert!(fund.asset.assets.contains(type_name::get<TakeAsset>()), ETakeNonLiquidityNotInFund);
    }


    fun assert_if_put_amount_is_zero(request_put_amount: u64){
        assert!(request_put_amount != 0 , EPutAmountNotSet);
    }

    fun assert_if_put_liquidity_not_equal_to_put_amount(
        request_put_amount: u64,
        balance_amount: u64,
    ){
        assert!(request_put_amount == balance_amount , EPutAmountNotMatchedPutBalance);
    }

    fun assert_if_nonliquidity_in_asset_bag<PutAsset, FundCoinType>(
        fund: &Fund<FundCoinType>,
    ){
        assert!(!fund.asset.assets.contains(type_name::get<PutAsset>()), ENonLiquidityInFund);
    }

    fun assert_if_time_setting_wrong(
        start_time: u64,
        end_time: u64,
    ){
        assert!(end_time > start_time, EEndTimeNotBiggerThanStartTime);
        //assert!(invest_duration >= 3600000, ELessThanMinDuration);
    }

    fun assert_if_trader_not_matched<FundCoinType>(
        fund: &Fund<FundCoinType>,
        trader: &Trader,
    ){
        assert!(trader.id() == fund.trader, ETraderNotMatched);
    }

    fun assert_if_not_finished(
        request: &SettleRequest,
    ){
        assert!(request.is_finished, ESettleNotFinished);
    }

    fun assert_if_fund_has_nonbasic_asset<FundCoinType>(
        fund: &Fund<FundCoinType>,
    ){
        assert!(fund.asset.asset_types.length() == 1, EFundHasNonBaseAsset);
        assert!(fund.asset.asset_types.borrow(0) == type_name::get<Balance<FundCoinType>>(), EBaseTypeNotMatched);
    }

    fun assert_if_not_settle<FundCoinType>(
        fund: &Fund<FundCoinType>,
    ){
        assert!(fund.is_settle, ENotSettle);
    }

    fun assert_if_init_value_over_limit<CoinType>(
        limit_amount: u64, 
        coin: &Coin<CoinType>
    ){
        assert!(limit_amount >= coin.value(), EInitValueOverLimit);
    }

    fun assert_if_over_invest_duration<FundCoinType>(
        fund: &Fund<FundCoinType>,
        clock: &Clock,
    ){
        assert!(fund.time.start_time + fund.time.invest_duration >= clock.timestamp_ms(), EOverInvestTime);
    }
    fun assert_if_not_arrived_invest_duration<FundCoinType>(
        fund: &Fund<FundCoinType>,
        clock: &Clock,
    ){
        assert!(fund.time.start_time <= clock.timestamp_ms(), ENotArrivedInvestTime);
    }

    fun assert_if_not_inclued_in_asset_array<FundCoinType>(
        fund: &Fund<FundCoinType>,
        asset_type: TypeName,
    ):u64{
        let (is_contain, idx) = fund.asset.asset_types.index_of(&asset_type);
        assert!(is_contain, EAssetNotInAssetArray);
        idx
    }

    fun assert_if_base_over_limit<CoinType>(
        fund: &Fund<CoinType>,
        final_value: u64,
    ){
        assert!(fund.limit_amount >= final_value, EOverFundLimitAmount)
    }

    fun assert_if_init_value_not_enough<CoinType>(
        config: &GlobalConfig,
        amount_limit: u64,
        coin: &Coin<CoinType>
    ){
        let coin_amount = coin.value();
        assert!(coin_amount >= (amount_limit * config.trader_init_percentage() / config.base_percentage()), ETraderInitBalanceNeedToOverThreshold);
    }

    fun assert_if_take_action_not_available<FundCoinType>(
        fund: &Fund<FundCoinType>,
        clock: &Clock,
    ){
        assert!(clock.timestamp_ms() >= fund.time.start_time + fund.time.invest_duration, EOperationTimeNotArrived);
    }

    fun assert_if_is_settled<FundCoinType>(
        fund: &Fund<FundCoinType>,
    ){
        assert!(!fund.is_settle, EAlreadySettled);
    }

    fun assert_if_in_end_time<FundCoinType>(
        fund: &Fund<FundCoinType>,
        clock: &Clock,
    ){
        assert!(fund.time.end_time < clock.timestamp_ms(), EInTradingPeriod );
    }

    fun assert_if_shares_empty(
        shares: &vector<FundShare>,
    ){
        assert!(shares.length() != 0, EEmptyArray);
    }

    fun assert_if_deinvest_init_share(
        share: &FundShare,
    ){
        assert!(!share.is_init(), ETraderCanNotDeInvest);
    }

    fun assert_if_fund_type_not_matched<FundCoinType>(
        fund: &Fund<FundCoinType>,
        share: &FundShare,
    ){      
        assert!(*fund.id.as_inner() == share.fund_id(), EFundNotMatched);
    }

    fun pay_platforem_fee<CoinType>(
        config: &GlobalConfig,
        fund: &mut Fund<CoinType>,
        amount: u64,
        ctx: &mut TxContext,
    ){
        let platform_fee = fund.asset.assets.borrow_mut<TypeName, Balance<CoinType>>(type_name::get<Balance<CoinType>>()).split(amount);
        transfer::public_transfer(coin::from_balance(platform_fee, ctx), config.platform());
    }

    // temporary function
    public entry fun withdraw<CoinType>(
        _: &AdminCap,
        fund: &mut Fund<CoinType>,
        ctx: &mut TxContext,
    ){
        let output_coin = fund.asset.assets.remove<TypeName ,Balance<CoinType>>(type_name::get<Balance<CoinType>>());
        transfer::public_transfer(coin::from_balance(output_coin, ctx), ctx.sender());
    }
}