module stingray::trader{
    use std::{
        string::{Self, String},
    };
    use sui::{
        package,
        display,
        balance::{Self, Balance},
        coin::{Self, Coin},
        dynamic_object_field as dof, 
        clock::{Clock},
        event::{Self, },
        table::{Self, Table},
        sui::{SUI},
    };

    use suins::suins_registration::{SuinsRegistration};
    use stingray::config::{Self, GlobalConfig, AdminCap,};

    public struct TRADER has drop{}
    
    const VERSION: u64 = 1;
    const EDuplicateAssign: u64 = 0;
    const ENsExpired: u64 = 1;
    const ENoNsBounnd: u64 = 2;
    const EBalanceNotMatched: u64 = 3;
    const EAlreadyMinted: u64 = 4;

    public struct Trader has key{
        id: UID,
        last_name: String,
        first_name: String,
        card_img: String,
        pfp_img: String,
        description: String,
        birth: u64,
    }
    public struct HostController has key {
        id: UID,
        balance: Balance<SUI>,
        register_fee: u64,
        mint_record: Table<address, ID>,
    }
    
    // define key
    public struct Name has copy, store, drop {}

    // define event 
    public struct Rename has copy, drop{
        trader_id: ID,
        new_first_name: String,
        new_last_name: String,
    }

    public struct Mint has copy, drop{
        trader_id: ID,
        new_first_name: String,
        new_last_name: String,
        minter: address,
        description: String,
        pfp_img: String
    }

    public struct UpdatePFP has copy, drop{
        trader_id: ID,
        pfp_img: String,
        card_img: String,
    }
    
    #[allow(lint(share_owned))]
    fun init (otw: TRADER, ctx: &mut TxContext){

        let keys = vector[
            string::utf8(b"name"),
            string::utf8(b"description"),
            string::utf8(b"image_url"),
            string::utf8(b"project_url"),
        ];

        let values = vector[
            // name
            string::utf8(b"Stingray: {first_name} {last_name}"),
            // description
            string::utf8(b"{description}"),
            // image_url
            string::utf8(b"https://aggregator.walrus-testnet.walrus.space/v1/{card_img}"),
            // project_url
            string::utf8(b"https://stingraylabs.xyz"),
        ];

        let deployer = ctx.sender();
        let publisher = package::claim(otw, ctx);
        let mut displayer = display::new_with_fields<Trader>(
            &publisher, keys, values, ctx,
        );

        display::update_version(&mut displayer);

        let controller = HostController{
            id: object::new(ctx),
            balance: balance::zero<SUI>(),
            register_fee: 1000000000, // 1 SUI
            mint_record: table::new<address, ID>(ctx),
        };

        transfer::public_transfer(displayer, deployer);
        transfer::public_transfer(publisher, deployer);
        transfer::share_object(controller);
    } 

    public entry fun mint(
        config: &mut GlobalConfig,
        controller: &mut HostController,
        //sui_ns: &SuinsRegistration,
        pfp_img: String, // blob id 
        card_img: String, // blob id 
        description: String,
        //coin: Coin<SUI>,
        clock: &Clock,
        ctx: &mut TxContext,
    ) {

        config::assert_if_version_not_matched(config, VERSION);
        assert_if_already_minted(controller, ctx);
        //let balance = coin.into_balance();
        //assert_if_ns_expired_by_ns(&sui_ns, clock);
        //assert_if_balance_not_matched(controller, &balance );

        // let first_name = *sui_ns.domain().sld();
        // let last_name =  *sui_ns.domain().tld();

        let first_name = string::utf8(b"");
        let last_name = string::utf8(b"");
        
        
        let mut name = string::utf8(b"");
        name.append(first_name);
        name.append(last_name);

        let trader = Trader{
            id: object::new(ctx),
            first_name,
            last_name,
            card_img,
            pfp_img,
            description,
            birth: clock.timestamp_ms(),
        };
        
        //controller.balance.join(balance);

        event::emit( 
            Mint{
                trader_id: *trader.id.as_inner(),
                new_first_name: first_name, 
                new_last_name: last_name,//last_name
                minter: ctx.sender(),
                description,
                pfp_img,
            }
        );

        controller.mint_record.add(ctx.sender(), *trader.id.as_inner());
        transfer::transfer(trader, ctx.sender());
    }

