#[test_only]
#[allow(unused_use, unused_assignment, unused_variable)]
module flask::sbuck_tests {
    use sui::test_scenario::{Self as test, Scenario, next_tx, ctx};
    use sui::coin::{ Self, Coin, TreasuryCap, CoinMetadata, mint_for_testing as mint, burn_for_testing as burn};
    use sui::balance::{destroy_for_testing as destroy, create_for_testing as create};

    use flask::sbuck::{Self, Flask, SBUCK};
    use flask::mock_buck::{Self, MOCK_BUCK as BUCK};
    
    public fun dummy_address():address{
        @0x00000000000000000000000000000000
    }

    public fun assert_in_range(a: u64, b: u64, tolerance: u64){
        assert!(a >= b - tolerance && a <= b + tolerance, 404);
    }

    #[test, expected_failure(abort_code = flask::sbuck::ERR_FUNCTION_DEPRECATED)]
    public fun main_test(){
        let sender = dummy_address();
        let mut scenario = test::begin(sender);
        let s = &mut scenario;
    
        // deploy coin contract
        mock_buck::deploy_coin(ctx(s));

        // initialize
        setup<BUCK>(s);
        // deposit 
        test_sbuck_deposit<BUCK>(s);
        // withdraw
        test_withdraw_sbuck<BUCK>(s);
        // accured rewards
        test_sbuck_deposit<BUCK>(s);
        test_accrued_rewards<BUCK>(s);

        test::end(scenario);
    }

    #[test, expected_failure(abort_code = flask::sbuck::ERR_FUNCTION_DEPRECATED)]
    public fun test_deposit_zero_value(){
        let sender = dummy_address();
        let mut scenario = test::begin(sender);
        let s = &mut scenario;
    
        // deploy coin contract
        mock_buck::deploy_coin(ctx(s));

        setup<BUCK>(s);

        next_tx(s,sender);{
            // Deposit 50 BUCk in 1:1 ratio
            let mut flask = test::take_shared<Flask<BUCK>>(s);

            let deposit_buck = 0;

            let buck_bal = sbuck::deposit(&mut flask, mint<BUCK>(deposit_buck, ctx(s)));

            assert!(destroy(buck_bal) == deposit_buck, 404);
            assert!(sbuck::reserves(&flask) == deposit_buck, 404);
            assert!(sbuck::sbuck_supply(&flask) == deposit_buck, 404);

            test::return_shared(flask);
        };

        test::end(scenario);
    }

    // #[test, expected_failure(abort_code = flask::sbuck::ERR_ZERO_VALUE)]
    // public fun test_collect_rewards_zero_value(){
    //     let sender = dummy_address();
    //     let mut scenario = test::begin(sender);
    //     let s = &mut scenario;
    
    //     // deploy coin contract
    //     mock_buck::deploy_coin(ctx(s));

    //     setup<BUCK>(s);
    //     test_sbuck_deposit<BUCK>(s);

    //     next_tx(s,sender);{
    //         let mut flask = test::take_shared<Flask<BUCK>>(s);

    //         sbuck::collect_rewards(&mut flask, create<BUCK>(0));

    //         test::return_shared(flask);
    //     };

    //     test::end(scenario);
    // }

    #[test, expected_failure(abort_code = flask::sbuck::ERR_FUNCTION_DEPRECATED)]
    public fun test_withdraw_zero_value(){
        let sender = dummy_address();
        let mut scenario = test::begin(sender);
        let s = &mut scenario;
    
        // deploy coin contract
        mock_buck::deploy_coin(ctx(s));

        setup<BUCK>(s);
        test_sbuck_deposit<BUCK>(s);

        next_tx(s,sender);{
            let mut flask = test::take_shared<Flask<BUCK>>(s);

            let buck_balance = sbuck::withdraw(&mut flask, mint<SBUCK>(0, test::ctx(s)));
            destroy<BUCK>(buck_balance);

            test::return_shared(flask);
        };

        test::end(scenario);
    }

