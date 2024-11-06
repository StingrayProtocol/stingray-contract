module bucket_protocol::pipe_events {

    // ----- Use Statements -----

    use sui::balance;

    // ----- public structs -----

    public struct Input<phantom T0, phantom T1: drop> has copy, drop {
        volume: u64,
    }

    public struct Output<phantom T0, phantom T1: drop> has copy, drop {
        volume: u64,
    }
    // ----- Public Functions -----

    public(package) fun emit_input<T0, T1: drop>(arg0: &balance::Balance<T0>) {
        abort 0
    }

    public(package) fun emit_output<T0, T1: drop>(arg0: u64) {
        abort 0
    }
}
