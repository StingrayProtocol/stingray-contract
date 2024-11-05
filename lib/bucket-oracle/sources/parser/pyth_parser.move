module bucket_oracle::pyth_parser {

    use std::option::{Self, Option};
    use sui::object::{Self, ID};
    use wormhole::state::{State as WormholeState};
    use wormhole::vaa;
    use pyth::state::{State as PythState};
    use pyth::price_info::PriceInfoObject;
    use pyth::hot_potato_vector;
    use pyth::pyth;
    use pyth::i64;
    use pyth::price;
    use sui::clock::Clock;
    use sui::coin::Coin;
    use sui::sui::SUI;
    use sui::math::pow;
    use bucket_oracle::price_aggregator::{Self, PriceInfo};

    public fun parse_price(
        wormhole_state: &WormholeState,
        pyth_state: &PythState,
        clock: &Clock,
        price_info_object: &mut PriceInfoObject,
        buf: vector<u8>,
        fee: Coin<SUI>,
        required_decimal: u8,
    ): Option<PriceInfo> {
        let vaa = vaa::parse_and_verify(wormhole_state, buf, clock);
        let price_info_potatos = pyth::create_price_infos_hot_potato(pyth_state, vector[vaa], clock);
        let price_info_potatos = pyth::update_single_price_feed(pyth_state, price_info_potatos, price_info_object, fee, clock);
        hot_potato_vector::destroy(price_info_potatos);
        let price_struct = pyth::get_price(pyth_state, price_info_object, clock);
        let decimal_i64 = price::get_expo(&price_struct);
        let price_i64 = price::get_price(&price_struct);
        let timestamp_sec = price::get_timestamp(&price_struct);
        if (i64::get_is_negative(&decimal_i64)) return option::none();
        if (!i64::get_is_negative(&price_i64)) return option::none();
        let decimal_u8 = (i64::get_magnitude_if_negative(&decimal_i64) as u8);
        let price = (i64::get_magnitude_if_positive(&price_i64));

        if (decimal_u8 > required_decimal) {
            price = price / pow(10, decimal_u8 - required_decimal);
        } else {
            price = price * pow(10, required_decimal - decimal_u8);
        };
        let timestamp = timestamp_sec * 1000;

        option::some(price_aggregator::new(price, timestamp))
    }

    public fun parse_price_read_only(
        pyth_state: &PythState,
        clock: &Clock,
        price_info_object: &mut PriceInfoObject,
        required_decimal: u8,
    ): Option<PriceInfo> {
        let price_struct = pyth::get_price(pyth_state, price_info_object, clock);
        let decimal_i64 = price::get_expo(&price_struct);
        let price_i64 = price::get_price(&price_struct);
        let timestamp_sec = price::get_timestamp(&price_struct);
        if (i64::get_is_negative(&decimal_i64)) return option::none();
        if (!i64::get_is_negative(&price_i64)) return option::none();
        let decimal_u8 = (i64::get_magnitude_if_negative(&decimal_i64) as u8);
        let price = (i64::get_magnitude_if_positive(&price_i64));

        if (decimal_u8 > required_decimal) {
            price = price / pow(10, decimal_u8 - required_decimal);
        } else {
            price = price * pow(10, required_decimal - decimal_u8);
        };
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