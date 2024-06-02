use starknet::ContractAddress;


#[starknet::interface]
trait ICounter<TContractState> {
    fn get_counter(self: @TContractState) -> u32;
    fn increase_counter(ref self: TContractState);
}


#[starknet::contract]
mod Counter {
    use super::ICounter;
    use starknet::ContractAddress;

    use kill_switch::{IKillSwitchDispatcherTrait, IKillSwitchDispatcher};

    use openzeppelin::access::ownable::OwnableComponent;

    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);

    #[abi(embed_v0)]
    impl OwnableImpl = OwnableComponent::OwnableImpl<ContractState>;
    
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        counter: u32,
        kill_switch: IKillSwitchDispatcher,
        #[substorage(v0)]
        ownable: OwnableComponent::Storage
    }


    #[derive(Drop, starknet::Event)]
    struct CounterIncreased {
        #[key]
        counter: u32,
    }

    #[constructor]
    fn constructor(ref self: ContractState, initial_counter: u32, address: ContractAddress, initial_owner: ContractAddress) {
        self.counter.write(initial_counter);
        self.kill_switch.write(IKillSwitchDispatcher{contract_address:  address});
        self.ownable.initializer(initial_owner);
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        CounterIncreased : CounterIncreased,
        OwnableEvent: OwnableComponent::Event, 
    }

    #[abi(embed_v0)]
    impl CounterImpl of ICounter<ContractState>{

        fn get_counter(self: @ContractState) -> u32 { 
            self.counter.read()
        }

        fn increase_counter(ref self: ContractState) {
            self.ownable.assert_only_owner();
            let is_active = self.kill_switch.read().is_active();
            assert!(!is_active, "Kill Switch is active");
            self.counter.write(self.counter.read() + 1);
            self.emit(CounterIncreased {counter: self.counter.read()});
        }

    }
}