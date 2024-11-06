module flask::utils {
    const ERR_OVERFLOW: u64 = 101;
    const ERR_DIVIDE_BY_ZERO: u64 = 101;

    const U64_MAX: u64 = 18446744073709551615;

    public fun mul_div(a: u64, b: u64, c: u64): u64 { 
        let a = (a as u128);
        let b = (b as u128);
        let c = (c as u128);
        let res = u128_mul_div(a, b, c);
        assert!(res <= ( U64_MAX as u128), ERR_OVERFLOW); 
        (res as u64)
    }
    
    public fun u128_mul_div(a: u128, b: u128, c: u128): u128 { 
        let (a,b) = if( a >= b ){
            (a, b)
        }else{
            (b, a)
        };
        assert!(c > 0, ERR_DIVIDE_BY_ZERO);

        ((a / c) * b) + (((a % c) * b) / c) 
    }
}
