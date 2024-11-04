module bucket_protocol::buck {

    // ----- Use Statements -----

    use sui::object;
    use sui::coin;
    use sui::tx_context;
    use 0xce7ff77a83ea0cb6fd39bd8748e2ec89a3f41e8efdc3f4eb123e0ca37b184db2::bucket;
    use 0xce7ff77a83ea0cb6fd39bd8748e2ec89a3f41e8efdc3f4eb123e0ca37b184db2::pipe;
    use 0xce7ff77a83ea0cb6fd39bd8748e2ec89a3f41e8efdc3f4eb123e0ca37b184db2::reservoir;
    use sui::balance;
    use 0xce7ff77a83ea0cb6fd39bd8748e2ec89a3f41e8efdc3f4eb123e0ca37b184db2::well;
    use std::option;
    use bucket_oracle::bucket_oracle;
    use sui::clock;
    use 0xce7ff77a83ea0cb6fd39bd8748e2ec89a3f41e8efdc3f4eb123e0ca37b184db2::tank;
    use 0xce7ff77a83ea0cb6fd39bd8748e2ec89a3f41e8efdc3f4eb123e0ca37b184db2::bkt;
    use 0xce7ff77a83ea0cb6fd39bd8748e2ec89a3f41e8efdc3f4eb123e0ca37b184db2::strap;
    use 0x1798f84ee72176114ddbf5525a6d964c5f8ea1b3738d08d50d0d3de4cf584884::sbuck;

    // ----- public structs -----

    public struct AdminCap has store, key {
        id: object::UID,
    }

    public struct BUCK has drop {
        dummy_field: bool,
    }

    public struct BucketProtocol has key {
        id: object::UID,
        version: u64,
        buck_treasury_cap: coin::TreasuryCap<BUCK>,
        min_bottle_size: u64,
    }

    public struct BucketType<phantom T0> has copy, drop, store {
        dummy_field: bool,
    }

    public struct FlashMintConfig has store, key {
        id: object::UID,
        fee_rate: u64,
        max_amount: u64,
        total_amount: u64,
    }

    public struct FlashMintReceipt {
        config_id: object::ID,
        mint_amount: u64,
        fee_amount: u64,
    }

    public struct NoFeePermission has key {
        id: object::UID,
    }

    public struct ReservoirType<phantom T0> has copy, drop, store {
        dummy_field: bool,
    }

    public struct TankType<phantom T0> has copy, drop, store {
        dummy_field: bool,
    }

    public struct TestVersion has store, key {
        id: object::UID,
        version: u64,
    }

    public struct WellType<phantom T0> has copy, drop, store {
        dummy_field: bool,
    }
    // ----- Public Functions -----

    public entry fun create_bucket<T0>(arg0: &AdminCap, arg1: &mut BucketProtocol, arg2: u64, arg3: u64, arg4: u8, arg5: option::Option<u64>, arg6: &mut tx_context::TxContext) {
        abort 0
    }

    public entry fun release_bkt<T0>(arg0: &AdminCap, arg1: &mut BucketProtocol, arg2: &mut bkt::BktTreasury, arg3: u64) {
        abort 0
    }

    public entry fun update_max_mint_amount<T0>(arg0: &AdminCap, arg1: &mut BucketProtocol, arg2: option::Option<u64>) {
        abort 0
    }

    public entry fun update_min_bottle_size(arg0: &AdminCap, arg1: &mut BucketProtocol, arg2: u64) {
        abort 0
    }

    public entry fun update_protocol_version(arg0: &AdminCap, arg1: &mut BucketProtocol, arg2: u64) {
        abort 0
    }

    public fun add_interest_table_to_bucket<T0>(arg0: &AdminCap, arg1: &mut BucketProtocol, arg2: &clock::Clock, arg3: &mut tx_context::TxContext) {
        abort 0
    }

    public fun add_pending_record_to_bucket<T0>(arg0: &AdminCap, arg1: &mut BucketProtocol, arg2: &mut tx_context::TxContext) {
        abort 0
    }

    public fun add_test_version(arg0: &AdminCap, arg1: &mut BucketProtocol, arg2: u64, arg3: &mut tx_context::TxContext) {
        abort 0
    }

    public fun adjust_pending_record<T0>(arg0: &AdminCap, arg1: &mut BucketProtocol) {
        abort 0
    }

    public fun borrow<T0>(arg0: &mut BucketProtocol, arg1: &bucket_oracle::BucketOracle, arg2: &clock::Clock, arg3: balance::Balance<T0>, arg4: u64, arg5: option::Option<address>, arg6: &mut tx_context::TxContext) : balance::Balance<BUCK> {
        abort 0
    }

    public fun borrow_bucket<T0>(arg0: &BucketProtocol) : &bucket::Bucket<T0> {
        abort 0
    }

    public fun borrow_pipe<T0, T1: drop>(arg0: &BucketProtocol) : &pipe::Pipe<T0, T1> {
        abort 0
    }

    public fun borrow_reservoir<T0>(arg0: &BucketProtocol) : &reservoir::Reservoir<T0> {
        abort 0
    }

    public fun borrow_tank<T0>(arg0: &BucketProtocol) : &tank::Tank<BUCK, T0> {
        abort 0
    }

    public fun borrow_tank_mut<T0>(arg0: &mut BucketProtocol) : &mut tank::Tank<BUCK, T0> {
        abort 0
    }

    public fun borrow_well<T0>(arg0: &BucketProtocol) : &well::Well<T0> {
        abort 0
    }

    public fun borrow_well_mut<T0>(arg0: &mut BucketProtocol) : &mut well::Well<T0> {
        abort 0
    }

    public fun borrow_with_strap<T0>(arg0: &mut BucketProtocol, arg1: &bucket_oracle::BucketOracle, arg2: &strap::BottleStrap<T0>, arg3: &clock::Clock, arg4: balance::Balance<T0>, arg5: u64, arg6: option::Option<address>, arg7: &mut tx_context::TxContext) : balance::Balance<BUCK> {
        abort 0
    }

    public fun burn_sbuck(arg0: &mut BucketProtocol, arg1: &mut sbuck::Flask<BUCK>, arg2: coin::Coin<sbuck::SBUCK>) : balance::Balance<BUCK> {
        abort 0
    }

    public fun charge_reservoir<T0>(arg0: &mut BucketProtocol, arg1: balance::Balance<T0>) : balance::Balance<BUCK> {
        abort 0
    }

    public fun charge_reservoir_by_partner<T0, T1: drop>(arg0: &mut BucketProtocol, arg1: balance::Balance<T0>, arg2: T1) : balance::Balance<BUCK> {
        abort 0
    }

    public fun charge_reservoir_without_fee<T0>(arg0: &NoFeePermission, arg1: &mut BucketProtocol, arg2: balance::Balance<T0>) : balance::Balance<BUCK> {
        abort 0
    }

    public fun collect_interests<T0>(arg0: &mut BucketProtocol) {
        abort 0
    }

    public fun collect_interests_to_flask<T0>(arg0: &mut BucketProtocol, arg1: &mut sbuck::Flask<BUCK>) {
        abort 0
    }

    public fun compute_base_rate_fee<T0>(arg0: &bucket::Bucket<T0>, arg1: &clock::Clock) : u64 {
        abort 0
    }

    public fun create_bucket_with_interest_table<T0>(arg0: &AdminCap, arg1: &mut BucketProtocol, arg2: u64, arg3: u64, arg4: u8, arg5: option::Option<u64>, arg6: &clock::Clock, arg7: u256, arg8: &mut tx_context::TxContext) {
        abort 0
    }

    public fun create_flash_mint_config_to(arg0: &AdminCap, arg1: u64, arg2: u64, arg3: address, arg4: &mut tx_context::TxContext) {
        abort 0
    }

    public fun create_no_fee_permission_to(arg0: &AdminCap, arg1: address, arg2: &mut tx_context::TxContext) {
        abort 0
    }

    public fun create_pipe<T0, T1: drop>(arg0: &AdminCap, arg1: &mut BucketProtocol, arg2: &mut tx_context::TxContext) {
        abort 0
    }

    public fun create_reservoir<T0>(arg0: &AdminCap, arg1: &mut BucketProtocol, arg2: u64, arg3: u64, arg4: u64, arg5: &mut tx_context::TxContext) {
        abort 0
    }

    public fun destroy_pipe<T0, T1: drop>(arg0: &AdminCap, arg1: &mut BucketProtocol) {
        abort 0
    }

    public fun discharge_reservoir<T0>(arg0: &mut BucketProtocol, arg1: balance::Balance<BUCK>) : balance::Balance<T0> {
        abort 0
    }

    public fun discharge_reservoir_by_partner<T0, T1: drop>(arg0: &mut BucketProtocol, arg1: balance::Balance<BUCK>, arg2: T1) : balance::Balance<T0> {
        abort 0
    }

    public fun discharge_reservoir_without_fee<T0>(arg0: &NoFeePermission, arg1: &mut BucketProtocol, arg2: balance::Balance<BUCK>) : balance::Balance<T0> {
        abort 0
    }

    public fun flash_borrow<T0>(arg0: &mut BucketProtocol, arg1: u64) : (balance::Balance<T0>, bucket::FlashReceipt<T0>) {
        abort 0
    }

    public fun flash_borrow_buck<T0>(arg0: &mut BucketProtocol, arg1: u64) : (balance::Balance<BUCK>, tank::FlashReceipt<BUCK, T0>) {
        abort 0
    }

    public fun flash_burn(arg0: &mut BucketProtocol, arg1: &mut FlashMintConfig, arg2: balance::Balance<BUCK>, arg3: FlashMintReceipt) {
        abort 0
    }

    public fun flash_mint(arg0: &mut BucketProtocol, arg1: &mut FlashMintConfig, arg2: u64) : (balance::Balance<BUCK>, FlashMintReceipt) {
        abort 0
    }

    public fun flash_repay<T0>(arg0: &mut BucketProtocol, arg1: balance::Balance<T0>, arg2: bucket::FlashReceipt<T0>) {
        abort 0
    }

    public fun flash_repay_buck<T0>(arg0: &mut BucketProtocol, arg1: balance::Balance<BUCK>, arg2: tank::FlashReceipt<BUCK, T0>) {
        abort 0
    }

    public fun get_bottle_info_by_debtor<T0>(arg0: &BucketProtocol, arg1: address) : (u64, u64) {
        abort 0
    }

    public fun get_bottle_info_with_interest_by_debtor<T0>(arg0: &BucketProtocol, arg1: address, arg2: &clock::Clock) : (u64, u64) {
        abort 0
    }

    public fun get_min_bottle_size(arg0: &BucketProtocol) : u64 {
        abort 0
    }

    public fun init_bottle_current_interest_index<T0>(arg0: &AdminCap, arg1: &mut BucketProtocol, arg2: address, arg3: &mut tx_context::TxContext) {
        abort 0
    }

    public fun init_bottle_interest_index<T0>(arg0: &AdminCap, arg1: &mut BucketProtocol, arg2: address, arg3: u256, arg4: &mut tx_context::TxContext) {
        abort 0
    }

    public fun input<T0, T1: drop>(arg0: &mut BucketProtocol, arg1: pipe::InputCarrier<T0, T1>) {
        abort 0
    }

    public fun is_liquidatable<T0>(arg0: &BucketProtocol, arg1: &bucket_oracle::BucketOracle, arg2: &clock::Clock, arg3: address) : bool {
        abort 0
    }

    public fun liquidate_under_normal_mode<T0>(arg0: &mut BucketProtocol, arg1: &bucket_oracle::BucketOracle, arg2: &clock::Clock, arg3: address) : balance::Balance<T0> {
        abort 0
    }

    public fun liquidate_under_recovery_mode<T0>(arg0: &mut BucketProtocol, arg1: &bucket_oracle::BucketOracle, arg2: &clock::Clock, arg3: address) : balance::Balance<T0> {
        abort 0
    }

    public fun mint_sbuck(arg0: &mut BucketProtocol, arg1: &mut sbuck::Flask<BUCK>, arg2: coin::Coin<BUCK>) : balance::Balance<sbuck::SBUCK> {
        abort 0
    }

    public fun new_strap_with_fee_rate_to<T0>(arg0: &AdminCap, arg1: u64, arg2: address, arg3: &mut tx_context::TxContext) {
        abort 0
    }

    public fun output<T0, T1: drop>(arg0: &mut BucketProtocol, arg1: u64) : pipe::OutputCarrier<T0, T1> {
        abort 0
    }

    public fun package_version() : u64 {
        abort 0
    }

    public fun redeem<T0>(arg0: &mut BucketProtocol, arg1: &bucket_oracle::BucketOracle, arg2: &clock::Clock, arg3: balance::Balance<BUCK>, arg4: option::Option<address>) : balance::Balance<T0> {
        abort 0
    }

    public fun remove_test_version(arg0: &AdminCap, arg1: &mut BucketProtocol) {
        abort 0
    }

    public fun repay<T0>(arg0: &mut BucketProtocol, arg1: balance::Balance<BUCK>, arg2: &tx_context::TxContext) : balance::Balance<T0> {
        abort 0
    }

    public fun repay_debt<T0>(arg0: &mut BucketProtocol, arg1: balance::Balance<BUCK>, arg2: &clock::Clock, arg3: &tx_context::TxContext) : balance::Balance<T0> {
        abort 0
    }

    public fun repay_with_strap<T0>(arg0: &mut BucketProtocol, arg1: &strap::BottleStrap<T0>, arg2: balance::Balance<BUCK>, arg3: &clock::Clock) : balance::Balance<T0> {
        abort 0
    }

    public fun set_interest_rate<T0>(arg0: &AdminCap, arg1: &mut BucketProtocol, arg2: u256, arg3: &clock::Clock) {
        abort 0
    }

    public fun set_reservoir_partner<T0, T1: drop>(arg0: &AdminCap, arg1: &mut BucketProtocol, arg2: u64, arg3: u64) {
        abort 0
    }

    public fun share_flash_mint_config(arg0: &AdminCap, arg1: u64, arg2: u64, arg3: &mut tx_context::TxContext) {
        abort 0
    }

    public fun tank_withdraw<T0>(arg0: &mut BucketProtocol, arg1: &bucket_oracle::BucketOracle, arg2: &clock::Clock, arg3: &mut bkt::BktTreasury, arg4: tank::ContributorToken<BUCK, T0>, arg5: &tx_context::TxContext) : (balance::Balance<BUCK>, balance::Balance<T0>, balance::Balance<bkt::BKT>) {
        abort 0
    }

    public fun top_up<T0>(arg0: &mut BucketProtocol, arg1: balance::Balance<T0>, arg2: address, arg3: option::Option<address>) {
        abort 0
    }

    public fun top_up_coll<T0>(arg0: &mut BucketProtocol, arg1: balance::Balance<T0>, arg2: address, arg3: option::Option<address>, arg4: &clock::Clock) {
        abort 0
    }

    public fun update_flash_mint_config(arg0: &AdminCap, arg1: &mut FlashMintConfig, arg2: u64, arg3: u64) {
        abort 0
    }

    public fun update_reservoir_fee_rate<T0>(arg0: &AdminCap, arg1: &mut BucketProtocol, arg2: u64, arg3: u64) {
        abort 0
    }

    public fun withdraw<T0>(arg0: &mut BucketProtocol, arg1: &bucket_oracle::BucketOracle, arg2: &clock::Clock, arg3: u64, arg4: option::Option<address>, arg5: &tx_context::TxContext) : balance::Balance<T0> {
        abort 0
    }

    public fun withdraw_surplus_collateral<T0>(arg0: &mut BucketProtocol, arg1: &tx_context::TxContext) : balance::Balance<T0> {
        abort 0
    }

    public fun withdraw_surplus_with_strap<T0>(arg0: &mut BucketProtocol, arg1: &strap::BottleStrap<T0>) : balance::Balance<T0> {
        abort 0
    }

    public fun withdraw_with_strap<T0>(arg0: &mut BucketProtocol, arg1: &bucket_oracle::BucketOracle, arg2: &strap::BottleStrap<T0>, arg3: &clock::Clock, arg4: u64, arg5: option::Option<address>) : balance::Balance<T0> {
        abort 0
    }

    public fun interest_amount(
        _protocol: &BucketProtocol,
        _flask: &sbuck::Flask<BUCK>,
        _clock: &clock::Clock,
    ): u64 {
        abort 0
    }

    public fun buck_to_sbuck(
        _protocol: &mut BucketProtocol,
        _flask: &mut sbuck::Flask<BUCK>,
        _clock: &clock::Clock,
        _input: balance::Balance<BUCK>,
    ): balance::Balance<sbuck::SBUCK> {
        abort 0
    }

    public fun sbuck_to_buck(
        _protocol: &mut BucketProtocol,
        _flask: &mut sbuck::Flask<BUCK>,
        _clock: &clock::Clock,
        _input: balance::Balance<sbuck::SBUCK>,
    ): balance::Balance<BUCK> {
        abort 0    
    }
}
