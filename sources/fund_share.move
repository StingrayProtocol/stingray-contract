module stingray::fund_share{
    use std::{
        string::{String},
    };
    
    // use sui::{
    //     event::{Self, },
    // };

    public struct FundShare has key, store {
        id: UID,
        fund_id: ID,
        trader: ID,
        fund_type: String,
        invest_amount: u64,
        end_time: u64,
    }

    // hot potato
    public struct MintRequest<phantom FundCoinType>{
        fund_id: ID,
        trader: ID,
        fund_type: String,
        invest_amount: u64,
        end_time: u64,
    }

    public struct BurnRequest<phantom FundCoinType>{
        fund_id: ID,
        end_time: u64,
    }


    use stingray::config::{Self, GlobalConfig,};

    public struct FUND_SHARE has drop{}
    
    const VERSION: u64 = 1;

    const EFundIdNotMatched: u64 = 0;
    const EFundEndTimeNotMatched: u64 = 1;
    const EOutOfAmount:u64 = 2;
    const EFundShareFundIdNotMatched: u64 = 3;
    const EFundShareTraderNotMatched: u64 = 4;
    const EFundShareFundTypeNotMatched: u64 = 5;
    const EFundShareEndTimeNotMatched: u64 = 6;

    public(package) fun create_mint_request<FundCoinType>(
        config: &GlobalConfig,
        fund_id: ID,
        trader: ID,
        fund_type: String,
        invest_amount: u64,
        end_time: u64,

    ): MintRequest<FundCoinType>{

        config::assert_if_version_not_matched(config, VERSION);
        
        MintRequest{
            fund_id,
            trader,
            fund_type,
            invest_amount,
            end_time,
            }
    }

    public(package) fun create_burn_request<FundCoinType>(
        config: &GlobalConfig,
        fund_id: ID,
        end_time: u64,
    ): BurnRequest<FundCoinType>{

        config::assert_if_version_not_matched(config, VERSION);
        
        BurnRequest{
            fund_id,
            end_time,
        }
    }

    public fun split(
        share: &mut FundShare,
        amount: u64,
        ctx: &mut TxContext,
    ): FundShare{
        assert_if_amount_not_enough(share, amount);
        share.invest_amount = share.invest_amount - amount;
        FundShare{
            id: object::new(ctx),
            fund_id: share.fund_id,
            trader: share.trader,
            fund_type: share.fund_type,
            invest_amount: share.invest_amount,
            end_time: share.end_time,
        }
    }

    public fun join(
        share: &mut FundShare,
        to_be_join: FundShare,
    ){
        assert_if_share_not_same_category(share, &to_be_join);

        let FundShare{
            id: id,
            fund_id: _,
            trader: _,
            fund_type: _,
            invest_amount: invest_amount,
            end_time: _,
        } = to_be_join;
        
        share.invest_amount = share.invest_amount + invest_amount;

        object::delete(id);

    }

    public fun mint<FundCoinType>(
        config: &mut GlobalConfig,
        request: MintRequest<FundCoinType>,
        ctx: &mut TxContext,
    ) : FundShare{

        config::assert_if_version_not_matched(config, VERSION);

        let MintRequest{
            fund_id,
            trader,
            fund_type,
            invest_amount,
            end_time,
        } = request;

        FundShare{
            id: object::new(ctx),
            fund_id,
            trader,
            fund_type,
            invest_amount,
            end_time
        }
    }

    public fun burn<FundCoinType>(
        config: &GlobalConfig,
        request: BurnRequest<FundCoinType>,
        share: FundShare,
    ){
        config::assert_if_version_not_matched(config, VERSION);

        let BurnRequest{
            fund_id: request_fund_id,
            end_time: request_end_time,
        } = request;

        assert_if_fund_id_not_matched(&share, request_fund_id);
        assert_if_fund_end_time_not_matched(&share, request_end_time);

        let FundShare{
            id,
            fund_id:_,
            trader:_,
            fund_type:_,
            invest_amount:_,
            end_time:_
        } = share;

        object::delete(id);
    }

    public fun invest_amount(
        share: &FundShare,
    ): u64{
        share.invest_amount
    }


    fun assert_if_fund_id_not_matched(
        share: &FundShare,
        request_fund_id: ID,
    ){
        assert!(share.fund_id == request_fund_id, EFundIdNotMatched);
    }

    fun assert_if_fund_end_time_not_matched(
        share: &FundShare,
        request_end_time: u64,
    ){
        assert!(share.end_time == request_end_time, EFundEndTimeNotMatched);
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
        assert!(share.end_time == to_be_join.end_time, EFundShareEndTimeNotMatched);
    }
}