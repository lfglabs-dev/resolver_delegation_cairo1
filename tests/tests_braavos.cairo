use array::ArrayTrait;
use debug::PrintTrait;
use clone::Clone;
use zeroable::Zeroable;

use starknet::ContractAddress;
use starknet::contract_address_const;
use starknet::testing::set_caller_address;

use resolver_delegation::braavos::BraavosResolverDelegation;

const ENCODED_NAME : felt252 = 1426911989;

//
// Helpers
//

fn setup() -> ContractAddress {
    let account: ContractAddress = contract_address_const::<123>();
    set_caller_address(account);

    BraavosResolverDelegation::initializer(account);
    account
}

#[test]
#[available_gas(2000000)]
fn test_claim_name() {
    let account: ContractAddress = setup();

    BraavosResolverDelegation::open_registration(); 
    BraavosResolverDelegation::set_wl_class_hash(456); 

    let mut name = ArrayTrait::<felt252>::new();
    name.append(ENCODED_NAME);

    // Should resolve to 123 because we'll register it (with the encoded domain "thomas").
    let prev_owner = BraavosResolverDelegation::domain_to_address(name.clone());
    assert(prev_owner.is_zero(), 'name already registered');

    let success = BraavosResolverDelegation::claim_name(ENCODED_NAME); 
    assert(success, 'claim_name failed');

    let owner = BraavosResolverDelegation::domain_to_address(name.clone());
    assert(owner == account, 'name not registered');

    // Should resolve to 456 because we'll change the resolving value (with the encoded domain "thomas").
    let new_owner = contract_address_const::<456>();
    let success = BraavosResolverDelegation::transfer_name(ENCODED_NAME, new_owner);
    assert(success, 'transfer_name failed');

    let owner = BraavosResolverDelegation::domain_to_address(name.clone());
    assert(owner == new_owner, 'name not registered');
}