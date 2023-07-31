use array::ArrayTrait;
use debug::PrintTrait;
use zeroable::Zeroable;
use traits::Into;

use starknet::ContractAddress;
use starknet::testing;

use resolver_delegation::braavos::{
    BraavosResolverDelegation, IBraavosResolverDelegation, IBraavosResolverDelegationDispatcher,
    IBraavosResolverDelegationDispatcherTrait
};

use super::mocks::proxy_wallet::{
    ProxyWallet, IProxyWallet, IProxyWalletDispatcher, IProxyWalletDispatcherTrait,
};
use super::constants::{
    ENCODED_NAME, OTHER_NAME, OWNER, USER, ZERO, OTHER, WL_CLASS_HASH, OTHER_WL_CLASS_HASH,
    CLASS_HASH_ZERO, NEW_CLASS_HASH
};
use super::utils;

//
// Helpers
//

#[cfg(test)]
fn setup() -> IBraavosResolverDelegationDispatcher {
    let mut calldata = ArrayTrait::<felt252>::new();
    calldata.append(OWNER().into());
    let address = utils::deploy(BraavosResolverDelegation::TEST_CLASS_HASH, calldata);
    IBraavosResolverDelegationDispatcher { contract_address: address }
}

#[cfg(test)]
fn deploy_proxy_wallet() -> IProxyWalletDispatcher {
    let address = utils::deploy(ProxyWallet::TEST_CLASS_HASH, ArrayTrait::<felt252>::new());
    IProxyWalletDispatcher { contract_address: address }
}

#[cfg(test)]
fn assert_domain_to_address(
    braavos_resolver: IBraavosResolverDelegationDispatcher,
    domain: felt252,
    expected: ContractAddress
) {
    let mut calldata = ArrayTrait::<felt252>::new();
    calldata.append(domain);
    let owner = braavos_resolver.domain_to_address(calldata);
    assert(owner == expected, 'Owner should be expected');
}

//
// Tests
//

#[cfg(test)]
#[test]
#[available_gas(200000000)]
fn test_claim_transfer_name() {
    let braavos_resolver = setup();
    let account = deploy_proxy_wallet();
    let other_account = deploy_proxy_wallet();

    // Open registration & set class hash whitelisted
    testing::set_caller_address(OWNER());
    testing::set_contract_address(OWNER());
    braavos_resolver.open_registration();
    braavos_resolver.set_wl_class_hash(WL_CLASS_HASH());

    testing::set_caller_address(account.contract_address);
    testing::set_contract_address(account.contract_address);

    // Should resolve to 123 because we'll register it (with the encoded domain "thomas").
    assert_domain_to_address(braavos_resolver, ENCODED_NAME(), ZERO());
    braavos_resolver.claim_name(ENCODED_NAME());
    assert_domain_to_address(braavos_resolver, ENCODED_NAME(), account.contract_address);

    // Should resolve to 456 because we'll change the resolving value (with the encoded domain "thomas").
    braavos_resolver.transfer_name(ENCODED_NAME(), other_account.contract_address);
    assert_domain_to_address(braavos_resolver, ENCODED_NAME(), other_account.contract_address);
}

#[cfg(test)]
#[test]
#[available_gas(200000000)]
#[should_panic(expected: ('Name is less than 4 characters', 'ENTRYPOINT_FAILED', ))]
fn test_claim_not_allowed_name() {
    let braavos_resolver = setup();
    let account = deploy_proxy_wallet();

    // Open registration & set class hash whitelisted
    testing::set_caller_address(OWNER());
    testing::set_contract_address(OWNER());
    braavos_resolver.open_registration();
    braavos_resolver.set_wl_class_hash(WL_CLASS_HASH());

    // Should revert because of names are less than 4 chars (with the encoded domain "ben").
    testing::set_caller_address(account.contract_address);
    testing::set_contract_address(account.contract_address);
    let encoded_ben = 18925;
    braavos_resolver.claim_name(encoded_ben);
}

#[cfg(test)]
#[test]
#[available_gas(200000000)]
#[should_panic(expected: ('Name is already taken', 'ENTRYPOINT_FAILED', ))]
fn test_claim_taken_name_should_fail() {
    let braavos_resolver = setup();
    let account = deploy_proxy_wallet();
    let other_account = deploy_proxy_wallet();

    // Open registration & set class hash whitelisted
    testing::set_caller_address(OWNER());
    testing::set_contract_address(OWNER());
    braavos_resolver.open_registration();
    braavos_resolver.set_wl_class_hash(WL_CLASS_HASH());

    // Should resolve to 123 because we'll register it (with the encoded domain "thomas").
    testing::set_caller_address(account.contract_address);
    testing::set_contract_address(account.contract_address);
    braavos_resolver.claim_name(ENCODED_NAME());
    assert_domain_to_address(braavos_resolver, ENCODED_NAME(), account.contract_address);

    // Should revert because the name is taken (with the encoded domain "thomas").
    testing::set_caller_address(other_account.contract_address);
    testing::set_contract_address(other_account.contract_address);
    braavos_resolver.claim_name(ENCODED_NAME());
}