    #[allow(lint(self_transfer))]
    public fun rename (
        config: &GlobalConfig,
        sui_ns: SuinsRegistration,
        trader: &mut Trader,
        ctx: &mut TxContext,
    ){
        config::assert_if_version_not_matched(config, VERSION);

        assert_if_no_ns(trader);

        let new_first_name = *sui_ns.domain().sld();
        let new_last_name = *sui_ns.domain().tld();
        
        if ((*trader.first_name.as_bytes() == *new_first_name.as_bytes()) &&
            (*trader.last_name.as_bytes() == *new_last_name.as_bytes())
        ){
            abort EDuplicateAssign
        }else{

            let mut name = string::utf8(b"");
            name.append( trader.first_name);
            name.append(trader.last_name);
            
            trader.first_name = new_first_name;
            trader.last_name = new_last_name;

            name = string::utf8(b"");
            name.append( trader.first_name);
            name.append(trader.last_name);

            let old_ns = dof::remove<Name, SuinsRegistration>(&mut trader.id, Name{});
            dof::add<Name, SuinsRegistration>(&mut trader.id, Name{}, sui_ns);

            event::emit(Rename{
                trader_id: *trader.id.as_inner(),
                new_first_name,
                new_last_name,
            });

            transfer::public_transfer(old_ns, ctx.sender());
            
        };
    }

    public fun updatePfp(
        config: &GlobalConfig,
        trader: &mut Trader,
        pfp_img: String,
        card_img: String,
    ){
        config::assert_if_version_not_matched(config, VERSION);
        
        trader.pfp_img = pfp_img;
        trader.card_img = card_img;

        event::emit(UpdatePFP{
            trader_id: *trader.id.as_inner(),
            pfp_img,
            card_img,
        });
    }

    public fun id(
        trader: &Trader,
    ):ID{
        *trader.id.as_inner()
    }

    public fun first_name(
        trader: &Trader,
    ): String{
        trader.first_name
    }

    public fun last_name(
        trader: &Trader,
    ): String{
        trader.last_name
    }

    public fun name(
        trader: &Trader,
    ): String{
        let mut name = string::utf8(b"");
        name.append(trader.first_name());
        name.append(string::utf8(b" "));
        name.append(trader.last_name());
        name
    }

    public fun pfp_img(
        trader: &Trader,
    ): String{
        trader.pfp_img
    }

    public fun card_img(
        trader: &Trader,
    ): String{
        trader.card_img
    }

    public fun birth(
        trader: &Trader,
    ): u64{
        trader.birth
    }

    // admin function 
    public fun withdraw(
        _: &AdminCap,
        controller: &mut HostController,
        ctx: &mut TxContext, 
    ): Coin<SUI>{
        let withdraw_amount = controller.balance.value();
        let withdraw_balance = controller.balance.split(withdraw_amount);
        let withdraw_coin = coin::from_balance(withdraw_balance, ctx);
        withdraw_coin
    }

    public(package)fun assert_if_ns_expired_by_card(
        card: &Trader,
        clock: &Clock,
    ){
        assert!(!dof::borrow<Name, SuinsRegistration >(&card.id, Name{}).has_expired(clock), ENsExpired);
    }

    // fun assert_if_ns_expired_by_ns(
    //     sui_ns: &SuinsRegistration,
    //     clock: &Clock,
    // ){
    //     assert!(!sui_ns.has_expired(clock), ENsExpired);
    // }

    fun assert_if_no_ns(
        trader: &Trader,
    ){
        assert!(dof::exists_(&trader.id, Name{}), ENoNsBounnd);
    }


    fun assert_if_balance_not_matched(
        controller: &HostController, 
        balance: &Balance<SUI>,
    ){
        assert!(controller.register_fee == balance.value(), EBalanceNotMatched)
    }

    fun assert_if_already_minted(
        controller: &HostController, 
        ctx: &TxContext
    ){
        assert!(!controller.mint_record.contains(ctx.sender()), EAlreadyMinted);
    }


    #[test_only]
    public(package) fun test_init(
        ctx: &mut TxContext
    ){
        init(TRADER{}, ctx);
    }

}