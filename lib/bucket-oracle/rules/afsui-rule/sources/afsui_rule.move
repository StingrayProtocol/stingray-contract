module afsui_rule::afsui_rule {

    use sui::sui::SUI;
    use sui::coin::TreasuryCap;
    use sui::clock::Clock;
    use lsd::staked_sui_vault::{Self as ssv, StakedSuiVault};
    use afsui::afsui::AFSUI;
    use safe::safe::Safe;
    use bucket_oracle::bucket_oracle::{Self as bo, BucketOracle};
    use bucket_oracle::single_oracle as so;

    struct Rule has drop {}

    public fun update_price(
        oracle: &mut BucketOracle,
        vault: &StakedSuiVault,
        safe: &Safe<TreasuryCap<AFSUI>>,
        clock: &Clock,
    ) {
        let (
            sui_price,
            sui_precision,
        ) = bo::get_price<SUI>(oracle, clock);
        let exchage_rate = ssv::afsui_to_sui_exchange_rate(vault, safe);
        let afsui_price = mul_and_div_u128(sui_price, exchage_rate, 1_000_000_000_000_000_000);
        let afsui_oracle = bo::borrow_single_oracle_mut<AFSUI>(oracle);
        let afsui_precision = so::precision(afsui_oracle);
        let afsui_price = mul_and_div_u128(afsui_precision, (afsui_price as u128), (sui_precision as u128));
        so::update_oracle_price_with_rule(afsui_oracle, Rule {}, clock, afsui_price);
    }

    fun mul_and_div_u128(x: u64, n: u128, m: u128): u64 {
        (((x as u128) * n / m) as u64)
    }

}