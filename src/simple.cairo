#[starknet::interface]
trait ISimpleResolverDelegation<TContractState> {
    fn domain_to_address(
        self: @TContractState, domain: array::Array::<felt252>
    ) -> starknet::ContractAddress;
    fn claim_name(ref self: TContractState, name: felt252);
    fn transfer_name(ref self: TContractState, name: felt252, new_owner: starknet::ContractAddress);
}

#[starknet::contract]
mod SimpleResolverDelegation {
    use array::ArrayTrait;
    use debug::PrintTrait;

    use starknet::get_caller_address;
    use starknet::contract_address_const;
    use starknet::ContractAddress;

    #[storage]
    struct Storage {
        name_owners: LegacyMap::<felt252, ContractAddress>,
    }

    #[external(v0)]
    impl SimpleResolverDelegationImpl of super::ISimpleResolverDelegation<ContractState> {
        fn domain_to_address(self: @ContractState, domain: Array<felt252>) -> ContractAddress {
            assert(domain.len() == 1_u32, 'Domain must have a length of 1');
            self.name_owners.read(*domain.at(0_u32))
        }

        fn claim_name(ref self: ContractState, name: felt252) {
            let owner = self.name_owners.read(name);
            assert(owner == contract_address_const::<0>(), 'Name is already taken');
            let caller = get_caller_address();
            self.name_owners.write(name, caller);
        }

        fn transfer_name(ref self: ContractState, name: felt252, new_owner: ContractAddress) {
            let owner = self.name_owners.read(name);
            let caller = get_caller_address();
            assert(owner == caller, 'Caller is not owner');
            self.name_owners.write(name, new_owner);
        }
    }
}
