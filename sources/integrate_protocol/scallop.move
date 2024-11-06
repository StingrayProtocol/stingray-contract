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
        coin_type: TypeName,
        amount: u64,
    }

    public struct Withdrawed has copy, drop{
        protocol: String,
        coin_type: TypeName,
        amount: u64,
    }

    public fun deposit<X>(
        request: &mut Take_1_Liquidity_For_1_Liquidity_Request<X, MarketCoin<X>>,
        coin: Coin<X>,
        version: &Version,
        market: &mut Market,
        clock: &Clock,
        ctx: &mut TxContext
    ):Coin<MarketCoin<X>>{

        event::emit(
            Deposited{
                protocol: string::utf8(b"Scallop"),
                coin_type: type_name::get<X>(),
                amount: coin.value(),
            }
        );  

        let output = mint::mint(
            version,
            market,
            coin,
            clock,
            ctx,
        );

        request.supported_defi_confirm_1l_for_1l(output.value());
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
                coin_type: type_name::get<X>(),
                amount: output.value(),
            }
        );

        output
    }
}
