use starknet::testing;
use resolver_delegation::utils::_get_amount_of_chars;

#[cfg(test)]
#[test]
#[available_gas(20000000000)]
fn test_get_amount_of_chars() {
    // Should return 0 (empty string)
    assert(_get_amount_of_chars(u256 { low: 0, high: 0 }) == 0, 'Should return 0');

    // Should return 4 ("toto")
    assert(_get_amount_of_chars(u256 { low: 796195, high: 0 }) == 4, 'Should return 4');

    // Should return 5 ("aloha")
    assert(_get_amount_of_chars(u256 { low: 77554770, high: 0 }) == 5, 'Should return 5');

    // Should return 9 ("chocolate")
    assert(_get_amount_of_chars(u256 { low: 19565965532212, high: 0 }) == 9, 'Should return 9');

    // Should return 30 ("这来abcdefghijklmopqrstuvwyq1234")
    assert(
        _get_amount_of_chars(
            integer::u256_from_felt252(801855144733576077820330221438165587969903898313)
        ) == 30,
        'Should return 30'
    );
}
