module bucket_framework::vesting_lock {

    use sui::object::{Self, UID};
    use sui::balance::{Self, Balance};
    use sui::coin::{Self, Coin};
    use sui::clock::{Self, Clock};
    use sui::transfer;
    use sui::tx_context::TxContext;
    
    use bucket_framework::math::mul_factor;

    const EZeroReleasableAmount: u64 = 0;
    const ECannotDestroyNonEmptyLock: u64 = 1;
    const EInvalidStartTime: u64 = 2;
    const EDurationCannotBeZero: u64 = 3;
    const ECannotSplitAfterVesting: u64 = 4;
    const ENotEnoughToSplit: u64 = 5;

    struct VestingLock<phantom T> has key, store {
        id: UID,
        vault: Balance<T>,
        // settings
        start_time: u64,
        duration: u64,
        // recording
        released_amount: u64,
    }

    public fun new<T>(input: Balance<T>, clock: &Clock, start_time: u64, duration: u64, ctx: &mut TxContext): VestingLock<T> {
        assert!(start_time >= clock::timestamp_ms(clock), EInvalidStartTime);
        assert!(duration > 0, EDurationCannotBeZero);
        VestingLock {
            id: object::new(ctx),
            vault: input,
            start_time,
            duration,
            released_amount: 0,
        }
    }

    public entry fun create<T>(
        input: Coin<T>,
        clock: &Clock,
        start_time: u64,
        duration: u64,
        receipient: address,
        ctx: &mut TxContext
    ) {
        let vesting_lock = new(coin::into_balance(input), clock, start_time, duration, ctx);
        transfer::transfer(vesting_lock, receipient);
    }

    public fun release<T>(lock: &mut VestingLock<T>, clock: &Clock): Balance<T> {
        let amount = releasable_amount(lock, clock);
        assert!(amount > 0, EZeroReleasableAmount);
        lock.released_amount = lock.released_amount + amount;
        balance::split(&mut lock.vault, amount)
    }

    public entry fun release_to<T>(lock: &mut VestingLock<T>, clock: &Clock, receipient: address, ctx: &mut TxContext) {
        let output = release(lock, clock);
        transfer::public_transfer(coin::from_balance(output, ctx), receipient);
    }

    public entry fun destroy_empty<T>(lock: VestingLock<T>) {
        let VestingLock { id, vault, released_amount: _, start_time: _, duration: _ } = lock;
        assert!(balance::value(&vault) == 0, ECannotDestroyNonEmptyLock);
        object::delete(id);
        balance::destroy_zero(vault);
    }

    public fun duration<T>(lock: &VestingLock<T>): u64 {
        lock.duration
    }

    public fun start_time<T>(lock: &VestingLock<T>): u64 {
        lock.start_time
    }

    public fun released_amount<T>(lock: &VestingLock<T>): u64 {
        lock.released_amount
    }

    public fun compute_vested_amount<T>(lock: &VestingLock<T>, timestamp_ms: u64): u64 {
        let total_balance = balance::value(&lock.vault) + lock.released_amount;
        if (timestamp_ms < lock.start_time) {
            0
        } else if (timestamp_ms > lock.start_time + lock.duration) {
            total_balance
        } else {
            mul_factor(total_balance, timestamp_ms - lock.start_time, lock.duration)
        }
    }

    public fun releasable_amount<T>(lock: &VestingLock<T>, clock: &Clock): u64 {
        compute_vested_amount(lock, clock::timestamp_ms(clock)) - released_amount(lock)    
    }

    public fun split<T>(lock: &mut VestingLock<T>, clock: &Clock, amount: u64, ctx: &mut TxContext): VestingLock<T> {
        assert!(clock::timestamp_ms(clock) < lock.start_time, ECannotSplitAfterVesting);
        let lock_balance = balance::value(&lock.vault);
        assert!(lock_balance >= amount, ENotEnoughToSplit);
        let splitted_balance = balance::split(&mut lock.vault, amount);
        VestingLock {
            id: object::new(ctx),
            vault: splitted_balance,
            start_time: lock.start_time,
            duration: lock.duration,
            released_amount: lock.released_amount,
        }
    }

    public entry fun split_to<T>(
        lock: &mut VestingLock<T>,
        clock: &Clock,
        amount: u64,
        to: address,
        ctx: &mut TxContext
    ) {
        let splitted_lock = split(lock, clock, amount, ctx);
        transfer::transfer(splitted_lock, to);
    }

