#[starknet::interface]
trait IProxyWallet<TContractState> {
    fn get_implementation(self: @TContractState) -> felt252;
}

#[starknet::interface]
trait MockProxyWalletABI<TContractState> {
    fn get_implementation(self: @TContractState) -> felt252;
}

#[starknet::contract]
mod ProxyWallet {
    use super::IProxyWallet;
    use zeroable::Zeroable;
    use resolver_delegation::tests::constants::WL_CLASS_HASH;

    //
    // Storage
    //

    #[storage]
    struct Storage {}

    //
    // Interface impl
    //

    #[external(v0)]
    impl IProxyWalletImpl of IProxyWallet<ContractState> {
        fn get_implementation(self: @ContractState) -> felt252 {
            WL_CLASS_HASH()
        }
    }
}
