module stingray::other_coin{
    //import library
    use sui::coin::{Self, Coin, TreasuryCap,};
    use stingray::config::{AdminCap};
    

    // one time witness
    public struct OTHER_COIN has drop {}

    //init function, first args is one-time-witness(OTW)
    fun init (witness: OTHER_COIN, ctx: &mut TxContext){
        // create new fungible token instance, and set its information.
        // sui::coin will return two object
        // one is TreasuryCap, another is Metadata
        //TreasuryCap is capability, which reprensent someone has access to operate the this fungible tokens.
        //metadata is the static information of this fungible tokens.
        let (treasury_cap, metadata) = coin::create_currency<OTHER_COIN>(
            witness,
            2,
            b"OTHER",
            b"Other Coin",
            b"",
            option::none(),
            ctx);

        transfer::public_share_object(metadata);
        transfer::public_share_object(treasury_cap);
    }
    
    // mint the fingible tokens.
    public(package) fun mint(treasury_cap: &mut TreasuryCap<OTHER_COIN>, amount: u64, ctx: &mut TxContext): Coin<OTHER_COIN>{
        coin::mint(treasury_cap, amount, ctx)
    }
    
    //burn the fungible tokens.
    public entry fun burn (treasury_cap: &mut TreasuryCap<OTHER_COIN>, coin: Coin<OTHER_COIN>){
        coin::burn(treasury_cap, coin);

    }

    // mint the fingible tokens.
    public entry fun mint_by_admin(_admin: &AdminCap,treasury_cap: &mut TreasuryCap<OTHER_COIN>, ctx: &mut TxContext){
        let other = coin::mint(treasury_cap, 1000000000000000000, ctx);
        transfer::public_transfer(other, ctx.sender());
    }
    
}