module bucket_oracle::bucket_oracle {
    
    use sui::tx_context::{Self, TxContext};
    use sui::object::{Self, UID};
    use sui::transfer;
    use sui::dynamic_object_field as dof;
    use sui::sui::SUI;
    use sui::clock::Clock;
    use sui::coin::Coin;
    use std::option::{Self, Option};

    use bucket_oracle::single_oracle::{Self, SingleOracle};
    use switchboard_std::aggregator::Aggregator;
    use SupraOracle::SupraSValueFeed::OracleHolder;
    use wormhole::state::{State as WormholeState};
    use pyth::state::{State as PythState};
    use pyth::price_info::PriceInfoObject;

    // Supra OracleHolder
    // 0xaa0315f0748c1f24ddb2b45f7939cff40f7a8104af5ccbc4a1d32f870c0b4105

    // SUI
    const SUI_SWITCHBOARD_CONFIG: address = @0xbca474133638352ba83ccf7b5c931d50f764b09550e16612c9f70f1e21f3f594;
    const SUI_PYTH_CONFIG: address = @0x168aa44fa92b27358beb17643834078b1320be6adf1b3bb0c7f018ac3591db1a;
    const SUI_SUPRA_CONFIG: u32 = 90;

    // BTC
    // const BTC_SWITCHBOARD_CONFIG: address = @0x7c30e48db7dfd6a2301795be6cb99d00c87782e2547cf0c63869de244cfc7e47;
    // const BTC_PYTH_CONFIG: address = @0x878b118488aeb5763b5f191675c3739a844ce132cb98150a465d9407d7971e7c;
    // const BTC_SUPRA_CONFIG: u32 = 18;

    // ETH
    // const ETH_SWITCHBOARD_CONFIG: address = @0x68ed81c5dd07d12c629e5cdad291ca004a5cd3708d5659cb0b6bfe983e14778c;
    // const ETH_PYTH_CONFIG: address = @0x8deeebad0a8fb86d97e6ad396cc84639da5a52ae4bbc91c78eb7abbf3e641ed6;
    // const ETH_SUPRA_CONFIG: u32 = 19;
    
    // USDT
    // const USDT_SWITCHBOARD_CONFIG: address = @0xe8a09db813c07b0a30c9026b3ff7d5617d2505a097f1a90a06a941d34bee9585;
    // const USDT_PYTH_CONFIG: address = @0x83f74b8a33b540cbf1edd24e219eac1215d1668a711ca2be3aa5d703763f91db;
    // const USDT_SUPRA_CONFIG: u32 = 48;

    // USDC
    // const USDC_SWITCHBOARD_CONFIG: address = @0xde58993e6aabe1248a9956557ba744cb930b61437f94556d0380b87913d5ef47;
    // const USDC_PYTH_CONFIG: address = @0xa3d3e81bd7e890ac189b3f581b511f89333b94f445c914c983057e1ac09ff296;
    // const USDC_SUPRA_CONFIG: u32 = 89;

    const PACKAGE_VERSION: u64 = 1;

    struct AdminCap has key { id: UID }

    struct BucketOracle has key {
        id: UID,
        version: u64,
    }

    struct PriceType<phantom T> has copy, drop, store {}

    #[lint_allow(share_owned)]
    fun init(ctx: &mut TxContext) {
        let (oracle, admin_cap) = new_oracle(ctx);
        create_single_oracle<SUI>(
            &admin_cap,
            &mut oracle,
            6,
            3600_000,
            1,
            option::some(SUI_SWITCHBOARD_CONFIG),
            option::some(SUI_PYTH_CONFIG),
            option::some(SUI_SUPRA_CONFIG),
            ctx,
        );
        // create_single_oracle<WBTC>(
        //     &admin_cap,
        //     &mut oracle,
        //     2,
        //     3600_000,
        //     option::some(BTC_SWITCHBOARD_CONFIG),
        //     option::some(BTC_PYTH_CONFIG),
        //     option::some(BTC_SUPRA_CONFIG),
        //     ctx,
        // );
        // create_single_oracle<WETH>(
        //     &admin_cap,
        //     &mut oracle,
        //     3,
        //     3600_000,
        //     option::some(ETH_SWITCHBOARD_CONFIG),
        //     option::some(ETH_PYTH_CONFIG),
        //     option::some(ETH_SUPRA_CONFIG),
        //     ctx,
        // );
        // create_single_oracle<USDT>(
        //     &admin_cap,
        //     &mut oracle,
        //     6,
        //     MAX_U64,
        //     option::some(USDT_SWITCHBOARD_CONFIG),
        //     option::some(USDT_PYTH_CONFIG),
        //     option::some(USDT_SUPRA_CONFIG),
        //     ctx,
        // );
        // create_single_oracle<USDC>(
        //     &admin_cap,
        //     &mut oracle,
        //     6,
        //     MAX_U64,
        //     option::some(USDC_SWITCHBOARD_CONFIG),
        //     option::some(USDC_PYTH_CONFIG),
        //     option::some(USDC_SUPRA_CONFIG),
        //     ctx,
        // );

        transfer::transfer(admin_cap, tx_context::sender(ctx));
        transfer::share_object(oracle);
    }

