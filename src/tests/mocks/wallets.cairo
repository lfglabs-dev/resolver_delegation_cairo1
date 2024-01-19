#[starknet::interface]
trait IArgentWallet<TContractState> {
    fn get_name(self: @TContractState) -> felt252;
}

#[starknet::interface]
trait IBraavosWallet<TContractState> {
    // it's actually more structured but we won't check it
    fn get_signers(self: @TContractState) -> felt252;
}


#[starknet::contract]
mod ArgentWallet {
    use super::IArgentWallet;

    #[storage]
    struct Storage {}

    #[external(v0)]
    impl IArgentWalletImpl of IArgentWallet<ContractState> {
        fn get_name(self: @ContractState) -> felt252 {
            'ArgentAccount'
        }
    }
}

#[starknet::contract]
mod BraavosWallet {
    use super::IBraavosWallet;

    #[storage]
    struct Storage {}

    #[external(v0)]
    impl IBraavosWalletImpl of IBraavosWallet<ContractState> {
        fn get_signers(self: @ContractState) -> felt252 {
            '000.000.011'
        }
    }
}
