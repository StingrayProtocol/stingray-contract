module volo::native_pool {

    use volo::cert::Metadata;
    use volo::cert::CERT;

    public struct NativePool has key {
        id: UID,
    }

    public fun from_shares(
        _native_pool: &NativePool,
        _metadata: &Metadata<CERT>,
        _shares: u64,
    ): u64 {
        abort 0
    }

}
