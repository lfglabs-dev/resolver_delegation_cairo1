use array::ArrayTrait;
use debug::PrintTrait;
use result::ResultTrait;
use clone::Clone;
use array::ArrayTCloneImpl;

use starknet::ContractAddress;
use starknet::contract_address_const;
use starknet::testing::set_caller_address;

use argent::contracts::argent::ArgentResolverDelegation;

use cheatcodes::RevertedTransactionTrait;

const THOMAS_ENCODED : felt252 = 1426911989;
const MOTTY_ENCODED : felt252 = 1426911989;
const WL_CLASS_HASH : felt252 = 11111;

//
// Helpers
//

// todo: should deploy with proxy
fn setup_and_init() -> felt252 {
    // deploy argent contract
    let contract_address = deploy_contract('argent', ArrayTrait::new()).unwrap();

    // initialize contract
    let mut calldata = ArrayTrait::new();
    calldata.append(123);
    invoke(contract_address, 'initializer', calldata).unwrap();

    start_prank(123, contract_address).unwrap();

    // Open registration 
    invoke(contract_address, 'open_registration', ArrayTrait::new()).unwrap();

    // set wl class hash
    let mut calldata = ArrayTrait::new();
    calldata.append(WL_CLASS_HASH);
    invoke(contract_address, 'set_wl_class_hash', calldata).unwrap();

    stop_prank(123).unwrap();

    contract_address
}

fn assert_domain_to_address(contract_address: felt252, domain: felt252, expected: felt252) {
    let mut calldata = ArrayTrait::new();
    calldata.append(1);
    calldata.append(domain);
    match call(contract_address, 'domain_to_address', calldata) {
        Result::Ok(prev_owner) => {
            assert(*prev_owner.at(0_u32) == expected, 'Owner should be expected')
        },
        Result::Err(x) => {
            assert(false, 'domain_to_address reverted');
        }
    }
}

//
// Tests
//

#[test]
#[available_gas(2000000)]
fn test_claim_name() {
    let contract_address = setup_and_init();
    start_prank(123, contract_address).unwrap();

    // Should resolve to 123 because we'll register it (with the encoded domain "thomas").
    assert_domain_to_address(contract_address, THOMAS_ENCODED, 0);

    let mut calldata = ArrayTrait::new();
    calldata.append(THOMAS_ENCODED);
    invoke(contract_address, 'claim_name', calldata).unwrap();
    assert_domain_to_address(contract_address, THOMAS_ENCODED, 123);

    // Should resolve to 456 because we'll change the resolving value (with the encoded domain "thomas").
    let mut calldata = ArrayTrait::new();
    calldata.append(THOMAS_ENCODED);
    calldata.append(456);
    invoke(contract_address, 'transfer_name', calldata).unwrap();
    assert_domain_to_address(contract_address, THOMAS_ENCODED, 456);

    stop_prank(123).unwrap();
}

// todo: test names with less than 4 characters with alpha-7
// #[test]
// #[available_gas(2000000)]
// fn test_claim_not_allowed_name() {
//     let contract_address = setup_and_init();
//     start_prank(123, contract_address).unwrap();

//     // Should revert because of names are less than 4 chars (with the encoded domain "ben").
//     let mut calldata = ArrayTrait::new();
//     calldata.append(18925);
//     let invoke_result = invoke(contract_address, 'claim_name', calldata);
//     assert(invoke_result.is_err(), 'claim_name should fail');

//     stop_prank(123).unwrap();
// }

#[test]
#[available_gas(2000000)]
fn test_claim_taken_name_should_fail() {
    let contract_address = setup_and_init();
    start_prank(123, contract_address).unwrap();

    let mut calldata = ArrayTrait::new();
    calldata.append(THOMAS_ENCODED);
    invoke(contract_address, 'claim_name', calldata).unwrap();

    stop_prank(123).unwrap();
    start_prank(456, contract_address).unwrap();

    // Should revert because the name is taken (with the encoded domain "thomas").
    let mut calldata = ArrayTrait::new();
    calldata.append(THOMAS_ENCODED);
    let invoke_result = invoke(contract_address, 'claim_name', calldata);
    assert(invoke_result.is_err(), 'claim_name should fail');

    stop_prank(456).unwrap();
}

#[test]
#[available_gas(2000000)]
fn test_claim_two_names_should_fail() {
    let contract_address = setup_and_init();
    start_prank(123, contract_address).unwrap();

    let mut calldata = ArrayTrait::new();
    calldata.append(THOMAS_ENCODED);
    invoke(contract_address, 'claim_name', calldata).unwrap();

    // Should revert because the name is taken (with the encoded domain "thomas" and "motty").
    let mut calldata = ArrayTrait::new();
    calldata.append(MOTTY_ENCODED);
    let invoke_result = invoke(contract_address, 'claim_name', calldata);
    assert(invoke_result.is_err(), 'claim_name should fail');

    stop_prank(123).unwrap();
}

#[test]
#[available_gas(2000000)]
fn test_open_registration() {
    // deploy argent contract
    let contract_address = deploy_contract('argent', ArrayTrait::new()).unwrap();

    // initialize contract
    let mut calldata = ArrayTrait::new();
    calldata.append(123);
    invoke(contract_address, 'initializer', calldata).unwrap();

    start_prank(123, contract_address).unwrap();

    // set wl class hash
    let mut calldata = ArrayTrait::new();
    calldata.append(WL_CLASS_HASH);
    invoke(contract_address, 'set_wl_class_hash', calldata).unwrap();

    // Should revert because the registration is closed (with the encoded domain "thomas").
    let mut calldata = ArrayTrait::new();
    calldata.append(THOMAS_ENCODED);
    let invoke_result = invoke(contract_address, 'claim_name', calldata);
    assert(invoke_result.is_err(), 'claim_name should fail');

    stop_prank(123).unwrap();
}

// todo: uncomment when we can check if owner is an argent contract in wallet
// #[test]
// #[available_gas(2000000)]
// fn test_implementation_class_hash_not_set() {
//     // deploy argent contract
//     let contract_address = deploy_contract('argent', ArrayTrait::new()).unwrap();

//     // initialize contract
//     let mut calldata = ArrayTrait::new();
//     calldata.append(123);
//     invoke(contract_address, 'initializer', calldata).unwrap();

//     start_prank(123, contract_address).unwrap();

//     // Open registration 
//     invoke(contract_address, 'open_registration', ArrayTrait::new()).unwrap();

//     // Should revert because the implementation class hash is not set (with the encoded domain "thomas").
//     let mut calldata = ArrayTrait::new();
//     calldata.append(THOMAS_ENCODED);
//     let invoke_result = invoke(contract_address, 'claim_name', calldata);
//     assert(invoke_result.is_err(), 'claim_name should fail');
    
//     stop_prank(123).unwrap();
// }

// todo: uncomment when we can check if owner is a argent contract in wallet
// #[test]
// #[available_gas(2000000)]
// fn test_implementation_class_hash_not_whitelisted() {
//     let contract_address = setup_and_init();
//     start_prank(123, contract_address).unwrap();

//     // Should revert because the implementation class hash of the receiver is not whitelisted.
//     let mut calldata = ArrayTrait::new();
//     calldata.append(THOMAS_ENCODED);
//     let invoke_result = invoke(contract_address, 'claim_name', calldata);
//     assert(invoke_result.is_err(), 'claim_name should fail');
    
//     stop_prank(123).unwrap();
// }
