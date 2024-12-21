module stingray::voucher{

    use sui::{
        balance::{Self, Balance},
        coin::{Coin},
        clock::{Clock},
        table::{Self, Table},
    };

    use std::{
        type_name:: {Self, TypeName},
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

    public struct SponsorPoolHost has key {
        id : UID,
        pool_table: Table<TypeName, ID>,
    }

    public struct VoucherConsumeRequest< phantom CoinType>{
        request_amount: u64,
        base_provider: ID,
    }

    public struct PoolCap has key{
        id: UID,
    }

    fun init (ctx: &mut TxContext){
        let host = SponsorPoolHost{
            id: object::new(ctx),
            pool_table: table::new<TypeName, ID>(ctx),
        };
        transfer::share_object(host);
    }

    public fun new_sponsor_pool<CoinType>(
        config: &GlobalConfig,
        host: &mut SponsorPoolHost,
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

        host.pool_table.add(type_name::get<CoinType>(), *pool.id.as_inner());
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
            pool.allocated = pool.allocated + amount;
            pool.remaining = pool.remaining - amount;
            let voucher = mint<CoinType>(amount, deadline, ctx);
            transfer::transfer(voucher, to);
        };
    }

    public fun consume<CoinType>(
        config: &GlobalConfig,
        pool: &mut SponsorPool<CoinType>,
        mut vouchers: vector<Voucher<CoinType>>,
        clock: &Clock,
    ):(Balance<CoinType>, VoucherConsumeRequest<CoinType>){
        config::assert_if_version_not_matched(config, VERSION);
        
        let mut total_amount = 0;
        
        while (vouchers.length() != 0){
            let voucher = vouchers.pop_back();
            total_amount = total_amount + burn_and_get_voucher_amount<CoinType>(pool, voucher, clock);
        };

        vouchers.destroy_empty();
        
        let sponsor_balance =pool.asset.split(total_amount);

        let request = VoucherConsumeRequest<CoinType>{
            request_amount: total_amount,
            base_provider: *pool.id.as_inner(),
        };

        (sponsor_balance, request)
    }

    public fun request_amount<CoinType>(
        request: &VoucherConsumeRequest<CoinType>,
    ): u64{
        request.request_amount
    }

    public fun base_provider<CoinType>(
        request: &VoucherConsumeRequest<CoinType>,
    ): ID{
        request.base_provider
    }

    public(package) fun burn_request<CoinType>(
        request: VoucherConsumeRequest<CoinType>,
    ){
        let VoucherConsumeRequest<CoinType>{
            request_amount: _,
            base_provider: _,
        } = request;
    }

    public(package) fun put_back<CoinType>(
        pool: &mut SponsorPool<CoinType>,
        balance: Balance<CoinType>,
    ){
        pool.asset.join(balance);
    }

    public(package) fun sponsor_pool<CoinType>(
        host: &SponsorPoolHost,
    ): ID{
        let pool_type=  type_name::get<CoinType>();
        *host.pool_table.borrow(pool_type )
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

    fun burn_and_get_voucher_amount<CoinType>(
        pool: &mut SponsorPool<CoinType>,
        voucher: Voucher<CoinType>,
        clock: &Clock,
    ): u64{
        let Voucher<CoinType>{
            id: voucher_id,
            amount,
            deadline,
        } = voucher;

        object::delete(voucher_id);
        
        if (deadline >= clock.timestamp_ms()){
            amount
        }else{
            increase_remaining(pool, amount);
            0
        }
    }

    fun increase_remaining<CoinType>(
        pool: &mut SponsorPool<CoinType>,
        amount: u64,
    ){
        pool.remaining = pool.remaining + amount;
    }

    fun assert_if_over_sponsor_balance<CoinType>(
        pool: &SponsorPool<CoinType>,
        amount: u64,
    ){
        assert!(pool.remaining >= amount, ESponsorPoolBalanceNotEnough);
    }

    
}