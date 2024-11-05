module stingray::scallop{
    use sui::coin::Coin;
    use sui::clock::Clock;

    use protocol::mint;
    use protocol::redeem;
    use protocol::reserve::MarketCoin;
    use protocol::version::Version;
    use protocol::market::Market;

    use stingray::{
        fund:: { Take_1_Liquidity_For_1_Liquidity_Request,},
    };

    public fun deposit<X>(
        request: &mut Take_1_Liquidity_For_1_Liquidity_Request<X, MarketCoin<X>>,
        coin: Coin<X>,
        version: &Version,
        market: &mut Market,
        clock: &Clock,
        ctx: &mut TxContext
    ):Coin<MarketCoin<X>>{
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

        output
    }
}
