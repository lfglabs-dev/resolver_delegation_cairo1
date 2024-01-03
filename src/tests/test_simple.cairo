use array::ArrayTrait;
use debug::PrintTrait;
use zeroable::Zeroable;

use starknet::ContractAddress;
use starknet::testing;

use resolver_delegation::simple::{
    SimpleResolverDelegation, ISimpleResolverDelegation, ISimpleResolverDelegationDispatcher,
    ISimpleResolverDelegationDispatcherTrait
};
use naming::interface::resolver::{IResolver, IResolverDispatcher, IResolverDispatcherTrait};

use super::constants::{ENCODED_NAME, USER, ZERO, OTHER};
use super::utils;

//
// Helpers
//

fn setup() -> (IResolverDispatcher, ISimpleResolverDelegationDispatcher) {
    let address = utils::deploy(
        SimpleResolverDelegation::TEST_CLASS_HASH, ArrayTrait::<felt252>::new()
    );
    (
        IResolverDispatcher { contract_address: address },
        ISimpleResolverDelegationDispatcher { contract_address: address }
    )
}

fn assert_domain_to_address(
    argent_resolver: IResolverDispatcher, domain: felt252, expected: ContractAddress
) {
    let owner = argent_resolver.resolve(array![domain].span(), 'starknet', array![].span());
    assert(owner == expected.into(), 'Owner should be expected');
}

//
// Tests
//

#[test]
#[available_gas(2000000)]
fn test_claim_transfer_name() {
    let (simple_resolver, contract_part) = setup();
    testing::set_caller_address(USER());
    testing::set_contract_address(USER());

    // Should resolve to 123 because we'll register it (with the encoded domain "thomas").
    assert_domain_to_address(simple_resolver, ENCODED_NAME(), ZERO());
    contract_part.claim_name(ENCODED_NAME());
    assert_domain_to_address(simple_resolver, ENCODED_NAME(), USER());

    // Should resolve to 456 because we'll change the resolving value (with the encoded domain "thomas").
    contract_part.transfer_name(ENCODED_NAME(), OTHER());
    assert_domain_to_address(simple_resolver, ENCODED_NAME(), OTHER());
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Name is already taken', 'ENTRYPOINT_FAILED',))]
fn test_claim_taken_name_should_fail() {
    let (simple_resolver, contract_part) = setup();
    testing::set_caller_address(USER());
    testing::set_contract_address(USER());

    // Should resolve to 123 because we'll register it (with the encoded domain "thomas").
    assert_domain_to_address(simple_resolver, ENCODED_NAME(), ZERO());
    contract_part.claim_name(ENCODED_NAME());
    assert_domain_to_address(simple_resolver, ENCODED_NAME(), USER());

    // Should fail because the name is already registered.
    testing::set_caller_address(OTHER());
    testing::set_contract_address(OTHER());
    contract_part.claim_name(ENCODED_NAME());
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Caller is not owner', 'ENTRYPOINT_FAILED',))]
fn test_transfer_name_not_owner_should_fail() {
    let (simple_resolver, contract_part) = setup();
    testing::set_caller_address(USER());
    testing::set_contract_address(USER());

    // Should resolve to 123 because we'll register it (with the encoded domain "thomas").
    assert_domain_to_address(simple_resolver, ENCODED_NAME(), ZERO());
    contract_part.claim_name(ENCODED_NAME());
    assert_domain_to_address(simple_resolver, ENCODED_NAME(), USER());

    // Transfer name should fail because the caller is not the owner.
    testing::set_caller_address(OTHER());
    testing::set_contract_address(OTHER());
    contract_part.transfer_name(ENCODED_NAME(), OTHER());
}
