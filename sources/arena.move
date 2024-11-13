module stingray::arena{

    use std::{
        type_name::{Self, TypeName},
        string::{String},
    };

    use sui::{
        balance::{Balance},
        table::{Self, Table,},
        clock:: {Clock},
        dynamic_field as df,
        event::{Self,},
        coin::{Self, Coin},
    };

    use stingray::{
        config::{Self, AdminCap, GlobalConfig},
        fund::{Fund},
        trader::{Trader},
    };

    const VERSION: u64 = 1;
    
    const WEEK: u8 = 0;
    const MONTH: u8 = 1;
    const SEASON:u8 = 2;
    const YEAR: u8 = 4;

    const FIRST_PLACE: u64 = 5000;
    const SECOND_PLACE: u64 = 3000;
    const THIRD_PLACE: u64 = 2000;


    const ETraderAlreadyAttended: u64 = 0;
    const ETypeNotMatched: u64 = 1;
    const EArenaTypeNotAllowed: u64 = 2;
    const ENotArriveAttendTime: u64 = 3;
    const ETraderNotMatched: u64 = 4;
    const EPreviousFund: u64 = 5;
    const ETraderNotAttended: u64 = 6;
    const EAttendTimeExpired: u64 = 7;
    const EAlreadyAttendAnotherArena: u64 = 8;
    const EArenaTypeNotDefined: u64 = 9;
    const EOverEndTime: u64 = 10;
    const EHostNotForThisArena: u64 = 11;
    const EAlreadyClaimed: u64 = 12;

    const BASE: u128 = 1_000_000_000;
    const RANK_AMOUNT: u64 = 3;

    public struct ArenaRequest<phantom CoinType>{
        arena_type: u8,
    }

    public struct BonusHost<phantom CoinType> has key {
        id: UID,
        arena: ID,
        bonus: Balance<CoinType>,
        is_claimed: Table<ID, bool>,
    }

    public struct Result has store{
        trader: ID,
        result: u128,
    }

    public struct Arena<phantom CoinType> has key {
        id: UID,
        arena_type: u8,
        start_time: u64,
        attend_duration: u64,
        invest_duration: u64,
        end_time: u64,
        funds: Table<ID, ID>, // trader -> fund
        traders: vector<ID>,
        result: Table<u64, Result>,
        is_rank_claimed: Table<ID, bool>,
    }

    public struct Certificate has store {
        arena: ID,
        arena_type: u8,
        end_time: u64, 
        rank: u64,
        is_matched: bool,
    }

    public struct NewArena<phantom CoinType> has copy, drop{
        id: ID,
        arena_type: u8,
        start_time: u64,
        attend_duration: u64,
        invest_duration: u64,
        end_time: u64,
    } 

    public struct Attended<phantom CoinType> has copy, drop{
        arena: ID,
        fund: ID,
        name: String,
        description: String, 
        fund_img: String,
        trader: ID,
        trader_fee: u64,
        start_time: u64,
        invest_duration: u64,
        end_time: u64,
    } 
    
    public struct Challenge has copy , drop{
        fund_id: ID,
        is_success: bool,
    }

    public struct ClaimRank has copy, drop{
        trader: ID,
        arena: ID,
        fund: ID,
        rank: u64,
    }

    public entry fun new_arena <CoinType>(
        config: &GlobalConfig,
        cap: &AdminCap,
        arena_type: u8,
        start_time: u64,
        attend_duration: u64,
        invest_duration: u64,
        init_bouns: Coin<CoinType>,
        ctx: &mut TxContext
    ){
        let arena = create_arena<CoinType>(
            config,
            cap,
            arena_type,
            start_time,
            attend_duration,
            invest_duration,
            ctx,
        );
        
        event::emit(
            NewArena<CoinType>{
                id: *arena.id.as_inner(),
                arena_type: arena.arena_type,
                start_time: arena.start_time,
                attend_duration: arena.attend_duration,
                invest_duration: arena.invest_duration,
                end_time: arena.end_time,
            },
        );

        let host = BonusHost<CoinType> {
            id: object::new(ctx),
            arena: *arena.id.as_inner(),
            bonus: init_bouns.into_balance(),
            is_claimed: table::new<ID, bool>(ctx),
        };

        transfer::share_object(host);
        transfer::share_object(arena);
        
    }

    public entry fun sponsor_bonus<CoinType>(
        host: &mut BonusHost<CoinType>,
        sponsor_bonus: Coin<CoinType>,
    ){
        host.bonus.join(sponsor_bonus.into_balance<CoinType>());
    }

    public fun create_arena_request<CoinType>(
        arena_type: u8,
    ): ArenaRequest<CoinType>{
        assert_if_arena_type_not_supported(arena_type);
        ArenaRequest<CoinType> { arena_type, }
    }

    public fun create_arena <CoinType> (
        config: &GlobalConfig,
        _: &AdminCap,
        arena_type: u8,
        start_time: u64,
        attend_duration: u64,
        invest_duration: u64,
        ctx: &mut TxContext
    ): Arena<CoinType> {

        config::assert_if_version_not_matched(config, VERSION);
        assert_if_arena_type_not_allowed(arena_type);
        //assert_if_over_current_time(start_time, clock);

        let result = table::new<u64, Result>(ctx);

        if (arena_type == WEEK){
            Arena{
                id: object::new(ctx),
                arena_type,
                start_time,
                attend_duration,
                invest_duration,
                end_time: start_time + attend_duration + invest_duration + (86400000 * 7),
                funds: table::new<ID, ID>(ctx),
                traders: vector::empty<ID>(),
                result,
                is_rank_claimed: table::new<ID,bool>(ctx)
            }
        }else if (arena_type == MONTH){ 
            Arena{
                id: object::new(ctx),
                arena_type,
                start_time,
                attend_duration,
                invest_duration,
                end_time: start_time + attend_duration + invest_duration + (86400000 * 30),
                funds: table::new<ID, ID>(ctx),
                traders: vector::empty<ID>(),
                result,
                is_rank_claimed: table::new<ID,bool>(ctx)
            }
        }else if (arena_type == SEASON){
            Arena{
                id: object::new(ctx),
                arena_type,
                start_time,
                attend_duration,
                invest_duration,
                end_time: start_time + attend_duration + invest_duration + (86400000 * 90),
                funds: table::new<ID, ID>(ctx),
                traders: vector::empty<ID>(),
                result,
                is_rank_claimed: table::new<ID,bool>(ctx)
            }
        } else{ // YEAR
            Arena{
                id: object::new(ctx),
                arena_type,
                start_time,
                attend_duration,
                invest_duration,
                end_time: start_time + attend_duration + invest_duration + (86400000 * 365),
                funds: table::new<ID, ID>(ctx),
                traders: vector::empty<ID>(),
                result,
                is_rank_claimed: table::new<ID,bool>(ctx)
            }
        } 
    }

    public fun attend<CoinType>(
        config: &GlobalConfig,
        request: ArenaRequest<CoinType>,
        arena: &mut Arena<CoinType>,
        fund: &mut Fund<CoinType>,
        trader: &Trader,
        clock: &Clock,
    ){
        config::assert_if_version_not_matched(config, VERSION);
        assert_if_already_attend_other_arena(fund);

        assert_if_trader_already_attend(arena, fund);
        assert_if_not_arrive_attend_time(arena,clock); 
        assert_if_fund_is_previous(fund, arena);
        let request_type = request.arena_type;
        assert_if_fund_type_not_matched(arena, request_type);
        assert_if_fund_trader_not_matched<CoinType>(fund, trader);
        // consume hot potato
        let ArenaRequest { 
            arena_type: _,
        } = request;

        // add fund to arena
        arena.funds.add(fund.trader(), *fund.id().as_inner());
        let certificate = create_certificate(arena);

        df::add(fund.id(), type_name::get<Certificate>(), certificate);

        // update fund
        fund.update_time(arena.start_time + arena.attend_duration, arena.invest_duration, arena.end_time);
        fund.set_is_arena(true);
        arena.traders.push_back(trader.id());
        
        event::emit(
            Attended<CoinType>{
                arena: *arena.id.as_inner(),
                fund: *fund.id().as_inner(),
                name: fund.name(),
                description: fund.description(), 
                fund_img: fund.fund_img(),
                trader: fund.trader(),
                trader_fee: fund.trader_fee(),
                start_time: fund.start_time(),
                invest_duration: fund.invest_duration(),
                end_time: fund.invest_duration(),
            },
        ); 
    }

    public fun challenge<CoinType>(
        arena: &mut Arena<CoinType>,
        fund: &mut Fund<CoinType>,
        trader: &Trader,
        clock: &Clock,
    ){
        assert_if_fund_trader_not_matched(fund, trader);
        assert_if_trader_not_attended_arena(arena, trader);
        assert_if_over_end_time<CoinType>(arena, clock);

        let mut result = 0;

        let mut is_replace = false;
        
        if (fund.after_amount() > fund.base()){
            result = ((fund.after_amount() - fund.base()) as u128) * BASE / (fund.base() as u128);
        };

        if (result > 0){
            
            let mut current_idx = 0;
            let mut key =  trader.id();
            let mut value = result;

            while(current_idx < RANK_AMOUNT){
                if (!arena.result.contains(current_idx)){
                    arena.result.add(current_idx, 
                        Result{
                            trader: trader.id(),
                            result: result,
                        });
                };
                let recorded_win = arena.result.remove(current_idx);
                if (recorded_win.result < value){
                    arena.result.add(current_idx, Result{
                        trader: key,
                        result: value,
                    });
                    is_replace = true;
                    key = recorded_win.trader;
                    value = recorded_win.result;
                }else{
                    arena.result.add(current_idx, Result{
                        trader: recorded_win.trader,
                        result: recorded_win.result,
                    });
                };
                current_idx = current_idx + 1;

                let Result{
                    trader: _,
                    result: _,
                } = recorded_win;
            }
            
        };

        event::emit(Challenge{
                fund_id: *fund.id().as_inner(),
                is_success: is_replace,
        });
    }

    public fun claim_rank<CoinType>(
        config: &GlobalConfig,
        host: &mut BonusHost<CoinType>,
        arena: &mut Arena<CoinType>,
        fund: &mut Fund<CoinType>,
        trader: &mut Trader,
        ctx: &mut TxContext,
    ): Coin<CoinType>{
        assert_if_host_not_for_this_arena(host, arena);
        assert_if_fund_trader_not_matched(fund, trader);
        assert_if_trader_not_attended_arena(arena, trader);
        assert_if_already_claimed(host, trader);

        let first = arena.result.borrow(0);
        let second = arena.result.borrow(1);
        let third = arena.result.borrow(2);

        let certificate = df::borrow_mut<ID, Certificate>(&mut arena.id, *fund.id().as_inner());
        let mut rank = 0;
        let mut receive_value: u64 = 0;
        if (trader.id() == first.trader){
            certificate.rank = 1;
            rank = 1;
            receive_value = host.bonus.value() * FIRST_PLACE / config.base_percentage();
        }else if (trader.id() == second.trader){
            certificate.rank = 2;
            rank = 2;
            receive_value = host.bonus.value() * SECOND_PLACE / config.base_percentage();
        }else if (trader.id() == third.trader){
            certificate.rank = 3;
            rank = 3;
            receive_value = host.bonus.value() * THIRD_PLACE / config.base_percentage();
        };
        
        host.is_claimed.add(trader.id(), true);
        event::emit(
            ClaimRank{
                trader: trader.id(),
                fund: *fund.id().as_inner(),
                arena: *arena.id.as_inner(),
                rank,
            }
        );

        coin::from_balance(host.bonus.split(receive_value), ctx)
    }

    fun create_certificate<CoinType>(
        arena: &Arena<CoinType>
    ): Certificate{
        Certificate{
            arena: *arena.id.as_inner(),
            arena_type: arena.arena_type,
            end_time: arena.end_time,
            rank: 0,
            is_matched: false,
        }
    }   

    fun assert_if_trader_already_attend<CoinType>(
        arena: &Arena<CoinType>,
        fund: &Fund<CoinType>,
    ){
        assert!(!arena.funds.contains(fund.trader()), ETraderAlreadyAttended);
    }

    fun assert_if_fund_type_not_matched<CoinType>(
        arena: &Arena<CoinType>,
        request_type: u8,
    ){
        assert!(arena.arena_type == request_type, ETypeNotMatched);
    }

    fun assert_if_arena_type_not_allowed(
        arena_type: u8,
    ){
        assert!(arena_type == WEEK || arena_type == MONTH, EArenaTypeNotAllowed);
    }

    fun assert_if_not_arrive_attend_time<ArenaCoinType>(
        arena: &Arena<ArenaCoinType>,
        clock: &Clock,
    ){
        assert!(clock.timestamp_ms() >= arena.start_time, ENotArriveAttendTime);
        assert!(clock.timestamp_ms() <= (arena.start_time + arena.attend_duration), EAttendTimeExpired);
    }

    fun assert_if_fund_trader_not_matched<FundCoinType>(
        fund: &Fund<FundCoinType>,
        trader: &Trader,
    ){
        assert!(fund.trader() == trader.id(), ETraderNotMatched);
    }

    fun assert_if_fund_is_previous<FundCoinType>(
        fund: &Fund<FundCoinType>,
        arena: &Arena<FundCoinType>,
    ){
        assert!(fund.start_time() >= arena.start_time, EPreviousFund);
    }

    fun assert_if_trader_not_attended_arena<FundCoinType>(   
        arena: &Arena<FundCoinType>,
        trader: &Trader,
    ){
        assert!(arena.funds.contains(trader.id()), ETraderNotAttended );
    }

    fun assert_if_already_attend_other_arena<FundCoinType>(
        fund: &mut Fund<FundCoinType>,
    ){
        let certificate_type = type_name::get<Certificate>();
        assert!(!df::exists_<TypeName>(fund.id(), certificate_type), EAlreadyAttendAnotherArena);
    }

    fun assert_if_arena_type_not_supported(
        arena_type: u8,
    ){
        assert!(arena_type == WEEK || arena_type == MONTH || arena_type == SEASON || arena_type == YEAR, EArenaTypeNotDefined);
    }

    fun assert_if_over_end_time<ArenaType>(
        arena: &Arena<ArenaType>,
        clock: &Clock,
    ){  
        assert!(clock.timestamp_ms() <= arena.end_time, EOverEndTime);
    }

    fun assert_if_host_not_for_this_arena<CoinType>(
        host: & BonusHost<CoinType>,
        arena: & Arena<CoinType>,
    ){
        assert!(host.arena == *arena.id.as_inner(), EHostNotForThisArena);
    }

    fun assert_if_already_claimed<CoinType>(
        host: & BonusHost<CoinType>,
        trader: &Trader,
    ){
        assert!(!host.is_claimed.contains(trader.id()), EAlreadyClaimed);
    }

}