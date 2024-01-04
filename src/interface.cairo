#[starknet::interface]
trait IArgentWallet<TContractState> {
    fn get_name(self: @TContractState) -> felt252;
}

#[starknet::interface]
trait IBraavosWallet<TContractState> {
    fn get_impl_version(self: @TContractState) -> felt252;
}
