#[starknet::interface]
trait ISimpleResolverDelegation<TContractState> {
    fn claim_name(ref self: TContractState, name: felt252);
    fn transfer_name(ref self: TContractState, name: felt252, new_owner: starknet::ContractAddress);
}

#[starknet::contract]
mod SimpleResolverDelegation {
    use array::SpanTrait;
    use starknet::storage::{
        StoragePointerReadAccess, StoragePointerWriteAccess, StoragePathEntry, Map
    };
    use starknet::{get_caller_address, ContractAddress};
    use starknet::contract_address::ContractAddressZeroable;
    use naming::interface::resolver::IResolver;

    #[storage]
    struct Storage {
        name_owners: Map::<felt252, ContractAddress>,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        DomainToAddressUpdate: DomainToAddressUpdate,
    }

    #[derive(Drop, starknet::Event)]
    struct DomainToAddressUpdate {
        #[key]
        domain: Span<felt252>,
        address: ContractAddress,
    }

    #[abi(embed_v0)]
    impl AdditionResolveImpl of IResolver<ContractState> {
        fn resolve(
            self: @ContractState, mut domain: Span<felt252>, field: felt252, hint: Span<felt252>
        ) -> felt252 {
            assert(domain.len() == 1, 'Domain must have a length of 1');
            assert(field == 'starknet', 'Not supported');
            self.name_owners.read(*domain.at(0)).into()
        }
    }

    #[abi(embed_v0)]
    impl SimpleResolverDelegationImpl of super::ISimpleResolverDelegation<ContractState> {
        fn claim_name(ref self: ContractState, name: felt252) {
            let owner = self.name_owners.read(name);
            assert(owner == ContractAddressZeroable::zero(), 'Name is already taken');
            let caller = get_caller_address();
            self.name_owners.write(name, caller);
            self
                .emit(
                    Event::DomainToAddressUpdate(
                        DomainToAddressUpdate { domain: array![name].span(), address: caller, }
                    )
                )
        }

        fn transfer_name(ref self: ContractState, name: felt252, new_owner: ContractAddress) {
            let owner = self.name_owners.read(name);
            assert(owner == get_caller_address(), 'Caller is not owner');
            self.name_owners.write(name, new_owner);
        }
    }
}
