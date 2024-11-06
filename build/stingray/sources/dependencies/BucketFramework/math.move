module bucket_framework::math {

    const EDividedByZero: u64 = 0;

    public fun mul_factor(number: u64, numerator: u64, denominator: u64): u64 {
        assert!(denominator > 0, EDividedByZero);
        ((
            ((number as u128) * (numerator as u128) + (denominator as u128) / 2)
            / (denominator as u128)
        ) as u64)
    }

    public fun mul_factor_u128(number: u128, numerator: u128, denominator: u128): u128 {
        assert!(denominator > 0, EDividedByZero);
        ((
            ((number as u256) * (numerator as u256) + (denominator as u256) / 2)
            / (denominator as u256)
        ) as u128)
    }

    #[test_only]
    use std::debug;

    #[test]
    #[expected_failure]
    fun test_native_mul() {
        let amount = 10000000000; // 100 SUI
        let price = 4000000000; // 1 SUI = 4000 USD
        let denominator = 1000000;
        let value = amount * price / denominator; // overflow
        debug::print(&value);
    }

    #[test]
    fun test_mul_factor() {
        use std::debug;
        let amount = 10000000000; // 100 SUI
        let price = 4000000000; // 1 SUI = 4000 USD
        let decimals = 1000000;
        let value = mul_factor(amount, price, decimals);
        debug::print(&value);
        assert!(value == 40000000000000, 0);
    }
}
