#[starknet::interface]
trait ISimpleResolverDelegation<TContractState> {
    fn domain_to_address(
        self: @TContractState, domain: Span::<felt252>
    ) -> starknet::ContractAddress;
    fn claim_name(ref self: TContractState, name: felt252);
    fn transfer_name(ref self: TContractState, name: felt252, new_owner: starknet::ContractAddress);
}

#[starknet::contract]
mod SimpleResolverDelegation {
    use array::SpanTrait;
    use starknet::{get_caller_address, ContractAddress};
    use starknet::contract_address::ContractAddressZeroable;

    #[storage]
    struct Storage {
        name_owners: LegacyMap::<felt252, ContractAddress>,
    }

    #[external(v0)]
    impl SimpleResolverDelegationImpl of super::ISimpleResolverDelegation<ContractState> {
        fn domain_to_address(self: @ContractState, domain: Span<felt252>) -> ContractAddress {
            assert(domain.len() == 1, 'Domain must have a length of 1');
            self.name_owners.read(*domain.at(0))
        }

        fn claim_name(ref self: ContractState, name: felt252) {
            let owner = self.name_owners.read(name);
            assert(owner == ContractAddressZeroable::zero(), 'Name is already taken');
            self.name_owners.write(name, get_caller_address());
        }

        fn transfer_name(ref self: ContractState, name: felt252, new_owner: ContractAddress) {
            let owner = self.name_owners.read(name);
            assert(owner == get_caller_address(), 'Caller is not owner');
            self.name_owners.write(name, new_owner);
        }
    }
}
