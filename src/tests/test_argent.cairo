use array::ArrayTrait;
use debug::PrintTrait;
use zeroable::Zeroable;
use traits::Into;

use starknet::ContractAddress;
use starknet::testing;

use resolver_delegation::argent::{
    ArgentResolverDelegation, IArgentResolverDelegation, IArgentResolverDelegationDispatcher,
    IArgentResolverDelegationDispatcherTrait
};

use super::mocks::proxy_wallet::{
    ProxyWallet, IProxyWallet, IProxyWalletDispatcher, IProxyWalletDispatcherTrait,
};
use super::constants::{
    ENCODED_NAME, OTHER_NAME, OWNER, USER, ZERO, OTHER, WL_CLASS_HASH, OTHER_WL_CLASS_HASH,
    NEW_CLASS_HASH, CLASS_HASH_ZERO
};
use super::utils;

//
// Helpers
//

#[cfg(test)]
fn setup() -> IArgentResolverDelegationDispatcher {
    let mut calldata = ArrayTrait::<felt252>::new();
    calldata.append(OWNER().into());
    let address = utils::deploy(ArgentResolverDelegation::TEST_CLASS_HASH, calldata);
    IArgentResolverDelegationDispatcher { contract_address: address }
}

#[cfg(test)]
fn deploy_proxy_wallet() -> IProxyWalletDispatcher {
    let address = utils::deploy(ProxyWallet::TEST_CLASS_HASH, ArrayTrait::<felt252>::new());
    IProxyWalletDispatcher { contract_address: address }
}

#[cfg(test)]
fn assert_domain_to_address(
    argent_resolver: IArgentResolverDelegationDispatcher, domain: felt252, expected: ContractAddress
) {
    let mut calldata = ArrayTrait::<felt252>::new();
    calldata.append(domain);
    let owner = argent_resolver.domain_to_address(calldata);
    assert(owner == expected, 'Owner should be expected');
}

//
// Tests
//

#[cfg(test)]
#[test]
#[available_gas(200000000)]
fn test_claim_transfer_name() {
    let argent_resolver = setup();
    let account = deploy_proxy_wallet();
    let other_account = deploy_proxy_wallet();

    // Open registration & set class hash whitelisted
    testing::set_caller_address(OWNER());
    testing::set_contract_address(OWNER());
    argent_resolver.open_registration();
    argent_resolver.set_wl_class_hash(WL_CLASS_HASH());

    testing::set_caller_address(account.contract_address);
    testing::set_contract_address(account.contract_address);

    // Should resolve to 123 because we'll register it (with the encoded domain "thomas").
    assert_domain_to_address(argent_resolver, ENCODED_NAME(), ZERO());
    argent_resolver.claim_name(ENCODED_NAME());
    assert_domain_to_address(argent_resolver, ENCODED_NAME(), account.contract_address);

    // Should resolve to 456 because we'll change the resolving value (with the encoded domain "thomas").
    argent_resolver.transfer_name(ENCODED_NAME(), other_account.contract_address);
    assert_domain_to_address(argent_resolver, ENCODED_NAME(), other_account.contract_address);
}

#[cfg(test)]
#[test]
#[available_gas(200000000)]
#[should_panic(expected: ('Name is less than 4 characters', 'ENTRYPOINT_FAILED', ))]
fn test_claim_not_allowed_name() {
    let argent_resolver = setup();
    let account = deploy_proxy_wallet();

    // Open registration & set class hash whitelisted
    testing::set_caller_address(OWNER());
    testing::set_contract_address(OWNER());
    argent_resolver.open_registration();
    argent_resolver.set_wl_class_hash(WL_CLASS_HASH());

    // Should revert because of names are less than 4 chars (with the encoded domain "ben").
    testing::set_caller_address(account.contract_address);
    testing::set_contract_address(account.contract_address);
    let encoded_ben = 18925;
    argent_resolver.claim_name(encoded_ben);
}

#[cfg(test)]
#[test]
#[available_gas(200000000)]
#[should_panic(expected: ('Name is already taken', 'ENTRYPOINT_FAILED', ))]
fn test_claim_taken_name_should_fail() {
    let argent_resolver = setup();
    let account = deploy_proxy_wallet();
    let other_account = deploy_proxy_wallet();

    // Open registration & set class hash whitelisted
    testing::set_caller_address(OWNER());
    testing::set_contract_address(OWNER());
    argent_resolver.open_registration();
    argent_resolver.set_wl_class_hash(WL_CLASS_HASH());

    // Should resolve to 123 because we'll register it (with the encoded domain "thomas").
    testing::set_caller_address(account.contract_address);
    testing::set_contract_address(account.contract_address);
    argent_resolver.claim_name(ENCODED_NAME());
    assert_domain_to_address(argent_resolver, ENCODED_NAME(), account.contract_address);

    // Should revert because the name is taken (with the encoded domain "thomas").
    testing::set_caller_address(other_account.contract_address);
    testing::set_contract_address(other_account.contract_address);
    argent_resolver.claim_name(ENCODED_NAME());
}

