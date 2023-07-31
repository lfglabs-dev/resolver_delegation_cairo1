#[starknet::interface]
trait IProxyWallet<TContractState> {
    fn get_implementation(self: @TContractState) -> felt252;
}