    #[test_only]
    public fun destroy_for_testing<T>(lock: VestingLock<T>) {
        let VestingLock { id, vault, released_amount: _, start_time: _, duration: _ } = lock;
        object::delete(id);
        balance::destroy_for_testing(vault);
    }

    #[test_only]
    use sui::test_scenario::{Self as ts, Scenario};

    #[test_only]
    public fun setup<T>(user: address, input_amount: u64, start_time_after: u64, duration: u64): (Clock, Scenario) {
        let scenario_val = ts::begin(user);
        let scenario = &mut scenario_val;
        let clock = clock::create_for_testing(ts::ctx(scenario));
        
        let current_time = 1683818680162;
        clock::set_for_testing(&mut clock, current_time);

        ts::next_tx(scenario, user);
        {
            let input = balance::create_for_testing<T>(input_amount);
            let lock = new(input, &clock, current_time + start_time_after, duration, ts::ctx(scenario));
            transfer::public_transfer(lock, user);
        };

        ts::next_tx(scenario, user);
        {
            let lock = ts::take_from_sender<VestingLock<T>>(scenario);
            assert!(start_time(&lock) == current_time + start_time_after, 0);
            assert!(duration(&lock) == duration, 0);
            assert!(released_amount(&lock) == 0, 0);
            ts::return_to_sender(scenario, lock);
        };

        (clock, scenario_val)
    }

    #[test_only]
    fun days_to_ms(days: u64): u64 { days * 86400000 }