    fun new_oracle(ctx: &mut TxContext): (BucketOracle, AdminCap) {
        (
            BucketOracle {
                id: object::new(ctx),
                version: PACKAGE_VERSION,
            },
            AdminCap {
                id: object::new(ctx)
            }
        )
    }

    public entry fun create_single_oracle<T>(
        _: &AdminCap,
        bucket_oracle: &mut BucketOracle,
        precision_decimal: u8,
        tolerance_ms: u64,
        threshold: u64,
        switchboard_config: Option<address>,
        pyth_config: Option<address>,
        supra_config: Option<u32>,
        ctx: &mut TxContext,
    ) {
        dof::add<PriceType<T>, SingleOracle<T>>(
            &mut bucket_oracle.id,
            PriceType<T> {}, 
            single_oracle::new(
                precision_decimal,
                tolerance_ms,
                threshold,
                switchboard_config,
                pyth_config,
                supra_config,
                ctx
            ),
        );
    }

    public entry fun update_threshold<T>(
        _: &AdminCap,
        bucket_oracle: &mut BucketOracle,
        threshold: u64,
    ) {
        let oracle = borrow_single_oracle_mut<T>(bucket_oracle);
        single_oracle::update_threshold(oracle, threshold);
    }

    public entry fun update_switchboard_config<T>(
        _: &AdminCap,
        bucket_oracle: &mut BucketOracle,
        switchboard_config: Option<address>,
    ) {
        let oracle = borrow_single_oracle_mut<T>(bucket_oracle);
        single_oracle::update_switchboard_config<T>(oracle, switchboard_config);
    }

    public entry fun update_pyth_config<T>(
        _: &AdminCap,
        bucket_oracle: &mut BucketOracle,
        pyth_config: Option<address>,
    ) {
        let oracle = borrow_single_oracle_mut<T>(bucket_oracle);
        single_oracle::update_pyth_config(oracle, pyth_config);
    }

    public entry fun update_supra_config<T>(
        _: &AdminCap,
        bucket_oracle: &mut BucketOracle,
        supra_config: Option<u32>,
    ) {
        let oracle = borrow_single_oracle_mut<T>(bucket_oracle);
        single_oracle::update_supra_config(oracle, supra_config);
    }

    public fun update_tolerance_ms<T>(
        _: &AdminCap,
        bucket_oracle: &mut BucketOracle,
        tolerance_ms: u64,
    ) {
        let oracle = borrow_single_oracle_mut<T>(bucket_oracle);
        single_oracle::update_tolerance_ms(oracle, tolerance_ms);
    }

    #[allow(unused_type_parameter)]
    public entry fun update_package_version<T>(
        _: &AdminCap,
        bucket_oracle: &mut BucketOracle,
        version: u64,
    ) {
        bucket_oracle.version = version;
    }

    public fun get_price<T>(bucket_oracle: &BucketOracle, clock: &Clock): (u64, u64) {
        assert!(bucket_oracle.version == PACKAGE_VERSION, 99);
        single_oracle::get_price<T>(borrow_single_oracle(bucket_oracle), clock)
    }

    public fun borrow_single_oracle<T>(bucket_oracle: &BucketOracle): &SingleOracle<T> {
        assert!(bucket_oracle.version == PACKAGE_VERSION, 99);
        dof::borrow<PriceType<T>, SingleOracle<T>>(&bucket_oracle.id, PriceType<T> {})
    }

    public fun borrow_single_oracle_mut<T>(bucket_oracle: &mut BucketOracle): &mut SingleOracle<T> {
        assert!(bucket_oracle.version == PACKAGE_VERSION, 99);
        dof::borrow_mut<PriceType<T>, SingleOracle<T>>(&mut bucket_oracle.id, PriceType<T> {})
    }

