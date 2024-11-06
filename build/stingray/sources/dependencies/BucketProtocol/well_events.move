module bucket_protocol::well_events {

    // ----- Use Statements -----

    use std::ascii;
    use sui::balance;

    // ----- public structs -----

    public struct Claim has copy, drop {
        well_type: ascii::String,
        reward_amount: u64,
    }

    public struct CollectFee has copy, drop {
        well_type: ascii::String,
        fee_amount: u64,
    }

    public struct CollectFeeFrom has copy, drop {
        well_type: ascii::String,
        fee_amount: u64,
        from: ascii::String,
    }

    public struct Penalty has copy, drop {
        well_type: ascii::String,
        penalty_amount: u64,
    }

    public struct Stake has copy, drop {
        well_type: ascii::String,
        stake_amount: u64,
        stake_weight: u64,
        lock_time: u64,
    }

    public struct Unstake has copy, drop {
        well_type: ascii::String,
        unstake_amount: u64,
        unstake_weigth: u64,
        reward_amount: u64,
    }
    // ----- Public Functions -----

    public(package) fun emit_claim<T0>(arg0: u64) {
        abort 0
    }

    public(package) fun emit_collect_fee<T0>(arg0: u64) {
        abort 0
    }

    public(package) fun emit_collect_fee_from<T0>(arg0: &balance::Balance<T0>, arg1: vector<u8>) {
        abort 0
    }

    public(package) fun emit_penalty<T0>(arg0: u64) {
        abort 0
    }

    public(package) fun emit_stake<T0>(arg0: u64, arg1: u64, arg2: u64) {
        abort 0
    }

    public(package) fun emit_unstake<T0>(arg0: u64, arg1: u64, arg2: u64) {
        abort 0
    }
}
