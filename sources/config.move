module stingray::config{

    const EVersionNotMatched: u64 = 0;
    const EOverBaseMax: u64 = 1;
    const ELessThanMinAsset: u64 = 2;

    public struct GlobalConfig has key{ 
        id: UID,
        version: u64,
        max_trader_fee: u64,
        min_fund_base: u64,
        max_fund_base: u64,
        min_rewards: u64,
        settle_percentage: u64,
        base_percentage: u64,
        platform_fee: u64,
        platform: address,
    }

    public struct AdminCap has key{
        id: UID,
    }

    fun init(ctx: &mut TxContext){

        let admin_cap = AdminCap{
            id: object::new(ctx),
        };

        let config = GlobalConfig{
            id: object::new(ctx),
            version: 1u64,
            max_trader_fee: 2000,
            min_fund_base: 100000000,
            max_fund_base: 500000000,
            min_rewards: 1000000,
            settle_percentage: 100,
            base_percentage: 10000,
            platform_fee: 200,
            platform: @0x39dfa26ecaf49a466cfe33b2e98de9b46425eec170e59eb40d3f69d061a67778,
        };

        transfer::transfer(admin_cap, ctx.sender());
        transfer::share_object(config);
    }

    public fun upgrade(
        _: &AdminCap,
        config: &mut GlobalConfig,
    ){
        config.version = config.version + 1;
    }

    public fun set_platform(
        _: &AdminCap,
        config: &mut GlobalConfig,
        new_platform: address,
    ){
        config.platform = new_platform;
    }

    public fun update_trader_fee(
        _: &AdminCap,
        config: &mut GlobalConfig,
        new_trader_fee: u64,
    ){
        config.max_trader_fee = new_trader_fee;
    }

    public fun update_min_base(
        _: &AdminCap,
        config: &mut GlobalConfig,
        new_fund_base: u64,
    ){
        config.min_fund_base = new_fund_base;
    }

     public fun update_max_base(
        _: &AdminCap,
        config: &mut GlobalConfig,
        new_fund_base: u64,
    ){
        config.max_fund_base = new_fund_base;
    }

    public fun update_platform_fee(
        _: &AdminCap,
        config: &mut GlobalConfig,
        new_platform_fee: u64,
    ){
        config.platform_fee = new_platform_fee;
    }

    public(package) fun max_trader_fee(
        config: &GlobalConfig,
    ): u64{
        config.max_trader_fee
    }

    public(package) fun platform_fee(
        config: &GlobalConfig,
    ): u64{
         config.platform_fee
    }

    public(package) fun min_rewards(
        config: &GlobalConfig,
    ): u64{
        config.min_rewards
    }

    public(package) fun platform(
        config: &GlobalConfig,
    ): address{
        config.platform
    }

    public(package) fun min_fund_base(
        config: &GlobalConfig,
    ): u64{
        config.min_fund_base
    }

    public(package) fun settle_percentage(
        config: &GlobalConfig,
    ): u64{
        config.settle_percentage
    }

    public(package) fun base_percentage(
        config: &GlobalConfig,
    ): u64{
        config.base_percentage
    }

    public(package) fun max_fund_base(
        config: &GlobalConfig,
    ): u64{
        config.max_fund_base
    }

    public(package) fun assert_if_version_not_matched(
        config: &GlobalConfig,
        contract_version: u64,
    ) {
        assert!(config.version == contract_version, EVersionNotMatched);
    }

    public(package) fun assert_if_base_over_max(
        config: &GlobalConfig,
        after_base: u64,
    ) {
        assert!(after_base <= config.max_fund_base, EOverBaseMax);
    }

    public(package) fun assert_if_less_than_min_fund_base(
        config: &GlobalConfig,
        input_base_amount: u64,
    ){
        assert!(config.min_fund_base() <= input_base_amount, ELessThanMinAsset);
    }

    #[test_only]
    public(package) fun test_init(
        ctx: &mut TxContext
    ){
        init( ctx);
    }
}