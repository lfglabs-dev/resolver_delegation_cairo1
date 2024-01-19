use array::{ArrayTrait, SpanTrait};
use debug::PrintTrait;
use zeroable::Zeroable;
use traits::Into;

use starknet::ContractAddress;
use starknet::testing;

use resolver_delegation::braavos::{
    BraavosResolverDelegation, IBraavosResolverDelegation, IBraavosResolverDelegationDispatcher,
    IBraavosResolverDelegationDispatcherTrait
};
use naming::interface::resolver::{IResolver, IResolverDispatcher, IResolverDispatcherTrait};

use super::mocks::wallets::{
    ArgentWallet, IArgentWallet, IArgentWalletDispatcher, IArgentWalletDispatcherTrait,
};
use super::mocks::wallets::{
    BraavosWallet, IBraavosWallet, IBraavosWalletDispatcher, IBraavosWalletDispatcherTrait,
};
use super::constants::{
    ENCODED_NAME, OTHER_NAME, OWNER, USER, ZERO, OTHER, WL_CLASS_HASH, OTHER_WL_CLASS_HASH,
    CLASS_HASH_ZERO, NEW_CLASS_HASH
};
use super::utils;

//
// Helpers
//

fn setup() -> (IResolverDispatcher, IBraavosResolverDelegationDispatcher) {
    let address = utils::deploy(BraavosResolverDelegation::TEST_CLASS_HASH, array![OWNER().into()]);
    (
        IResolverDispatcher { contract_address: address },
        IBraavosResolverDelegationDispatcher { contract_address: address }
    )
}

fn deploy_braavos_wallet() -> IBraavosWalletDispatcher {
    let address = utils::deploy(BraavosWallet::TEST_CLASS_HASH, ArrayTrait::<felt252>::new());
    IBraavosWalletDispatcher { contract_address: address }
}

