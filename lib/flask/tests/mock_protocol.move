#[test_only]
module flask::buck {

    use sui::coin::{Self, Coin, TreasuryCap};
    use sui::clock::{Clock};
    use flask::sbuck::{Flask, SBUCK};
    use flask::float::{Self as f, Float};

    public struct BUCK has drop {}

    public struct BUCKET_PROTOCOL has drop {}

    public struct BucketProtocol has key {
        id: UID,
        cap: TreasuryCap<BUCK>,
        latest_time: u64,
        interest_rate: Float,
    }

    fun init(witness: BUCK, ctx: &mut TxContext)
    {
        let (treasury_cap, metadata) = coin::create_currency<BUCK>(
            witness,
            9,
            b"BUCK",
            b"Bucket USD",
            b"Mock BUCK for testing",
            option::none(),
            ctx,
        );
        transfer::public_freeze_object(metadata);
        transfer::share_object(BucketProtocol {
            id: object::new(ctx),
            cap: treasury_cap,
            latest_time: 0,
            interest_rate: f::from(0),
        });
    }

    public fun update_interest_rate(
        protocol: &mut BucketProtocol,
        flask: &mut Flask<BUCK>,
        clock: &Clock,
        interest_rate_bps: u64,
    ) {
        if (protocol.latest_time() > 0) {
            let interest_amount = protocol.interest_amount(flask, clock);
            let interest = protocol.cap.mint_balance(interest_amount);
            flask.collect_rewards(interest);            
        };
        protocol.latest_time = clock.timestamp_ms();
        protocol.interest_rate = f::from_bps(interest_rate_bps);
    }

    public fun deposit(
        p: &mut BucketProtocol,
        flask: &mut Flask<BUCK>,
        clock: &Clock,
        coin: Coin<BUCK>,
        ctx: &mut TxContext,
    ): Coin<SBUCK> {
        let interest_amount = p.interest_amount(flask, clock);
        let interest = p.cap.mint_balance(interest_amount);
        p.latest_time = clock.timestamp_ms();
        flask.collect_rewards(interest);
        coin::from_balance(
            flask.deposit_by_protocol(BUCKET_PROTOCOL {}, coin.into_balance()),
            ctx,
        )
    }

    public fun withdraw(
        p: &mut BucketProtocol,
        flask: &mut Flask<BUCK>,
        clock: &Clock,
        coin: Coin<SBUCK>,
        ctx: &mut TxContext,
    ): Coin<BUCK> {
        let interest_amount = p.interest_amount(flask, clock);
        let interest = p.cap.mint_balance(interest_amount);
        p.latest_time = clock.timestamp_ms();
        flask.collect_rewards(interest);
        coin::from_balance(
            flask.withdraw_by_protocol(BUCKET_PROTOCOL {}, coin.into_balance()),
            ctx,
        )
    }

    // Getter Funs

    public fun latest_time(p: &BucketProtocol): u64 {
        p.latest_time
    }

    public fun interest_rate(p: &BucketProtocol): Float {
        p.interest_rate
    }

    public fun one_year_timestamp_ms(): u64 {
        31_536_000_000
    }

    public fun interest_amount<BUCK>(
        p: &mut BucketProtocol,
        flask: &Flask<BUCK>,
        clock: &Clock,
    ): u64 {
        let interval = clock.timestamp_ms() - p.latest_time();
        f::from(flask.reserves())
            .mul(p.interest_rate())
            .mul_u64(interval)
            .div_u64(one_year_timestamp_ms())
            .floor()
    }

    // Test-only
    #[test_only]
    public fun init_for_testing(ctx: &mut TxContext) {
        init(BUCK {}, ctx);
    }
}
