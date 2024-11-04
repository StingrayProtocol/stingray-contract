module bucket_protocol::bucket {

    // ----- Use Statements -----

    use sui::object;
    use std::option;
    use sui::balance;
    use 0xce7ff77a83ea0cb6fd39bd8748e2ec89a3f41e8efdc3f4eb123e0ca37b184db2::bottle;
    use sui::table;
    use 0xce7ff77a83ea0cb6fd39bd8748e2ec89a3f41e8efdc3f4eb123e0ca37b184db2::interest;
    use 0xce7ff77a83ea0cb6fd39bd8748e2ec89a3f41e8efdc3f4eb123e0ca37b184db2::strap;
    use bucket_oracle::bucket_oracle;
    use sui::clock;
    use sui::tx_context;

    // ----- public structs -----

    public struct Bucket<phantom T0> has store, key {
        id: object::UID,
        min_collateral_ratio: u64,
        recovery_mode_threshold: u64,
        collateral_decimal: u8,
        max_mint_amount: option::Option<u64>,
        collateral_vault: balance::Balance<T0>,
        bottle_table: bottle::BottleTable,
        surplus_bottle_table: table::Table<address, bottle::Bottle>,
        minted_buck_amount: u64,
        base_fee_rate: u64,
        latest_redemption_time: u64,
        total_flash_loan_amount: u64,
    }

    public struct FlashReceipt<phantom T0> {
        amount: u64,
        fee: u64,
    }

    public struct OutputKey has copy, drop, store {
        dummy_field: bool,
    }

    public struct OutputVolume has store {
        volume: u64,
    }

    public struct PendingRecord has store, key {
        id: object::UID,
        bucket_pending_debt: u64,
        bucket_pending_collateral: u64,
    }
    // ----- Public Functions -----

    public fun borrow_bottle_table<T0>(arg0: &Bucket<T0>) : &bottle::BottleTable {
        abort 0
    }

    public fun borrow_interest_table<T0>(arg0: &Bucket<T0>) : &interest::InterestTable {
        abort 0
    }

    public fun borrow_pending_record<T0>(arg0: &Bucket<T0>) : &PendingRecord {
        abort 0
    }

    public fun borrow_surplus_bottle_table<T0>(arg0: &Bucket<T0>) : &table::Table<address, bottle::Bottle> {
        abort 0
    }

    public fun bottle_exists<T0>(arg0: &Bucket<T0>, arg1: address) : bool {
        abort 0
    }

    public fun compute_base_rate<T0>(arg0: &Bucket<T0>, arg1: u64) : u64 {
        abort 0
    }

    public fun destroy_empty_strap<T0>(arg0: &Bucket<T0>, arg1: strap::BottleStrap<T0>) {
        abort 0
    }

    public fun get_bottle_icr<T0>(arg0: &Bucket<T0>, arg1: &bucket_oracle::BucketOracle, arg2: &clock::Clock, arg3: address) : u64 {
        abort 0
    }

    public fun get_bottle_info<T0>(arg0: &Bucket<T0>, arg1: &bottle::Bottle) : (u64, u64) {
        abort 0
    }

    public fun get_bottle_info_by_debtor<T0>(arg0: &Bucket<T0>, arg1: address) : (u64, u64) {
        abort 0
    }

    public fun get_bottle_info_with_interest<T0>(arg0: &Bucket<T0>, arg1: &bottle::Bottle, arg2: &clock::Clock) : (u64, u64) {
        abort 0
    }

    public fun get_bottle_info_with_interest_by_debtor<T0>(arg0: &Bucket<T0>, arg1: address, arg2: &clock::Clock) : (u64, u64) {
        abort 0
    }

    public fun get_bottle_table_length<T0>(arg0: &Bucket<T0>) : u64 {
        abort 0
    }

    public fun get_bucket_debt<T0>(arg0: &Bucket<T0>, arg1: &clock::Clock) : u64 {
        abort 0
    }

    public fun get_bucket_pending_collateral<T0>(arg0: &Bucket<T0>) : u64 {
        abort 0
    }

    public fun get_bucket_pending_debt<T0>(arg0: &Bucket<T0>) : u64 {
        abort 0
    }

    public fun get_bucket_size<T0>(arg0: &Bucket<T0>) : u64 {
        abort 0
    }

    public fun get_bucket_tcr<T0>(arg0: &Bucket<T0>, arg1: &bucket_oracle::BucketOracle, arg2: &clock::Clock) : u64 {
        abort 0
    }

    public fun get_collateral_output_volume<T0>(arg0: &Bucket<T0>) : u64 {
        abort 0
    }

    public fun get_collateral_vault_balance<T0>(arg0: &Bucket<T0>) : u64 {
        abort 0
    }

    public fun get_lowest_cr_debtor<T0>(arg0: &Bucket<T0>) : option::Option<address> {
        abort 0
    }

    public fun get_max_mint_amount<T0>(arg0: &Bucket<T0>) : option::Option<u64> {
        abort 0
    }

    public fun get_minimum_collateral_ratio<T0>(arg0: &Bucket<T0>) : u64 {
        abort 0
    }

    public fun get_minted_buck_amount<T0>(arg0: &Bucket<T0>) : u64 {
        abort 0
    }

    public fun get_receipt_info<T0>(arg0: &FlashReceipt<T0>) : (u64, u64) {
        abort 0
    }

    public fun get_surplus_bottle_info_by_debtor<T0>(arg0: &Bucket<T0>, arg1: address) : (u64, u64) {
        abort 0
    }

    public fun get_surplus_bottle_table_size<T0>(arg0: &Bucket<T0>) : u64 {
        abort 0
    }

    public fun get_surplus_collateral_amount<T0>(arg0: &Bucket<T0>, arg1: address) : u64 {
        abort 0
    }

    public fun get_total_collateral_balance<T0>(arg0: &Bucket<T0>) : u64 {
        abort 0
    }

    public fun get_total_flash_loan_amount<T0>(arg0: &Bucket<T0>) : u64 {
        abort 0
    }

    public fun has_liquidatable_bottle<T0>(arg0: &Bucket<T0>, arg1: &bucket_oracle::BucketOracle, arg2: &clock::Clock) : bool {
        abort 0
    }

    public fun is_healthy_bottle<T0>(arg0: &Bucket<T0>, arg1: &bucket_oracle::BucketOracle, arg2: &clock::Clock, arg3: &bottle::Bottle) : bool {
        abort 0
    }

    public fun is_healthy_bottle_by_debtor<T0>(arg0: &Bucket<T0>, arg1: &bucket_oracle::BucketOracle, arg2: &clock::Clock, arg3: address) : bool {
        abort 0
    }

    public fun is_in_recovery_mode<T0>(arg0: &Bucket<T0>, arg1: &bucket_oracle::BucketOracle, arg2: &clock::Clock) : bool {
        abort 0
    }

    public fun is_interest_table_exists<T0>(arg0: &Bucket<T0>) : bool {
        abort 0
    }

    public fun is_liquidatable<T0>(arg0: &Bucket<T0>, arg1: &bucket_oracle::BucketOracle, arg2: &clock::Clock, arg3: address) : bool {
        abort 0
    }

    public fun is_not_locked<T0>(arg0: &Bucket<T0>) : bool {
        abort 0
    }

    public fun next_debtor<T0>(arg0: &Bucket<T0>, arg1: address) : &option::Option<address> {
        abort 0
    }

    public fun prev_debtor<T0>(arg0: &Bucket<T0>, arg1: address) : &option::Option<address> {
        abort 0
    }

    public(package) fun accrue_interests_by_debtor<T0>(arg0: &mut Bucket<T0>, arg1: address, arg2: &clock::Clock) : u64 {
        abort 0
    }

    public(package) fun add_interest_index_to_bottle(arg0: &mut bottle::Bottle, arg1: u256, arg2: &mut tx_context::TxContext) {
        abort 0
    }

    public(package) fun add_interest_index_to_bottle_by_debtor<T0>(arg0: &mut Bucket<T0>, arg1: address, arg2: u256, arg3: &mut tx_context::TxContext) {
        abort 0
    }

    public(package) fun add_interest_table_to_bucket<T0>(arg0: &mut Bucket<T0>, arg1: &clock::Clock, arg2: &mut tx_context::TxContext) {
        abort 0
    }

    public(package) fun add_pending_record_to_bucket<T0>(arg0: &mut Bucket<T0>, arg1: &mut tx_context::TxContext) {
        abort 0
    }

    public(package) fun adjust_pending_record<T0>(arg0: &mut Bucket<T0>, arg1: u64, arg2: u64) {
        abort 0
    }

    public(package) fun borrow_interest_table_mut<T0>(arg0: &mut Bucket<T0>) : &mut interest::InterestTable {
        abort 0
    }

    public(package) fun borrow_pending_record_mut<T0>(arg0: &mut Bucket<T0>) : &mut PendingRecord {
        abort 0
    }

    public(package) fun handle_borrow<T0>(arg0: &mut Bucket<T0>, arg1: &bucket_oracle::BucketOracle, arg2: address, arg3: &clock::Clock, arg4: balance::Balance<T0>, arg5: u64, arg6: option::Option<address>, arg7: u64, arg8: &mut tx_context::TxContext) {
        abort 0
    }

    public(package) fun handle_flash_borrow<T0>(arg0: &mut Bucket<T0>, arg1: u64) : (balance::Balance<T0>, FlashReceipt<T0>) {
        abort 0
    }

    public(package) fun handle_flash_repay<T0>(arg0: &mut Bucket<T0>, arg1: balance::Balance<T0>, arg2: FlashReceipt<T0>) : balance::Balance<T0> {
        abort 0
    }

    public(package) fun handle_redeem<T0>(arg0: &mut Bucket<T0>, arg1: &bucket_oracle::BucketOracle, arg2: &clock::Clock, arg3: u64, arg4: option::Option<address>) : balance::Balance<T0> {
        abort 0
    }

    public(package) fun handle_repay<T0>(arg0: &mut Bucket<T0>, arg1: address, arg2: u64, arg3: u64, arg4: bool, arg5: &clock::Clock) : balance::Balance<T0> {
        abort 0
    }

    public(package) fun handle_repay_capped<T0>(arg0: &mut Bucket<T0>, arg1: address, arg2: u64, arg3: &bucket_oracle::BucketOracle, arg4: &clock::Clock) : balance::Balance<T0> {
        abort 0
    }

    public(package) fun handle_top_up<T0>(arg0: &mut Bucket<T0>, arg1: balance::Balance<T0>, arg2: address, arg3: option::Option<address>, arg4: &clock::Clock) {
        abort 0
    }

    public(package) fun handle_withdraw<T0>(arg0: &mut Bucket<T0>, arg1: &bucket_oracle::BucketOracle, arg2: address, arg3: &clock::Clock, arg4: u64, arg5: option::Option<address>) : balance::Balance<T0> {
        abort 0
    }

    public(package) fun input<T0>(arg0: &mut Bucket<T0>, arg1: balance::Balance<T0>) {
        abort 0
    }

    public(package) fun new<T0>(arg0: u64, arg1: u64, arg2: u8, arg3: option::Option<u64>, arg4: &mut tx_context::TxContext) : Bucket<T0> {
        abort 0
    }

    public(package) fun new_pending_record(arg0: &mut tx_context::TxContext) : PendingRecord {
        abort 0
    }

    public(package) fun output<T0>(arg0: &mut Bucket<T0>, arg1: u64) : balance::Balance<T0> {
        abort 0
    }

    public(package) fun update_base_rate_fee<T0>(arg0: &mut Bucket<T0>, arg1: u64, arg2: u64) {
        abort 0
    }

    public(package) fun update_max_mint_amount<T0>(arg0: &mut Bucket<T0>, arg1: option::Option<u64>) {
        abort 0
    }

    public(package) fun update_snapshot<T0>(arg0: &mut Bucket<T0>) {
        abort 0
    }

    public(package) fun withdraw_surplus_collateral<T0>(arg0: &mut Bucket<T0>, arg1: address) : balance::Balance<T0> {
        abort 0
    }
}
