module adapters::suilend{
    use sui::clock::Clock;
    use sui::coin::Coin;

    use suilend::reserve::CToken;
    use suilend::lending_market::{Self, LendingMarket};

    public fun deposit<P, X>(
        coin: Coin<X>,
        lending_market: &mut LendingMarket<P>, 
        reserve_array_index: u64,
        clock: &Clock,
        ctx: &mut TxContext
    ):Coin<CToken<P, X>>{
        lending_market::deposit_liquidity_and_mint_ctokens(lending_market, reserve_array_index, clock, coin, ctx)
    }

    public fun withdraw<P, X>(
        c_token: Coin<CToken<P, X>>,
        lending_market: &mut LendingMarket<P>, 
        reserve_array_index: u64,
        clock: &Clock,
        ctx: &mut TxContext
    ):Coin<X>{
        lending_market::redeem_ctokens_and_withdraw_liquidity(lending_market, reserve_array_index, clock, c_token, option::none(), ctx)
    }
}
