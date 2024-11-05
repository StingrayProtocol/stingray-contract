module hasui_rule::hasui_rule {

    use sui::sui::SUI;
    use sui::clock::Clock;
    use haedal::hasui::HASUI;
    use haedal::staking::{Self, Staking};
    use bucket_oracle::bucket_oracle::{Self as bo, BucketOracle};
    use bucket_oracle::single_oracle as so;

    public struct Rule has drop {}

    public fun update_price(
        oracle: &mut BucketOracle,
        staking: &Staking,
        clock: &Clock,
    ) {
        let (sui_price, sui_precision) = bo::get_price<SUI>(oracle, clock);
        let exchage_rate = staking::get_exchange_rate(staking);
        let hasui_price = mul_and_div(sui_price, exchage_rate, rate_precision());
        let hasui_oracle = bo::borrow_single_oracle_mut<HASUI>(oracle);
        let hasui_precision = so::precision(hasui_oracle);
        let hasui_price = mul_and_div(hasui_precision, hasui_price, sui_precision);
        so::update_oracle_price_with_rule(hasui_oracle, Rule {}, clock, hasui_price);
    }

    public fun rate_precision(): u64 { 1_000_000 }

    fun mul_and_div(x: u64, n: u64, m: u64): u64 {
        (((x as u128) * (n as u128) / (m as u128)) as u64)
    }
}
