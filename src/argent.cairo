#[starknet::interface]
trait IArgentResolverDelegation<TContractState> {
    fn open_registration(ref self: TContractState);
    fn close_registration(ref self: TContractState);
    fn set_wl_class_hash(ref self: TContractState, new_class_hash: felt252);
    fn set_admin(ref self: TContractState, new_admin: starknet::ContractAddress);
    fn upgrade(ref self: TContractState, impl_hash: starknet::class_hash::ClassHash);
    fn claim_name(ref self: TContractState, name: felt252);
    fn transfer_name(ref self: TContractState, name: felt252, new_owner: starknet::ContractAddress);
    fn domain_to_address(
        self: @TContractState, domain: array::Array::<felt252>
    ) -> starknet::ContractAddress;
    fn is_registration_open(self: @TContractState) -> bool;
    fn is_class_hash_wl(self: @TContractState, class_hash: felt252) -> bool;
}

#[starknet::contract]
mod ArgentResolverDelegation {
    use array::ArrayTrait;
    use debug::PrintTrait;
    use zeroable::Zeroable;
    use integer::{u256, u128_from_felt252, u256_from_felt252};
    use starknet::class_hash::ClassHash;

    use starknet::get_caller_address;
    use starknet::contract_address_const;
    use starknet::ContractAddress;

    use resolver_delegation::interface::{IProxyWalletDispatcher, IProxyWalletDispatcherTrait};
    use resolver_delegation::utils::_get_amount_of_chars;

    #[storage]
    struct Storage {
        _name_owners: LegacyMap::<felt252, ContractAddress>,
        _is_registration_open: bool,
        _blacklisted_addresses: LegacyMap::<ContractAddress, bool>,
        _is_class_hash_wl: LegacyMap::<felt252, bool>,
        _admin_address: ContractAddress,
    }

    //
    // Events
    //

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        domain_to_addr_update: domain_to_addr_update,
    }

    #[derive(Drop, starknet::Event)]
    struct domain_to_addr_update {
        #[key]
        domain: Span<felt252>,
        address: ContractAddress,
    }

    #[constructor]
    fn constructor(ref self: ContractState, admin: ContractAddress) {
        self._admin_address.write(admin);
    }

    #[external(v0)]
    impl ArgentResolverDelegationImpl of super::IArgentResolverDelegation<ContractState> {
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

        fn set_wl_class_hash(ref self: ContractState, new_class_hash: felt252) {
            self._check_admin();
            self._is_class_hash_wl.write(new_class_hash, true);
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
            let is_open = self._is_registration_open.read();
            assert(is_open, 'Registration is closed');

            // Check if caller is an Argent wallet
            let caller = get_caller_address();
            self._check_argent_account(caller);

            // Check if name is not taken
            let owner = self._name_owners.read(name);
            assert(owner.is_zero(), 'Name is already taken');

            // Check if name is more than 4 letters (requires alpha-7 for u256 div)
            let number_of_character: felt252 = _get_amount_of_chars(u256_from_felt252(name));
            assert(
                u128_from_felt252(number_of_character) >= 4_u128, 'Name is less than 4 characters'
            );

            // Check if address is not blackisted
            let is_blacklisted = self._blacklisted_addresses.read(caller);
            assert(!is_blacklisted, 'Caller is blacklisted');

            // Write name to storage and blacklist the address
            self._name_owners.write(name, caller);
            self._blacklisted_addresses.write(caller, true);

            let mut name_array = ArrayTrait::<felt252>::new();
            name_array.append(name);
            self
                .emit(
                    Event::domain_to_addr_update(
                        domain_to_addr_update { domain: name_array.span(), address: caller, }
                    )
                )
        }

        fn transfer_name(ref self: ContractState, name: felt252, new_owner: ContractAddress) {
            let owner = self._name_owners.read(name);
            let caller = get_caller_address();
            assert(owner == caller, 'caller is not owner');

            // Check if new owner is an Argent wallet
            self._check_argent_account(new_owner);

            // Change address in storage
            self._name_owners.write(name, new_owner);

            let mut name_array = ArrayTrait::<felt252>::new();
            name_array.append(name);
            let mut name_array = ArrayTrait::<felt252>::new();
            name_array.append(name);
            self
                .emit(
                    Event::domain_to_addr_update(
                        domain_to_addr_update { domain: name_array.span(), address: new_owner, }
                    )
                )
        }

        //
        // View functions
        // 

        fn domain_to_address(
            self: @ContractState, domain: array::Array::<felt252>
        ) -> ContractAddress {
            assert(domain.len() == 1_u32, 'domain must have a length of 1');
            self._name_owners.read(*domain.at(0_u32))
        }

        fn is_registration_open(self: @ContractState) -> bool {
            self._is_registration_open.read()
        }

        fn is_class_hash_wl(self: @ContractState, class_hash: felt252) -> bool {
            self._is_class_hash_wl.read(class_hash)
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

        fn _check_argent_account(self: @ContractState, owner: ContractAddress) {
            let caller_class_hash = IProxyWalletDispatcher { contract_address: owner }
                .get_implementation();
            let is_class_hash_wl = self._is_class_hash_wl.read(caller_class_hash);
            assert(is_class_hash_wl, 'Owner is not an argent wallet');
        }
    }
}

