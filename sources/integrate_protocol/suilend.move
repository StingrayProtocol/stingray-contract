module stingray::suilend{
    use sui::clock::Clock;
    use sui::coin::Coin;
    use sui::event::{Self,};
    
    use std::{
        type_name::{Self, TypeName},
        string::{Self, String},
    };
    

    use suilend::reserve::CToken;
    use suilend::lending_market::{Self, LendingMarket};

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

    public fun deposit<P, X>(
        request: &mut Take_1_Liquidity_For_1_Liquidity_Request<X, CToken<P, X>>,
        coin: Coin<X>,
        lending_market: &mut LendingMarket<P>, 
        reserve_array_index: u64,
        clock: &Clock,
        ctx: &mut TxContext
    ):Coin<CToken<P, X>>{

        event::emit(
            Deposited{
                protocol: string::utf8(b"Suilend"),
                coin_type: type_name::get<X>(),
                amount: coin.value(),
            }
        ); 

        let output = lending_market::deposit_liquidity_and_mint_ctokens(lending_market, reserve_array_index, clock, coin, ctx);
        request.supported_defi_confirm_1l_for_1l(output.value());
        output
    }

    public fun withdraw<P, X>(
        request: &mut Take_1_Liquidity_For_1_Liquidity_Request<CToken<P, X>,X >,
        c_token: Coin<CToken<P, X>>,
        lending_market: &mut LendingMarket<P>, 
        reserve_array_index: u64,
        clock: &Clock,
        ctx: &mut TxContext
    ):Coin<X>{
        let output = lending_market::redeem_ctokens_and_withdraw_liquidity(lending_market, reserve_array_index, clock, c_token, option::none(), ctx);
        request.supported_defi_confirm_1l_for_1l(output.value());

        event::emit(
            Withdrawed{
                protocol: string::utf8(b"Suilend"),
                coin_type: type_name::get<X>(),
                amount: output.value(),
            }
        );

        output
    }
}
