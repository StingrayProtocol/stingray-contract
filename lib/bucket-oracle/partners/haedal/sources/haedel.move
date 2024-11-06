module haedal::staking {

    public struct Staking has key {
        id: UID,
    }

    public fun get_exchange_rate(_staking: &Staking): u64 {
        abort 0
    }
}
