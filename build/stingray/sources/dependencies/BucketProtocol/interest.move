module bucket_protocol::interest {

    // ----- Use Statements -----

    use sui::object;
    use sui::clock;
    use sui::tx_context;

    // ----- public structs -----

    public struct BottleInterestIndex has store, key {
        id: object::UID,
        active_interest_index: u256,
    }

    public struct InterestTable has store, key {
        id: object::UID,
        interest_rate: u256,
        active_interest_index: u256,
        last_active_index_update: u64,
        interest_payable: u256,
    }
    // ----- Public Functions -----

    public fun get_active_interest_index(arg0: &InterestTable) : u256 {
        abort 0
    }

    public fun get_bottle_interest_index(arg0: &BottleInterestIndex) : u256 {
        abort 0
    }

    public fun get_interest_payable(arg0: &InterestTable) : u256 {
        abort 0
    }

    public fun get_interest_rate(arg0: &InterestTable) : u256 {
        abort 0
    }

    public fun get_interest_table_info(arg0: &InterestTable) : (u256, u256, u64, u256) {
        abort 0
    }

    public fun get_last_active_index_update(arg0: &InterestTable) : u64 {
        abort 0
    }

    public(package) fun accrue_active_interests(arg0: &mut InterestTable, arg1: u64, arg2: &clock::Clock) : (u256, u256) {
        abort 0
    }

    public(package) fun calculate_interest_index(arg0: &InterestTable, arg1: &clock::Clock) : (u256, u256) {
        abort 0
    }

    public(package) fun collect_interests(arg0: &mut InterestTable) : u64 {
        abort 0
    }

    public(package) fun new_bottle_interest_index(arg0: u256, arg1: &mut tx_context::TxContext) : BottleInterestIndex {
        abort 0
    }

    public(package) fun new_interest_table(arg0: &clock::Clock, arg1: &mut tx_context::TxContext) : InterestTable {
        abort 0
    }

    public(package) fun set_interest_rate(arg0: &mut InterestTable, arg1: u256, arg2: u64, arg3: &clock::Clock) {
        abort 0
    }

    public(package) fun update_bottle_interest_index(arg0: &mut BottleInterestIndex, arg1: u256) {
        abort 0
    }
}
