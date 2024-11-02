module stingray::arena{


    use std::type_name::{Self};

    use sui::{
        sui::{SUI},
        balance::{Self, Balance},
        table::{Self, Table,},
        clock:: {Clock},
        dynamic_field as df,
    };

    use stingray::{
        config::{Self, AdminCap, GlobalConfig},
        fund::{Fund},
        trader::{Trader},
    };

    const VERSION: u64 = 1;
    
    const WEEK: u8 = 0;
    const MONTH: u8 = 1;

    const ETraderAlreadyAttended: u64 = 0;
    const ETypeNotMatched: u64 = 1;
    const EArenaTypeNotAllowed: u64 = 2;
    const EStartTimeOverCurrentTime: u64 = 3;
    const EEndTimeNotMatched: u64 = 4;
    const ENotArriveAttendTime: u64 = 5;
    const ETraderNotMatched: u64 = 6;

    public struct ArenaRequest<phantom CoinType>{
        arena_type: u8,
    }

    public struct ArenaHost<phantom CoinType> has key {
        id: UID,
        balance: Balance<CoinType>,
        current_week_round: u64,
        current_month_round: u64,
    }

    public struct Arena<phantom CoinType> has key {
        id: UID,
        arena_type: u8,
        start_time: u64,
        attend_duration: u64,
        invest_duration: u64,
        end_time: u64,
        funds: Table<ID, ID>, // trader -> fund
        traders: vector<address>,
    }

    public struct Certificate has store {
        arena: ID,
        arena_type: u8,
        end_time: u64, 
        rank: u64,
    }

    fun init (ctx: &mut TxContext){
        let host = ArenaHost<SUI> {
            id: object::new(ctx),
            balance:  balance::zero<SUI>(),
            current_week_round: 0,
            current_month_round: 0,
        };

        transfer::share_object(host);
    }

    public entry fun new_arena <CoinType>(
        config: &GlobalConfig,
        cap: &AdminCap,
        arena_type: u8,
        start_time: u64,
        attend_duration: u64,
        invest_duration: u64,
        clock: &Clock,
        ctx: &mut TxContext
    ){
        let arena = create_arena<CoinType>(
            config,
            cap,
            arena_type,
            start_time,
            attend_duration,
            invest_duration,
            clock,
            ctx,
        );
        
        transfer::share_object(arena);
    }

    public fun create_arena_request<CoinType>(
        arena_type: u8,
    ): ArenaRequest<CoinType>{
        ArenaRequest<CoinType> { arena_type, }
    }

    public fun create_arena <CoinType> (
        config: &GlobalConfig,
        _: &AdminCap,
        arena_type: u8,
        start_time: u64,
        attend_duration: u64,
        invest_duration: u64,
        clock: &Clock,
        ctx: &mut TxContext
    ): Arena<CoinType> {

        config::assert_if_version_not_matched(config, VERSION);
        assert_if_arena_type_not_allowed(arena_type);
        assert_if_over_current_time(start_time, clock);

        if (arena_type == WEEK){
            Arena{
                id: object::new(ctx),
                arena_type,
                start_time,
                attend_duration,
                invest_duration,
                end_time: start_time + (86400000 * 7),
                funds: table::new<ID, ID>(ctx),
                traders: vector::empty<address>(),
            }
        }else{ // MONTH
            Arena{
                id: object::new(ctx),
                arena_type,
                start_time,
                attend_duration,
                invest_duration,
                end_time: start_time + (86400000 * 30),
                funds: table::new<ID, ID>(ctx),
                traders: vector::empty<address>(),
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
        assert_if_trader_already_attend(arena, fund);
        assert_if_not_arrive_attend_time(arena,clock); 
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
        fund.update_time(arena.start_time + arena.attend_duration, arena.start_time + arena.attend_duration + arena.invest_duration, arena.end_time);
        fund.set_is_arena(true);
        
    }


    fun create_certificate<CoinType>(
        arena: &Arena<CoinType>
    ): Certificate{
        Certificate{
            arena: *arena.id.as_inner(),
            arena_type: arena.arena_type,
            end_time: arena.end_time,
            rank: 0,
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

    fun assert_if_over_current_time(
        start_time: u64,
        clock: &Clock,
    ){
        assert!(start_time >= clock.timestamp_ms(), EStartTimeOverCurrentTime);
    }

    // fun assert_if_not_arrived_end_time<CoinType>(
    //     arena: &Arena<CoinType>,
    //     clock: &Clock,
    // ){
    //     assert!(arena.end_time <= clock.timestamp_ms(), ENotArrivedEndTime);
    // }


    fun assert_if_not_arrive_attend_time<ArenaCoinType>(
        arena: &Arena<ArenaCoinType>,
        clock: &Clock,
    ){
        assert!((clock.timestamp_ms() <= (arena.start_time + arena.attend_duration)) &&
                (clock.timestamp_ms() >= arena.start_time), ENotArriveAttendTime);
    }

    fun assert_if_fund_trader_not_matched<FundCoinType>(
        fund: &Fund<FundCoinType>,
        trader: &Trader,
    ){
        assert!(fund.trader() == trader.id(), ETraderNotMatched);
    }

    
}