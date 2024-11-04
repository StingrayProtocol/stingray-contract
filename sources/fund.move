module stingray::fund{
    use std::{
        type_name::{Self, TypeName},
        string::{Self, String},  
    };

    use sui::{
        coin::{ Self, Coin},
        balance::{Self, Balance},
        bag::{Self, Bag},
        table::{Self, Table},
        clock::{Clock},
    };

    use stingray::{
        config::{Self, GlobalConfig},
        trader::{Trader},
        fund_share::{Self, MintRequest, FundShare},
    };

    const VERSION: u64 = 1;

    // define constant
    const EOverMaxTraderFee: u64 = 0;
    const ETakeLiquidityNotInFund: u64 = 1;
    const EFundTakeLiquidityNotEnough: u64 = 2;
    const ETakeNonLiquidityNotInFund: u64 = 3;
    const EPutAmountNotSet: u64 = 4;
    const EPutAmountNotMatchedPutBalance:u64 = 5;
    const ENonLiquidityInFund: u64 = 6;
    const EEndTimeNotBiggerThanStartTime:u64 = 7;
    const ELessThanMinDuration: u64 = 8;
    const ETraderNotMatched: u64 = 9;
    const ENotInInvestorList: u64 = 10;
    const ENotArrivedSettleTime: u64 = 11;
    const ESettleNotFinished: u64 = 12;
    const EFundHasNonBaseAsset: u64 = 13;
    const EBaseTypeNotMatched: u64 = 14;
    const ENotSettle: u64 = 15;
    const EOverInvestTime: u64 = 16;
    
    // hot potato 
    public struct Take_1_Liquidity_For_1_Liquidity_Request<phantom TakeCoinType, phantom PutCoinType>{
        take_amount: u64,
        put_amount: u64,
    }
    public struct Take_1_Liquidity_For_2_Liquidity_Request<phantom TakeCoinType, phantom PutCoinType1, phantom PutCoinType2>{
        take_amount: u64,
        put_amount1: u64,
        put_amount2: u64,
    }
    
    public struct Take_1_Liquidity_For_1_NonLiquidity_Request<phantom TakeCoinType, phantom PutAsset>{
        take_amount: u64,
        put_amount: u64,
    }
    
    public struct Take_1_Liquidity_1_NonLiquidity_For_1_NonLiquidity_Request<phantom TakeCoinType, phantom TakeAsset, phantom PutAsset>{
        take_amount1: u64,
        take_amount2: u64,
        put_amount: u64,
    }
    public struct Take_1_NonLiquidity_For_1_Liquidity_Request<phantom TakeAsset, phantom PutCoinType>{
        take_amount: u64,
        put_amount: u64,
    }
    public struct Take_1_NonLiquidity_For_2_Liquidity_Request<phantom TakeAsset, phantom PutCoinType1, phantom PutCoinType2>{
        take_amount: u64,
        put_amount1: u64,
        put_amount2: u64,
    }

    public struct SettleRequest{
        fund: ID,
        settler: address,
        is_finished: bool, 
    }


    public struct InvestRecord has store{
        asset_types: vector<TypeName>,
        assets: Bag
    }

    public struct TimeInfo has store {
        start_time: u64,
        invest_duration: u64,
        end_time: u64, 
    }

    public struct ShareInfo has store {
        investor: Table<address, u64>,
        total_share: u64,
    }

    public struct Fund<phantom CoinType> has key {
        id: UID,
        description: String,
        trader: ID,
        trader_fee: u64,
        asset: InvestRecord,
        base: u64,
        time: TimeInfo,
        is_arena: bool,
        is_settle: bool,
        share_info: ShareInfo,
        after_amount: u64,
    }

    // create fund
    public fun create<FundCoinType> (
        config: &GlobalConfig,
        description: String,
        trader: &Trader,
        trader_fee: u64,
        is_arena: bool,
        start_time: u64,
        invest_duration: u64,
        end_time: u64,
        coin: Coin<FundCoinType>,
        ctx: &mut TxContext,
    ): Fund<FundCoinType>{

        let init_amount = coin.value();

        config::assert_if_version_not_matched(config, VERSION);
        assert_if_over_max_trader_fee(config, trader_fee);
        config::assert_if_less_than_min_fund_base(config, init_amount);
        assert_if_time_setting_wrong(start_time, invest_duration, end_time);

        let mut type_arr = vector::empty<TypeName>();
        let asset_type = type_name::get<Balance<FundCoinType>>();
        type_arr.push_back(asset_type);

        let mut asset_bag = bag::new(ctx);
        asset_bag.add(asset_type, coin.into_balance());

        let investRecord = InvestRecord{
            asset_types: type_arr,
            assets: asset_bag,
        };

        let fund = Fund<FundCoinType>{
            id: object::new(ctx),
            description,
            trader: trader.id(),
            trader_fee,
            asset: investRecord,
            base: init_amount,
            time: TimeInfo{
                start_time,
                invest_duration,
                end_time,
            },
            is_arena,
            is_settle: false,
            share_info: ShareInfo{
                investor: table::new<address, u64>(ctx),
                total_share: 0,
            },
            after_amount: 0,
        };

        fund
    }

    public fun to_share_object<FunCoinType>(
        fund: Fund<FunCoinType>,
    ){
        transfer::share_object(fund);
    }

    // invest fund
    public fun invest<FundCoinType>(
        config: &GlobalConfig,
        fund: &mut Fund<FundCoinType>,
        invest_coin: Coin<FundCoinType>,
        clock: &Clock,
    ): MintRequest<FundCoinType>{
        config::assert_if_version_not_matched(config, VERSION);
        assert_if_over_invest_duration(fund, clock);

        let total_base = fund.asset.assets.borrow<TypeName, Balance<FundCoinType>>(type_name::get<Balance<FundCoinType>>());
        let invest_amount = invest_coin.value();
        
        config::assert_if_base_over_max(config, (total_base.value() + invest_amount));

        // put coin into asset bag
        let asset_type = type_name::get<Balance<FundCoinType>>();
        fund.asset.assets.add<TypeName, Balance<FundCoinType>>(asset_type, invest_coin.into_balance());

        // take mint share request
        let mut fund_type = string::utf8(b"Common");
        
        if (fund.is_arena){
            fund_type=string::utf8(b"Arena");
        };

        fund_share::create_mint_request(
            config,
            *fund.id.as_inner(), 
            fund.trader, 
            fund_type, 
            invest_amount, 
            fund.time.end_time)
    }

    // take asset function , i.e scallop deposit, cetus swap
    public fun take_1_liquidity_for_1_liquidity< TakeCoinType, PutCoinType, FundCoinType>(
        config: &GlobalConfig,
        fund: &mut Fund<FundCoinType>,
        trader: &Trader,
        amount: u64,
    ): (Balance<TakeCoinType>, Take_1_Liquidity_For_1_Liquidity_Request<TakeCoinType, PutCoinType>){

        config::assert_if_version_not_matched(config, VERSION);
        assert_if_trader_not_matched<FundCoinType>(fund, trader);
        assert_if_take_liquidity_not_in_fund<TakeCoinType, FundCoinType>(fund);
        assert_if_take_amount_not_enough<TakeCoinType, FundCoinType>(fund, amount);
        

        let total_balance = fund.asset.assets.borrow_mut<TypeName, Balance<TakeCoinType>>(type_name::get<Balance<TakeCoinType>>());
        let take_balance = total_balance.split(amount);
        let take_request = Take_1_Liquidity_For_1_Liquidity_Request<TakeCoinType, PutCoinType>{
            take_amount: take_balance.value(),
            put_amount: 0,
        };

        (take_balance, take_request)
    }
    
    public fun take_1_liquidity_for_2_liqudity<TakeCoinType, PutCoinType1, PutCoinType2, FundCoinType>(
        config: &GlobalConfig,
        fund: &mut Fund<FundCoinType>,
        trader: &Trader,
        amount: u64,
    ): (Balance<TakeCoinType>, Take_1_Liquidity_For_2_Liquidity_Request<TakeCoinType, PutCoinType1, PutCoinType2>){

        config::assert_if_version_not_matched(config, VERSION);        
        assert_if_trader_not_matched<FundCoinType>(fund, trader);
        assert_if_take_liquidity_not_in_fund<TakeCoinType, FundCoinType>(fund);
        assert_if_take_amount_not_enough<TakeCoinType, FundCoinType>(fund, amount);
        

        let total_balance = fund.asset.assets.borrow_mut<TypeName, Balance<TakeCoinType>>(type_name::get<Balance<TakeCoinType>>());
        let take_balance = total_balance.split(amount);
        let take_request = Take_1_Liquidity_For_2_Liquidity_Request<TakeCoinType, PutCoinType1, PutCoinType2>{
            take_amount: take_balance.value(),
            put_amount1: 0,
            put_amount2: 0,
        };

        (take_balance, take_request)
    }
    
    public fun take_1_liquidity_for_1_nonliquidity<TakeCoinType, PutAsset: store, FundCoinType>(
        config: &GlobalConfig,
        fund: &mut Fund<FundCoinType>,
        trader: &Trader,
        amount: u64,
    ): (Balance<TakeCoinType>, Take_1_Liquidity_For_1_NonLiquidity_Request<TakeCoinType, PutAsset>){
        
        config::assert_if_version_not_matched(config, VERSION);
        assert_if_trader_not_matched<FundCoinType>(fund, trader);
        assert_if_take_liquidity_not_in_fund<TakeCoinType, FundCoinType>(fund);
        assert_if_take_amount_not_enough<TakeCoinType, FundCoinType>(fund, amount);

        let total_balance = fund.asset.assets.borrow_mut<TypeName, Balance<TakeCoinType>>(type_name::get<Balance<TakeCoinType>>());
        let take_balance = total_balance.split(amount);
        
        let take_request = Take_1_Liquidity_For_1_NonLiquidity_Request<TakeCoinType, PutAsset>{
            take_amount: take_balance.value(),
            put_amount: 0,
        };

        (take_balance, take_request)
    }

    public fun take_1_liquidity_1_nonliquidity_for_1_nonliquidity<TakeCoinType, TakeAsset: store, PutAsset: store, FundCoinType>(
        config: &GlobalConfig,
        fund: &mut Fund<FundCoinType>,
        trader: &Trader,
        amount: u64,
    ): (Balance<TakeCoinType>, TakeAsset, Take_1_Liquidity_1_NonLiquidity_For_1_NonLiquidity_Request<TakeCoinType, TakeAsset, PutAsset>){
        
        config::assert_if_version_not_matched(config, VERSION);
        assert_if_trader_not_matched<FundCoinType>(fund, trader);
        assert_if_take_liquidity_not_in_fund<TakeCoinType, FundCoinType>(fund);
        assert_if_take_nonliquidity_not_in_fund<TakeAsset, FundCoinType>(fund);
        assert_if_take_amount_not_enough<TakeCoinType, FundCoinType>(fund, amount);

        let total_balance = fund.asset.assets.borrow_mut<TypeName, Balance<TakeCoinType>>(type_name::get<Balance<TakeCoinType>>());
        let take_balance = total_balance.split(amount);
        let take_asset = fund.asset.assets.remove<TypeName, TakeAsset>(type_name::get<TakeAsset>());
        
        let take_request = Take_1_Liquidity_1_NonLiquidity_For_1_NonLiquidity_Request<TakeCoinType,TakeAsset, PutAsset>{
            take_amount1: take_balance.value(),
            take_amount2: 1,
            put_amount: 0,
        };

        (take_balance, take_asset, take_request)
    }   

    
    public fun take_1_nonLiquidity_for_1_liquidity<TakeAsset: store, PutCoinType, FundCoinType>(
        config: &GlobalConfig,
        fund: &mut Fund<FundCoinType>,
        trader: &Trader,
    ): (TakeAsset, Take_1_NonLiquidity_For_1_Liquidity_Request<TakeAsset, PutCoinType>){
        
        config::assert_if_version_not_matched(config, VERSION);
        assert_if_trader_not_matched<FundCoinType>(fund, trader);
        assert_if_take_nonliquidity_not_in_fund<TakeAsset, FundCoinType>(fund);

        let take_asset = fund.asset.assets.remove<TypeName, TakeAsset>(type_name::get<TakeAsset>());
        
        let take_request = Take_1_NonLiquidity_For_1_Liquidity_Request<TakeAsset,PutCoinType>{
            take_amount: 1,
            put_amount: 0,
        };

        (take_asset, take_request)
    }

    public fun take_1_nonliquidity_for_2_liquidity<TakeAsset: store, PutCoinType1, PutCoinType2, FundCoinType>(
        config: &GlobalConfig,
        fund: &mut Fund<FundCoinType>,
        trader: &Trader,
    ): (TakeAsset, Take_1_NonLiquidity_For_2_Liquidity_Request<TakeAsset, PutCoinType1, PutCoinType2>){
        
        config::assert_if_version_not_matched(config, VERSION);
        assert_if_trader_not_matched<FundCoinType>(fund, trader);
        assert_if_take_nonliquidity_not_in_fund<TakeAsset, FundCoinType>(fund);

        let take_asset = fund.asset.assets.remove<TypeName, TakeAsset>(type_name::get<TakeAsset>());
        
        let take_request = Take_1_NonLiquidity_For_2_Liquidity_Request<TakeAsset,PutCoinType1, PutCoinType2>{
            take_amount: 1,
            put_amount1: 0,
            put_amount2: 0,
        };

        (take_asset, take_request)
    }

    // put asset function 
    public fun put_1_liquidity_for_1_liquidity< TakeCoinType, PutCoinType, FundCoinType>(
        config: &GlobalConfig,
        fund: &mut Fund<FundCoinType>,
        request: Take_1_Liquidity_For_1_Liquidity_Request<TakeCoinType, PutCoinType>,
        liquidity: Balance<PutCoinType>,
    ){
        
        config::assert_if_version_not_matched(config, VERSION);
        
        let Take_1_Liquidity_For_1_Liquidity_Request{
            take_amount: _,
            put_amount,
        } = request;

        assert_if_put_amount_is_zero(put_amount);
        assert_if_put_liquidity_not_equal_to_put_amount(put_amount, liquidity.value());

        let asset_type = type_name::get<Balance<PutCoinType>>();

        if (fund.asset.assets.contains(asset_type)){
            let fund_asset = fund.asset.assets.borrow_mut<TypeName, Balance<PutCoinType>>(asset_type);
            fund_asset.join(liquidity);
        }else{
            fund.asset.assets.add(asset_type, liquidity);
        }
    }

    public fun put_1_liquidity_for_2_liqudity<TakeCoinType, PutCoinType1, PutCoinType2, FundCoinType>(
        config: &GlobalConfig,
        fund: &mut Fund<FundCoinType>,
        request: Take_1_Liquidity_For_2_Liquidity_Request<TakeCoinType, PutCoinType1, PutCoinType2>,
        liquidity1: Balance<PutCoinType1>,
        liquidity2: Balance<PutCoinType2>,
    ){

        config::assert_if_version_not_matched(config, VERSION);
        
        let Take_1_Liquidity_For_2_Liquidity_Request{
            take_amount: _,
            put_amount1,
            put_amount2,
        } = request;

        assert_if_put_amount_is_zero(put_amount1);
        assert_if_put_amount_is_zero(put_amount2);
        assert_if_put_liquidity_not_equal_to_put_amount(put_amount1, liquidity1.value());
        assert_if_put_liquidity_not_equal_to_put_amount(put_amount2, liquidity2.value());

        let asset_type1 = type_name::get<Balance<PutCoinType1>>();
        let asset_type2 = type_name::get<Balance<PutCoinType2>>();
        
        if (fund.asset.assets.contains(asset_type1)){
            let fund_asset = fund.asset.assets.borrow_mut<TypeName, Balance<PutCoinType1>>(asset_type1);
            fund_asset.join(liquidity1);
        }else{
            fund.asset.assets.add(asset_type1, liquidity1);
        };

        if (fund.asset.assets.contains(asset_type2)){
            let fund_asset = fund.asset.assets.borrow_mut<TypeName, Balance<PutCoinType2>>(asset_type2);
            fund_asset.join(liquidity2);
        }else{
            fund.asset.assets.add(asset_type2, liquidity2);
        };
    }

    public fun put_1_liquidity_for_1_nonliquidity<TakeCoinType, PutAsset: store, FundCoinType>(
        config: &GlobalConfig,
        fund: &mut Fund<FundCoinType>,
        request: Take_1_Liquidity_For_1_NonLiquidity_Request<TakeCoinType, PutAsset>,
        nonliquidity: PutAsset,
    ){
        
        config::assert_if_version_not_matched(config, VERSION);
        
        let Take_1_Liquidity_For_1_NonLiquidity_Request{
            take_amount: _,
            put_amount,
        } = request;

        assert_if_put_amount_is_zero(put_amount);

        let asset_type = type_name::get<PutAsset>();
        assert_if_nonliquidity_in_asset_bag<PutAsset, FundCoinType>(fund,);

        fund.asset.assets.add(asset_type, nonliquidity);
    }
    

    public fun put_1_liquidity_1_nonliquidity_for_1_nonliquidity<TakeCoinType, TakeAsset: store, PutAsset: store, FundCoinType>(
        config: &GlobalConfig,
        fund: &mut Fund<FundCoinType>,
        request: Take_1_Liquidity_1_NonLiquidity_For_1_NonLiquidity_Request<TakeCoinType, TakeAsset, PutAsset>,
        nonliquidity: PutAsset,
    ){

        config::assert_if_version_not_matched(config, VERSION);
        
        let Take_1_Liquidity_1_NonLiquidity_For_1_NonLiquidity_Request{
            take_amount1: _,
            take_amount2: _,
            put_amount,
        } = request;

        assert_if_put_amount_is_zero(put_amount);

        let asset_type = type_name::get<PutAsset>();
        assert_if_nonliquidity_in_asset_bag<PutAsset, FundCoinType>(fund,);

        fund.asset.assets.add(asset_type, nonliquidity);
    }

    public fun put_1_nonLiquidity_for_1_liquidity<TakeAsset: store, PutCoinType, FundCoinType>(
        config: &GlobalConfig,
        fund: &mut Fund<FundCoinType>,
        request: Take_1_NonLiquidity_For_1_Liquidity_Request<TakeAsset, PutCoinType>,
        liquidity: Balance<PutCoinType>,
    ){

        config::assert_if_version_not_matched(config, VERSION);
        
        let Take_1_NonLiquidity_For_1_Liquidity_Request{
            take_amount: _,
            put_amount,
        } = request;

        assert_if_put_amount_is_zero(put_amount);
        assert_if_put_liquidity_not_equal_to_put_amount(put_amount, liquidity.value());

        let asset_type = type_name::get<Balance<PutCoinType>>();
        
        if (fund.asset.assets.contains(asset_type)){
            let fund_asset = fund.asset.assets.borrow_mut<TypeName, Balance<PutCoinType>>(asset_type);
            fund_asset.join(liquidity);
        }else{
            fund.asset.assets.add(asset_type, liquidity);
        };
    }

    public fun put_1_nonliquidity_for_2_liquidity<TakeAsset: store, PutCoinType1, PutCoinType2, FundCoinType>(
        config: &GlobalConfig,
        fund: &mut Fund<FundCoinType>,
        request: Take_1_NonLiquidity_For_2_Liquidity_Request<TakeAsset, PutCoinType1, PutCoinType2>,
        liquidity1: Balance<PutCoinType1>,
        liquidity2: Balance<PutCoinType2>,
    ){

        config::assert_if_version_not_matched(config, VERSION);
        
        let Take_1_NonLiquidity_For_2_Liquidity_Request{
            take_amount: _,
            put_amount1,
            put_amount2,
        } = request;

        assert_if_put_amount_is_zero(put_amount1);
        assert_if_put_amount_is_zero(put_amount2);
        assert_if_put_liquidity_not_equal_to_put_amount(put_amount1, liquidity1.value());
        assert_if_put_liquidity_not_equal_to_put_amount(put_amount2, liquidity2.value());

        let asset_type1 = type_name::get<Balance<PutCoinType1>>();
        let asset_type2 = type_name::get<Balance<PutCoinType2>>();
        
        if (fund.asset.assets.contains(asset_type1)){
            let fund_asset = fund.asset.assets.borrow_mut<TypeName, Balance<PutCoinType1>>(asset_type1);
            fund_asset.join(liquidity1);
        }else{
            fund.asset.assets.add(asset_type1, liquidity1);
        };

        if (fund.asset.assets.contains(asset_type2)){
            let fund_asset = fund.asset.assets.borrow_mut<TypeName, Balance<PutCoinType2>>(asset_type1);
            fund_asset.join(liquidity2);
        }else{
            fund.asset.assets.add(asset_type2, liquidity2);
        };
    }
    // settle 
    public fun settle_1_liquidity_for_1_liquidity< TakeCoinType, PutCoinType, FundCoinType>(
        config: &GlobalConfig,
        fund: &mut Fund<FundCoinType>,
        take_request: Take_1_Liquidity_For_1_Liquidity_Request<TakeCoinType, PutCoinType>,
        liquidity: Balance<PutCoinType>,
        mut settle_request: SettleRequest,
        is_finished: bool,
    ): SettleRequest{
        
        config::assert_if_version_not_matched(config, VERSION);
        
        let Take_1_Liquidity_For_1_Liquidity_Request{
            take_amount: _,
            put_amount,
        } = take_request;

        assert_if_put_amount_is_zero(put_amount);
        assert_if_put_liquidity_not_equal_to_put_amount(put_amount, liquidity.value());

        let asset_type = type_name::get<Balance<PutCoinType>>();

        if (fund.asset.assets.contains(asset_type)){
            let fund_asset = fund.asset.assets.borrow_mut<TypeName, Balance<PutCoinType>>(asset_type);
            fund_asset.join(liquidity);
        }else{
            fund.asset.assets.add(asset_type, liquidity);
        };
        // update settle request
        settle_request.is_finished = is_finished;
        settle_request
    }

    public fun settle_1_liquidity_for_2_liqudity<TakeCoinType, PutCoinType1, PutCoinType2, FundCoinType>(
        config: &GlobalConfig,
        fund: &mut Fund<FundCoinType>,
        request: Take_1_Liquidity_For_2_Liquidity_Request<TakeCoinType, PutCoinType1, PutCoinType2>,
        liquidity1: Balance<PutCoinType1>,
        liquidity2: Balance<PutCoinType2>,
        mut settle_request: SettleRequest,
        is_finished: bool,
    ): SettleRequest{

        config::assert_if_version_not_matched(config, VERSION);
        
        let Take_1_Liquidity_For_2_Liquidity_Request{
            take_amount: _,
            put_amount1,
            put_amount2,
        } = request;

        assert_if_put_amount_is_zero(put_amount1);
        assert_if_put_amount_is_zero(put_amount2);
        assert_if_put_liquidity_not_equal_to_put_amount(put_amount1, liquidity1.value());
        assert_if_put_liquidity_not_equal_to_put_amount(put_amount2, liquidity2.value());

        let asset_type1 = type_name::get<Balance<PutCoinType1>>();
        let asset_type2 = type_name::get<Balance<PutCoinType2>>();
        
        if (fund.asset.assets.contains(asset_type1)){
            let fund_asset = fund.asset.assets.borrow_mut<TypeName, Balance<PutCoinType1>>(asset_type1);
            fund_asset.join(liquidity1);
        }else{
            fund.asset.assets.add(asset_type1, liquidity1);
        };

        if (fund.asset.assets.contains(asset_type2)){
            let fund_asset = fund.asset.assets.borrow_mut<TypeName, Balance<PutCoinType2>>(asset_type2);
            fund_asset.join(liquidity2);
        }else{
            fund.asset.assets.add(asset_type2, liquidity2);
        };

        // update settle request
        settle_request.is_finished = is_finished;
        settle_request
    }

    public fun settle_1_liquidity_for_1_nonliquidity<TakeCoinType, PutAsset: store, FundCoinType>(
        config: &GlobalConfig,
        fund: &mut Fund<FundCoinType>,
        request: Take_1_Liquidity_For_1_NonLiquidity_Request<TakeCoinType, PutAsset>,
        nonliquidity: PutAsset,
        mut settle_request: SettleRequest,
        is_finished: bool,
    ): SettleRequest{
        
        config::assert_if_version_not_matched(config, VERSION);
        
        let Take_1_Liquidity_For_1_NonLiquidity_Request{
            take_amount: _,
            put_amount,
        } = request;

        assert_if_put_amount_is_zero(put_amount);

        let asset_type = type_name::get<PutAsset>();
        assert_if_nonliquidity_in_asset_bag<PutAsset, FundCoinType>(fund,);

        fund.asset.assets.add(asset_type, nonliquidity);

        // update settle request
        settle_request.is_finished = is_finished;
        settle_request
    }
    

    public fun settle_1_liquidity_1_nonliquidity_for_1_nonliquidity<TakeCoinType, TakeAsset: store, PutAsset: store, FundCoinType>(
        config: &GlobalConfig,
        fund: &mut Fund<FundCoinType>,
        request: Take_1_Liquidity_1_NonLiquidity_For_1_NonLiquidity_Request<TakeCoinType, TakeAsset, PutAsset>,
        nonliquidity: PutAsset,
        mut settle_request: SettleRequest,
        is_finished: bool,
    ): SettleRequest{

        config::assert_if_version_not_matched(config, VERSION);
        
        let Take_1_Liquidity_1_NonLiquidity_For_1_NonLiquidity_Request{
            take_amount1: _,
            take_amount2: _,
            put_amount,
        } = request;

        assert_if_put_amount_is_zero(put_amount);

        let asset_type = type_name::get<PutAsset>();
        assert_if_nonliquidity_in_asset_bag<PutAsset, FundCoinType>(fund,);

        fund.asset.assets.add(asset_type, nonliquidity);

        // update settle request
        settle_request.is_finished = is_finished;
        settle_request
    }

    public fun settle_1_nonLiquidity_for_1_liquidity<TakeAsset: store, PutCoinType, FundCoinType>(
        config: &GlobalConfig,
        fund: &mut Fund<FundCoinType>,
        request: Take_1_NonLiquidity_For_1_Liquidity_Request<TakeAsset, PutCoinType>,
        liquidity: Balance<PutCoinType>,
        mut settle_request: SettleRequest,
        is_finished: bool,
    ): SettleRequest{

        config::assert_if_version_not_matched(config, VERSION);
        
        let Take_1_NonLiquidity_For_1_Liquidity_Request{
            take_amount: _,
            put_amount,
        } = request;

        assert_if_put_amount_is_zero(put_amount);
        assert_if_put_liquidity_not_equal_to_put_amount(put_amount, liquidity.value());

        let asset_type = type_name::get<Balance<PutCoinType>>();
        
        if (fund.asset.assets.contains(asset_type)){
            let fund_asset = fund.asset.assets.borrow_mut<TypeName, Balance<PutCoinType>>(asset_type);
            fund_asset.join(liquidity);
        }else{
            fund.asset.assets.add(asset_type, liquidity);
        };

        // update settle request
        settle_request.is_finished = is_finished;
        settle_request
    }

    public fun settle_1_nonliquidity_for_2_liquidity<TakeAsset: store, PutCoinType1, PutCoinType2, FundCoinType>(
        config: &GlobalConfig,
        fund: &mut Fund<FundCoinType>,
        request: Take_1_NonLiquidity_For_2_Liquidity_Request<TakeAsset, PutCoinType1, PutCoinType2>,
        liquidity1: Balance<PutCoinType1>,
        liquidity2: Balance<PutCoinType2>,
        mut settle_request: SettleRequest,
        is_finished: bool,
    ): SettleRequest{

        config::assert_if_version_not_matched(config, VERSION);
        
        let Take_1_NonLiquidity_For_2_Liquidity_Request{
            take_amount: _,
            put_amount1,
            put_amount2,
        } = request;

        assert_if_put_amount_is_zero(put_amount1);
        assert_if_put_amount_is_zero(put_amount2);
        assert_if_put_liquidity_not_equal_to_put_amount(put_amount1, liquidity1.value());
        assert_if_put_liquidity_not_equal_to_put_amount(put_amount2, liquidity2.value());

        let asset_type1 = type_name::get<Balance<PutCoinType1>>();
        let asset_type2 = type_name::get<Balance<PutCoinType2>>();
        
        if (fund.asset.assets.contains(asset_type1)){
            let fund_asset = fund.asset.assets.borrow_mut<TypeName, Balance<PutCoinType1>>(asset_type1);
            fund_asset.join(liquidity1);
        }else{
            fund.asset.assets.add(asset_type1, liquidity1);
        };

        if (fund.asset.assets.contains(asset_type2)){
            let fund_asset = fund.asset.assets.borrow_mut<TypeName, Balance<PutCoinType2>>(asset_type1);
            fund_asset.join(liquidity2);
        }else{
            fund.asset.assets.add(asset_type2, liquidity2);
        };

        // update settle request
        settle_request.is_finished = is_finished;
        settle_request
    }

    public fun create_settle_request< FundCoinType>(
        config: &GlobalConfig,
        fund: &mut Fund<FundCoinType>,
        is_finished: bool,
        clock: &Clock,
        ctx: &TxContext,
    ): SettleRequest{
        
        config::assert_if_version_not_matched(config, VERSION);

        assert_if_not_arrived_end_time(fund, clock);
        assert_if_settler_not_fund_investor<FundCoinType>(fund, ctx);
        
        SettleRequest{
            fund: *fund.id.as_inner(),
            settler: ctx.sender(),
            is_finished,
        }
    }

    public fun settle<FundCoinType>(
        config: &GlobalConfig,
        fund: &mut Fund<FundCoinType>,
        request: SettleRequest, 
        ctx: &mut TxContext,
    ): Coin<FundCoinType>{
        config::assert_if_version_not_matched(config, VERSION);
        assert_if_not_finished(&request);
        assert_if_fund_has_nonbasic_asset(fund);

        let SettleRequest{
            fund: _,
            settler: _,
            is_finished: _, 
        } = request;

        fund.is_settle = true;
        

        // calculate rewards
        let total_base = fund.asset.assets.borrow<TypeName, Balance<FundCoinType>>(type_name::get<Balance<FundCoinType>>()).value();
        fund.after_amount = total_base;
        if (total_base > fund.base){
            if (fund.base < config.min_rewards()){
                coin::from_balance<FundCoinType>(balance::zero<FundCoinType>(), ctx)
            }else{
                let rewards = fund.asset.assets.borrow_mut<TypeName, Balance<FundCoinType>>(type_name::get<Balance<FundCoinType>>());
                let to_settler_value = rewards.value() *  config.settle_percentage() / config.base_percentage();
                let to_settle_balance = rewards.split(to_settler_value);
                coin::from_balance<FundCoinType>(to_settle_balance, ctx)
            }
        }else{
            coin::from_balance<FundCoinType>(balance::zero<FundCoinType>(), ctx)
        }
    }

    public fun claim<FundCoinType>(
        config: &GlobalConfig,
        fund: &mut Fund<FundCoinType>,
        shares: FundShare,
        ctx: &mut TxContext,
    ): (Coin<FundCoinType>){

        config::assert_if_version_not_matched(config, VERSION);
        assert_if_not_settle(fund);
        let value = fund.share_info.investor.remove(ctx.sender());
        let share_amount = shares.invest_amount();

        if (value != shares.invest_amount()){
            fund.share_info.investor.add(ctx.sender(), value - shares.invest_amount());
        };
        
        let burn_request = fund_share::create_burn_request<FundCoinType>(config, *fund.id.as_inner(), fund.time.end_time);
        fund_share::burn<FundCoinType>(config, burn_request, shares);
        
        // calculate rewards
        if (fund.asset.assets.borrow<TypeName, Balance<FundCoinType>>(type_name::get<Balance<FundCoinType>>()).value() - fund.base >= config.min_rewards()){
            let total_asset = fund.asset.assets.borrow_mut<TypeName, Balance<FundCoinType>>(type_name::get<Balance<FundCoinType>>());
            let investor_amount =  fund.after_amount  * share_amount / fund.share_info.total_share;
            let to_investor_balance = total_asset.split<FundCoinType>(investor_amount);
            coin::from_balance<FundCoinType>(to_investor_balance, ctx)
        }else{
            coin::from_balance<FundCoinType>(balance::zero<FundCoinType>(), ctx)
        }
    }

    public fun trader_claim<FundCoinType>(
        config: &GlobalConfig,
        fund: &mut Fund<FundCoinType>,
        trader: &Trader,
        ctx: &mut TxContext,
    ): Coin<FundCoinType>{
        assert_if_trader_not_matched(fund, trader);
        assert_if_not_settle(fund);
        
        if (fund.asset.assets.borrow<TypeName, Balance<FundCoinType>>(type_name::get<Balance<FundCoinType>>()).value() >= fund.base ){
            if (fund.asset.assets.borrow<TypeName, Balance<FundCoinType>>(type_name::get<Balance<FundCoinType>>()).value() - fund.base >= config.min_rewards()){
                let total_asset = fund.asset.assets.borrow_mut<TypeName, Balance<FundCoinType>>(type_name::get<Balance<FundCoinType>>());
                let trader_amount = ( total_asset.value() - fund.base ) * fund.trader_fee / config.base_percentage();
                let to_trader_balance = total_asset.split<FundCoinType>(trader_amount);

                coin::from_balance<FundCoinType>(to_trader_balance, ctx)
            }else{
                coin::from_balance<FundCoinType>(balance::zero<FundCoinType>(), ctx)
            }
        }else{
            coin::from_balance<FundCoinType>(balance::zero<FundCoinType>(), ctx)
        }
    }

    public fun description<CoinType>(
        fund: &Fund<CoinType>,
    ):String{
        fund.description
    }

    public fun is_arena<CoinType>(
        fund: &Fund<CoinType>,
    ): bool{
        fund.is_arena
    }

    public fun trader<CoinType>(
        fund: &Fund<CoinType>,
    ): ID{
        fund.trader
    }

    public fun end_time<CoinType>(
        fund: &Fund<CoinType>
    ): u64{
        fund.time.end_time
    }

    public fun start_time<CoinType>(
        fund: &Fund<CoinType>
    ):u64{
        fund.time.start_time
    }

    public(package) fun id <CoinType>(
        fund: &mut Fund<CoinType>
    ): &mut UID{
        &mut fund.id
    }

    public(package) fun update_time<FundCoinType>(
        fund: &mut Fund<FundCoinType>,
        start_time: u64,
        invest_duration: u64,
        end_time: u64,
    ){
        fund.time.start_time = start_time;
        fund.time.invest_duration = invest_duration;
        fund.time.end_time = end_time;
    }

    public(package) fun update_description<FundCoinType>(
        fund: &mut Fund<FundCoinType>,
        new_description: String,
        trader: &Trader,
    ){
        assert_if_trader_not_matched(fund, trader);
        fund.description = new_description;
    }

    public(package) fun set_is_arena<FundCoinType>(
        fund: &mut Fund<FundCoinType>,
        is_arena: bool,
    ){
        fund.is_arena = is_arena;
    }

    // defi confirm 
    public(package) fun supported_defi_confirm_1l_for_1l<TakeCoinType, PutCoinType>(
        reqeust: &mut Take_1_Liquidity_For_1_Liquidity_Request<TakeCoinType, PutCoinType>,
        put_amount: u64,
    ){
        reqeust.put_amount = put_amount;
    }

    public(package) fun supported_defi_confirm_1l_for_2l<TakeCoinType1, PutCoinType1, PutCoinType2 >(
        reqeust: &mut Take_1_Liquidity_For_2_Liquidity_Request<TakeCoinType1, PutCoinType1, PutCoinType2>,
        put_amount1: u64,
        put_amount2: u64,
    ){
        reqeust.put_amount1 = put_amount1;
        reqeust.put_amount2 = put_amount2;
    }

    public(package) fun supported_defi_confirm_1l_for_1nl<TakeCoinType1, PutAsset: store >(
        reqeust: &mut Take_1_Liquidity_For_1_NonLiquidity_Request<TakeCoinType1, PutAsset>,
        put_amount: u64,
    ){
        reqeust.put_amount = put_amount;
    }

    public(package) fun supported_defi_confirm_1l_1nl_for_1nl<TakeCoinType, TakeAsset: store, PutAsset: store>(
        request: &mut Take_1_Liquidity_1_NonLiquidity_For_1_NonLiquidity_Request<TakeCoinType, TakeAsset, PutAsset>,
        put_amount: u64,
    ){
        request.put_amount = put_amount;
    }

    public(package) fun supported_defi_confirm_1nl_for_1l<TakeAsset: store, PutCoinType>(
        request: &mut Take_1_NonLiquidity_For_1_Liquidity_Request<TakeAsset, PutCoinType>,
        put_amount: u64,
    ){
        request.put_amount = put_amount;
    }

    public(package) fun supported_defi_confirm_1nl_for_2l<TakeAsset: store, PutCoinType1, PutCoinType2>(
        request: &mut Take_1_NonLiquidity_For_2_Liquidity_Request<TakeAsset, PutCoinType1, PutCoinType2>,
        put_amount1: u64,
        put_amount2: u64,
    ){
        request.put_amount1 = put_amount1;
        request.put_amount2 = put_amount2;
    }

    fun assert_if_over_max_trader_fee(
        config: &GlobalConfig,
        input_trader_fee: u64,
    ){
        assert!(config.max_trader_fee() >= input_trader_fee, EOverMaxTraderFee);
    }
    
    fun assert_if_take_liquidity_not_in_fund<TakeCoinType, FundCoinType>(
        fund: &Fund<FundCoinType>
    ){
        assert!(fund.asset.assets.contains(type_name::get<Balance<TakeCoinType>>()), ETakeLiquidityNotInFund);
    }

    fun assert_if_take_nonliquidity_not_in_fund<TakeAsset, FundCoinType>(
        fund: &Fund<FundCoinType>
    ){
        assert!(fund.asset.assets.contains(type_name::get<TakeAsset>()), ETakeNonLiquidityNotInFund);
    }

    fun assert_if_take_amount_not_enough<TakeCoinType, FundCoinType>(
        fund: &Fund<FundCoinType>,
        amount: u64,
    ){
        assert!(fund.asset.assets.borrow<TypeName, Balance<TakeCoinType>>(type_name::get<TakeCoinType>()).value() >= amount, EFundTakeLiquidityNotEnough);
    }

    fun assert_if_put_amount_is_zero(request_put_amount: u64){
        assert!(request_put_amount != 0 , EPutAmountNotSet);
    }

    fun assert_if_put_liquidity_not_equal_to_put_amount(
        request_put_amount: u64,
        balance_amount: u64,
    ){
        assert!(request_put_amount == balance_amount , EPutAmountNotMatchedPutBalance);
    }

    fun assert_if_nonliquidity_in_asset_bag<PutAsset, FundCoinType>(
        fund: &Fund<FundCoinType>,
    ){
        assert!(!fund.asset.assets.contains(type_name::get<PutAsset>()), ENonLiquidityInFund);
    }

    fun assert_if_time_setting_wrong(
        start_time: u64,
        invest_duration: u64,
        end_time: u64,
    ){
        assert!(end_time > start_time, EEndTimeNotBiggerThanStartTime);
        assert!(invest_duration >= 3600000, ELessThanMinDuration);
    }

    fun assert_if_trader_not_matched<FundCoinType>(
        fund: &Fund<FundCoinType>,
        trader: &Trader,
    ){
        assert!(trader.id() == fund.trader, ETraderNotMatched);
    }

    fun assert_if_settler_not_fund_investor<FundCoinType>(
        fund: &Fund<FundCoinType>,
        ctx: &TxContext,
    ){
        assert!(fund.share_info.investor.contains(ctx.sender()), ENotInInvestorList);
    }
    fun assert_if_not_arrived_end_time<FundCoinType>(
        fund: &Fund<FundCoinType>,
        clock: &Clock,
    ){
        assert!(fund.time.end_time <= clock.timestamp_ms(), ENotArrivedSettleTime);
    }

    fun assert_if_not_finished(
        request: &SettleRequest,
    ){
        assert!(request.is_finished, ESettleNotFinished);
    }

    fun assert_if_fund_has_nonbasic_asset<FundCoinType>(
        fund: &Fund<FundCoinType>,
    ){
        assert!(fund.asset.asset_types.length() == 1, EFundHasNonBaseAsset);
        assert!(fund.asset.asset_types.borrow(0) == type_name::get<Balance<FundCoinType>>(), EBaseTypeNotMatched);
    }

    fun assert_if_not_settle<FundCoinType>(
        fund: &Fund<FundCoinType>,
    ){
        assert!(fund.is_settle, ENotSettle);
    }

    fun assert_if_over_invest_duration<FundCoinType>(
        fund: &Fund<FundCoinType>,
        clock: &Clock,
    ){
        assert!(fund.time.start_time + fund.time.invest_duration >= clock.timestamp_ms(), EOverInvestTime);
    }

}
