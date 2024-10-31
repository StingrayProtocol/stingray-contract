module stingray::suilend_card{
    use std::{
        string::{Self},
    };
    use sui::{
        package,
        display,
        
    };
   
    public struct SUILEND_CARD has drop{}
    

    public struct SuilendCard has key{
        id: UID,
    }
    
    
    #[allow(lint(share_owned))]
    fun init (otw: SUILEND_CARD, ctx: &mut TxContext){

        let keys = vector[
            string::utf8(b"name"),
            string::utf8(b"description"),
            string::utf8(b"image_url"),
            string::utf8(b"project_url"),
        ];

        let values = vector[
            // name
            string::utf8(b"Stingrey: {first_name} {last_name}"),
            // description
            string::utf8(b"Trader Certificate"),
            // image_url
            string::utf8(b"https://aggregator-devnet.walrus.space/v1/{card_img}"),
            // project_url
            string::utf8(b"https://stingray.walrus.site"),
        ];

        let deployer = ctx.sender();
        let publisher = package::claim(otw, ctx);
        let mut displayer = display::new_with_fields<SuilendCard>(
            &publisher, keys, values, ctx,
        );

        display::update_version(&mut displayer);

        transfer::public_transfer(displayer, deployer);
        transfer::public_transfer(publisher, deployer);
    } 

    public(package) fun mint( 
        ctx: &mut TxContext,
    ) : SuilendCard{

        SuilendCard{
            id: object::new(ctx)
        }
    }

}