    #[test, expected_failure(abort_code = flask::sbuck::ERR_FUNCTION_DEPRECATED)]
    public fun test_insufficient_deposit(){
        let sender = dummy_address();
        let mut scenario = test::begin(sender);
        let s = &mut scenario;
    
        // deploy coin contract
        mock_buck::deploy_coin(ctx(s));

        setup<BUCK>(s);
        test_sbuck_deposit<BUCK>(s);

        // topup
        next_tx(s,sender);{
            let mut flask = test::take_shared<Flask<BUCK>>(s);
            let rewards = 10_000_000_000;
            sbuck::collect_rewards(&mut flask, create<BUCK>(rewards));

            test::return_shared(flask);
        };

        next_tx(s,sender);{
            let mut flask = test::take_shared<Flask<BUCK>>(s);

            let buck_bal = sbuck::deposit(&mut flask, mint<BUCK>(1, ctx(s)));

            destroy(buck_bal); 

            test::return_shared(flask);
        };

        test::end(scenario);
    }

    public fun setup<T>(s: &mut Scenario){
        let sender = dummy_address();

        // init functions
        sbuck::init_for_testing(ctx(s));

        // initialize
        next_tx(s, sender);{
            let cap = test::take_from_sender<TreasuryCap<SBUCK>>(s);
            sbuck::initialize<T>(cap, ctx(s));
        };

        next_tx(s, sender);{
            let flask = test::take_shared<Flask<T>>(s);
            assert!(sbuck::reserves(&flask) == 0 ,404);
            assert!(sbuck::sbuck_supply(&flask) == 0 ,404);

            test::return_shared(flask);
        };
    }

    public fun test_sbuck_deposit<T>(s: &mut Scenario){
        let sender = dummy_address();
        
        next_tx(s,sender);{
            // Deposit 50 BUCk in 1:1 ratio
            let mut flask = test::take_shared<Flask<T>>(s);
            let deposit_buck = 50_000_000_000;

            let buck_bal = sbuck::deposit(&mut flask, mint<T>(deposit_buck, ctx(s)));

            assert!(destroy(buck_bal) == deposit_buck, 404);
            assert!(sbuck::reserves(&flask) == deposit_buck, 404);
            assert!(sbuck::sbuck_supply(&flask) == deposit_buck, 404);

            test::return_shared(flask);
        };
        
        next_tx(s,sender);{
            // Deposit additional 50 BUCK in 1:1 ratio
            let mut flask = test::take_shared<Flask<T>>(s);
            let deposit_buck = 50_000_000_000;

            let buck_bal = sbuck::deposit(&mut flask, mint<T>(deposit_buck, ctx(s)));

            assert!(destroy(buck_bal) == deposit_buck, 404);
            assert!(sbuck::reserves(&flask) == 2 * deposit_buck, 404);
            assert!(sbuck::sbuck_supply(&flask) == 2 * deposit_buck, 404);

            test::return_shared(flask);
        };
    }

    public fun test_withdraw_sbuck<T>(s: &mut Scenario){
        let sender = dummy_address();

        // topup
        let rewards = 10_000_000_000;
        next_tx(s,sender);{
            let mut flask = test::take_shared<Flask<T>>(s);

            sbuck::collect_rewards(&mut flask, create<T>(rewards));

            assert!(sbuck::reserves(&flask) == 110_000_000_000, 404);
            assert!(sbuck::sbuck_supply(&flask) == 100_000_000_000, 404);
            
            // check claimable
            assert!(sbuck::claimable(&flask, 50_000_000_000) == 55_000_000_000, 404);

            test::return_shared(flask);
        };

        next_tx(s,sender);{
            let mut flask = test::take_shared<Flask<T>>(s);
            let shares = 50_000_000_000;

            let buck = sbuck::withdraw(&mut flask, mint<SBUCK>(shares, ctx(s)));
            assert!(destroy(buck) == 55_000_000_000, 404);
            assert!(sbuck::reserves(&flask) == 55_000_000_000, 404);
            assert!(sbuck::sbuck_supply(&flask) == 50_000_000_000, 404);
            
            test::return_shared(flask);
        };

        next_tx(s,sender);{
            let mut flask = test::take_shared<Flask<T>>(s);
            let shares = 50_000_000_000;

            let buck = sbuck::withdraw(&mut flask, mint<SBUCK>(shares, ctx(s)));
            assert!(destroy(buck) == 55_000_000_000, 404);
            assert!(sbuck::reserves(&flask) == 0, 404);
            assert!(sbuck::sbuck_supply(&flask) == 0, 404);
            
            test::return_shared(flask);
        };
    }

