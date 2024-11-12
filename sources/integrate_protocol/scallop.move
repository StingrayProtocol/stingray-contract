module stingray::scallop{
    use sui::coin::Coin;
    use sui::clock::Clock;
    use sui::event::{Self,};

    use protocol::mint;
    use protocol::redeem;
    use protocol::reserve::MarketCoin;
    use protocol::version::Version;
    use protocol::market::Market;

    use std::{
        type_name::{Self, TypeName},
        string::{Self, String},
    };

    use stingray::{
        fund:: { Take_1_Liquidity_For_1_Liquidity_Request,},
    };

    public struct Deposited has copy, drop{
        protocol: String,
        input_type: TypeName,
        in_amount: u64,
        output_type: TypeName,
        output_amount: u64,
    }

    public struct Withdrawed has copy, drop{
        protocol: String,
        input_type: TypeName,
        in_amount: u64,
        output_type: TypeName,
        output_amount: u64,
    }

    public fun deposit<X>(
        request: &mut Take_1_Liquidity_For_1_Liquidity_Request<X, MarketCoin<X>>,
        coin: Coin<X>,
        version: &Version,
        market: &mut Market,
        clock: &Clock,
        ctx: &mut TxContext
    ):Coin<MarketCoin<X>>{

        let input_value = coin.value();

        let output = mint::mint(
            version,
            market,
            coin,
            clock,
            ctx,
        );

        request.supported_defi_confirm_1l_for_1l(output.value());

        event::emit(
            Deposited{
                protocol: string::utf8(b"Scallop"),
                input_type: type_name::get<X>(),
                in_amount: input_value,
                output_type: type_name::get<MarketCoin<X>>(),
                output_amount: output.value(),
            }
        );  

        output
    }

    public fun withdraw<X>(
        request: &mut Take_1_Liquidity_For_1_Liquidity_Request<MarketCoin<X>, X>,
        coin: Coin<MarketCoin<X>>,
        version: &Version,
        market: &mut Market,
        clock: &Clock,
        ctx: &mut TxContext
    ):Coin<X>{
        let input_value = coin.value();
        
        let output = redeem::redeem(
            version,
            market,
            coin,
            clock,
            ctx,
        );

        request.supported_defi_confirm_1l_for_1l(output.value());

        event::emit(
            Withdrawed{
                protocol: string::utf8(b"Scallop"),
                input_type: type_name::get<MarketCoin<X>>(),
                in_amount: input_value,
                output_type: type_name::get<X>(),
                output_amount: output.value(),
            }
        );

        output
    }
}
