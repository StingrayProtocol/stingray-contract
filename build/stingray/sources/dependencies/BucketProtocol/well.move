module bucket_protocol::well {

    // ----- Use Statements -----

    use sui::object;
    use sui::balance;
    use 0xce7ff77a83ea0cb6fd39bd8748e2ec89a3f41e8efdc3f4eb123e0ca37b184db2::bkt;
    use sui::tx_context;
    use sui::clock;

    // ----- public structs -----

    public struct StakedBKT<phantom T0> has store, key {
        id: object::UID,
        stake_amount: u64,
        start_s: u128,
        stake_weight: u64,
        lock_until: u64,
    }

    public struct WELL has drop {
        dummy_field: bool,
    }

    public struct Well<phantom T0> has store, key {
        id: object::UID,
        shared_pool: balance::Balance<T0>,
        reserve: balance::Balance<T0>,
        staked: balance::Balance<bkt::BKT>,
        total_weight: u64,
        current_s: u128,
    }
    // ----- Public Functions -----

    public fun airdrop<T0>(arg0: &mut Well<T0>, arg1: balance::Balance<T0>) {
        abort 0
    }

    public fun claim<T0>(arg0: &mut Well<T0>, arg1: &mut StakedBKT<T0>) : balance::Balance<T0> {
        abort 0
    }

    public fun collect_fee<T0>(arg0: &mut Well<T0>, arg1: balance::Balance<T0>) {
        abort 0
    }

    public fun force_unstake<T0>(arg0: &clock::Clock, arg1: &mut Well<T0>, arg2: &mut bkt::BktTreasury, arg3: StakedBKT<T0>) : (balance::Balance<bkt::BKT>, balance::Balance<T0>) {
        abort 0
    }

    public fun get_reward_amount<T0>(arg0: &Well<T0>, arg1: &StakedBKT<T0>) : u64 {
        abort 0
    }

    public fun get_token_lock_until<T0>(arg0: &StakedBKT<T0>) : u64 {
        abort 0
    }

    public fun get_token_penalty_amount<T0>(arg0: &StakedBKT<T0>, arg1: u64) : u64 {
        abort 0
    }

    public fun get_token_stake_amount<T0>(arg0: &StakedBKT<T0>) : u64 {
        abort 0
    }

    public fun get_token_stake_weight<T0>(arg0: &StakedBKT<T0>) : u64 {
        abort 0
    }

    public fun get_well_pool_balance<T0>(arg0: &Well<T0>) : u64 {
        abort 0
    }

    public fun get_well_reserve_balance<T0>(arg0: &Well<T0>) : u64 {
        abort 0
    }

    public fun get_well_staked_balance<T0>(arg0: &Well<T0>) : u64 {
        abort 0
    }

    public fun get_well_total_weight<T0>(arg0: &Well<T0>) : u64 {
        abort 0
    }

    public fun stake<T0>(arg0: &clock::Clock, arg1: &mut Well<T0>, arg2: balance::Balance<bkt::BKT>, arg3: u64, arg4: &mut tx_context::TxContext) : StakedBKT<T0> {
        abort 0
    }

    public fun unstake<T0>(arg0: &clock::Clock, arg1: &mut Well<T0>, arg2: StakedBKT<T0>) : (balance::Balance<bkt::BKT>, balance::Balance<T0>) {
        abort 0
    }

    public fun withdraw_reserve<T0>(arg0: &bkt::BktAdminCap, arg1: &mut Well<T0>) : balance::Balance<T0> {
        abort 0
    }

    public(package) fun new<T0>(arg0: &mut tx_context::TxContext) : Well<T0> {
        abort 0
    }
}
