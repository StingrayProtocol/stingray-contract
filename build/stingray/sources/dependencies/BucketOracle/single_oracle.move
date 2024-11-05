module bucket_oracle::single_oracle {

    use sui::object::{Self, ID, UID};
    use sui::tx_context::TxContext;
    use sui::clock::Clock;
    use sui::math;
    use std::option::{Self, Option};

    friend bucket_oracle::bucket_oracle;

    const TOLERANCE_MS_OF_GET_PRICE: u64 = 5000;

    const ENoSourceConfig: u64 = 0;
    const EWrongSourceConfig: u64 = 1;
    const EPriceOutdated: u64 = 2;

    struct SingleOracle<phantom T> has key, store {
        id: UID,
        price: u64,
        // settings
        precision_decimal: u8,
        precision: u64,
        // recordings
        latest_update_ms: u64,
        // oracle configs
        switchboard_config: Option<ID>,
        pyth_config: Option<ID>,
        supra_config: Option<u32>,
    }

    public(friend) fun new<T>(
        precision_decimal: u8,
        _switchboard_config: Option<address>,
        _pyth_config: Option<address>,
        _supra_config: Option<u32>,
        ctx: &mut TxContext,
    ): SingleOracle<T> {
        SingleOracle {
            id: object::new(ctx),
            price: 0,
            precision_decimal,
            precision: math::pow(10, precision_decimal),
            latest_update_ms: 0,
            switchboard_config: option::none(),
            pyth_config: option::none(),
            supra_config: option::none(),
        }
    }

    public fun get_price<T>(oracle: &SingleOracle<T>, _clock: &Clock): (u64, u64) {
        // assert!(clock::timestamp_ms(clock) - oracle.latest_update_ms <= TOLERANCE_MS_OF_GET_PRICE, EPriceOutdated);
        (oracle.price, oracle.precision)
    }

    #[test_only]
    public fun update_price_for_testing<T>(oracle: &mut SingleOracle<T>, price: u64) {
        oracle.price = price;
    }
}