#[cfg(test)]
#[test]
#[available_gas(200000000)]
#[should_panic(expected: ('Caller is blacklisted', 'ENTRYPOINT_FAILED', ))]
fn test_claim_two_names_should_fail() {
    let braavos_resolver = setup();
    let account = deploy_proxy_wallet();
    let other_account = deploy_proxy_wallet();

    // Open registration & set class hash whitelisted
    testing::set_caller_address(OWNER());
    testing::set_contract_address(OWNER());
    braavos_resolver.open_registration();
    braavos_resolver.set_wl_class_hash(WL_CLASS_HASH());

    // Should resolve to 123 because we'll register it (with the encoded domain "thomas").
    testing::set_caller_address(account.contract_address);
    testing::set_contract_address(account.contract_address);
    braavos_resolver.claim_name(ENCODED_NAME());
    assert_domain_to_address(braavos_resolver, ENCODED_NAME(), account.contract_address);

    // Should revert because the name is taken (with the encoded domain "thomas").
    braavos_resolver.claim_name(OTHER_NAME());
}

#[cfg(test)]
#[test]
#[available_gas(200000000)]
#[should_panic(expected: ('Registration is closed', 'ENTRYPOINT_FAILED', ))]
fn test_open_registration() {
    let braavos_resolver = setup();
    let account = deploy_proxy_wallet();

    // Open registration & set class hash whitelisted
    testing::set_caller_address(OWNER());
    testing::set_contract_address(OWNER());
    braavos_resolver.set_wl_class_hash(WL_CLASS_HASH());

    // Should revert because the registration is closed (with the encoded domain "thomas").
    testing::set_caller_address(account.contract_address);
    testing::set_contract_address(account.contract_address);
    braavos_resolver.claim_name(ENCODED_NAME());
}

#[cfg(test)]
#[test]
#[available_gas(200000000)]
#[should_panic(expected: ('Caller is not a braavos wallet', 'ENTRYPOINT_FAILED', ))]
fn test_implementation_class_hash_not_set() {
    let braavos_resolver = setup();
    let account = deploy_proxy_wallet();

    // Open registration & set class hash whitelisted
    testing::set_caller_address(OWNER());
    testing::set_contract_address(OWNER());
    braavos_resolver.open_registration();

    // Should revert because the implementation class hash is not set
    testing::set_caller_address(account.contract_address);
    testing::set_contract_address(account.contract_address);
    braavos_resolver.claim_name(ENCODED_NAME());
}

#[cfg(test)]
#[test]
#[available_gas(200000000)]
#[should_panic(expected: ('Caller is not a braavos wallet', 'ENTRYPOINT_FAILED', ))]
fn test_implementation_class_hash_not_whitelisted() {
    let braavos_resolver = setup();
    let account = deploy_proxy_wallet();

    // Open registration & set class hash whitelisted
    testing::set_caller_address(OWNER());
    testing::set_contract_address(OWNER());
    braavos_resolver.open_registration();
    braavos_resolver.set_wl_class_hash(OTHER_WL_CLASS_HASH());

    // Should revert because the implementation class hash is not set
    testing::set_caller_address(account.contract_address);
    testing::set_contract_address(account.contract_address);
    braavos_resolver.claim_name(ENCODED_NAME());
}

#[cfg(test)]
#[test]
#[available_gas(200000000)]
fn test_change_implementation_class_hash() {
    let braavos_resolver = setup();

    // Open registration & set class hash whitelisted
    testing::set_caller_address(OWNER());
    testing::set_contract_address(OWNER());
    braavos_resolver.open_registration();
    braavos_resolver.set_wl_class_hash(OTHER_WL_CLASS_HASH());

    // Should change implementation class hash
    braavos_resolver.upgrade(NEW_CLASS_HASH());
}

#[cfg(test)]
#[test]
#[available_gas(200000000)]
#[should_panic(expected: ('caller is not admin', 'ENTRYPOINT_FAILED', ))]
fn test_change_implementation_class_hash_not_admin() {
    let braavos_resolver = setup();

    // Open registration & set class hash whitelisted
    testing::set_caller_address(OWNER());
    testing::set_contract_address(OWNER());
    braavos_resolver.open_registration();
    braavos_resolver.set_wl_class_hash(OTHER_WL_CLASS_HASH());

    // Should revert because the caller is not admin of the contract
    testing::set_caller_address(USER());
    testing::set_contract_address(USER());
    braavos_resolver.upgrade(NEW_CLASS_HASH());
}


#[cfg(test)]
#[test]
#[available_gas(200000000)]
#[should_panic(expected: ('Class hash cannot be zero', 'ENTRYPOINT_FAILED', ))]
fn test_change_implementation_class_hash_0_failed() {
    let braavos_resolver = setup();

    // Open registration & set class hash whitelisted
    testing::set_caller_address(OWNER());
    testing::set_contract_address(OWNER());
    braavos_resolver.open_registration();
    braavos_resolver.set_wl_class_hash(OTHER_WL_CLASS_HASH());

    // Should revert because the implementation class hash cannot be zero
    braavos_resolver.upgrade(CLASS_HASH_ZERO());
}
