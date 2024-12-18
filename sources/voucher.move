module stingray::voucher{

    use sui::{
        balance::{Self, Balance},
        coin::{Self, Coin},
    };

    use stingray::{
        config::{Self, GlobalConfig, AdminCap},
    };

    const VERSION: u64 = 1;

    const ESponsorPoolBalanceNotEnough: u64 = 1;

    public struct Voucher<phantom CoinType> has key{
        id: UID,
        amount: u64,
        deadline: u64,
    }

    public struct SponsorPool <phantom CoinType> has key{
        id: UID,
        asset: Balance<CoinType>,
        allocated: u64,
        remaining: u64,
    }

    public struct PoolCap has key{
        id: UID,
    }

    public fun new_sponsor_pool<CoinType>(
        config: &GlobalConfig,
        _: &AdminCap,
        ctx: &mut TxContext,
    ){
        config::assert_if_version_not_matched(config, VERSION);
        
        let pool = SponsorPool<CoinType>{
            id: object::new(ctx),
            asset: balance::zero<CoinType>(),
            allocated: 0u64,
            remaining: 0u64,
        };
        
        transfer::share_object(pool);
    }

    public fun deposit<CoinType>(
        config: &GlobalConfig,
        _: &AdminCap,
        pool: &mut SponsorPool<CoinType>,
        donated_asset: Coin<CoinType>,
    ){
        config::assert_if_version_not_matched(config, VERSION);
        let amount = donated_asset.value();
        pool.asset.join(donated_asset.into_balance());
        pool.remaining = pool.remaining + amount;
    }

    public fun mint_to<CoinType>(
        config: &GlobalConfig,
        _: &AdminCap,
        pool: &mut SponsorPool<CoinType>,
        mut tos: vector<address>,
        mut amounts: vector<u64>,
        mut deadlines: vector<u64>,
        ctx: &mut TxContext,
    ){
        config::assert_if_version_not_matched(config, VERSION);

        while( tos.length() > 0 ){
            let to = tos.pop_back();
            let amount = amounts.pop_back();
            let deadline = deadlines.pop_back();
            assert_if_over_sponsor_balance<CoinType>(pool, amount);
            let voucher = mint<CoinType>(amount, deadline, ctx);
            transfer::transfer(voucher, to);

        }
    }

    fun mint<CoinType>(
        amount: u64,
        deadline: u64,
        ctx: &mut TxContext,
    ): Voucher<CoinType>{
        Voucher<CoinType>{
            id: object::new(ctx),
            amount,
            deadline,
        }
    }

    fun assert_if_over_sponsor_balance<CoinType>(
        pool: &SponsorPool<CoinType>,
        amount: u64,
    ){
        assert!(pool.remaining >= amount, ESponsorPoolBalanceNotEnough);
    }


    

    
}