module stingray::defi_demo{

    use sui::{
        balance::{Self, Balance},
        sui::{SUI},
        coin::{Coin},
    };

    use stingray::other_coin::{ OTHER_COIN, };
    use stingray::scallop::{ SCALLOP, };
    use stingray::bucket::{ BUCKET, };
    use stingray::suilend_card::{Self, SuilendCard};
    use stingray::proof::{Self, Proof};

    public struct House has key, store{
        id: UID,
        balance_sui: Balance<SUI>,
        balance_other: Balance<OTHER_COIN>,
        balance_scallop: Balance<SCALLOP>,
        balance_bucket: Balance<BUCKET>,
    }

    fun init(ctx: &mut TxContext){
        let house = House{
            id: object::new(ctx),
            balance_sui: balance::zero<SUI>(),
            balance_other: balance::zero<OTHER_COIN>(),
            balance_scallop: balance::zero<SCALLOP>(),
            balance_bucket: balance::zero<BUCKET>(),
        };

        transfer::public_share_object(house);
    }

    public fun mock_first_suilend_deposit_sui(
        house: &mut House,
        balance: Balance<SUI>,
        ctx: &mut TxContext
    ):SuilendCard{
        house.balance_sui.join(balance);
        suilend_card::mint(ctx)
    }

    public fun mock_first_suilend_deposit_other(
        house: &mut House,
        balance: Balance<OTHER_COIN>,
        ctx: &mut TxContext
    ):SuilendCard{
        house.balance_other.join(balance);
        suilend_card::mint(ctx)
    }
    
    public fun mock_suilend_deposit_sui(
        house: &mut House,
        _card: &mut SuilendCard,
        balance: Balance<SUI>,
    ){
        house.balance_sui.join(balance);
    }

    public fun mock_suilend_deposit_other(
        house: &mut House,
        _card: &mut SuilendCard,
        balance: Balance<OTHER_COIN>,
    ){
        house.balance_other.join(balance);
    }
    
    public fun mock_suilend_withdraw_other(
        house: &mut House,
        _card: &mut SuilendCard,
    ): Balance<OTHER_COIN>{
        let put_coin = house.balance_other.split(1);
        put_coin
    }

    public fun mock_suilend_withdraw_sui(
        house: &mut House,
        _card: &mut SuilendCard,
    ): Balance<SUI>{
        let put_coin = house.balance_sui.split(1);
        put_coin
    }

    public fun mock_cetus_swap_sui_to_other(
        house: &mut House,
        balance: Balance<SUI>,
    ): Balance<OTHER_COIN>{  
        house.balance_sui.join(balance);
        house.balance_other.split(1)
    }  

    public fun mock_cetus_swap_other_to_sui(
        house: &mut House,
        balance: Balance<OTHER_COIN>,
    ): Balance<SUI>{  
        house.balance_other.join(balance);
        house.balance_sui.split(1)
    }   

    public fun mock_scallop_deposit_sui(
        house: &mut House,
        balance: Balance<SUI>,
    ): Balance<SCALLOP>{
        house.balance_sui.join(balance);
        house.balance_scallop.split(1)
    }

    public fun mock_scallop_withdraw(
        house: &mut House,
        balance: Balance<SCALLOP>,
    ): Balance<SUI>{
        house.balance_scallop.join(balance);
        house.balance_sui.split(1)
    }

    public fun mock_bucket_deposit(
        house: &mut House,
        balance: Balance<BUCKET>,
        ctx: &mut TxContext,
    ): Proof{
        house.balance_bucket.join(balance);
        proof::mint(ctx)
    }

    public fun mock_bucket_withdraw(
        house: &mut House,
        proof: Proof,
    ): Balance<BUCKET>{
        proof::burn(proof);
        house.balance_bucket.split(1)
    }

    public entry fun deposit_other_coin(
        house: &mut House,
        coin: Coin<OTHER_COIN>,
    ){
        house.balance_other.join(coin.into_balance());
    }

    public entry fun deposit_sui_coin(
        house: &mut House,
        coin: Coin<SUI>,
    ){
        house.balance_sui.join(coin.into_balance());
    }

    public entry fun deposit_scallop_coin(
        house: &mut House,
        coin: Coin<SCALLOP>,
    ){
        house.balance_scallop.join(coin.into_balance());
    }

    public entry fun deposit_bucket_coin(
        house: &mut House,
        coin: Coin<BUCKET>,
    ){
        house.balance_bucket.join(coin.into_balance());
    }
}