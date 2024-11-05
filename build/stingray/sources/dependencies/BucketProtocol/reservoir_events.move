module bucket_protocol::reservoir_events {

    // ----- public structs -----

    public struct ChargeReservior<phantom T0> has copy, drop {
        inflow_amount: u64,
        buck_amount: u64,
    }

    public struct DischargeReservior<phantom T0> has copy, drop {
        outflow_amount: u64,
        buck_amount: u64,
    }
    // ----- Public Functions -----

    public(package) fun emit_charge_reservoir<T0>(arg0: u64, arg1: u64) {
        abort 0
    }

    public(package) fun emit_discharge_reservoir<T0>(arg0: u64, arg1: u64) {
        abort 0
    }
}
