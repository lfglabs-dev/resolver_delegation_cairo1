use array::ArrayTrait;
use debug::PrintTrait;
use zeroable::Zeroable;

use starknet::ContractAddress;
use starknet::testing;

use resolver_delegation::simple::{
    SimpleResolverDelegation, ISimpleResolverDelegation, ISimpleResolverDelegationDispatcher,
    ISimpleResolverDelegationDispatcherTrait
};

use super::constants::{ENCODED_NAME, USER, ZERO, OTHER};
use super::utils;

//
// Helpers
//

#[cfg(test)]
fn setup() -> ISimpleResolverDelegationDispatcher {
    let address = utils::deploy(
        SimpleResolverDelegation::TEST_CLASS_HASH, ArrayTrait::<felt252>::new()
    );
    ISimpleResolverDelegationDispatcher { contract_address: address }
}

#[cfg(test)]
fn assert_domain_to_address(
    simple_resolver: ISimpleResolverDelegationDispatcher, domain: felt252, expected: ContractAddress
) {
    let mut calldata = ArrayTrait::<felt252>::new();
    calldata.append(domain);
    let owner = simple_resolver.domain_to_address(calldata);
    assert(owner == expected, 'Owner should be expected');
}

//
// Tests
//

#[cfg(test)]
#[test]
#[available_gas(2000000)]
fn test_claim_transfer_name() {
    let simple_resolver = setup();
    testing::set_caller_address(USER());
    testing::set_contract_address(USER());

    // Should resolve to 123 because we'll register it (with the encoded domain "thomas").
    assert_domain_to_address(simple_resolver, ENCODED_NAME(), ZERO());
    simple_resolver.claim_name(ENCODED_NAME());
    assert_domain_to_address(simple_resolver, ENCODED_NAME(), USER());

    // Should resolve to 456 because we'll change the resolving value (with the encoded domain "thomas").
    simple_resolver.transfer_name(ENCODED_NAME(), OTHER());
    assert_domain_to_address(simple_resolver, ENCODED_NAME(), OTHER());
}

#[cfg(test)]
#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Name is already taken', 'ENTRYPOINT_FAILED', ))]
fn test_claim_taken_name_should_fail() {
    let simple_resolver = setup();
    testing::set_caller_address(USER());
    testing::set_contract_address(USER());

    // Should resolve to 123 because we'll register it (with the encoded domain "thomas").
    assert_domain_to_address(simple_resolver, ENCODED_NAME(), ZERO());
    simple_resolver.claim_name(ENCODED_NAME());
    assert_domain_to_address(simple_resolver, ENCODED_NAME(), USER());

    // Should fail because the name is already registered.
    testing::set_caller_address(OTHER());
    testing::set_contract_address(OTHER());
    simple_resolver.claim_name(ENCODED_NAME());
}

#[cfg(test)]
#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Caller is not owner', 'ENTRYPOINT_FAILED', ))]
fn test_transfer_name_not_owner_should_fail() {
    let simple_resolver = setup();
    testing::set_caller_address(USER());
    testing::set_contract_address(USER());

    // Should resolve to 123 because we'll register it (with the encoded domain "thomas").
    assert_domain_to_address(simple_resolver, ENCODED_NAME(), ZERO());
    simple_resolver.claim_name(ENCODED_NAME());
    assert_domain_to_address(simple_resolver, ENCODED_NAME(), USER());

    // Transfer name should fail because the caller is not the owner.
    testing::set_caller_address(OTHER());
    testing::set_contract_address(OTHER());
    simple_resolver.transfer_name(ENCODED_NAME(), OTHER());
}
