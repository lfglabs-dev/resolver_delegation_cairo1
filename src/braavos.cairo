#[contract]
mod BraavosResolverDelegation {
    use array::ArrayTrait;
    use debug::PrintTrait;
    use zeroable::Zeroable;

    // use keccak::u128_split;
    // use integer::u128_try_from_felt252;
    use integer::u256;
    use integer::{u256_from_felt252, u256_safe_divmod, u256_as_non_zero};

    use starknet::get_caller_address;
    use starknet::contract_address_const;
    use starknet::ContractAddress;

    use resolver_delegation::interfaces::IProxyWalletDispatcher;
    use resolver_delegation::interfaces::IProxyWalletDispatcherTrait;

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
    fn domain_to_addr_update(
        domain: Array<felt252>,
        address: ContractAddress,
    ) {}

    //
    // Proxy functions
    //

    #[external]
    fn initializer(admin: ContractAddress) {
        let current_admin = _admin_address::read();
        assert(current_admin.is_zero(), 'admin is already set');

        _admin_address::write(admin);
    }

    // #[external]
    // fn upgrade(new_implementation: felt252) {
    //     // Set contract implementation
    //     _check_admin();
    //     Proxy._set_implementation_hash(new_implementation);
    //     return ();
    // }

    //
    // Admin functions
    //

    #[external]
    fn open_registration() {
        _check_admin();
         _is_registration_open::write(true);
    }

    #[external]
    fn close_registration() {
        _check_admin();
        _is_registration_open::write(false);
    }

    #[external]
    fn set_wl_class_hash(new_class_hash: felt252) {
        _check_admin();
        _is_class_hash_wl::write(new_class_hash, true);
    }

    #[external]
    fn set_admin(new_admin: ContractAddress) {
        _check_admin();
        _admin_address::write(new_admin);
    }

    //
    // User functions
    //

    #[external]
    fn claim_name(name: felt252) -> bool {
        // Check if registration is open
        let is_open = _is_registration_open::read();
        assert(is_open == true, 'registration is closed');

        // TODO: Check if caller is a braavos wallet
        let caller = get_caller_address();
        // let caller_class_hash = IProxyWalletDispatcher {
        //     contract_address: caller
        // }.get_implementation();
        // let is_class_hash_wl = _is_class_hash_wl::read(caller_class_hash);
        // assert(is_class_hash_wl, 'caller is not a braavos wallet');

        // Check if name is not taken
        let owner = _name_owners::read(name);
        assert(owner.is_zero(), 'name is already taken');

        // Check if name is more than 4 letters
        let number_of_character = _get_amount_of_chars(u256_from_felt252(name));
        assert(u256_from_felt252(number_of_character) >= u256_from_felt252(4), 'name is less than 4 characters');

        // Check if address is not blackisted
        let is_blacklisted = _blacklisted_addresses::read(caller);
        assert(!is_blacklisted, 'caller is blacklisted');

        // Write name to storage and blacklist the address
        let mut name_array = ArrayTrait::<felt252>::new();
        name_array.append(name);
        domain_to_addr_update(name_array, caller);
        _name_owners::write(name, caller);
        _blacklisted_addresses::write(caller, true);

        true
    }

    #[external]
    fn transfer_name(name: felt252, new_owner: ContractAddress) -> bool {
        let owner = _name_owners::read(name);
        let caller = get_caller_address();
        assert(owner == caller, 'caller is not owner');

        // TODO: Check if new owner is a braavos wallet
        // let caller_class_hash = IProxyWalletDispatcher {
        //     contract_address: caller
        // }.get_implementation();
        // let is_class_hash_wl = _is_class_hash_wl::read(caller_class_hash);
        // assert(is_class_hash_wl, 'caller is not a braavos wallet');

        // Change address in storage
        let mut name_array = ArrayTrait::<felt252>::new();
        name_array.append(name);
        domain_to_addr_update(name_array, caller);
        _name_owners::write(name, new_owner);
        true
    }

    //
    // View functions
    //

    #[view]
    fn domain_to_address(domain: Array<felt252>) -> ContractAddress {
        assert(domain.len() == 1, 'domain must have a length of 1');
        _name_owners::read(*domain.at(0))
    }

    #[view]
    fn is_registration_open() -> bool {
        _is_registration_open::read()
    }

    #[view]
    fn is_class_hash_wl(class_hash: felt252) -> bool {
        _is_class_hash_wl::read(class_hash)
    }


    //
    // Utils
    //

    fn _check_admin() {
        let caller = get_caller_address();
        let admin = _admin_address::read();
        assert(caller == admin, 'caller is not admin');
    }

    fn _get_amount_of_chars(domain: u256) -> felt252 {
        if domain == (u256 { low: 0, high: 0 }) {
            return 0;
        }
        // 38 = simple_alphabet_size
        let (p, q) = u256_safe_divmod(domain, u256_as_non_zero(u256 { low: 38, high: 0 }));
        if q == (u256 { low: 37, high: 0 }) {
            // 3 = complex_alphabet_size
            let (shifted_p, _) = u256_safe_divmod(p, u256_as_non_zero(u256 { low: 2, high: 0 }));
            let next = _get_amount_of_chars(shifted_p);
            return 1 + next;
        }
        let next = _get_amount_of_chars(p);
        1 + next
    }
}