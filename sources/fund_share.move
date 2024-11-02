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
        config: &mut GlobalConfig,
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



}