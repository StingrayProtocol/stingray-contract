module vsui_rule::vsui_rule {

    use sui::sui::SUI;
    use sui::clock::Clock;
    use volo::cert::{CERT, Metadata};
    use volo::native_pool::{Self, NativePool};
    use bucket_oracle::bucket_oracle::{Self as bo, BucketOracle};
    use bucket_oracle::single_oracle as so;

    public struct Rule has drop {}

    public fun update_price(
        oracle: &mut BucketOracle,
        native_pool: &NativePool,
        metadata: &Metadata<CERT>,
        clock: &Clock,
    ) {
        let (sui_price, sui_precision) = bo::get_price<SUI>(oracle, clock);
        let vsui_price = native_pool::from_shares(native_pool, metadata, sui_price);
        let vsui_oracle = bo::borrow_single_oracle_mut<CERT>(oracle);
        let vsui_precision = so::precision(vsui_oracle);
        let vsui_price = (vsui_precision as u128) * (vsui_price as u128) / (sui_precision as u128);
        so::update_oracle_price_with_rule(vsui_oracle, Rule {}, clock, (vsui_price as u64));
    }
}