fn deploy_argent_wallet() -> IArgentWalletDispatcher {
    let address = utils::deploy(ArgentWallet::TEST_CLASS_HASH, ArrayTrait::<felt252>::new());
    IArgentWalletDispatcher { contract_address: address }
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
#[available_gas(200000000)]
fn test_claim_transfer_name() {
    let (braavos_resolver, contract_part) = setup();
    let account = deploy_braavos_wallet();
    let other_account = deploy_braavos_wallet();

    // Open registration & set class hash whitelisted
    testing::set_contract_address(OWNER());
    contract_part.open_registration();

    testing::set_caller_address(account.contract_address);
    testing::set_contract_address(account.contract_address);

    // Should resolve to 123 because we'll register it (with the encoded domain "thomas").
    assert_domain_to_address(braavos_resolver, ENCODED_NAME(), ZERO());
    contract_part.claim_name(ENCODED_NAME());
    assert_domain_to_address(braavos_resolver, ENCODED_NAME(), account.contract_address);

    // Should resolve to 456 because we'll change the resolving value (with the encoded domain "thomas").
    contract_part.transfer_name(ENCODED_NAME(), other_account.contract_address);
    assert_domain_to_address(braavos_resolver, ENCODED_NAME(), other_account.contract_address);
}

#[test]
#[available_gas(200000000)]
#[should_panic(expected: ('Name is less than 4 characters', 'ENTRYPOINT_FAILED',))]
fn test_claim_not_allowed_name() {
    let (braavos_resolver, contract_part) = setup();
    let account = deploy_braavos_wallet();

    // Open registration & set class hash whitelisted
    testing::set_contract_address(OWNER());
    contract_part.open_registration();

    // Should revert because of names are less than 4 chars (with the encoded domain "ben").
    testing::set_contract_address(account.contract_address);
    let encoded_ben = 18925;
    contract_part.claim_name(encoded_ben);
}

#[test]
#[available_gas(200000000)]
#[should_panic(expected: ('Name is already taken', 'ENTRYPOINT_FAILED',))]
fn test_claim_taken_name_should_fail() {
    let (braavos_resolver, contract_part) = setup();
    let account = deploy_braavos_wallet();
    let other_account = deploy_braavos_wallet();

    // Open registration & set class hash whitelisted
    testing::set_contract_address(OWNER());
    contract_part.open_registration();

    // Should resolve to 123 because we'll register it (with the encoded domain "thomas").
    testing::set_contract_address(account.contract_address);
    contract_part.claim_name(ENCODED_NAME());
    assert_domain_to_address(braavos_resolver, ENCODED_NAME(), account.contract_address);

    // Should revert because the name is taken (with the encoded domain "thomas").
    testing::set_contract_address(other_account.contract_address);
    contract_part.claim_name(ENCODED_NAME());
}

#[test]
#[available_gas(200000000)]
#[should_panic(expected: ('Caller is blacklisted', 'ENTRYPOINT_FAILED',))]
fn test_claim_two_names_should_fail() {
    let (braavos_resolver, contract_part) = setup();
    let account = deploy_braavos_wallet();
    let other_account = deploy_braavos_wallet();

    // Open registration & set class hash whitelisted
    testing::set_contract_address(OWNER());
    contract_part.open_registration();

    // Should resolve to 123 because we'll register it (with the encoded domain "thomas").
    testing::set_contract_address(account.contract_address);
    contract_part.claim_name(ENCODED_NAME());
    assert_domain_to_address(braavos_resolver, ENCODED_NAME(), account.contract_address);

    // Should revert because the name is taken (with the encoded domain "thomas").
    contract_part.claim_name(OTHER_NAME());
}

#[test]
#[available_gas(200000000)]
#[should_panic(expected: ('Registration is closed', 'ENTRYPOINT_FAILED',))]
fn test_open_registration() {
    let (braavos_resolver, contract_part) = setup();
    let account = deploy_braavos_wallet();

    // Open registration & set class hash whitelisted
    testing::set_contract_address(OWNER());

    // Should revert because the registration is closed (with the encoded domain "thomas").
    testing::set_contract_address(account.contract_address);
    contract_part.claim_name(ENCODED_NAME());
}

#[test]
#[available_gas(200000000)]
#[should_panic(expected: ('Not a Braavos wallet', 'ENTRYPOINT_FAILED',))]
fn test_wrong_wallet() {
    let (braavos_resolver, contract_part) = setup();
    let account = deploy_argent_wallet();

    // Open registration & set class hash whitelisted
    testing::set_contract_address(OWNER());
    contract_part.open_registration();

    // Should revert because the implementation class hash is not set
    testing::set_contract_address(account.contract_address);
    contract_part.claim_name(ENCODED_NAME());
}

// doesn't seem to work in tests, tested on deployment
// #[test]
// #[available_gas(200000000)]
// fn test_change_implementation_class_hash() {
//     let (braavos_resolver, contract_part) = setup();

//     // Open registration & set class hash whitelisted
//     testing::set_contract_address(OWNER());
//     contract_part.open_registration();

//     // Should change implementation class hash
//     contract_part.upgrade(NEW_CLASS_HASH());
// }

#[test]
#[available_gas(200000000)]
#[should_panic(expected: ('caller is not admin', 'ENTRYPOINT_FAILED',))]
fn test_change_implementation_class_hash_not_admin() {
    let (braavos_resolver, contract_part) = setup();

    // Open registration & set class hash whitelisted
    testing::set_contract_address(OWNER());
    contract_part.open_registration();

    // Should revert because the caller is not admin of the contract
    testing::set_contract_address(USER());
    contract_part.upgrade(NEW_CLASS_HASH());
}


#[test]
#[available_gas(200000000)]
#[should_panic(expected: ('Class hash cannot be zero', 'ENTRYPOINT_FAILED',))]
fn test_change_implementation_class_hash_0_failed() {
    let (braavos_resolver, contract_part) = setup();

    // Open registration & set class hash whitelisted
    testing::set_contract_address(OWNER());
    contract_part.open_registration();

    // Should revert because the implementation class hash cannot be zero
    contract_part.upgrade(CLASS_HASH_ZERO());
}
