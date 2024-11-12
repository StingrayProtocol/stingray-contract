module stingray::bucket{
    use sui::balance::Balance;
    use sui::sui::SUI;
    use sui::clock::Clock;
    use sui::event::{Self};

    use std::string::{Self, String};
    use std::type_name::{Self, TypeName,};
    
    use flask::sbuck::{SBUCK, Flask};
    use fountain::fountain_core::{Self as fountain, Fountain, StakeProof};
    use bucket_protocol::buck::{Self, BUCK, BucketProtocol};

    use stingray::{
        fund::{
            Take_1_Liquidity_For_1_NonLiquidity_Request,
            Take_1_NonLiquidity_For_2_Liquidity_Request,
            },
    };

    public struct Deposited has copy, drop{
        protocol: String,
        input_type: TypeName,
        in_amount: u64,
        output_type: TypeName,
        output_amount: u64,
    }

    public struct Withdrawed has copy, drop{
        protocol: String,
        input_type: TypeName,
        in_amount: u64,
        output_type1: TypeName,
        output_amount1: u64,
        output_type2: TypeName,
        output_amount2: u64,
    }

    // 1. Deposit BUCK in exchange for sBUCK
    // 2. stake sBUCK to earn SUI rewards 
    public fun deposit(
        request: &mut Take_1_Liquidity_For_1_NonLiquidity_Request<BUCK, StakeProof<SBUCK, SUI>>,
        buck: Balance<BUCK>,
        bucket_protocol: &mut BucketProtocol,
        flask: &mut Flask<BUCK>,
        fountain: &mut Fountain<SBUCK, SUI>,
        clock: &Clock,
        ctx: &mut TxContext
    ):StakeProof<SBUCK, SUI>{
        let buck_amount= buck.value();
        let sbuck = bucket_protocol.buck_to_sbuck(flask, clock, buck);  
        let (_, max_lock_time) = fountain.get_lock_time_range();
        let share = fountain::stake(clock, fountain, sbuck, max_lock_time, ctx);
        request.supported_defi_confirm_1l_for_1nl(share.get_proof_stake_amount());

        event::emit(
            Deposited{
                protocol: string::utf8(b"Bucket"),
                input_type: type_name::get<BUCK>(),
                in_amount: buck_amount,
                output_type: type_name::get<StakeProof<SBUCK, SUI>>(),
                output_amount: 1,
            }
        );

        share
    }

    public fun withdraw(
        request: &mut Take_1_NonLiquidity_For_2_Liquidity_Request<StakeProof<SBUCK, SUI>, BUCK, SUI>,
        stake_proof: StakeProof<SBUCK, SUI>,
        bucket_protocol: &mut BucketProtocol,
        flask: &mut Flask<BUCK>,
        fountain: &mut Fountain<SBUCK, SUI>,
        clock: &Clock
    ):(Balance<BUCK>, Balance<SUI>){
        let (sbuck, reward_bal) = fountain::force_unstake(clock, fountain, stake_proof);
        let buck = buck::sbuck_to_buck(bucket_protocol, flask, clock, sbuck);
        
        request.supported_defi_confirm_1nl_for_2l(buck.value(), reward_bal.value());

        event::emit(
            Withdrawed{
                protocol: string::utf8(b"Bucket"),
                input_type: type_name::get<StakeProof<SBUCK, SUI>>(),
                in_amount: 1,
                output_type1: type_name::get<BUCK>(),
                output_amount1: buck.value(),
                output_type2: type_name::get<SUI>(),
                output_amount2: reward_bal.value(),
            }
        );
        
        (buck, reward_bal)
    }
}