    #[test]
    fun test_vesting() {
        use sui::sui::SUI;
        let user_1 = @0x101;
        let user_2 = @0x201;
        let user_3 = @0x301;
        let input_amount = 36884800000000000;
        // let input_amount = 720;
        let start_time = days_to_ms(720);
        let duration = days_to_ms(720);

        let (clock, scenario_val) = setup<SUI>(user_1, input_amount, start_time, duration);
        let scenario = &mut scenario_val;

        let expect_released_amount = 0;

        ts::next_tx(scenario, user_1);
        {
            clock::increment_for_testing(&mut clock, days_to_ms(60));
            let lock = ts::take_from_sender<VestingLock<SUI>>(scenario);
            assert!(releasable_amount(&lock, &clock) == 0, 0);
            ts::return_to_sender(scenario, lock);
        };

        ts::next_tx(scenario, user_1);
        {
            clock::increment_for_testing(&mut clock, days_to_ms(360));
            let lock = ts::take_from_sender<VestingLock<SUI>>(scenario);
            assert!(releasable_amount(&lock, &clock) == 0, 0);
            ts::return_to_sender(scenario, lock);
        };

        ts::next_tx(scenario, user_1);
        {
            clock::increment_for_testing(&mut clock, days_to_ms(720 - 60 - 360 + 90));
            let lock = ts::take_from_sender<VestingLock<SUI>>(scenario);
            let expected_releasable_amount = mul_factor(input_amount, 90, 720);
            assert!(released_amount(&lock) == expect_released_amount, 0);
            expect_released_amount = expect_released_amount + expected_releasable_amount;
            assert!(releasable_amount(&lock, &clock) == expected_releasable_amount, 0);
            let released_sui = release(&mut lock, &clock);
            assert!(balance::value(&released_sui) == expected_releasable_amount, 0);
            assert!(released_amount(&lock) == expect_released_amount, 0);
            balance::destroy_for_testing(released_sui);
            ts::return_to_sender(scenario, lock);
        };

        ts::next_tx(scenario, user_1);
        {
            clock::increment_for_testing(&mut clock, days_to_ms(150));
            let lock = ts::take_from_sender<VestingLock<SUI>>(scenario);
            let expected_releasable_amount = mul_factor(input_amount, 150, 720);
            assert!(released_amount(&lock) == expect_released_amount, 0);
            expect_released_amount = expect_released_amount + expected_releasable_amount;
            assert!(releasable_amount(&lock, &clock) == expected_releasable_amount, 0);
            let released_sui = release(&mut lock, &clock);
            assert!(balance::value(&released_sui) == expected_releasable_amount, 0);
            assert!(released_amount(&lock) == expect_released_amount, 0);
            balance::destroy_for_testing(released_sui);
            ts::return_to_sender(scenario, lock);
        };

        ts::next_tx(scenario, user_1);
        {
            clock::increment_for_testing(&mut clock, days_to_ms(360));
            let lock = ts::take_from_sender<VestingLock<SUI>>(scenario);
            let expected_releasable_amount = mul_factor(input_amount, 360, 720);
            assert!(released_amount(&lock) == expect_released_amount, 0);
            expect_released_amount = expect_released_amount + expected_releasable_amount;
            assert!(releasable_amount(&lock, &clock) == expected_releasable_amount, 0);
            release_to(&mut lock, &clock, user_2, ts::ctx(scenario));
            assert!(released_amount(&lock) == expect_released_amount, 0);
            ts::return_to_sender(scenario, lock);
        };

        ts::next_tx(scenario, user_1);
        {
            let expected_releasable_amount = mul_factor(input_amount, 360, 720);
            let sui_coin = ts::take_from_address<Coin<SUI>>(scenario, user_2);
            assert!(coin::value(&sui_coin) == expected_releasable_amount, 0);
            ts::return_to_address(user_2, sui_coin);

            clock::increment_for_testing(&mut clock, days_to_ms(45));
            let lock = ts::take_from_sender<VestingLock<SUI>>(scenario);
            let expected_releasable_amount = mul_factor(input_amount, 45, 720);
            assert!(released_amount(&lock) == expect_released_amount, 0);
            expect_released_amount = expect_released_amount + expected_releasable_amount;
            assert!(releasable_amount(&lock, &clock) == expected_releasable_amount, 0);
            release_to(&mut lock, &clock, user_3, ts::ctx(scenario));
            assert!(released_amount(&lock) == expect_released_amount, 0);
            ts::return_to_sender(scenario, lock);
        };

        ts::next_tx(scenario, user_1);
        {
            let expected_releasable_amount = mul_factor(input_amount, 45, 720);
            let sui_coin = ts::take_from_address<Coin<SUI>>(scenario, user_3);
            assert!(coin::value(&sui_coin) == expected_releasable_amount, 0);
            ts::return_to_address(user_3, sui_coin);

            clock::increment_for_testing(&mut clock, days_to_ms(100));
            let lock = ts::take_from_sender<VestingLock<SUI>>(scenario);
            let expected_releasable_amount = mul_factor(input_amount, 75, 720);
            std::debug::print(&lock);
            assert!(released_amount(&lock) == expect_released_amount, 0);
            expect_released_amount = expect_released_amount + expected_releasable_amount;
            // std::debug::print(&releasable_amount(&lock, &clock));
            // std::debug::print(&expected_releasable_amount);
            assert!(releasable_amount(&lock, &clock) == expected_releasable_amount, 0);
            release_to(&mut lock, &clock, user_1, ts::ctx(scenario));
            assert!(released_amount(&lock) == expect_released_amount, 0);
            ts::return_to_sender(scenario, lock);
        };

        ts::next_tx(scenario, user_1);
        {
            let expected_releasable_amount = mul_factor(input_amount, 75, 720);
            let sui_coin = ts::take_from_sender<Coin<SUI>>(scenario);
            assert!(coin::value(&sui_coin) == expected_releasable_amount, 0);
            ts::return_to_sender(scenario, sui_coin);

            let lock = ts::take_from_sender<VestingLock<SUI>>(scenario);
            destroy_empty(lock);
        };

        clock::destroy_for_testing(clock);
        ts::end(scenario_val);
    }

    #[test]
    #[expected_failure]
    fun test_vesting_release_early() {
        use sui::sui::SUI; 
        let user_2 = @0x102;
        let input_amount = 18500000000000000;
        let start_time = days_to_ms(30);
        let duration = days_to_ms(150);

        let (clock, scenario_val) = setup<SUI>(user_2, input_amount, start_time, duration);
        let scenario = &mut scenario_val;

        ts::next_tx(scenario, user_2);
        { 
            clock::increment_for_testing(&mut clock, days_to_ms(18));
            let lock = ts::take_from_sender<VestingLock<SUI>>(scenario);
            let released_sui = release(&mut lock, &clock);
            balance::destroy_for_testing(released_sui);
            ts::return_to_sender(scenario, lock);
        };

        clock::destroy_for_testing(clock);
        ts::end(scenario_val);
    }
}