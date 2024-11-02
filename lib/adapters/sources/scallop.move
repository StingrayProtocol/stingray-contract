module adapters::scallop{
    use sui::coin::Coin;
    use sui::clock::Clock;

    use protocol::mint;
    use protocol::redeem;
    use protocol::reserve::MarketCoin;
    use protocol::version::Version;
    use protocol::market::Market;

    public fun deposit<X>(
        coin: Coin<X>,
        version: &Version,
        market: &mut Market,
        clock: &Clock,
        ctx: &mut TxContext
    ):Coin<MarketCoin<X>>{
        mint::mint(
            version,
            market,
            coin,
            clock,
            ctx,
        )
    }

    public fun withdraw<X>(
        coin: Coin<MarketCoin<X>>,
        version: &Version,
        market: &mut Market,
        clock: &Clock,
        ctx: &mut TxContext
    ):Coin<X>{
        redeem::redeem(
            version,
            market,
            coin,
            clock,
            ctx,
        )
    }
}
