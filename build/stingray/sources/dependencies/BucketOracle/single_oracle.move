module bucket_oracle::single_oracle {

    use sui::object::{Self, ID, UID};
    use sui::tx_context::TxContext;
    use sui::clock::{Self, Clock};
    use sui::math;
    use sui::dynamic_field as df;
    use sui::coin::Coin;
    use sui::sui::SUI;
    use sui::event;
    use std::option::{Self, Option};
    use std::ascii::String;
    use std::type_name;
    use bucket_oracle::price_aggregator::{Self, PriceInfo};

    struct ParsePriceEvent has drop, copy {
        coin_type: String,
        source_id: u8,
        price_info: Option<PriceInfo>,
    }

    // switchboard
    use switchboard_std::aggregator::Aggregator;

    // pyth
    use wormhole::state::{State as WormholeState};
    use pyth::state::{State as PythState};
    use pyth::price_info::PriceInfoObject;

    // supra
    use SupraOracle::SupraSValueFeed::OracleHolder;

    // parsers
    use bucket_oracle::switchboard_parser;
    use bucket_oracle::pyth_parser;
    use bucket_oracle::supra_parser;

    friend bucket_oracle::bucket_oracle;

    const TOLERANCE_MS_OF_GET_PRICE: u64 = 10_000;

    const ENoSourceConfig: u64 = 0;
    const EWrongSourceConfig: u64 = 1;
    const EPriceOutdated: u64 = 2;
    const EInvalidUpdateRule: u64 = 3;

    struct SingleOracle<phantom T> has key, store {
        id: UID,
        price: u64,
        // settings
        precision_decimal: u8,
        precision: u64,
        tolerance_ms: u64,
        threshold: u64,
        // recordings
        latest_update_ms: u64,
        // oracle configs
        switchboard_config: Option<ID>,
        pyth_config: Option<ID>,
        supra_config: Option<u32>,
    }

    struct PriceCollector<phantom T> {
        switchboard_result: Option<PriceInfo>,
        pyth_result: Option<PriceInfo>,
        supra_result: Option<PriceInfo>,
    }

    public(friend) fun new<T>(
        precision_decimal: u8,
        tolerance_ms: u64,
        threshold: u64,
        switchboard_config: Option<address>,
        pyth_config: Option<address>,
        supra_config: Option<u32>,
        ctx: &mut TxContext,
    ): SingleOracle<T> {
        let switchboard_config = switchboard_parser::parse_config(switchboard_config);
        let pyth_config = pyth_parser::parse_config(pyth_config);
        SingleOracle {
            id: object::new(ctx),
            price: 0,
            precision_decimal,
            tolerance_ms,
            threshold, 
            precision: math::pow(10, precision_decimal),
            latest_update_ms: 0,
            switchboard_config,
            pyth_config,
            supra_config,
        }
    }

    public fun get_price<T>(oracle: &SingleOracle<T>, clock: &Clock): (u64, u64) {
        assert!(clock::timestamp_ms(clock) - oracle.latest_update_ms <= TOLERANCE_MS_OF_GET_PRICE, EPriceOutdated);
        (oracle.price, oracle.precision)
    }

    public(friend) fun update_threshold<T>(oracle: &mut SingleOracle<T>, threshold: u64) {
        oracle.threshold = threshold;
    }

    public(friend) fun update_tolerance_ms<T>(oracle: &mut SingleOracle<T>, tolerance_ms: u64) {
        oracle.tolerance_ms = tolerance_ms;
    }

    ////////////////////////////////////////////////////////////////////////
    //
    //    Swichboard
    //
    ////////////////////////////////////////////////////////////////////////

    public(friend) fun update_switchboard_config<T>(oracle: &mut SingleOracle<T>, config: Option<address>) {
        let config = switchboard_parser::parse_config(config);
        oracle.switchboard_config = config;
    }

    public fun collect_price_from_switchboard<T>(
        oracle: &SingleOracle<T>,
        // collector
        price_collector: &mut PriceCollector<T>,
        // switchboard input
        source: &Aggregator,
    ) {
        assert!(option::is_some(&oracle.switchboard_config), ENoSourceConfig);
        assert!(option::borrow(&oracle.switchboard_config) == &object::id(source), EWrongSourceConfig);
        let price_info = switchboard_parser::parse_price(source, oracle.precision_decimal);
        let coin_type = type_name::into_string(type_name::get<T>());
        event::emit(ParsePriceEvent { coin_type, source_id: 0, price_info });
        price_collector.switchboard_result = price_info;
    }

    ////////////////////////////////////////////////////////////////////////
    //
    //    Pyth
    //
    ////////////////////////////////////////////////////////////////////////

    public(friend) fun update_pyth_config<T>(oracle: &mut SingleOracle<T>, config: Option<address>) {
        let config = pyth_parser::parse_config(config);
        oracle.pyth_config = config;
    }

    public fun collect_price_from_pyth<T>(
        oracle: &SingleOracle<T>,
        // collector
        price_collector: &mut PriceCollector<T>,
        // pyth inputs
        clock: &Clock,
        wormhole_state: &WormholeState,
        pyth_state: &PythState,
        price_info_object: &mut PriceInfoObject,
        buf: vector<u8>,
        fee: Coin<SUI>,
    ) {
        assert!(option::is_some(&oracle.pyth_config), ENoSourceConfig);
        assert!(option::borrow(&oracle.pyth_config) == &object::id(price_info_object), EWrongSourceConfig);
        let price_info = pyth_parser::parse_price(wormhole_state, pyth_state, clock, price_info_object, buf, fee, oracle.precision_decimal);
        let coin_type = type_name::into_string(type_name::get<T>());
        event::emit(ParsePriceEvent { coin_type, source_id: 1, price_info});
        price_collector.pyth_result = price_info;
    }

    public fun collect_price_from_pyth_read_only<T>(
        oracle: &SingleOracle<T>,
        // collector
        price_collector: &mut PriceCollector<T>,
        // pyth inputs
        clock: &Clock,
        pyth_state: &PythState,
        price_info_object: &mut PriceInfoObject,
    ) {
        assert!(option::is_some(&oracle.pyth_config), ENoSourceConfig);
        assert!(option::borrow(&oracle.pyth_config) == &object::id(price_info_object), EWrongSourceConfig);
        let price_info = pyth_parser::parse_price_read_only(pyth_state, clock, price_info_object,oracle.precision_decimal);
        let coin_type = type_name::into_string(type_name::get<T>());
        event::emit(ParsePriceEvent { coin_type, source_id: 1, price_info});
        price_collector.pyth_result = price_info;
    }

    ////////////////////////////////////////////////////////////////////////
    //
    //    Supra
    //
    ////////////////////////////////////////////////////////////////////////

    public(friend) fun update_supra_config<T>(oracle: &mut SingleOracle<T>, config: Option<u32>) {
        oracle.supra_config = config;
    }

    public fun collect_price_from_supra<T>(
        oracle: &SingleOracle<T>,
        // collector
        price_collector: &mut PriceCollector<T>,
        // supra inputs
        source: &OracleHolder,
        pair_id: u32,
    ) {
        assert!(option::is_some(&oracle.supra_config), ENoSourceConfig);
        assert!(*option::borrow(&oracle.supra_config) == pair_id, EWrongSourceConfig);
        let price_info = supra_parser::parse_price(source, pair_id, oracle.precision_decimal);
        let coin_type = type_name::into_string(type_name::get<T>());
        event::emit(ParsePriceEvent { coin_type, source_id: 2, price_info });
        price_collector.supra_result = price_info;
    }

    ////////////////////////////////////////////////////////////////////////
    //
    //    Aggregate
    //
    ////////////////////////////////////////////////////////////////////////

    public fun issue_price_collector<T>(): PriceCollector<T> {
        PriceCollector {
            switchboard_result: option::none(),
            pyth_result: option::none(),
            supra_result: option::none(),    
        }
    }

    public fun update_oracle_price<T>(
        single_oracle: &mut SingleOracle<T>,
        clock: &Clock,
        price_collector: PriceCollector<T>,
    ) {
        let price_info_vec = vector<PriceInfo>[];
        let PriceCollector { switchboard_result, pyth_result, supra_result } = price_collector;
        price_aggregator::push_price(&mut price_info_vec, switchboard_result);
        price_aggregator::push_price(&mut price_info_vec, pyth_result);
        price_aggregator::push_price(&mut price_info_vec, supra_result);
        let agg_price = price_aggregator::aggregate_price(clock, price_info_vec, single_oracle.tolerance_ms, single_oracle.threshold);
        single_oracle.price = agg_price;
        single_oracle.latest_update_ms = clock::timestamp_ms(clock);
    }

    // >>>>>>>>>>>>>> Derivative >>>>>>>>>>>>>>

    struct WhitelistRule<phantom R: drop> has store, copy, drop {}

    public fun update_oracle_price_with_rule<T, R: drop>(
        single_oracle: &mut SingleOracle<T>,
        _rule: R,
        clock: &Clock,
        price: u64,
    ) {
        assert!(
            df::exists_(&single_oracle.id, WhitelistRule<R> {}),
            EInvalidUpdateRule,
        );
        single_oracle.price = price;
        let current_time = clock::timestamp_ms(clock);
        single_oracle.latest_update_ms = current_time;
    }

    public fun precision_decimal<T>(single_oracle: &SingleOracle<T>): u8 {
        single_oracle.precision_decimal
    }

    public fun precision<T>(single_oracle: &SingleOracle<T>): u64 {
        single_oracle.precision
    }

    public(friend) fun add_rule<T, R: drop>(
        single_oracle: &mut SingleOracle<T>,
    ) {
        df::add(
            &mut single_oracle.id, WhitelistRule<R> {}, true,
        );
    }

    public(friend) fun remove_rule<T, R: drop>(
        single_oracle: &mut SingleOracle<T>,
    ) {
        df::remove<WhitelistRule<R>, bool>(
            &mut single_oracle.id, WhitelistRule<R> {},
        );
    }

    // <<<<<<<<<<<<<< Derivative <<<<<<<<<<<<<<

    #[test_only]
    public fun update_price_for_testing<T>(oracle: &mut SingleOracle<T>, price: u64) {
        oracle.price = price;
    }
}