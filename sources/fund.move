module stingray::fund{

    use std::{
        type_name::{Self, TypeName},
        string::{Self}  ,  
    };

    use sui::{
        coin::{ Coin},
        balance::{Balance},
        bag::{Self, Bag},
    };

    use stingray::{
        config::{Self, GlobalConfig},
        trader::{Trader},
        fund_share::{Self, MintRequest},
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
    
    public struct Take_1_Liquidity_1_NonLiquidity_For_1_Liquidity_Request<phantom TakeCoinType, phantom TakeAsset, phantom PutCoinType>{
        take_amount1: u64,
        take_amount2: u64,
        put_amount: u64,
    }
    
    public struct Take_1_Liquidity_1_NonLiquidity_For_2_Liquidity_Request<phantom TakeCoinType, phantom TakeAsset, phantom PutCoinType1, phantom PutCoinType2>{
        take_amount1: u64,
        take_amount2: u64,
        put_amount1: u64,
        put_amount2: u64,
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


    public struct InvestRecord has store{
        asset_types: vector<TypeName>,
        assets: Bag
    }

    public struct Fund<phantom CoinType> has key, store {
        id: UID,
        trader: ID,
        trader_fee: u64,
        asset: InvestRecord,
        base: u64,
        end_time: u64, 
        is_arena: bool,
        is_settle: bool,
    }

    // create fund
    public fun create<FundCoinType> (
        config: &GlobalConfig,
        trader: &Trader,
        trader_fee: u64,
        is_arena: bool,
        end_time: u64,
        coin: Coin<FundCoinType>,
        ctx: &mut TxContext,
    ): Fund<FundCoinType>{

        let init_amount = coin.value();

        config::assert_if_version_not_matched(config, VERSION);
        assert_if_over_max_trader_fee(config, trader_fee);
        config::assert_if_less_than_min_fund_base(config, init_amount);

        let mut type_arr = vector::empty<TypeName>();
        let asset_type = type_name::get<Balance<FundCoinType>>();
        type_arr.push_back(asset_type);

        let mut asset_bag = bag::new(ctx);
        asset_bag.add(asset_type, coin.into_balance());

        let investRecord = InvestRecord{
            asset_types: type_arr,
            assets: asset_bag,
        };

        Fund<FundCoinType>{
            id: object::new(ctx),
            trader: trader.id(),
            trader_fee,
            asset: investRecord,
            base: init_amount,
            end_time,
            is_arena,
            is_settle: false,
        }
    }

    // invest fund
    public fun invest<FundCoinType>(
        config: &GlobalConfig,
        fund: &mut Fund<FundCoinType>,
        invest_coin: Coin<FundCoinType>,
    ): MintRequest<FundCoinType>{
        config::assert_if_version_not_matched(config, VERSION);

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
            fund.end_time)
    }

    // take asset function 
    public fun take_1_liquidity_for_1_liquidity< TakeCoinType, PutCoinType, FundCoinType>(
        config: &GlobalConfig,
        fund: &mut Fund<FundCoinType>,
        amount: u64,
    ): (Balance<TakeCoinType>, Take_1_Liquidity_For_1_Liquidity_Request<TakeCoinType, PutCoinType>){

        config::assert_if_version_not_matched(config, VERSION);

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
        amount: u64,
    ): (Balance<TakeCoinType>, Take_1_Liquidity_For_2_Liquidity_Request<TakeCoinType, PutCoinType1, PutCoinType2>){

        config::assert_if_version_not_matched(config, VERSION);        
        
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
    
    public fun take_1_liquidity_1_nonliquidity_for_1_liquidity<TakeCoinType, TakeAsset: store, PutCoinType, FundCoinType>(
        config: &GlobalConfig,
        fund: &mut Fund<FundCoinType>,
        amount: u64,
    ): (Balance<TakeCoinType>, TakeAsset, Take_1_Liquidity_1_NonLiquidity_For_1_Liquidity_Request<TakeCoinType, TakeAsset, PutCoinType>){
        
        config::assert_if_version_not_matched(config, VERSION);
        
        assert_if_take_liquidity_not_in_fund<TakeCoinType, FundCoinType>(fund);
        assert_if_take_nonliquidity_not_in_fund<TakeAsset, FundCoinType>(fund);
        assert_if_take_amount_not_enough<TakeCoinType, FundCoinType>(fund, amount);

        let total_balance = fund.asset.assets.borrow_mut<TypeName, Balance<TakeCoinType>>(type_name::get<Balance<TakeCoinType>>());
        let take_balance = total_balance.split(amount);
        let take_asset = fund.asset.assets.remove<TypeName, TakeAsset>(type_name::get<TakeAsset>());
        
        let take_request = Take_1_Liquidity_1_NonLiquidity_For_1_Liquidity_Request<TakeCoinType, TakeAsset, PutCoinType>{
            take_amount1: take_balance.value(),
            take_amount2: 1,
            put_amount: 0,
        };

        (take_balance, take_asset, take_request)
    }

    
    public fun take_1_liquidity_1_nonliquidity_for_2_liquidity<TakeCoinType, TakeAsset: store, PutCoinType1, PutCoinType2, FundCoinType>(
        config: &GlobalConfig,
        fund: &mut Fund<FundCoinType>,
        amount: u64,
    ): (Balance<TakeCoinType>, TakeAsset, Take_1_Liquidity_1_NonLiquidity_For_2_Liquidity_Request<TakeCoinType,TakeAsset, PutCoinType1, PutCoinType2>){
        
        config::assert_if_version_not_matched(config, VERSION);
        
        assert_if_take_liquidity_not_in_fund<TakeCoinType, FundCoinType>(fund);
        assert_if_take_nonliquidity_not_in_fund<TakeAsset, FundCoinType>(fund);
        assert_if_take_amount_not_enough<TakeCoinType, FundCoinType>(fund, amount);

        let total_balance = fund.asset.assets.borrow_mut<TypeName, Balance<TakeCoinType>>(type_name::get<Balance<TakeCoinType>>());
        let take_balance = total_balance.split(amount);
        let take_asset = fund.asset.assets.remove<TypeName, TakeAsset>(type_name::get<TakeAsset>());
        
        let take_request = Take_1_Liquidity_1_NonLiquidity_For_2_Liquidity_Request<TakeCoinType,TakeAsset, PutCoinType1, PutCoinType2>{
            take_amount1: take_balance.value(),
            take_amount2: 1,
            put_amount1: 0,
            put_amount2: 0,
        };

        (take_balance, take_asset, take_request)
    }

    public fun take_1_liquidity_1_nonliquidity_for_1_nonliquidity<TakeCoinType, TakeAsset: store, PutAsset: store, FundCoinType>(
        config: &GlobalConfig,
        fund: &mut Fund<FundCoinType>,
        amount: u64,
    ): (Balance<TakeCoinType>, TakeAsset, Take_1_Liquidity_1_NonLiquidity_For_1_NonLiquidity_Request<TakeCoinType, TakeAsset, PutAsset>){
        
        config::assert_if_version_not_matched(config, VERSION);
        
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
    ): (TakeAsset, Take_1_NonLiquidity_For_1_Liquidity_Request<TakeAsset, PutCoinType>){
        
        config::assert_if_version_not_matched(config, VERSION);
        
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
    ): (TakeAsset, Take_1_NonLiquidity_For_2_Liquidity_Request<TakeAsset, PutCoinType1, PutCoinType2>){
        
        config::assert_if_version_not_matched(config, VERSION);
        
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

    public fun put_1_liquidity_1_nonliquidity_for_1_liquidity<TakeCoinType, TakeAsset: store, PutCoinType, FundCoinType>(
        config: &GlobalConfig,
        fund: &mut Fund<FundCoinType>,
        request: Take_1_Liquidity_1_NonLiquidity_For_1_Liquidity_Request<TakeCoinType, TakeAsset, PutCoinType>,
        liquidity: Balance<PutCoinType>,
    ){

        config::assert_if_version_not_matched(config, VERSION);
        
        let Take_1_Liquidity_1_NonLiquidity_For_1_Liquidity_Request{
            take_amount1: _,
            take_amount2: _,
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

     public fun put_1_liquidity_1_nonliquidity_for_2_liquidity<TakeCoinType, TakeAsset: store, PutCoinType1, PutCoinType2, FundCoinType>(
        config: &GlobalConfig,
        fund: &mut Fund<FundCoinType>,
        request: Take_1_Liquidity_1_NonLiquidity_For_2_Liquidity_Request<TakeCoinType,TakeAsset, PutCoinType1, PutCoinType2>,
        liquidity1: Balance<PutCoinType1>,
        liquidity2: Balance<PutCoinType2>,
    ){
        
        config::assert_if_version_not_matched(config, VERSION);
        
        let Take_1_Liquidity_1_NonLiquidity_For_2_Liquidity_Request{
            take_amount1: _,
            take_amount2: _,
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
            fund.asset.assets.add(asset_type1, liquidity2);
        };
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
        fund.end_time
    }

    public(package) fun id <CoinType>(
        fund: &mut Fund<CoinType>
    ): &mut UID{
        &mut fund.id
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

}
