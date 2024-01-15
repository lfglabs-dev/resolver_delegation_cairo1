#[starknet::interface]
trait IBraavosResolverDelegation<TContractState> {
    fn open_registration(ref self: TContractState);
    fn close_registration(ref self: TContractState);
    fn set_admin(ref self: TContractState, new_admin: starknet::ContractAddress);
    fn upgrade(ref self: TContractState, impl_hash: starknet::class_hash::ClassHash);
    fn claim_name(ref self: TContractState, name: felt252);
    fn claim_name_for(ref self: TContractState, name: felt252, address: starknet::ContractAddress);
    fn transfer_name(ref self: TContractState, name: felt252, new_owner: starknet::ContractAddress);
    fn is_registration_open(self: @TContractState) -> bool;
}

#[starknet::contract]
mod BraavosResolverDelegation {
    use core::traits::Into;
    use array::SpanTrait;
    use zeroable::Zeroable;

    use starknet::{get_caller_address, ContractAddress};
    use starknet::class_hash::ClassHash;

    use resolver_delegation::interface::{IBraavosWalletDispatcher, IBraavosWalletDispatcherTrait};
    use resolver_delegation::utils::_get_amount_of_chars;
    use naming::interface::resolver::IResolver;
    use debug::PrintTrait;


    #[storage]
    struct Storage {
        _name_owners: LegacyMap::<felt252, ContractAddress>,
        _is_registration_open: bool,
        _blacklisted_addresses: LegacyMap::<ContractAddress, bool>,
        _admin_address: ContractAddress,
    }

    //
    // Events
    //

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

    #[constructor]
    fn constructor(ref self: ContractState, admin: ContractAddress) {
        self._admin_address.write(admin);
    }


    #[external(v0)]
    impl AdditionResolveImpl of IResolver<ContractState> {
        fn resolve(
            self: @ContractState, mut domain: Span<felt252>, field: felt252, hint: Span<felt252>
        ) -> felt252 {
            assert(domain.len() == 1, 'Domain must have a length of 1');
            assert(field == 'starknet', 'Not supported');
            self._name_owners.read(*domain.at(0)).into()
        }
    }

    #[external(v0)]
    impl BraavosResolverDelegationImpl of super::IBraavosResolverDelegation<ContractState> {
        //
        // Admin functions
        //
        fn open_registration(ref self: ContractState) {
            self._check_admin();
            self._is_registration_open.write(true);
        }

        fn close_registration(ref self: ContractState) {
            self._check_admin();
            self._is_registration_open.write(false);
        }

        fn set_admin(ref self: ContractState, new_admin: ContractAddress) {
            self._check_admin();
            self._admin_address.write(new_admin);
        }

        fn upgrade(ref self: ContractState, impl_hash: ClassHash) {
            self._check_admin();
            // todo: use components
            assert(!impl_hash.is_zero(), 'Class hash cannot be zero');
            starknet::replace_class_syscall(impl_hash).unwrap();
        }

        //
        // User functions
        //

        fn claim_name(ref self: ContractState, name: felt252) {
            // Check if registration is open
            assert(self._is_registration_open.read(), 'Registration is closed');

            // Check if caller is a braavos wallet
            let caller = get_caller_address();
            self._check_braavos_account(caller);

            // Check if name is not taken
            let owner = self._name_owners.read(name);
            assert(owner.is_zero(), 'Name is already taken');

            // Check if name is more than 4 letters (requires alpha-7 for u256 div)
            let number_of_chars = _get_amount_of_chars(name.into());
            assert(number_of_chars >= 4, 'Name is less than 4 characters');

            // Check if address is not blackisted
            let is_blacklisted = self._blacklisted_addresses.read(caller);
            assert(!is_blacklisted, 'Caller is blacklisted');

            // Write name to storage and blacklist the address
            self._name_owners.write(name, caller);
            self._blacklisted_addresses.write(caller, true);

            self
                .emit(
                    Event::DomainToAddressUpdate(
                        DomainToAddressUpdate { domain: array![name].span(), address: caller, }
                    )
                )
        }

        fn claim_name_for(ref self: ContractState, name: felt252, address: ContractAddress) {
            // Check if registration is open
            let is_open = self._is_registration_open.read();
            assert(is_open, 'Registration is closed');

            // Check if receiver is a braavos wallet
            let caller = get_caller_address();
            self._check_braavos_account(caller);

            // Check if name is not taken
            let owner = self._name_owners.read(name);
            assert(owner.is_zero(), 'name is already taken');

            // Check if name is more than 4 letters (requires alpha-7 for u256 div)
            let number_of_chars = _get_amount_of_chars(name.into());
            assert(number_of_chars >= 4, 'Name is less than 4 characters');

            // Check if address is not blackisted
            let is_blacklisted = self._blacklisted_addresses.read(address);
            assert(!is_blacklisted, 'address is blacklisted');

            // Write name to storage and blacklist the address
            self._name_owners.write(name, address);
            self._blacklisted_addresses.write(address, true);

            self
                .emit(
                    Event::DomainToAddressUpdate(
                        DomainToAddressUpdate { domain: array![name].span(), address, }
                    )
                )
        }

        fn transfer_name(ref self: ContractState, name: felt252, new_owner: ContractAddress) {
            let owner = self._name_owners.read(name);
            let caller = get_caller_address();
            assert(owner == caller, 'caller is not owner');

            // Check if new owner is a braavos wallet
            let caller = get_caller_address();
            self._check_braavos_account(caller);

            // Change address in storage
            self._name_owners.write(name, new_owner);

            self
                .emit(
                    Event::DomainToAddressUpdate(
                        DomainToAddressUpdate { domain: array![name].span(), address: new_owner, }
                    )
                )
        }

        //
        // View functions
        // 

        fn is_registration_open(self: @ContractState) -> bool {
            self._is_registration_open.read()
        }
    }

    //
    // Internals
    //

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn _check_admin(self: @ContractState) {
            let caller = get_caller_address();
            let admin = self._admin_address.read();
            assert(caller == admin, 'caller is not admin');
        }

        fn _check_braavos_account(self: @ContractState, owner: ContractAddress) {
            // would panic because entrypoint doesn't exist on other wallets
            IBraavosWalletDispatcher { contract_address: owner }.get_impl_version();
        }
    }
}
