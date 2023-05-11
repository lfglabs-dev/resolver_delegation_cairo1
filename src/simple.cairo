#[contract]
mod SimpleResolverDelegation {
    use array::ArrayTrait;
    use debug::PrintTrait;

    use starknet::get_caller_address;
    use starknet::contract_address_const;
    use starknet::ContractAddress;

    struct Storage {
        name_owners: LegacyMap::<felt252, ContractAddress>,
    }

    #[view]
    fn domain_to_address(domain: Array<felt252>) -> ContractAddress {
        assert(domain.len() == 1, 'domain must have a length of 1');
        name_owners::read(*domain.at(0))
    }

    #[external]
    fn claim_name(name: felt252) -> bool {
        let owner = name_owners::read(name);
        assert(owner == contract_address_const::<0>(), 'name is already taken');
        let caller = get_caller_address();
        name_owners::write(name, caller);
        true
    }

    #[external]
    fn transfer_name(name: felt252, new_owner: ContractAddress) -> bool {
        let owner = name_owners::read(name);
        let caller = get_caller_address();
        assert(owner == caller, 'caller is not owner');
        name_owners::write(name, new_owner);
        true
    }
}