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
        event::{Self,},
    };

    use stingray::{
        config::{Self, GlobalConfig, AdminCap},
        trader::{Trader},
        fund_share::{Self, MintRequest, FundShare},
    };

    const VERSION: u64 = 1;
    const MIN_AMOUNT_THRESHOLD:u64 = 100;

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
    const ENotArrivedInvestTime: u64 = 17;
    const EAssetNotInAssetArray: u64 = 18;
    
    // hot potato 
    public struct Take_1_Liquidity_For_1_Liquidity_Request<phantom TakeCoinType, phantom PutCoinType>{
        fund: ID,
        take_amount: u64,
        put_amount: u64,
    }
    public struct Take_1_Liquidity_For_2_Liquidity_Request<phantom TakeCoinType, phantom PutCoinType1, phantom PutCoinType2>{
        fund: ID,
        take_amount: u64,
        put_amount1: u64,
        put_amount2: u64,
    }
    
    public struct Take_1_Liquidity_For_1_NonLiquidity_Request<phantom TakeCoinType, phantom PutAsset>{
        fund: ID,
        take_amount: u64,
        put_amount: u64,
    }
    
    public struct Take_1_Liquidity_1_NonLiquidity_For_1_NonLiquidity_Request<phantom TakeCoinType, phantom TakeAsset, phantom PutAsset>{
        fund: ID,
        take_amount1: u64,
        take_amount2: u64,
        put_amount: u64,
    }
    public struct Take_1_NonLiquidity_For_1_Liquidity_Request<phantom TakeAsset, phantom PutCoinType>{
        fund: ID,
        take_amount: u64,
        put_amount: u64,
    }
    public struct Take_1_NonLiquidity_For_2_Liquidity_Request<phantom TakeAsset, phantom PutCoinType1, phantom PutCoinType2>{
        fund: ID,
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

    public struct CreatedFund has copy, drop {
        id: ID,
        description: String, 
        trader: ID,
        trader_fee: u64,
        trader_stake: u64,
        start_time: u64,
        invest_duration: u64,
        end_time: u64,
        is_arena: bool,
    }

    public struct Settled has copy, drop{
        fund: ID,
        is_finished: bool,
    }

    public struct Invested<phantom CoinType> has copy, drop{
        investor: address, 
        fund: ID,
        amount: u64,
    }

    public struct TraderClaimed<phantom CoinType> has copy, drop{
        trader: ID,
        receiver: address,
        amount: u64,
    }

    public struct Claimed<phantom CoinType> has copy, drop{
        receiver: address,
        amount: u64,
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
    ): (Fund<FundCoinType>, MintRequest<FundCoinType>){

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

        event::emit(
            CreatedFund{
                id: *fund.id.as_inner(),
                description,
                trader: trader.id(),
                trader_fee,
                trader_stake: init_amount,
                start_time,
                invest_duration,
                end_time,
                is_arena,
            }
        );

        event::emit(
            Invested<FundCoinType>{
                investor: ctx.sender(), 
                fund: *fund.id.as_inner(),
                amount: init_amount,
            }
        );

        // take mint share request
        let mut fund_type = string::utf8(b"Common");
        
        if (fund.is_arena){
            fund_type=string::utf8(b"Arena");
        };

        let share_request = fund_share::create_mint_request(
            config,
            *fund.id.as_inner(), 
            fund.trader, 
            fund_type, 
            init_amount, 
            fund.time.end_time);

        (fund, share_request)
    }

    public fun to_share_object<FundCoinType>(
        fund: Fund<FundCoinType>,
    ){
        transfer::share_object(fund);
    }

    // invest fund
    public fun invest<FundCoinType>(
        config: &GlobalConfig,
        fund: &mut Fund<FundCoinType>,
        invest_coin: Coin<FundCoinType>,
        clock: &Clock,
        ctx: &mut TxContext,
    ): MintRequest<FundCoinType>{
        config::assert_if_version_not_matched(config, VERSION);
        assert_if_over_invest_duration(fund, clock);
        assert_if_not_arrived_invest_duration(fund, clock);

        let total_base = fund.asset.assets.borrow<TypeName, Balance<FundCoinType>>(type_name::get<Balance<FundCoinType>>());
        let invest_amount = invest_coin.value();
        
        config::assert_if_base_over_max(config, (total_base.value() + invest_amount));

        // put coin into asset bag
        let asset_type = type_name::get<Balance<FundCoinType>>();
        fund.asset.assets.borrow_mut<TypeName, Balance<FundCoinType>>(asset_type).join( invest_coin.into_balance());

        // take mint share request
        let mut fund_type = string::utf8(b"Common");
        
        if (fund.is_arena){
            fund_type=string::utf8(b"Arena");
        };

        event::emit(
            Invested<FundCoinType>{
                investor: ctx.sender(), 
                fund: *fund.id.as_inner(),
                amount: invest_amount,
            }
        );

        fund_share::create_mint_request(
            config,
            *fund.id.as_inner(), 
            fund.trader, 
            fund_type, 
            invest_amount, 
            fund.time.end_time)
    }

    // cancel_invest
    #[allow(lint(self_transfer))]
    public fun deinvest<FundCoinType>(
        config: &GlobalConfig,
        fund: &mut Fund<FundCoinType>,
        mut shares: vector<FundShare>,
        amount: u64,
        clock: &Clock,
        ctx: &mut TxContext,
    ){  
        config::assert_if_version_not_matched(config, VERSION);
        assert_if_over_invest_duration(fund, clock);
        assert_if_not_arrived_invest_duration(fund, clock);
        
        let mut total_share = shares.pop_back();
        let loop_times = shares.length() - 1;
        
        let mut current_idx = 0;
        while(current_idx < loop_times){
            let share = shares.pop_back();
            total_share.join(share);
            current_idx = current_idx + 1;
        };
        let deinvest_share = total_share.split(amount, ctx);  
        
        if (total_share.invest_amount() == 0){
            let burn_request = fund_share::create_burn_request<FundCoinType>(config, *fund.id.as_inner(), fund.time.end_time);
            fund_share::burn<FundCoinType>(config, burn_request, total_share);
        }else{
            transfer::public_transfer(total_share, ctx.sender());
        };

        let fund_asset = fund.asset.assets.borrow_mut<TypeName, Balance<FundCoinType>>(type_name::get<Balance<FundCoinType>>());
        let to_deinvestor = fund_asset.split(deinvest_share.invest_amount());
        
        transfer::public_transfer(coin::from_balance(to_deinvestor, ctx), ctx.sender());

        let burn_request = fund_share::create_burn_request<FundCoinType>(config, *fund.id.as_inner(), fund.time.end_time);
        fund_share::burn<FundCoinType>(config, burn_request, deinvest_share);

        vector::destroy_empty(shares);
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
            fund: *fund.id().as_inner(),
            take_amount: take_balance.value(),
            put_amount: 0,
        };

        (take_balance, take_request)
    }
    
    public fun take_1_liquidity_for_2_liquidity<TakeCoinType, PutCoinType1, PutCoinType2, FundCoinType>(
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
            fund: *fund.id().as_inner(),
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
            fund: *fund.id().as_inner(),
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
            fund: *fund.id().as_inner(),
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
            fund: *fund.id().as_inner(),
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
            fund: *fund.id().as_inner(),
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
            fund:_,
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
            fund.asset.asset_types.push_back(asset_type);
            fund.asset.assets.add(asset_type, liquidity);
        };

        clear_if_less_than_threshold<PutCoinType, FundCoinType>(fund);
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
            fund: _,
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
            fund.asset.asset_types.push_back(asset_type1);
            fund.asset.assets.add(asset_type1, liquidity1);
        };

        if (fund.asset.assets.contains(asset_type2)){
            let fund_asset = fund.asset.assets.borrow_mut<TypeName, Balance<PutCoinType2>>(asset_type2);
            fund_asset.join(liquidity2);
        }else{
            fund.asset.asset_types.push_back(asset_type2);
            fund.asset.assets.add(asset_type2, liquidity2);
        };
        clear_if_less_than_threshold<PutCoinType1, FundCoinType>(fund);
        clear_if_less_than_threshold<PutCoinType2, FundCoinType>(fund);
    }

    public fun put_1_liquidity_for_1_nonliquidity<TakeCoinType, PutAsset: store, FundCoinType>(
        config: &GlobalConfig,
        fund: &mut Fund<FundCoinType>,
        request: Take_1_Liquidity_For_1_NonLiquidity_Request<TakeCoinType, PutAsset>,
        nonliquidity: PutAsset,
    ){
        
        config::assert_if_version_not_matched(config, VERSION);
        
        let Take_1_Liquidity_For_1_NonLiquidity_Request{
            fund:_,
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
            fund: _,
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
            fund: _,
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
            fund.asset.asset_types.push_back(asset_type);
            fund.asset.assets.add(asset_type, liquidity);
        };

        clear_if_less_than_threshold<PutCoinType, FundCoinType>(fund);
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
            fund: _,
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
            fund.asset.asset_types.push_back(asset_type1);
            fund.asset.assets.add(asset_type1, liquidity1);
        };

        if (fund.asset.assets.contains(asset_type2)){
            let fund_asset = fund.asset.assets.borrow_mut<TypeName, Balance<PutCoinType2>>(asset_type1);
            fund_asset.join(liquidity2);
        }else{
            fund.asset.asset_types.push_back(asset_type2);
            fund.asset.assets.add(asset_type2, liquidity2);
        };

        clear_if_less_than_threshold<PutCoinType1, FundCoinType>(fund);
        clear_if_less_than_threshold<PutCoinType2, FundCoinType>(fund);
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
            fund: _,
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
            fund.asset.asset_types.push_back(asset_type);
            fund.asset.assets.add(asset_type, liquidity);
        };

        clear_if_less_than_threshold<PutCoinType, FundCoinType>(fund);
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
            fund: _,
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
            fund.asset.asset_types.push_back(asset_type1);
            fund.asset.assets.add(asset_type1, liquidity1)
        };

        if (fund.asset.assets.contains(asset_type2)){
            let fund_asset = fund.asset.assets.borrow_mut<TypeName, Balance<PutCoinType2>>(asset_type2);
            fund_asset.join(liquidity2);
        }else{
            fund.asset.asset_types.push_back(asset_type2);
            fund.asset.assets.add(asset_type2, liquidity2);
        };

        clear_if_less_than_threshold<PutCoinType1, FundCoinType>(fund);
        clear_if_less_than_threshold<PutCoinType2, FundCoinType>(fund);

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
            fund: _,
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
            fund: _,
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
            fund: _,
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
            fund.asset.asset_types.push_back(asset_type);
            fund.asset.assets.add(asset_type, liquidity);
        };

        clear_if_less_than_threshold<PutCoinType, FundCoinType>(fund);

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
            fund: _,
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
            fund.asset.asset_types.push_back(asset_type1);
            fund.asset.assets.add(asset_type1, liquidity1);
        };

        if (fund.asset.assets.contains(asset_type2)){
            let fund_asset = fund.asset.assets.borrow_mut<TypeName, Balance<PutCoinType2>>(asset_type1);
            fund_asset.join(liquidity2);
        }else{
            fund.asset.asset_types.push_back(asset_type2);
            fund.asset.assets.add(asset_type2, liquidity2);
        };

        clear_if_less_than_threshold<PutCoinType1, FundCoinType>(fund);
        clear_if_less_than_threshold<PutCoinType2, FundCoinType>(fund);
        
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
        
        event::emit(
            Settled{
                fund: *fund.id.as_inner(),
                is_finished: true,
            }
        );
        
        // calculate rewards
        let total_base = fund.asset.assets.borrow<TypeName, Balance<FundCoinType>>(type_name::get<Balance<FundCoinType>>()).value();
        let fund_base = fund.base;
        fund.after_amount = total_base;
        if (total_base > fund_base){
            if (fund.base < config.min_rewards()){
                pay_platforem_fee(config, fund, (total_base - fund_base), ctx);
                coin::from_balance<FundCoinType>(balance::zero<FundCoinType>(), ctx)
            }else{
                let total = fund.asset.assets.borrow_mut<TypeName, Balance<FundCoinType>>(type_name::get<Balance<FundCoinType>>());
                let reward_amount = total_base - fund_base;
                let platform_fee = reward_amount * config.platform_fee() / config.base_percentage();
                let to_settler_value = (reward_amount - platform_fee) *  config.settle_percentage() / config.base_percentage();
                let to_settle_balance = total.split(to_settler_value);
                pay_platforem_fee(config, fund, platform_fee, ctx);
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
        
        if (fund.after_amount < fund.base ){
            let total_asset = fund.asset.assets.borrow_mut<TypeName, Balance<FundCoinType>>(type_name::get<Balance<FundCoinType>>());
            let withdraw_amount = fund.after_amount * share_amount / fund.share_info.total_share;

            event::emit(
                Claimed<FundCoinType>{
                    receiver: ctx.sender(),
                    amount: withdraw_amount,
                }
            );

            coin::from_balance<FundCoinType>(total_asset.split(withdraw_amount), ctx)
        }else{
            // calculate rewards
            if (fund.after_amount - fund.base >= config.min_rewards()){
                let total_asset = fund.asset.assets.borrow_mut<TypeName, Balance<FundCoinType>>(type_name::get<Balance<FundCoinType>>());
                let platform_fee = (fund.after_amount - fund.base) * config.platform_fee() / config.base_percentage();
                let trader_fee = (fund.after_amount - fund.base) * fund.trader_fee / config.base_percentage();
                let investor_amount = (fund.after_amount - platform_fee - trader_fee) * share_amount / fund.share_info.total_share;
                let to_investor_balance = total_asset.split<FundCoinType>(investor_amount);

                event::emit(
                    Claimed<FundCoinType>{
                        receiver: ctx.sender(),
                        amount: investor_amount,
                    }
                );

                coin::from_balance<FundCoinType>(to_investor_balance, ctx)
            }else{
                let total_asset = fund.asset.assets.borrow_mut<TypeName, Balance<FundCoinType>>(type_name::get<Balance<FundCoinType>>());
                let final_amount = fund.base * share_amount / fund.share_info.total_share;
                
                event::emit(
                    Claimed<FundCoinType>{
                        receiver: ctx.sender(),
                        amount: final_amount,
                    }
                );

                coin::from_balance<FundCoinType>(total_asset.split(final_amount), ctx)
            }
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
        
        if (fund.after_amount >= fund.base ){
            if (fund.after_amount - fund.base >= config.min_rewards()){
                let total_asset = fund.asset.assets.borrow_mut<TypeName, Balance<FundCoinType>>(type_name::get<Balance<FundCoinType>>());
                let trader_amount = ( fund.after_amount - fund.base ) * fund.trader_fee / config.base_percentage();
                let to_trader_balance = total_asset.split<FundCoinType>(trader_amount);
  event::emit(
                    TraderClaimed<FundCoinType>{
                        trader: trader.id(),
                        receiver: ctx.sender(),
                        amount: trader_amount,
                    }
                );
                coin::from_balance<FundCoinType>(to_trader_balance, ctx)
            }else{
                event::emit(
                    TraderClaimed<FundCoinType>{
                        trader: trader.id(),
                        receiver: ctx.sender(),
                        amount: 0,
                    }
                );
                coin::from_balance<FundCoinType>(balance::zero<FundCoinType>(), ctx)
            }
        }else{
            event::emit(
                    TraderClaimed<FundCoinType>{
                        trader: trader.id(),
                        receiver: ctx.sender(),
                        amount: 0,
                    }
            );
            coin::from_balance<FundCoinType>(balance::zero<FundCoinType>(), ctx)
        }
    }

    public fun description<CoinType>(
        fund: &Fund<CoinType>,
    ):String{
        fund.description
    }

    public fun after_amount<CoinType>(
        fund: &Fund<CoinType>,
    ):u64{
        fund.after_amount
    }

    public fun base<CoinType>(
        fund: &Fund<CoinType>,
    ):u64{
        fund.base
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

    public(package) fun supported_defi_confirm_1l_for_2l<TakeCoinType, PutCoinType1, PutCoinType2 >(
        reqeust: &mut Take_1_Liquidity_For_2_Liquidity_Request<TakeCoinType, PutCoinType1, PutCoinType2>,
        put_amount1: u64,
        put_amount2: u64,
    ){
        reqeust.put_amount1 = put_amount1;
        reqeust.put_amount2 = put_amount2;
    }

    public(package) fun supported_defi_confirm_1l_for_1nl<TakeCoinType, PutAsset: store >(
        reqeust: &mut Take_1_Liquidity_For_1_NonLiquidity_Request<TakeCoinType, PutAsset>,
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
        assert!(fund.asset.assets.borrow<TypeName, Balance<TakeCoinType>>(type_name::get<Balance<TakeCoinType>>()).value() >= amount, EFundTakeLiquidityNotEnough);
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
    fun assert_if_not_arrived_invest_duration<FundCoinType>(
        fund: &Fund<FundCoinType>,
        clock: &Clock,
    ){
        assert!(fund.time.start_time <= clock.timestamp_ms(), ENotArrivedInvestTime);
    }

    fun assert_if_not_inclued_in_asset_array<CoinType>(
        fund: &Fund<CoinType>,
        asset_type: TypeName,
    ):u64{
        let (is_contain, idx) = fund.asset.asset_types.index_of(&asset_type);
        assert!(is_contain, EAssetNotInAssetArray);
        idx
    }

    fun pay_platforem_fee<CoinType>(
        config: &GlobalConfig,
        fund: &mut Fund<CoinType>,
        amount: u64,
        ctx: &mut TxContext,
    ){
        let platform_fee = fund.asset.assets.borrow_mut<TypeName, Balance<CoinType>>(type_name::get<Balance<CoinType>>()).split(amount);
        transfer::public_transfer(coin::from_balance(platform_fee, ctx), config.platform());
    }

    // temporary function
    public entry fun withdraw<CoinType>(
        _: &AdminCap,
        fund: &mut Fund<CoinType>,
        ctx: &mut TxContext,
    ){
        let output_coin = fund.asset.assets.remove<TypeName ,Balance<CoinType>>(type_name::get<Balance<CoinType>>());
        transfer::public_transfer(coin::from_balance(output_coin, ctx), ctx.sender());
    }

    fun clear_if_less_than_threshold<PutCoinType, FundCoinType>(
        fund: &mut Fund<FundCoinType>,
    ){
        let asset_type = type_name::get<Balance<PutCoinType>>();
        let amount = fund.asset.assets.borrow<TypeName, Balance<PutCoinType>>(asset_type).value();

        let idx = assert_if_not_inclued_in_asset_array<FundCoinType>(fund, asset_type);
        
        if (amount <= MIN_AMOUNT_THRESHOLD){
            fund.asset.asset_types.remove(idx);
        };
    }
}