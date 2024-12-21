module stingray::fund_share{
    use std::{
        string::{String},
    };
    
    use sui::{
        event::{Self, },
    };

    

    public struct FundShare has key, store {
        id: UID,
        fund_id: ID,
        is_init: bool,
        trader: address,
        fund_type: String,
        invest_amount: u64,
        base_receiver: address,
        reward_receiver: address,
    }


    public struct Invested has copy, drop{
        share_id: ID,
        fund_id: ID,
        invest_amount: u64,
        investor: address,
    }

    public struct Splited has copy, drop{
        new_share_id: ID,
        invest_amount: u64,
    }

    public struct Merged has copy, drop{
        base_share_id: ID,
        base_invest_amount: u64,
        burn_share_id: ID,
        burn_invest_amount: u64,        
    }

    // hot potato
    public struct MintRequest<phantom FundCoinType>{
        fund_id: ID,
        is_init: bool,
        trader: address,
        fund_type: String,
        invest_amount: u64,
        base_receiver: address,
        reward_receiver: address,
    }

    public struct BurnRequest<phantom FundCoinType>{
        fund_id: ID,
    }


    use stingray::config::{Self, GlobalConfig,};

    public struct FUND_SHARE has drop{}
    
    const VERSION: u64 = 1;

    const EFundIdNotMatched: u64 = 0;
    const EOutOfAmount:u64 = 1;
    const EFundShareFundIdNotMatched: u64 = 2;
    const EFundShareTraderNotMatched: u64 = 3;
    const EFundShareFundTypeNotMatched: u64 = 4;

    public(package) fun create_mint_request<FundCoinType>(
        config: &GlobalConfig,
        fund_id: ID,
        is_init: bool,
        trader: address,
        fund_type: String,
        invest_amount: u64,
        base_receiver: address,
        reward_receiver: address,
    ): MintRequest<FundCoinType>{

        config::assert_if_version_not_matched(config, VERSION);
        
        MintRequest<FundCoinType>{
            fund_id,
            is_init,
            trader,
            fund_type,
            invest_amount,
            base_receiver,
            reward_receiver,
        }
    }

    public(package) fun create_burn_request<FundCoinType>(
        config: &GlobalConfig,
        fund_id: ID,
    ): BurnRequest<FundCoinType>{

        config::assert_if_version_not_matched(config, VERSION);
        
        BurnRequest{
            fund_id,
        }
    }

    public fun split(
        share: &mut FundShare,
        amount: u64,
        ctx: &mut TxContext,
    ): FundShare{
        assert_if_amount_not_enough(share, amount);
        share.invest_amount = share.invest_amount - amount;
        let new_share = FundShare{
            id: object::new(ctx),
            fund_id: share.fund_id,
            is_init: share.is_init,
            trader: share.trader,
            fund_type: share.fund_type,
            invest_amount: amount,
            base_receiver: share.base_receiver,
            reward_receiver: share.reward_receiver,
        };

        event::emit(Splited{
            new_share_id: *new_share.id.as_inner(),
            invest_amount: amount,
        });

        new_share

    }

    public fun join(
        share: &mut FundShare,
        to_be_join: FundShare,
    ){
        assert_if_share_not_same_category(share, &to_be_join);

        let FundShare{
            id: id,
            fund_id: _,
            is_init: _,
            trader: _,
            fund_type: _,
            invest_amount: invest_amount,
            base_receiver:_,
            reward_receiver:_,
        } = to_be_join;
        
        share.invest_amount = share.invest_amount + invest_amount;

        event::emit(Merged{
            base_share_id: *share.id.as_inner(),
            base_invest_amount: share.invest_amount,
            burn_share_id: *id.as_inner(),
            burn_invest_amount: invest_amount,
        });

        object::delete(id);
    }

    public fun mint<FundCoinType>(
        config: &mut GlobalConfig,
        request: MintRequest<FundCoinType>,
        ctx: &mut TxContext,
    ) : FundShare{

        config::assert_if_version_not_matched(config, VERSION);

        let MintRequest<FundCoinType>{
            fund_id,
            is_init, 
            trader,
            fund_type,
            invest_amount,
            base_receiver,
            reward_receiver,
        } = request;

        let share = FundShare{
            id: object::new(ctx),
            fund_id,
            is_init,
            trader,
            fund_type,
            invest_amount,
            base_receiver,
            reward_receiver,
        };

        event::emit(Invested{
            share_id: *share.id.as_inner(),
            fund_id: share.fund_id,
            invest_amount: share.invest_amount,
            investor: ctx.sender(),
        });

        share
    }

    public(package) fun burn<FundCoinType>(
        config: &GlobalConfig,
        request: BurnRequest<FundCoinType>,
        share: FundShare,
    ){
        config::assert_if_version_not_matched(config, VERSION);

        let BurnRequest{
            fund_id: request_fund_id,
        } = request;

        assert_if_fund_id_not_matched(&share, request_fund_id);

        let FundShare{
            id,
            fund_id:_,
            is_init: _,
            trader:_,
            fund_type:_,
            invest_amount:_,
            base_receiver: _,
            reward_receiver:_,
        } = share;

        object::delete(id);
    }

    public fun invest_amount(
        share: &FundShare,
    ): u64{
        share.invest_amount
    }

    public fun is_init(
        share: &FundShare,
    ): bool{
        share.is_init
    }

    public fun id(
        share: &FundShare,
    ): ID{
        *share.id.as_inner()
    }

    public fun fund_id(
        share: &FundShare,
    ): ID{
        share.fund_id
    }

    public fun base_receiver(
        share: &FundShare,
    ): address{
        share.base_receiver
    }

    public fun reward_receiver(
        share: &FundShare,
    ): address{
        share.reward_receiver
    }


    fun assert_if_fund_id_not_matched(
        share: &FundShare,
        request_fund_id: ID,
    ){
        assert!(share.fund_id == request_fund_id, EFundIdNotMatched);
    }

    fun assert_if_amount_not_enough(
        share: &FundShare,
        amount: u64,
    ){
        assert!(share.invest_amount >= amount, EOutOfAmount);
    }   

    fun assert_if_share_not_same_category(
        share: &FundShare,
        to_be_join: &FundShare,
    ){
        assert!(share.fund_id == to_be_join.fund_id, EFundShareFundIdNotMatched);
        assert!(share.trader == to_be_join.trader, EFundShareTraderNotMatched);
        assert!(share.fund_type == to_be_join.fund_type, EFundShareFundTypeNotMatched);
    }
}