    public entry fun update_price_from_switchboard<T>(
        bucket_oracle: &mut BucketOracle,
        clock: &Clock,
        switchboard_source: &Aggregator,
    ) {
        assert!(bucket_oracle.version == PACKAGE_VERSION, 99);
        let single_oracle = borrow_single_oracle_mut<T>(bucket_oracle);
        let price_collector = single_oracle::issue_price_collector<T>();
        single_oracle::collect_price_from_switchboard(single_oracle, &mut price_collector, switchboard_source);
        single_oracle::update_oracle_price(single_oracle, clock, price_collector);
    }

    public entry fun update_price_from_pyth<T>(
        bucket_oracle: &mut BucketOracle,
        clock: &Clock,
        wormhole_state: &WormholeState,
        pyth_state: &PythState,
        price_info_object: &mut PriceInfoObject,
        buf: vector<u8>,
        fee: Coin<SUI>,
    ) {
        assert!(bucket_oracle.version == PACKAGE_VERSION, 99);
        let single_oracle = borrow_single_oracle_mut<T>(bucket_oracle);
        let price_collector = single_oracle::issue_price_collector<T>();
        single_oracle::collect_price_from_pyth(single_oracle, &mut price_collector, clock, wormhole_state, pyth_state, price_info_object, buf, fee);
        single_oracle::update_oracle_price(single_oracle, clock, price_collector);
    }

    public entry fun update_price_from_pyth_read_only<T>(
        bucket_oracle: &mut BucketOracle,
        clock: &Clock,
        pyth_state: &PythState,
        price_info_object: &mut PriceInfoObject,
    ) {
        assert!(bucket_oracle.version == PACKAGE_VERSION, 99);
        let single_oracle = borrow_single_oracle_mut<T>(bucket_oracle);
        let price_collector = single_oracle::issue_price_collector<T>();
        single_oracle::collect_price_from_pyth_read_only(single_oracle, &mut price_collector, clock, pyth_state, price_info_object);
        single_oracle::update_oracle_price(single_oracle, clock, price_collector);
    }

    public entry fun update_price_from_supra<T>(
        bucket_oracle: &mut BucketOracle,
        clock: &Clock,
        supra_source: &OracleHolder,
        pair_id: u32,
    ) {
        let single_oracle = borrow_single_oracle_mut<T>(bucket_oracle);
        let price_collector = single_oracle::issue_price_collector<T>();
        single_oracle::collect_price_from_supra(single_oracle, &mut price_collector, supra_source, pair_id);
        single_oracle::update_oracle_price(single_oracle, clock, price_collector);
    }

    // >>>>>>>>>>>>>> Derivative >>>>>>>>>>>>>>

    public fun add_rule<T, R: drop>(
        _: &AdminCap,
        oracle: &mut BucketOracle,
    ) {
        let single_oracle = borrow_single_oracle_mut<T>(oracle);
        single_oracle::add_rule<T, R>(single_oracle);
    }

    public fun remove_rule<T, R: drop>(
        _: &AdminCap,
        oracle: &mut BucketOracle,
    ) {
        let single_oracle = borrow_single_oracle_mut<T>(oracle);
        single_oracle::remove_rule<T, R>(single_oracle);
    }

    // <<<<<<<<<<<<<< Derivative <<<<<<<<<<<<<<

    #[test_only]
    const MAX_U64: u64 = 0xffffffffffffffff;

    #[test_only]
    public fun new_for_testing<T>(precision_decimal: u8, ctx: &mut TxContext): (BucketOracle, AdminCap) {
        let (oracle, admin_cap) = new_oracle(ctx);
        create_single_oracle<T>(
            &admin_cap,
            &mut oracle,
            precision_decimal,
             MAX_U64,
             1,
            option::none(),
            option::none(),
            option::none(),
            ctx,
        );
        (oracle, admin_cap)
    }

    #[test_only]
    public fun share_for_testing<T>(precision_decimal: u8, admin: address, ctx: &mut TxContext) {
        let (oracle, admin_cap) = new_oracle(ctx);
        create_single_oracle<T>(
            &admin_cap,
            &mut oracle,
            precision_decimal,
            MAX_U64,
            1,
            option::none(),
            option::none(),
            option::none(),
            ctx,
        );
        transfer::share_object(oracle);
        transfer::transfer(admin_cap, admin);
    }

    #[test_only]
    public fun update_price_for_testing<T>(bucket_oracle: &mut BucketOracle, price: u64) {
        let oracle = borrow_single_oracle_mut<T>(bucket_oracle);
        single_oracle::update_price_for_testing(oracle, price);
    }
}