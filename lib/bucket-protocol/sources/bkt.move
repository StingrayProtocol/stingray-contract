module bucket_protocol::bkt {

    // ----- Use Statements -----

    use sui::object;
    use sui::balance;

    // ----- public structs -----

    public struct BKT has drop {
        dummy_field: bool,
    }

    public struct BktAdminCap has store, key {
        id: object::UID,
    }

    public struct BktTreasury has key {
        id: object::UID,
        eco_part: balance::Balance<BKT>,
        bkt_supply: balance::Supply<BKT>,
    }
    // ----- Public Functions -----

    public fun collect_bkt(arg0: &mut BktTreasury, arg1: balance::Balance<BKT>) {
        abort 0
    }

    public fun get_eco_part_balance(arg0: &BktTreasury) : u64 {
        abort 0
    }

    public fun withdraw_treasury(arg0: &BktAdminCap, arg1: &mut BktTreasury, arg2: u64) : balance::Balance<BKT> {
        abort 0
    }

    public(package) fun release_bkt(arg0: &mut BktTreasury, arg1: u64) : balance::Balance<BKT> {
        abort 0
    }
}
