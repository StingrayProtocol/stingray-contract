#[test_only]
module flask::sbuck_tests_v2;

use sui::test_scenario::{Self as ts, Scenario};
use sui::coin::{Self, Coin, TreasuryCap};
use sui::clock::{Self, Clock};
use flask::sbuck::{Self, Flask, SBUCK, WhitelistCap};
use flask::buck::{Self, BUCK, BUCKET_PROTOCOL, BucketProtocol};
use flask::float::{Self as f, Float};

public struct DUMMY_PROTOCOL has drop {}

public fun deployer(): address { @0xde }

public fun start_time(): u64 { 1726074044155 }

public fun interest_rate_bps(): u64 { 400 }

public fun interest_rate(): Float { f::from_bps(interest_rate_bps()) }

public fun within_rounding(x: u64, y: u64): bool {
    std::u64::diff(x, y) <= 1
}

public fun int(x: u64): u64 { x * 1_000_000_000 }

public fun setup(init_value: u64): Scenario {
    
    let mut scenario = ts::begin(deployer());
    let s = &mut scenario;
    
    // 1
    s.next_tx(deployer());
    sbuck::init_for_testing(s.ctx());
    buck::init_for_testing(s.ctx());
    let mut clock = clock::create_for_testing(s.ctx());
    clock.set_for_testing(start_time());
    clock.share_for_testing();

    // 2
    s.next_tx(deployer());
    let sbuck_cap = s.take_from_sender<TreasuryCap<SBUCK>>();
    sbuck::initialize<BUCK>(sbuck_cap, s.ctx());
    
    // 3
    s.next_tx(deployer());
    let mut flask = s.take_shared<Flask<BUCK>>();
    flask.patch_whitelist_for_testing<BUCK, BUCKET_PROTOCOL>();
    ts::return_shared(flask);
    
    // 4
    s.next_tx(deployer());
    let mut protocol = s.take_shared<BucketProtocol>();
    let mut flask = s.take_shared<Flask<BUCK>>();
    let clock = s.take_shared<Clock>();
    let coin = coin::mint_for_testing<BUCK>(init_value, s.ctx());
    let sbuck_coin = protocol.deposit(&mut flask, &clock, coin, s.ctx());
    assert!(sbuck_coin.value() == init_value);
    transfer::public_transfer(sbuck_coin, deployer());
    ts::return_shared(flask);
    ts::return_shared(protocol);
    ts::return_shared(clock);

    // 5
    s.next_tx(deployer());
    let mut protocol = s.take_shared<BucketProtocol>();
    let mut flask = s.take_shared<Flask<BUCK>>();
    let clock = s.take_shared<Clock>();
    protocol.update_interest_rate(&mut flask, &clock, interest_rate_bps());
    ts::return_shared(protocol);
    ts::return_shared(clock);
    ts::return_shared(flask);

    scenario
}

public fun days_pass_by(s: &mut Scenario, days: u64) {
    s.next_tx(deployer());
    let tick = days * 86400_000;
    let mut clock = s.take_shared<Clock>();
    clock.increment_for_testing(tick);
    ts::return_shared(clock);
}

public fun deposit(
    s: &mut Scenario,
    user: address,
    amount: u64,
) {
    s.next_tx(user);
    let mut protocol = s.take_shared<BucketProtocol>();
    let mut flask = s.take_shared<Flask<BUCK>>();
    let clock = s.take_shared<Clock>();
    let coin = coin::mint_for_testing<BUCK>(amount, s.ctx());
    let sbuck_coin = protocol.deposit(&mut flask, &clock, coin, s.ctx());
    transfer::public_transfer(sbuck_coin, user);
    ts::return_shared(flask);
    ts::return_shared(protocol);
    ts::return_shared(clock);
}

public fun withdraw(
    s: &mut Scenario,
    user: address,
    amount: u64,
) {
    s.next_tx(user);
    let mut protocol = s.take_shared<BucketProtocol>();
    let mut flask = s.take_shared<Flask<BUCK>>();
    let clock = s.take_shared<Clock>();
    let coin = coin::mint_for_testing<SBUCK>(amount, s.ctx());
    let buck_coin = protocol.withdraw(&mut flask, &clock, coin, s.ctx());
    transfer::public_transfer(buck_coin, user);
    ts::return_shared(flask);
    ts::return_shared(protocol);
    ts::return_shared(clock);
}

