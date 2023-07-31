#[starknet::interface]
trait IBraavosResolverDelegation<TContractState> {
    fn open_registration(ref self: TContractState);
    fn close_registration(ref self: TContractState);
    fn set_wl_class_hash(ref self: TContractState, new_class_hash: felt252);
    fn set_admin(ref self: TContractState, new_admin: starknet::ContractAddress);
    fn upgrade(ref self: TContractState, impl_hash: starknet::class_hash::ClassHash);
    fn upgrade_and_call(
        ref self: TContractState,
        impl_hash: starknet::class_hash::ClassHash,
        selector: felt252,
        calldata: Array<felt252>
    );
    fn claim_name(ref self: TContractState, name: felt252);
    fn claim_name_for(ref self: TContractState, name: felt252, address: starknet::ContractAddress);
    fn transfer_name(ref self: TContractState, name: felt252, new_owner: starknet::ContractAddress);
    fn domain_to_address(
        self: @TContractState, domain: array::Array::<felt252>
    ) -> starknet::ContractAddress;
    fn is_registration_open(self: @TContractState) -> bool;
    fn is_class_hash_wl(self: @TContractState, class_hash: felt252) -> bool;
}

#[starknet::contract]
mod BraavosResolverDelegation {
    use array::ArrayTrait;
    use debug::PrintTrait;
    use zeroable::Zeroable;
    use integer::{u256, u128_from_felt252, u256_from_felt252};

    use starknet::get_caller_address;
    use starknet::contract_address_const;
    use starknet::ContractAddress;
    use starknet::class_hash::ClassHash;

