module bucket_protocol::tank_events {

    // ----- Use Statements -----

    use std::ascii;

    // ----- public structs -----

    public struct Absorb has copy, drop {
        tank_type: ascii::String,
        buck_amount: u64,
        collateral_amount: u64,
    }

    public struct CollectBKT has copy, drop {
        tank_type: ascii::String,
        bkt_amount: u64,
    }

    public struct Deposite has copy, drop {
        tank_type: ascii::String,
        buck_amount: u64,
    }

    public struct TankUpdate has copy, drop {
        tank_type: ascii::String,
        current_epoch: u64,
        current_scale: u64,
        current_p: u64,
    }

    public struct Withdraw has copy, drop {
        tank_type: ascii::String,
        buck_amount: u64,
        collateral_amount: u64,
        bkt_amount: u64,
    }
    // ----- Public Functions -----

    public(package) fun emit_absorb<T0>(arg0: u64, arg1: u64) {
        abort 0
    }

    public(package) fun emit_collect_bkt<T0>(arg0: u64) {
        abort 0
    }

    public(package) fun emit_deposit<T0>(arg0: u64) {
        abort 0
    }

    public(package) fun emit_tank_update<T0>(arg0: u64, arg1: u64, arg2: u64) {
        abort 0
    }

    public(package) fun emit_withdraw<T0>(arg0: u64, arg1: u64, arg2: u64) {
        abort 0
    }
}