public fun withdraw_by_sbuck(
    s: &mut Scenario,
    user: address,
) {
    s.next_tx(user);
    let mut protocol = s.take_shared<BucketProtocol>();
    let mut flask = s.take_shared<Flask<BUCK>>();
    let clock = s.take_shared<Clock>();
    let sbuck_coin = s.take_from_sender<Coin<SBUCK>>();
    let buck_coin = protocol.withdraw(&mut flask, &clock, sbuck_coin, s.ctx());
    transfer::public_transfer(buck_coin, user);
    ts::return_shared(flask);
    ts::return_shared(protocol);
    ts::return_shared(clock);
}

#[test]
fun test_withdraw_after_one_year() {
    let init_value = 6232065462391947;
    let mut scenario = setup(init_value);
    let s = &mut scenario;
    let user = @0xabc;

    days_pass_by(s, 365);
    withdraw(s, user, int(100));

    s.next_tx(user);
    let buck_coin = s.take_from_sender<Coin<BUCK>>();
    // std::debug::print(&buck_coin.value());
    let expected_value = f::from(int(100))
        .mul(interest_rate().add_u64(1))
        .floor();
    assert!(within_rounding(buck_coin.value(), expected_value));
    transfer::public_transfer(buck_coin, user);

    scenario.end();
}

#[test]
fun test_user_deposit_after_one_year() {
    let mut scenario = setup(6232065462391947);
    let s = &mut scenario;
    let user_1 = @0xabc1;
    let user_2 = @0xabc2;

    deposit(s, user_1, int(100));
    days_pass_by(s, 365);
    deposit(s, user_2, int(200));
    days_pass_by(s, 365);
    
    withdraw_by_sbuck(s, user_1);

    s.next_tx(user_1);
    let buck_coin = s.take_from_sender<Coin<BUCK>>();
    // std::debug::print(&buck_coin.value());
    let expected_value = f::from(int(100))
        .mul(interest_rate().add_u64(1))
        .mul(interest_rate().add_u64(1))
        .floor();
    // std::debug::print(&expected_value);
    assert!(within_rounding(buck_coin.value(), expected_value));
    transfer::public_transfer(buck_coin, user_1);
    
    withdraw_by_sbuck(s, user_2);
    s.next_tx(user_2);
    let buck_coin = s.take_from_sender<Coin<BUCK>>();
    // std::debug::print(&buck_coin.value());
    let expected_value = f::from(int(200))
        .mul(interest_rate().add_u64(1))
        .floor();
    // std::debug::print(&expected_value);
    assert!(within_rounding(buck_coin.value(), expected_value));
    transfer::public_transfer(buck_coin, user_2);

    scenario.end();
}

#[test, expected_failure(abort_code = flask::sbuck::ERR_NOT_WHITELISTED_PROTOCOL)]
fun test_not_whitelisted_protocol() {
    let mut scenario = setup(6232065462391947);
    let s = &mut scenario;

    s.next_tx(deployer());
    let cap = s.take_from_sender<WhitelistCap>();
    let mut flask = s.take_shared<Flask<BUCK>>();
    flask.add_protocol<BUCK, DUMMY_PROTOCOL>(&cap);
    assert!(flask.whitelist().size() == 2);
    flask.remove_protocol<BUCK, BUCKET_PROTOCOL>(&cap);
    assert!(flask.whitelist().size() == 1);
    s.return_to_sender(cap);
    ts::return_shared(flask);

    let user = @0xabc;
    days_pass_by(s, 365);
    withdraw(s, user, int(100));

    scenario.end();
}

#[test]
fun test_whitelist_protocol(): Scenario {
    let mut scenario = setup(6232065462391947);
    let s = &mut scenario;

    s.next_tx(deployer());
    let cap = s.take_from_sender<WhitelistCap>();
    let mut flask = s.take_shared<Flask<BUCK>>();
    flask.remove_protocol<BUCK, BUCKET_PROTOCOL>(&cap);
    assert!(flask.whitelist().is_empty());
    s.return_to_sender(cap);
    ts::return_shared(flask);

    s.next_tx(deployer());
    let cap = s.take_from_sender<WhitelistCap>();
    let mut flask = s.take_shared<Flask<BUCK>>();
    flask.add_protocol<BUCK, BUCKET_PROTOCOL>(&cap);
    assert!(flask.whitelist().size() == 1);
    s.return_to_sender(cap);
    ts::return_shared(flask);

    let user = @0xabc;
    days_pass_by(s, 365);
    withdraw(s, user, int(100));

    s.next_tx(user);
    let buck_coin = s.take_from_sender<Coin<BUCK>>();
    // std::debug::print(&buck_coin.value());
    let expected_value = f::from(int(100))
        .mul(interest_rate().add_u64(1))
        .floor();
    assert!(within_rounding(buck_coin.value(), expected_value));
    transfer::public_transfer(buck_coin, user);

    scenario
}