    use resolver_delegation::interface::{IProxyWalletDispatcher, IProxyWalletDispatcherTrait};
    use resolver_delegation::utils::_get_amount_of_chars;
    use resolver_delegation::upgrades::upgradeable::Upgradeable;

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
        domain: Array<felt252>,
        address: ContractAddress,
    }

    #[constructor]
    fn constructor(ref self: ContractState, admin: ContractAddress) {
        self._admin_address.write(admin);
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
            let mut unsafe_state = Upgradeable::unsafe_new_contract_state();
            Upgradeable::InternalImpl::_upgrade(ref unsafe_state, impl_hash);
        }

        fn upgrade_and_call(
            ref self: ContractState,
            impl_hash: ClassHash,
            selector: felt252,
            calldata: Array<felt252>
        ) {
            self._check_admin();
            let mut unsafe_state = Upgradeable::unsafe_new_contract_state();
            Upgradeable::InternalImpl::_upgrade_and_call(
                ref unsafe_state, impl_hash, selector, calldata.span()
            );
        }

        //
        // User functions
        //

        fn claim_name(ref self: ContractState, name: felt252) {
            // Check if registration is open
            let is_open = self._is_registration_open.read();
            assert(is_open, 'Registration is closed');

            // Check if caller is a braavos wallet
            let caller = get_caller_address();
            let caller_class_hash = IProxyWalletDispatcher {
                contract_address: caller
            }.get_implementation();
            let is_class_hash_wl = self._is_class_hash_wl.read(caller_class_hash);
            assert(is_class_hash_wl, 'Caller is not a braavos wallet');

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
                        domain_to_addr_update { domain: name_array, address: caller,  }
                    )
                )
        }

        fn claim_name_for(
            ref self: ContractState, name: felt252, address: starknet::ContractAddress
        ) {
            // Check if registration is open
            let is_open = self._is_registration_open.read();
            assert(is_open, 'Registration is closed');

            // Check if receiver is a braavos wallet
            let caller_class_hash = IProxyWalletDispatcher {
                contract_address: address
            }.get_implementation();
            let is_class_hash_wl = self._is_class_hash_wl.read(caller_class_hash);
            assert(is_class_hash_wl, 'Receiver not a braavos wallet');

            // Check if name is not taken
            let owner = self._name_owners.read(name);
            assert(owner.is_zero(), 'name is already taken');

            // Check if name is more than 4 letters (requires alpha-7 for u256 div)
            let number_of_character: felt252 = _get_amount_of_chars(u256_from_felt252(name));
            assert(
                u128_from_felt252(number_of_character) >= 4_u128, 'Name is less than 4 characters'
            );

            // Check if address is not blackisted
            let is_blacklisted = self._blacklisted_addresses.read(address);
            assert(!is_blacklisted, 'address is blacklisted');

            // Write name to storage and blacklist the address
            self._name_owners.write(name, address);
            self._blacklisted_addresses.write(address, true);

            let mut name_array = ArrayTrait::<felt252>::new();
            name_array.append(name);
            self
                .emit(
                    Event::domain_to_addr_update(
                        domain_to_addr_update { domain: name_array, address,  }
                    )
                )
        }

        fn transfer_name(ref self: ContractState, name: felt252, new_owner: ContractAddress) {
            let owner = self._name_owners.read(name);
            let caller = get_caller_address();
            assert(owner == caller, 'caller is not owner');

            // Check if new owner is a braavos wallet
            let caller_class_hash = IProxyWalletDispatcher {
                contract_address: new_owner
            }.get_implementation();
            let is_class_hash_wl = self._is_class_hash_wl.read(caller_class_hash);
            assert(is_class_hash_wl, 'new_owner not a braavos wallet');

            // Change address in storage
            self._name_owners.write(name, new_owner);

            let mut name_array = ArrayTrait::<felt252>::new();
            name_array.append(name);
            let mut name_array = ArrayTrait::<felt252>::new();
            name_array.append(name);
            self
                .emit(
                    Event::domain_to_addr_update(
                        domain_to_addr_update { domain: name_array, address: new_owner,  }
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
    }
//
// Proxy functions
//

// #[external]
// fn initializer(admin: ContractAddress) {
//     let current_admin = _admin_address::read();
//     assert(current_admin.is_zero(), 'admin is already set');
//     _admin_address::write(admin);
// }

// todo: upgrade function
// #[external]
// fn upgrade(new_implementation: felt252) {
//     // Set contract implementation
//     _check_admin();
//     Proxy._set_implementation_hash(new_implementation);
// }

//
// Admin functions
//

// #[external]
// fn open_registration() {
//     _check_admin();
//     _is_registration_open::write(true);
// }

// #[external]
// fn close_registration() {
//     _check_admin();
//     _is_registration_open::write(false);
// }

// #[external]
// fn set_wl_class_hash(new_class_hash: felt252) {
//     _check_admin();
//     _is_class_hash_wl::write(new_class_hash, true);
// }

// #[external]
// fn set_admin(new_admin: ContractAddress) {
//     _check_admin();
//     _admin_address::write(new_admin);
// }

//
// User functions
//

// #[external]
// fn claim_name(name: felt252) -> bool {
//     // Check if registration is open
//     let is_open = _is_registration_open::read();
//     assert(is_open, 'registration is closed');

//     // Check if caller is a braavos wallet
//     let caller = get_caller_address();
//     // todo: commented for testing purposes as we cannot mock w/ current protostar version
//     // let caller_class_hash = IProxyWalletDispatcher {
//     //     contract_address: caller
//     // }.get_implementation();
//     // let is_class_hash_wl = _is_class_hash_wl::read(caller_class_hash);
//     // assert(is_class_hash_wl, 'caller is not a braavos wallet');

//     // Check if name is not taken
//     let owner = _name_owners::read(name);
//     assert(owner.is_zero(), 'name is already taken');

//     // Check if name is more than 4 letters (requires alpha-7 for u256 div)
//     let number_of_character = _get_amount_of_chars(u256_from_felt252(name));
//     assert(
//         u256_from_felt252(number_of_character) >= u256_from_felt252(4),
//         'name is less than 4 characters'
//     );

//     // Check if address is not blackisted
//     let is_blacklisted = _blacklisted_addresses::read(caller);
//     assert(!is_blacklisted, 'caller is blacklisted');

//     // Write name to storage and blacklist the address
//     _name_owners::write(name, caller);
//     _blacklisted_addresses::write(caller, true);
//     let mut name_array = ArrayTrait::<felt252>::new();
//     name_array.append(name);
//     domain_to_addr_update(name_array, caller);
//     true
// }

// #[external]
// fn transfer_name(name: felt252, new_owner: ContractAddress) -> bool {
//     let owner = _name_owners::read(name);
//     let caller = get_caller_address();
//     assert(owner == caller, 'caller is not owner');

//     // Check if new owner is a braavos wallet
//     // todo: commented for testing purposes as we cannot mock w/ current protostar version
//     // let caller_class_hash = IProxyWalletDispatcher {
//     //     contract_address: new_owner
//     // }.get_implementation();
//     // let is_class_hash_wl = _is_class_hash_wl::read(caller_class_hash);
//     // assert(is_class_hash_wl, 'new_owner is not a braavos wallet');

//     // Change address in storage
//     _name_owners::write(name, new_owner);
//     let mut name_array = ArrayTrait::<felt252>::new();
//     name_array.append(name);
//     domain_to_addr_update(name_array, caller);
//     true
// }

//
// View functions
//

// #[view]
// fn domain_to_address(domain: Array<felt252>) -> ContractAddress {
//     assert(domain.len() == 1_u32, 'domain must have a length of 1');
//     _name_owners::read(*domain.at(0_u32))
// }

// #[view]
// fn is_registration_open() -> bool {
//     _is_registration_open::read()
// }

// #[view]
// fn is_class_hash_wl(class_hash: felt252) -> bool {
//     _is_class_hash_wl::read(class_hash)
// }
// //
// // Utils
// //

// fn _check_admin() {
//     let caller = get_caller_address();
//     let admin = _admin_address::read();
//     assert(caller == admin, 'caller is not admin');
// }
}
