module adapters::bucket{
    use sui::balance::Balance;
    use sui::sui::SUI;
    use sui::clock::Clock;
    
    use flask::sbuck::{SBUCK, Flask};
    use fountain::fountain_core::{Self as fountain, Fountain, StakeProof};
    use bucket_protocol::buck::{Self, BUCK, BucketProtocol};

    // 1. Deposit BUCK in exchange for sBUCK
    // 2. stake sBUCK to earn SUI rewards 
    public fun deposit(
        buck: Balance<BUCK>,
        bucket_protocol: &mut BucketProtocol,
        flask: &mut Flask<BUCK>,
        fountain: &mut Fountain<SBUCK, SUI>,
        clock: &Clock,
        ctx: &mut TxContext
    ):StakeProof<SBUCK, SUI>{
        let sbuck = bucket_protocol.buck_to_sbuck(flask, clock, buck);  
        let (_, max_lock_time) = fountain.get_lock_time_range();
        fountain::stake(clock, fountain, sbuck, max_lock_time, ctx)
    }

    public fun withdraw(
        stake_proof: StakeProof<SBUCK, SUI>,
        bucket_protocol: &mut BucketProtocol,
        flask: &mut Flask<BUCK>,
        fountain: &mut Fountain<SBUCK, SUI>,
        clock: &Clock
    ):(Balance<BUCK>, Balance<SUI>){
        let (sbuck, reward_bal) = fountain::force_unstake(clock, fountain, stake_proof);
        let buck = buck::sbuck_to_buck(bucket_protocol, flask, clock, sbuck);

        (buck, reward_bal)
    }
}