    public fun test_accrued_rewards<T>(s: &mut Scenario){
        let sender = dummy_address();
        
        let rewards = 10_000_000_000;
        next_tx(s,sender);{
            let mut flask = test::take_shared<Flask<T>>(s);

            sbuck::collect_rewards(&mut flask, create<T>(rewards));

            assert!(sbuck::reserves(&flask) == 110_000_000_000, 404);
            assert!(sbuck::sbuck_supply(&flask) == 100_000_000_000, 404);
            
            // check claimable
            assert!(sbuck::claimable(&flask, 50_000_000_000) == 55_000_000_000, 404);

            test::return_shared(flask);
        };

        next_tx(s,sender);{
            let mut flask = test::take_shared<Flask<T>>(s);
            let deposit_buck = 50_000_000_000;

            let sbuck = sbuck::deposit<T>(&mut flask, mint<T>(deposit_buck, ctx(s)));
            let sbuck_val = destroy(sbuck);
            assert!(sbuck_val == 45_454545454, 404);
            assert_in_range(deposit_buck, sbuck::claimable(&flask, sbuck_val), 1);
            assert!(sbuck::reserves(&flask) == 160_000_000_000, 404);
            assert!(sbuck::sbuck_supply(&flask) == 145_454545454, 404);
            
            test::return_shared(flask);
        };

        // topup additional rewards; every SBUCK accrue 1 BUCK
        let rewards = 145_454545454;
        next_tx(s,sender);{
            let mut flask = test::take_shared<Flask<T>>(s);

            sbuck::collect_rewards(&mut flask, create<T>(rewards));

            // reserves in Flask
            assert!(sbuck::reserves(&flask) == 305_454_545_454, 404);
            assert!(sbuck::sbuck_supply(&flask) == 145_454545454, 404);

            // claimable
            let deposit_buck = 50_000_000_000;
            let initial_holder_rewards = 5_000_000_000 + deposit_buck;
            assert!(sbuck::claimable(&flask, 50_000_000_000) == deposit_buck + initial_holder_rewards, 404);

            let subsequent_holder_rewards = 45_454545454;
            assert_in_range(deposit_buck + subsequent_holder_rewards,sbuck::claimable(&flask, 45_454545454), 1);

            test::return_shared(flask);
        };

        // claim all sBUCk
        next_tx(s,sender);{
            let mut flask = test::take_shared<Flask<T>>(s);
            
            // first initial holder
            let holder_deposit = 50_000_000_000;
            let initial_holder_sbuck = 50_000_000_000;
            let total_accrued = 5_000_000_000 + 50_000_000_000;
            let buck = sbuck::withdraw(&mut flask, mint<SBUCK>(initial_holder_sbuck, ctx(s)));
            assert!(destroy(buck) == holder_deposit + total_accrued, 404);
            assert!(sbuck::reserves(&flask) == 200_454_545_454, 404);
            assert!(sbuck::sbuck_supply(&flask) == 95_454_545_454, 404);

            // second initial holder
            let buck = sbuck::withdraw(&mut flask, mint<SBUCK>(initial_holder_sbuck, ctx(s)));
            assert!(destroy(buck) == holder_deposit + total_accrued, 404);
            assert!(sbuck::reserves(&flask) == 95_454_545_454, 404);
            assert!(sbuck::sbuck_supply(&flask) == 45_454_545_454, 404);

            // last holder
            let last_holder_sbuck = 45_454_545_454;
            let total_accrued = 45_454_545_454;
            let buck = sbuck::withdraw(&mut flask, mint<SBUCK>(last_holder_sbuck, ctx(s)));
            assert!(destroy(buck) == initial_holder_sbuck + total_accrued, 404);
            assert!(sbuck::reserves(&flask) == 0, 404);
            assert!(sbuck::sbuck_supply(&flask) == 0, 404);

            test::return_shared(flask);
        };

    }
}
