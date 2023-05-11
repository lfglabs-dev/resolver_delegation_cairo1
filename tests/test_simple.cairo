use array::ArrayTrait;
use debug::PrintTrait;
use result::ResultTrait;
use clone::Clone;
use array::ArrayTCloneImpl;

use starknet::ContractAddress;
use starknet::contract_address_const;
use starknet::testing::set_caller_address;

use simple::contracts::simple::SimpleResolverDelegation;

use cheatcodes::RevertedTransactionTrait;

const ENCODED_NAME : felt252 = 1426911989;

//
// Helpers
//

fn setup() -> (ContractAddress, felt252) {
    let account: ContractAddress = contract_address_const::<123>();
    set_caller_address(account);
    let contract_address = deploy_contract('simple', ArrayTrait::new()).unwrap();
    (account, contract_address)
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
            assert(x.first() == 'error', 'first datum doesnt match');
            assert(*x.panic_data.at(1_u32) == 'data', 'second datum doesnt match');
        }
    }
}

//
// Tests
//

#[test]
#[available_gas(2000000)]
fn test_claim_name() {
    let contract_address = deploy_contract('simple', ArrayTrait::new()).unwrap();

    // Should resolve to 123 because we'll register it (with the encoded domain "thomas").
    assert_domain_to_address(contract_address, ENCODED_NAME, 0);

    start_prank(123, contract_address).unwrap();

    let mut calldata = ArrayTrait::new();
    calldata.append(ENCODED_NAME);
    invoke(contract_address, 'claim_name', calldata).unwrap();
    assert_domain_to_address(contract_address, ENCODED_NAME, 123);

    // Should resolve to 456 because we'll change the resolving value (with the encoded domain "thomas").
    let mut calldata = ArrayTrait::new();
    calldata.append(ENCODED_NAME);
    calldata.append(456);
    invoke(contract_address, 'transfer_name', calldata).unwrap();
    assert_domain_to_address(contract_address, ENCODED_NAME, 456);
}

#[test]
#[available_gas(2000000)]
fn test_claim_name_existing_should_fail() {
    let contract_address = deploy_contract('simple', ArrayTrait::new()).unwrap();

    // Should resolve to 123 because we'll register it (with the encoded domain "thomas").
    assert_domain_to_address(contract_address, ENCODED_NAME, 0);

    start_prank(123, contract_address).unwrap();

    let mut calldata = ArrayTrait::new();
    calldata.append(ENCODED_NAME);
    invoke(contract_address, 'claim_name', calldata).unwrap();
    assert_domain_to_address(contract_address, ENCODED_NAME, 123);

    // Should fail because the name is already registered.
    start_prank(456, contract_address).unwrap();
    let mut calldata = ArrayTrait::new();
    calldata.append(ENCODED_NAME);
    let invoke_result = invoke(contract_address, 'claim_name', calldata);
    assert(invoke_result.is_err(), 'Invoke should fail');
}

