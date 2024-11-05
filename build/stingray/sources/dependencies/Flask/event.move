module flask::event {
    use sui::event;

    // === Deposit ===
    public struct CollectRewards has copy, drop{
        buck_amount: u64
    }
    public fun collect_rewards(
        buck_amount: u64
    ){
        event::emit(
            CollectRewards{
                buck_amount
            }
        );
    }

    // === Mint ===
    public struct Deposit has copy, drop{
        buck_amount: u64,
        sbuck_share: u64
    }
    public fun deposit(
        buck_amount: u64,
        sbuck_share: u64
    ){
        event::emit(
            Deposit{
                buck_amount,
                sbuck_share
            }
        );
    }

    // === Burn ===
    public struct Burn has copy, drop{
        sbuck_share: u64,
        buck_amount: u64
    }
    public fun burn(
        sbuck_share: u64,
        buck_amount: u64
    ){
        event::emit(
            Burn{
                sbuck_share,
                buck_amount
            }
        );
    }
}
