module bucket_protocol::bottle {

    // ----- Use Statements -----

    use sui::object;
    use 0xdb9a10bb9536ab367b7d1ffa404c1d6c55f009076df1139dc108dd86608bbe::linked_table;
    use std::option;
    use 0xce7ff77a83ea0cb6fd39bd8748e2ec89a3f41e8efdc3f4eb123e0ca37b184db2::interest;
    use sui::clock;
    use sui::tx_context;
    use bucket_oracle::bucket_oracle;

    // ----- public structs -----

    public struct Bottle has store, key {
        id: object::UID,
        collateral_amount: u64,
        buck_amount: u64,
        stake_amount: u64,
        reward_coll_snapshot: u128,
        reward_debt_snapshot: u128,
    }

    public struct BottleTable has store, key {
        id: object::UID,
        table: linked_table::LinkedTable<address, Bottle>,
        total_stake: u64,
        total_stake_snapshot: u64,
        total_collateral_snapshot: u64,
        debt_per_unit_stake: u128,
        reward_per_unit_stake: u128,
        last_reward_error: u128,
        last_debt_error: u128,
    }
    // ----- Public Functions -----

    public fun borrow_bottle(arg0: &BottleTable, arg1: address) : &Bottle {
        abort 0
    }

    public fun borrow_interest_index(arg0: &Bottle) : &interest::BottleInterestIndex {
        abort 0
    }

    public fun borrow_table(arg0: &BottleTable) : &linked_table::LinkedTable<address, Bottle> {
        abort 0
    }

    public fun bottle_exists(arg0: &BottleTable, arg1: address) : bool {
        abort 0
    }

    public fun cr_greater(arg0: &BottleTable, arg1: &Bottle, arg2: &Bottle) : bool {
        abort 0
    }

    public fun cr_greater_with_interest(arg0: &BottleTable, arg1: &interest::InterestTable, arg2: &Bottle, arg3: &Bottle, arg4: &clock::Clock) : bool {
        abort 0
    }

    public fun cr_less_or_equal(arg0: &BottleTable, arg1: &Bottle, arg2: &Bottle) : bool {
        abort 0
    }

    public fun cr_less_or_equal_with_interest(arg0: &BottleTable, arg1: &interest::InterestTable, arg2: &Bottle, arg3: &Bottle, arg4: &clock::Clock) : bool {
        abort 0
    }

    public fun destroy_bottle(arg0: &mut BottleTable, arg1: address) {
        abort 0
    }

    public fun get_bottle_info(arg0: &BottleTable, arg1: &Bottle) : (u64, u64) {
        abort 0
    }

    public fun get_bottle_info_by_debtor(arg0: &BottleTable, arg1: address) : (u64, u64) {
        abort 0
    }

    public fun get_bottle_info_with_interest(arg0: &BottleTable, arg1: &Bottle, arg2: &interest::InterestTable, arg3: &clock::Clock) : (u64, u64) {
        abort 0
    }

    public fun get_bottle_info_with_interest_by_debtor(arg0: &BottleTable, arg1: address, arg2: &interest::InterestTable, arg3: &clock::Clock) : (u64, u64) {
        abort 0
    }

    public fun get_bottle_raw_info(arg0: &Bottle) : (u64, u64) {
        abort 0
    }

    public fun get_bottle_raw_info_by_debator(arg0: &BottleTable, arg1: address) : (u64, u64) {
        abort 0
    }

    public fun get_lowest_cr_debtor(arg0: &BottleTable) : option::Option<address> {
        abort 0
    }

    public fun get_pending_coll(arg0: &Bottle, arg1: &BottleTable) : u64 {
        abort 0
    }

    public fun get_pending_debt(arg0: &Bottle, arg1: &BottleTable) : u64 {
        abort 0
    }

    public fun get_table_length(arg0: &BottleTable) : u64 {
        abort 0
    }

    public fun is_interest_index_exists(arg0: &Bottle) : bool {
        abort 0
    }

    public fun re_insert(arg0: &mut BottleTable, arg1: address) {
        abort 0
    }

    public fun re_insert_bottle(arg0: &mut BottleTable, arg1: &interest::InterestTable, arg2: address, arg3: &clock::Clock) {
        abort 0
    }

    public(package) fun add_interest_index_to_bottle(arg0: &mut Bottle, arg1: u256, arg2: &mut tx_context::TxContext) {
        abort 0
    }

    public(package) fun borrow_bottle_mut(arg0: &mut BottleTable, arg1: address) : &mut Bottle {
        abort 0
    }

    public(package) fun borrow_interest_index_mut(arg0: &mut Bottle) : &mut interest::BottleInterestIndex {
        abort 0
    }

    public(package) fun destroy_surplus_bottle(arg0: Bottle) : u64 {
        abort 0
    }

    public(package) fun get_bottle_info_after_update(arg0: &mut BottleTable, arg1: address) : (u64, u64) {
        abort 0
    }

    public(package) fun insert(arg0: &mut BottleTable, arg1: address, arg2: Bottle, arg3: option::Option<address>) {
        abort 0
    }

    public(package) fun insert_bottle(arg0: &mut BottleTable, arg1: &interest::InterestTable, arg2: address, arg3: Bottle, arg4: option::Option<address>, arg5: &clock::Clock) {
        abort 0
    }

    public(package) fun new(arg0: &BottleTable, arg1: &mut tx_context::TxContext) : Bottle {
        abort 0
    }

    public(package) fun new_table(arg0: &mut tx_context::TxContext) : BottleTable {
        abort 0
    }

    public(package) fun pop_front(arg0: &mut BottleTable) : (address, Bottle) {
        abort 0
    }

    public(package) fun record_borrow(arg0: &mut Bottle, arg1: u64, arg2: u64, arg3: u64) {
        abort 0
    }

    public(package) fun record_redeem(arg0: &mut Bottle, arg1: u64, arg2: u64) {
        abort 0
    }

    public(package) fun record_redistribution(arg0: &mut BottleTable, arg1: u64, arg2: u64, arg3: address) {
        abort 0
    }

    public(package) fun record_repay(arg0: &mut Bottle, arg1: u64, arg2: u64, arg3: bool) : (bool, u64) {
        abort 0
    }

    public(package) fun record_repay_capped<T0>(arg0: &mut Bottle, arg1: u64, arg2: &bucket_oracle::BucketOracle, arg3: &clock::Clock, arg4: u64, arg5: u8) : (bool, u64) {
        abort 0
    }

    public(package) fun record_top_up(arg0: &mut Bottle, arg1: u64) {
        abort 0
    }

    public(package) fun record_withdraw(arg0: &mut Bottle, arg1: u64) {
        abort 0
    }

    public(package) fun remove_bottle(arg0: &mut BottleTable, arg1: address) : Bottle {
        abort 0
    }

    public(package) fun remove_bottle_stake(arg0: &mut BottleTable, arg1: address) {
        abort 0
    }

    public(package) fun update_bottle_debt_and_interest_index(arg0: &mut Bottle, arg1: u64, arg2: u256) {
        abort 0
    }

    public(package) fun update_snapshot(arg0: &mut BottleTable, arg1: u64) {
        abort 0
    }
}
