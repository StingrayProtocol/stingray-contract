module bucket_protocol::tank {

    // ----- Use Statements -----

    use sui::object;
    use sui::balance;
    use sui::table;
    use 0xce7ff77a83ea0cb6fd39bd8748e2ec89a3f41e8efdc3f4eb123e0ca37b184db2::bkt;
    use sui::tx_context;

    // ----- public structs -----

    public struct ContributorToken<phantom T0, phantom T1> has store, key {
        id: object::UID,
        deposit_amount: u64,
        start_p: u64,
        start_s: u64,
        start_g: u64,
        start_epoch: u64,
        start_scale: u64,
        ctx_epoch: u64,
    }

    public struct DigestKey has copy, drop, store {
        dummy_field: bool,
    }

    public struct EpochAndScale has copy, drop, store {
        epoch: u64,
        scale: u64,
    }

    public struct FlashReceipt<phantom T0, phantom T1> {
        amount: u64,
        fee: u64,
    }

    public struct TANK has drop {
        dummy_field: bool,
    }

    public struct Tank<phantom T0, phantom T1> has store, key {
        id: object::UID,
        reserve: balance::Balance<T0>,
        collateral_pool: balance::Balance<T1>,
        current_p: u64,
        current_epoch: u64,
        epoch_scale_sum_map: table::Table<EpochAndScale, u64>,
        current_scale: u64,
        bkt_pool: balance::Balance<bkt::BKT>,
        epoch_scale_gain_map: table::Table<EpochAndScale, u64>,
        total_flash_loan_amount: u64,
    }
    // ----- Public Functions -----

    public fun airdrop_bkt<T0, T1>(arg0: &mut Tank<T0, T1>, arg1: balance::Balance<bkt::BKT>) {
        abort 0
    }

    public fun airdrop_collateral<T0, T1>(arg0: &mut Tank<T0, T1>, arg1: balance::Balance<T1>) {
        abort 0
    }

    public fun claim<T0, T1>(arg0: &mut Tank<T0, T1>, arg1: &mut bkt::BktTreasury, arg2: &mut ContributorToken<T0, T1>, arg3: &tx_context::TxContext) : (balance::Balance<T1>, balance::Balance<bkt::BKT>) {
        abort 0
    }

    public fun deposit<T0, T1>(arg0: &mut Tank<T0, T1>, arg1: balance::Balance<T0>, arg2: &mut tx_context::TxContext) : ContributorToken<T0, T1> {
        abort 0
    }

    public fun err_deposit_and_withdraw_in_same_txn() {
        abort 0
    }

    public fun get_bkt_pool_balance<T0, T1>(arg0: &Tank<T0, T1>) : u64 {
        abort 0
    }

    public fun get_bkt_reward_amount<T0, T1>(arg0: &Tank<T0, T1>, arg1: &ContributorToken<T0, T1>) : u64 {
        abort 0
    }

    public fun get_collateral_pool_balance<T0, T1>(arg0: &Tank<T0, T1>) : u64 {
        abort 0
    }

    public fun get_collateral_reward_amount<T0, T1>(arg0: &Tank<T0, T1>, arg1: &ContributorToken<T0, T1>) : u64 {
        abort 0
    }

    public fun get_contributor_token_value<T0, T1>(arg0: &ContributorToken<T0, T1>) : (u64, u64, u64, u64, u64, u64) {
        abort 0
    }

    public fun get_current_epoch<T0, T1>(arg0: &Tank<T0, T1>) : u64 {
        abort 0
    }

    public fun get_current_p<T0, T1>(arg0: &Tank<T0, T1>) : u64 {
        abort 0
    }

    public fun get_current_scale<T0, T1>(arg0: &Tank<T0, T1>) : u64 {
        abort 0
    }

    public fun get_epoch_scale_gain_map<T0, T1>(arg0: &Tank<T0, T1>, arg1: u64, arg2: u64) : u64 {
        abort 0
    }

    public fun get_epoch_scale_sum_map<T0, T1>(arg0: &Tank<T0, T1>, arg1: u64, arg2: u64) : u64 {
        abort 0
    }

    public fun get_receipt_info<T0, T1>(arg0: &FlashReceipt<T0, T1>) : (u64, u64) {
        abort 0
    }

    public fun get_reserve_balance<T0, T1>(arg0: &Tank<T0, T1>) : u64 {
        abort 0
    }

    public fun get_token_ctx_epoch<T0, T1>(arg0: &ContributorToken<T0, T1>) : u64 {
        abort 0
    }

    public fun get_token_weight<T0, T1>(arg0: &Tank<T0, T1>, arg1: &ContributorToken<T0, T1>) : u64 {
        abort 0
    }

    public fun get_total_flash_loan_amount<T0, T1>(arg0: &Tank<T0, T1>) : u64 {
        abort 0
    }

    public fun is_not_locked<T0, T1>(arg0: &Tank<T0, T1>) : bool {
        abort 0
    }

    public fun new_table(arg0: &mut tx_context::TxContext) : table::Table<EpochAndScale, u64> {
        abort 0
    }

    public(package) fun absorb<T0, T1>(arg0: &mut Tank<T0, T1>, arg1: balance::Balance<T1>, arg2: u64) : balance::Balance<T0> {
        abort 0
    }

    public(package) fun collect_bkt<T0, T1>(arg0: &mut Tank<T0, T1>, arg1: balance::Balance<bkt::BKT>) {
        abort 0
    }

    public(package) fun handle_flash_borrow<T0, T1>(arg0: &mut Tank<T0, T1>, arg1: u64) : (balance::Balance<T0>, FlashReceipt<T0, T1>) {
        abort 0
    }

    public(package) fun handle_flash_repay<T0, T1>(arg0: &mut Tank<T0, T1>, arg1: balance::Balance<T0>, arg2: FlashReceipt<T0, T1>) : balance::Balance<T0> {
        abort 0
    }

    public(package) fun new<T0, T1>(arg0: &mut tx_context::TxContext) : Tank<T0, T1> {
        abort 0
    }

    public(package) fun withdraw<T0, T1>(arg0: &mut Tank<T0, T1>, arg1: &mut bkt::BktTreasury, arg2: ContributorToken<T0, T1>, arg3: &tx_context::TxContext) : (balance::Balance<T0>, balance::Balance<T1>, balance::Balance<bkt::BKT>) {
        abort 0
    }
}
