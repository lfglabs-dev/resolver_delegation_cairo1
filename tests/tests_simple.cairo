use array::ArrayTrait;
use debug::PrintTrait;
use clone::Clone;
use zeroable::Zeroable;

use starknet::ContractAddress;
use starknet::contract_address_const;
use starknet::testing::set_caller_address;

use resolver_delegation::simple::SimpleResolverDelegation;

const ENCODED_NAME : felt252 = 1426911989;

//
// Helpers
//

fn setup() -> ContractAddress {
    let account: ContractAddress = contract_address_const::<123>();
    set_caller_address(account);
    account
}

//
// Tests
//

#[test]
#[available_gas(2000000)]
fn test_claim_name() {
    let account = setup();

    let mut name = ArrayTrait::<felt252>::new();
    name.append(ENCODED_NAME);

    // Should resolve to 123 because we'll register it (with the encoded domain "thomas").
    let prev_owner = SimpleResolverDelegation::domain_to_address(name.clone());
    assert(prev_owner.is_zero(), 'owner should be 0');

    let success = SimpleResolverDelegation::claim_name(ENCODED_NAME);
    assert (success, 'claim should return true');

    let owner = SimpleResolverDelegation::domain_to_address(name.clone());
    assert (owner == account, 'owner should be the 123');

    // Should resolve to 456 because we'll change the resolving value (with the encoded domain "thomas").
    let new_owner = contract_address_const::<456>();
    let success = SimpleResolverDelegation::transfer_name(ENCODED_NAME, new_owner);
    assert(success, 'transfer should return true');

    let owner = SimpleResolverDelegation::domain_to_address(name);
    assert (owner == new_owner, 'owner should be 456');
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('domain must have a length of 1', ))]
fn test_domain_to_address_wrong_length() {
    let mut name = ArrayTrait::<felt252>::new();
    name.append(ENCODED_NAME);
    name.append(ENCODED_NAME);
    // Should fail because the domain is not of length 1.
    let owner = SimpleResolverDelegation::domain_to_address(name);
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('name is already taken', ))]
fn test_claim_name_already_taken() {
    set_caller_address(contract_address_const::<123>());
    let success = SimpleResolverDelegation::claim_name(ENCODED_NAME);
    assert (success, 'claim should return true');

    // Should fail because the domain is already taken.
    set_caller_address(contract_address_const::<456>());
    SimpleResolverDelegation::claim_name(ENCODED_NAME);
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('caller is not owner', ))]
fn test_transfer_name_not_owner() {
    set_caller_address(contract_address_const::<123>());
    let success = SimpleResolverDelegation::claim_name(ENCODED_NAME);
    assert (success, 'claim should return true');

    // Should fail because caller is not owner of domain and cannot transfer it
    set_caller_address(contract_address_const::<456>());
    SimpleResolverDelegation::transfer_name(ENCODED_NAME, contract_address_const::<789>());
}