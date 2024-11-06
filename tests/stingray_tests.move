#[test_only]
module stingray::stingray_tests{
    use stingray::trader::{HostController,Trader, Self};
    use stingray::config::{GlobalConfig, AdminCap, Self};
    use stingray::fund::{Self, Fund};
    use stingray::arena::{Self, Arena};
    use sui::coin::{Self, Coin};
    use sui::sui::{SUI};
    use sui::clock::{Self, Clock};
    use std::string::{Self, String};

    const ADMIN: address = @0xFFF;
    const USER1: address = @0x111;
    const ARENA_START: u64 = 1700000000000;
    const ATTEND_DURATION:u64 = 14400000;
    const INVEST_DURATION:u64 = 14400000;
    const ARENA_END: u64 = 1700604800000;


use sui::test_scenario::{Scenario, begin, end, ctx, next_tx, take_shared, return_shared, take_from_sender, return_to_sender, sender };

    fun scenario(): Scenario{
        let mut scenario = begin(ADMIN);
        trader::test_init(ctx( &mut scenario));
        next_tx(&mut scenario, ADMIN);
        arena::test_init(ctx( &mut scenario));
        next_tx(&mut scenario, ADMIN);
        config::test_init(ctx( &mut scenario));
        next_tx(&mut scenario, USER1);
        scenario
    }

    fun mint_trader(): Scenario {
        let mut scenario = scenario();
        let config = take_shared<GlobalConfig>(&scenario);
        let host_controller = take_shared<HostController>(&scenario);
        let mint_coin = coin::mint_for_testing<SUI>(10000000, ctx(&mut scenario));
        let clock = clock::create_for_testing(ctx(&mut scenario));
        clock::set_for_testing(&mut clock, ARENA_START);
        trader::mint(&mut config, &mut host_controller, string::utf8(b"123"), string::utf8(b"123"), mint_coin, &clock, ctx(&mut scenario));

        return_shared<GlobalConfig>(config);
        return_shared<HostController>(host_controller);
        coin::burn_for_testing<SUI>(mint_coin);
        clock::destroy_for_testing(clock);

        scenario
    }

    fun create_arena(): Scenario{

        let mut scenario = mint_trader();
        next_tx(&mut scenario, ADMIN);
        let config = take_shared<GlobalConfig>(&scenario);
        let admin_cap = take_from_sender<AdminCap>(&scenario);
        let clock = clock::create_for_testing(ctx(&mut scenario));
        clock.set_for_testing(ARENA_START);
        arena::new_arena<SUI>(&mut config, &admin_cap, 0, ARENA_START, ATTEND_DURATION, INVEST_DURATION, &clock, ctx(&mut scenario));

        return_shared<GlobalConfig>(config);
        clock::destroy_for_testing(clock);
        return_to_sender(&scenario, admin_cap);

        scenario
    }

    fun create_fund_and_attend_arena(): Scenario{
        let mut scenario = create_arena();
        next_tx(&mut scenario, USER1);
        let config = take_shared<GlobalConfig>(&scenario);
        let description = string::utf8(b"1234");
        let trader = take_from_sender<Trader>(&scenario);
        let is_arena = true;
        let start_time = ARENA_START + 200000;
        let invest_duartion = INVEST_DURATION;
        let end_time = ARENA_END;

        let clock = clock::create_for_testing(ctx(&mut scenario));
        clock.set_for_testing(ARENA_START);

        let arena = take_shared<Arena<SUI>>(&scenario);

        let create_coin = coin::mint_for_testing<SUI>(200000000, ctx(&mut scenario));
        let fund = fund::create<SUI>(&config, description, &trader, 2000, is_arena, start_time, invest_duartion, end_time, create_coin, ctx(&mut scenario));
        
        let hot_potato = arena::create_arena_request(0);
        
        arena::attend<SUI>(&config, hot_potato, &mut arena, &mut fund, &trader, &clock);

        fund.to_share_object<SUI>();

        return_shared<GlobalConfig>(config);
        return_shared<Arena<SUI>>(arena);
        clock::destroy_for_testing(clock);

        scenario
    }

    #[test]
    fun test_set_up(){
        let scenario = create_fund_and_attend_arena();
        end(scenario);
    }



}