#[cfg(test)]
#[test]
#[available_gas(200000000)]
#[should_panic(expected: ('Caller is blacklisted', 'ENTRYPOINT_FAILED', ))]
fn test_claim_two_names_should_fail() {
    let argent_resolver = setup();
    let account = deploy_proxy_wallet();
    let other_account = deploy_proxy_wallet();

    // Open registration & set class hash whitelisted
    testing::set_caller_address(OWNER());
    testing::set_contract_address(OWNER());
    argent_resolver.open_registration();
    argent_resolver.set_wl_class_hash(WL_CLASS_HASH());

    // Should resolve to 123 because we'll register it (with the encoded domain "thomas").
    testing::set_caller_address(account.contract_address);
    testing::set_contract_address(account.contract_address);
    argent_resolver.claim_name(ENCODED_NAME());
    assert_domain_to_address(argent_resolver, ENCODED_NAME(), account.contract_address);

    // Should revert because the name is taken (with the encoded domain "thomas").
    argent_resolver.claim_name(OTHER_NAME());
}

#[cfg(test)]
#[test]
#[available_gas(200000000)]
#[should_panic(expected: ('Registration is closed', 'ENTRYPOINT_FAILED', ))]
fn test_open_registration() {
    let argent_resolver = setup();
    let account = deploy_proxy_wallet();

    // Open registration & set class hash whitelisted
    testing::set_caller_address(OWNER());
    testing::set_contract_address(OWNER());
    argent_resolver.set_wl_class_hash(WL_CLASS_HASH());

    // Should revert because the registration is closed (with the encoded domain "thomas").
    testing::set_caller_address(account.contract_address);
    testing::set_contract_address(account.contract_address);
    argent_resolver.claim_name(ENCODED_NAME());
}

#[cfg(test)]
#[test]
#[available_gas(200000000)]
#[should_panic(expected: ('Owner is not an argent wallet', 'ENTRYPOINT_FAILED', ))]
fn test_implementation_class_hash_not_set() {
    let argent_resolver = setup();
    let account = deploy_proxy_wallet();

    // Open registration & set class hash whitelisted
    testing::set_caller_address(OWNER());
    testing::set_contract_address(OWNER());
    argent_resolver.open_registration();

    // Should revert because the implementation class hash is not set
    testing::set_caller_address(account.contract_address);
    testing::set_contract_address(account.contract_address);
    argent_resolver.claim_name(ENCODED_NAME());
}

#[cfg(test)]
#[test]
#[available_gas(200000000)]
#[should_panic(expected: ('Owner is not an argent wallet', 'ENTRYPOINT_FAILED', ))]
fn test_implementation_class_hash_not_whitelisted() {
    let argent_resolver = setup();
    let account = deploy_proxy_wallet();

    // Open registration & set class hash whitelisted
    testing::set_caller_address(OWNER());
    testing::set_contract_address(OWNER());
    argent_resolver.open_registration();
    argent_resolver.set_wl_class_hash(OTHER_WL_CLASS_HASH());

    // Should revert because the implementation class hash is not set
    testing::set_caller_address(account.contract_address);
    testing::set_contract_address(account.contract_address);
    argent_resolver.claim_name(ENCODED_NAME());
}

#[cfg(test)]
#[test]
#[available_gas(200000000)]
fn test_change_implementation_class_hash() {
    let argent_resolver = setup();

    // Open registration & set class hash whitelisted
    testing::set_caller_address(OWNER());
    testing::set_contract_address(OWNER());
    argent_resolver.open_registration();
    argent_resolver.set_wl_class_hash(OTHER_WL_CLASS_HASH());

    // Should change implementation class hash
    argent_resolver.upgrade(NEW_CLASS_HASH());
}

#[cfg(test)]
#[test]
#[available_gas(200000000)]
#[should_panic(expected: ('caller is not admin', 'ENTRYPOINT_FAILED', ))]
fn test_change_implementation_class_hash_not_admin() {
    let argent_resolver = setup();

    // Open registration & set class hash whitelisted
    testing::set_caller_address(OWNER());
    testing::set_contract_address(OWNER());
    argent_resolver.open_registration();
    argent_resolver.set_wl_class_hash(OTHER_WL_CLASS_HASH());

    // Should revert because the caller is not admin of the contract
    testing::set_caller_address(USER());
    testing::set_contract_address(USER());
    argent_resolver.upgrade(NEW_CLASS_HASH());
}


#[cfg(test)]
#[test]
#[available_gas(200000000)]
#[should_panic(expected: ('Class hash cannot be zero', 'ENTRYPOINT_FAILED', ))]
fn test_change_implementation_class_hash_0_failed() {
    let argent_resolver = setup();

    // Open registration & set class hash whitelisted
    testing::set_caller_address(OWNER());
    testing::set_contract_address(OWNER());
    argent_resolver.open_registration();
    argent_resolver.set_wl_class_hash(OTHER_WL_CLASS_HASH());

    // Should revert because the implementation class hash cannot be zero
    argent_resolver.upgrade(CLASS_HASH_ZERO());
}
