module bucket_protocol::pipe {

    // ----- Use Statements -----

    use sui::balance;
    use sui::object;
    use sui::tx_context;

    // ----- public structs -----

    public struct InputCarrier<phantom T0, phantom T1: drop> {
        content: balance::Balance<T0>,
    }

    public struct OutputCarrier<phantom T0, phantom T1: drop> {
        content: balance::Balance<T0>,
    }

    public struct Pipe<phantom T0, phantom T1: drop> has store, key {
        id: object::UID,
        output_volume: u64,
    }

    public struct PipeType<phantom T0, phantom T1: drop> has copy, drop, store {
        dummy_field: bool,
    }
    // ----- Public Functions -----

    public fun destroy_output_carrier<T0, T1: drop>(arg0: T1, arg1: OutputCarrier<T0, T1>) : balance::Balance<T0> {
        abort 0
    }

    public fun input<T0, T1: drop>(arg0: T1, arg1: balance::Balance<T0>) : InputCarrier<T0, T1> {
        abort 0
    }

    public fun input_carrier_volume<T0, T1: drop>(arg0: &InputCarrier<T0, T1>) : u64 {
        abort 0
    }

    public fun output_carrier_volume<T0, T1: drop>(arg0: &OutputCarrier<T0, T1>) : u64 {
        abort 0
    }

    public fun output_volume<T0, T1: drop>(arg0: &Pipe<T0, T1>) : u64 {
        abort 0
    }

    public(package) fun destroy_input_carrier<T0, T1: drop>(arg0: &mut Pipe<T0, T1>, arg1: InputCarrier<T0, T1>) : balance::Balance<T0> {
        abort 0
    }

    public(package) fun destroy_pipe<T0, T1: drop>(arg0: Pipe<T0, T1>) {
        abort 0
    }

    public(package) fun new_pipe<T0, T1: drop>(arg0: &mut tx_context::TxContext) : Pipe<T0, T1> {
        abort 0
    }

    public(package) fun new_type<T0, T1: drop>() : PipeType<T0, T1> {
        abort 0
    }

    public(package) fun output<T0, T1: drop>(arg0: &mut Pipe<T0, T1>, arg1: balance::Balance<T0>) : OutputCarrier<T0, T1> {
        abort 0
    }
}
