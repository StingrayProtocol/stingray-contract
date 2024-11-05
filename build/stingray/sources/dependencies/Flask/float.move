/// fixed point Float representation. 18 Float places are kept.
module flask::float {

    const EDividedByZero: u64 = 0;
    fun err_divided_by_zero() { abort EDividedByZero }

    const ESubtrahendTooLarge: u64 = 1;
    fun err_subtrahend_too_large() { abort ESubtrahendTooLarge }

    // 1e18
    const WAD: u256 = 1_000_000_000_000_000_000;

    public struct Float has copy, store, drop {
        value: u256
    }

    public fun from(v: u64): Float {
        Float {
            value: (v as u256) * WAD
        }
    }

    public fun from_percent(v: u8): Float {
        Float {
            value: (v as u256) * WAD / 100
        }
    }

    public fun from_percent_u64(v: u64): Float {
        Float {
            value: (v as u256) * WAD / 100
        }
    }

    public fun from_bps(v: u64): Float {
        Float {
            value: (v as u256) * WAD / 10_000
        }
    }

    public fun from_fraction(n: u64, m: u64): Float {
        if (m == 0) err_divided_by_zero();
        Float {
            value: (n as u256) * WAD / (m as u256)
        }
    }

    public fun from_scaled_val(v: u256): Float {
        Float {
            value: v
        }
    }

    public fun to_scaled_val(v: Float): u256 {
        v.value
    }

    public fun add(a: Float, b: Float): Float {
        Float {
            value: a.value + b.value
        }
    }

    public fun sub(a: Float, b: Float): Float {
        if (b.value > a.value) err_subtrahend_too_large();
        Float {
            value: a.value - b.value
        }
    }

    public fun saturating_sub(a: Float, b: Float): Float {
        if (a.value < b.value) {
            Float { value: 0 }
        } else {
            Float { value: a.value - b.value }
        }
    }

    public fun mul(a: Float, b: Float): Float {
        Float {
            value: (a.value * b.value) / WAD
        }
    }


    public fun div(a: Float, b: Float): Float {
        if (b.to_scaled_val() == 0) err_divided_by_zero();
        Float {
            value: (a.value * WAD) / b.value
        }
    }

    public fun add_u64(a: Float, b: u64): Float {
        a.add(from(b))
    }

    public fun sub_u64(a: Float, b: u64): Float {
        a.add(from(b))
    }

    public fun saturating_sub_u64(a: Float, b: u64): Float {
        a.saturating_sub(from(b))
    }

    public fun mul_u64(a: Float, b: u64): Float {
        a.mul(from(b))
    }

    public fun div_u64(a: Float, b: u64): Float {
        a.div(from(b))
    }

    public fun pow(b: Float, mut e: u64): Float {
        let mut cur_base = b;
        let mut result = from(1);

        while (e > 0) {
            if (e % 2 == 1) {
                result = mul(result, cur_base);
            };
            cur_base = mul(cur_base, cur_base);
            e = e / 2;
        };

        result
    }

    public fun floor(a: Float): u64 {
        ((a.value / WAD) as u64)
    }

    public fun ceil(a: Float): u64 {
        (((a.value + WAD - 1) / WAD) as u64)
    }

    public fun eq(a: Float, b: Float): bool {
        a.value == b.value
    }

    public fun ge(a: Float, b: Float): bool {
        a.value >= b.value
    }

    public fun gt(a: Float, b: Float): bool {
        a.value > b.value
    }

    public fun le(a: Float, b: Float): bool {
        a.value <= b.value
    }

    public fun lt(a: Float, b: Float): bool {
        a.value < b.value
    }

    public fun min(a: Float, b: Float): Float {
        if (a.value < b.value) {
            a
        } else {
            b
        }
    }

    public fun max(a: Float, b: Float): Float {
        if (a.value > b.value) {
            a
        } else {
            b
        }
    }

    public fun wad(): u256 { WAD }

    #[test]
    fun test_basic() {
        let a = from(1);
        let b = from(2);

        assert!(add(a, b) == from(3), 0);
        assert!(sub(b, a) == from(1), 0);
        assert!(mul(a, b) == from(2), 0);
        assert!(div(b, a) == from(2), 0);
        assert!(floor(from_percent(150)) == 1, 0);
        assert!(ceil(from_percent(150)) == 2, 0);
        assert!(lt(a, b), 0);
        assert!(gt(b, a), 0);
        assert!(le(a, b), 0);
        assert!(ge(b, a), 0);
        assert!(saturating_sub(a, b) == from(0), 0);
        assert!(saturating_sub(b, a) == from(1), 0);
    }

    #[test]
    fun test_pow() {
        assert!(pow(from(5), 4) == from(625), 0);
        assert!(pow(from(3), 0) == from(1), 0);
        assert!(pow(from(3), 1) == from(3), 0);
        assert!(pow(from(3), 7) == from(2187), 0);
        assert!(pow(from(3), 8) == from(6561), 0);
    }
}
