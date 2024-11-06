module bucket_oracle::switchboard_parser {

    use std::option::{Self, Option};
    use sui::object::{Self, ID};
    use sui::math::pow;
    use switchboard_std::aggregator::{Self, Aggregator};
    use switchboard_std::math;
    use bucket_oracle::price_aggregator::{Self, PriceInfo};

    fun extract_aggregator_info(feed: &Aggregator): (u128, u8, u64) {
        let (
            latest_result,
            latest_timestamp
        ) = aggregator::latest_value(feed);

        // get latest value
        let (value, scaling_factor, _) = math::unpack(latest_result);
        (value, scaling_factor, latest_timestamp)
    }

    public fun parse_price(feed: &Aggregator, required_decimal: u8): Option<PriceInfo> {
        let (price_u128, decimal, timestamp_sec) = extract_aggregator_info(feed);
        if (price_u128 == 0) return option::none();

        if (decimal > required_decimal) {
            price_u128 = price_u128 / (pow(10, decimal - required_decimal) as u128);
        } else {
            price_u128 = price_u128 * (pow(10, required_decimal - decimal) as u128);
        };

        let price = (price_u128 as u64);
        let timestamp = timestamp_sec * 1000;

        option::some(price_aggregator::new(price, timestamp))
    }

    public fun parse_config(config: Option<address>): Option<ID> {
        if (option::is_none(&config)) {
            option::none<ID>()
        } else {
            option::some(object::id_from_address(option::destroy_some(config)))
        }
    }
}