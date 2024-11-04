#[lint_allow(share_owned)]
#[test_only]
module flask::mock_buck {

    use sui::coin;
    use sui::url::{Self, Url};

    public struct MOCK_BUCK has drop {}

    fun init(witness: MOCK_BUCK, ctx: &mut TxContext)
    {
        let (mut treasury_cap, metadata) = coin::create_currency<MOCK_BUCK>(
            witness,
            8,
            b"ETH",
            b"Etherum",
            b"des",
            option::some<Url>(url::new_unsafe_from_bytes(b"https://assets.coingecko.com/coins/images/279/small/ethereum.png?1595348880")),
            ctx
        );
        transfer::public_transfer(coin::mint(&mut treasury_cap, 1_000_000 * std::u64::pow(10, 8), ctx), tx_context::sender(ctx));
        transfer::public_freeze_object(metadata);
        transfer::public_share_object(treasury_cap)
    }

    #[test_only]
    public fun deploy_coin(ctx: &mut TxContext)
    {
        init(MOCK_BUCK {}, ctx)
    }
}
