use integer::{u256, u256_from_felt252, u256_as_non_zero, u256_safe_divmod};

fn _get_amount_of_chars(domain: u256) -> felt252 {
    if domain == (u256 { low: 0, high: 0 }) {
        return 0;
    }
    // 38 = simple_alphabet_size
    let (p, q, _) = u256_safe_divmod(domain, u256_as_non_zero(u256 { low: 38, high: 0 }));
    if q == (u256 { low: 37, high: 0 }) {
        // 3 = complex_alphabet_size
        let (shifted_p, _, _) = u256_safe_divmod(p, u256_as_non_zero(u256 { low: 2, high: 0 }));
        let next = _get_amount_of_chars(shifted_p);
        return 1 + next;
    }
    let next = _get_amount_of_chars(p);
    1 + next
}
