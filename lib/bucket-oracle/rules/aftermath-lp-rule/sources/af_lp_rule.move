module aftermath_lp_rule::af_lp_rule {

    use std::option;
    use std::vector;
    use std::type_name;
    use sui::clock::Clock;
    use amm::math;
    use amm::pool::{Self, Pool};
    use bucket_oracle::bucket_oracle::{Self as bo, BucketOracle};
    use bucket_oracle::single_oracle as so;

    const EInvalidCoinType: u64 = 0;
    const EVectorLenNotTwo: u64 = 1;

    struct Rule has drop {}

    public fun update_price<LP, CoinA, CoinB>(
        oracle: &mut BucketOracle,
        pool: &Pool<LP>,
        clock: &Clock,
    ) {
        let price = lp_price<LP, CoinA, CoinB>(oracle, pool, clock);
        let lp_oracle = bo::borrow_single_oracle_mut<LP>(oracle);
        so::update_oracle_price_with_rule(lp_oracle, Rule {}, clock, price);
    }

    public fun lp_price<LP, CoinA, CoinB>(
        oracle: &BucketOracle,
        pool: &Pool<LP>,
        clock: &Clock,
    ): u64 {
        let type_names = pool::type_names(pool);
        let (coin_a_type, coin_b_type) = get_first_two_elements(&type_names);
        assert!(
            coin_a_type == type_name::into_string(type_name::get<CoinA>()),
            EInvalidCoinType,
        );
        assert!(
            coin_b_type == type_name::into_string(type_name::get<CoinB>()),
            EInvalidCoinType,
        );
        let unit_lp_amount = exp_decimals(pool::lp_decimals(pool));
        let coin_decimals = *option::borrow(pool::coin_decimals(pool));
        let (decimals_a, decimals_b) = get_first_two_elements(&coin_decimals);
        let denom_a = exp_decimals(decimals_a);
        let denom_b = exp_decimals(decimals_b);
        let amounts = math::calc_all_coin_withdraw(pool, unit_lp_amount);
        let (amount_a, amount_b) = get_first_two_elements(&amounts);
        let (price_a, precision_a) = bo::get_price<CoinA>(oracle, clock);
        let (price_b, precision_b) = bo::get_price<CoinB>(oracle, clock);
        let lp_oracle = bo::borrow_single_oracle<LP>(oracle);
        let lp_precision = so::precision(lp_oracle);
        let price_a = mul_and_div(price_a, lp_precision, precision_a);
        let price_b = mul_and_div(price_b, lp_precision, precision_b);
        mul_and_div(price_a, amount_a, denom_a) +
        mul_and_div(price_b, amount_b, denom_b)
    }

    fun get_first_two_elements<T: copy>(vec: &vector<T>): (T, T) {
        assert!(vector::length(vec) == 2, EVectorLenNotTwo);
        (
            *vector::borrow(vec, 0),
            *vector::borrow(vec, 1),
        )
    }

    fun exp_decimals(decimals: u8): u64 {
        sui::math::pow(10, decimals)
    }

    fun mul_and_div(x: u64, n: u64, m: u64): u64 {
        (((x as u128) * (n as u128) / (m as u128)) as u64)
    }
}