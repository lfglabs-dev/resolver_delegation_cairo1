use debug::PrintTrait;
use integer::{u256, u256_from_felt252};

use cheatcodes::RevertedTransactionTrait;

//
// Tests
//

#[test]
fn test_get_amount_of_chars_braavos() {
    // Should return 0 (empty string)
    assert(braavos::business_logic::utils::_get_amount_of_chars(u256 { low: 0, high: 0}) == 0, 'Should return 0');

    // Should return 4 ("toto")
    assert(braavos::business_logic::utils::_get_amount_of_chars(u256 { low: 796195, high: 0}) == 4, 'Should return 4');

    // Should return 5 ("aloha")
    assert(braavos::business_logic::utils::_get_amount_of_chars(u256 { low: 77554770, high: 0}) == 5, 'Should return 5');

    // Should return 9 ("chocolate")
    assert(braavos::business_logic::utils::_get_amount_of_chars(u256 { low: 19565965532212, high: 0}) == 9, 'Should return 9');

    // Should return 30 ("这来abcdefghijklmopqrstuvwyq1234")
    assert(braavos::business_logic::utils::_get_amount_of_chars(u256_from_felt252(801855144733576077820330221438165587969903898313)) == 30, 'Should return 30');
} 

#[test]
fn test_get_amount_of_chars_argent() {
    // Should return 0 (empty string)
    assert(argent::business_logic::utils::_get_amount_of_chars(u256 { low: 0, high: 0}) == 0, 'Should return 0');

    // Should return 4 ("toto")
    assert(argent::business_logic::utils::_get_amount_of_chars(u256 { low: 796195, high: 0}) == 4, 'Should return 4');

    // Should return 5 ("aloha")
    assert(argent::business_logic::utils::_get_amount_of_chars(u256 { low: 77554770, high: 0}) == 5, 'Should return 5');

    // Should return 9 ("chocolate")
    assert(argent::business_logic::utils::_get_amount_of_chars(u256 { low: 19565965532212, high: 0}) == 9, 'Should return 9');

    // Should return 30 ("这来abcdefghijklmopqrstuvwyq1234")
    assert(argent::business_logic::utils::_get_amount_of_chars(u256_from_felt252(801855144733576077820330221438165587969903898313)) == 30, 'Should return 30');
} 