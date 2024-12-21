module stingray::math{


    public fun ceil(
        amount: u64,
        part: u64,
        base: u64,
    ): u64{
        (((amount as u128) * (part as u128) + ((base - 1) as u128))/ (base as u128)) as u64
    }
}