//
// Copyright (c) 2022 by optke3
// 
//

// a simple 1-1 swap function that lets users swap SUI and MANAGED coin

module my_first_package::swap{
    use sui::id::VersionedID;
    use sui::sui::SUI;
    use sui::coin::{Coin, take, put, value};
    use sui::transfer;
    use sui::balance::{Self, Balance};
    use fungible_tokens::managed::MANAGED;
    use sui::tx_context::{Self, TxContext};

    struct Pool has key {
        id: VersionedID,
        /// SUI coins held in the reserve
        sui: Balance<SUI>,
        /// MANAGED coins held in the reserve
        managed: Balance<MANAGED>,
    }
    
    fun init(ctx: &mut TxContext){
        transfer::share_object(Pool {
           id: tx_context::new_id(ctx),
           sui: balance::zero<SUI>(),
           managed: balance::zero<MANAGED>(),
        })
    }

    public fun deposit_managed(pool:&mut Pool, managed:Coin<MANAGED>){  
         put(&mut pool.managed, managed);
    }

     public fun deposit_sui(pool:&mut Pool, sui:Coin<SUI>){  
         put(&mut pool.sui, sui);
    }

    public fun swap_for_managed(pool:&mut Pool, sui:Coin<SUI>, ctx: &mut TxContext): Coin<MANAGED>{
        let amt_in:u64 = value<SUI>(&sui);
        put(&mut pool.sui, sui);
        take(&mut pool.managed, amt_in, ctx)
    }

    public fun swap_for_sui(pool:&mut Pool, managed:Coin<MANAGED>, ctx: &mut TxContext): Coin<SUI>{
        let amt_in:u64 = value<MANAGED>(&managed);
        put(&mut pool.managed, managed);
        take(&mut pool.sui, amt_in, ctx)
    }

    #[test_only]
    /// Wrapper of module initializer for testing   
    public fun test_init(ctx: &mut TxContext) { 
        init(ctx)
    } 
    
}

#[test_only]
module my_first_package::test_swap{
    use sui::sui::{SUI};
    use sui::coin::{Coin, TreasuryCap, mint_for_testing};
    use sui::transfer;

    use sui::test_scenario::{Self, Scenario, next_tx, ctx, take_shared, take_owned, return_shared};
    use fungible_tokens::managed::{MANAGED, test_init as managed_test_init};
    use my_first_package::swap::{deposit_managed, swap_for_managed, Pool, test_init};
    
    fun scenario(): Scenario { test_scenario::begin(&@0x65916d9c6fdfec3e6bc6448a727ef9ad31761479) }
    fun people(): (address, address, address) { (@0x65916d9c6fdfec3e6bc6448a727ef9ad31761479, @0xE05, @0xFACE) }
    
    #[test]
    fun test_one() {
        test_one_(&mut scenario())
    }
    
    // Admin creates a regulated coin ABC and mints 1,000,000 of it.
    fun test_one_(test: &mut Scenario) {
        let (admin, _, _) = people();
        next_tx(test, &admin); {
            test_init(ctx(test));
            managed_test_init(ctx(test));
        };
        
        // admin mints MANAGED coins to himself
        next_tx(test, &admin);{
            let cap = take_owned<TreasuryCap<MANAGED>>(test);
            let coin = fungible_tokens::managed::mint(&mut cap, 1, ctx(test));
            test_scenario::return_owned(test, cap);
            transfer::transfer(coin, admin);
        };

        // admin deposit some MANAGED coin to pool
        next_tx(test, &admin);{
            let managed = test_scenario::take_owned<Coin<MANAGED>>(test);
            let pool = take_shared<Pool>(test);
            let pool_ref = test_scenario::borrow_mut(&mut pool);
            deposit_managed(pool_ref, managed);
            return_shared(test, pool);
        };

        // admin mints some SUI to themselves in test setting 
        next_tx(test, &admin);{
            //let cap = take_owned<TreasuryCap<SUI>>(test);
            let coin = mint_for_testing<SUI>(1, ctx(test));
            transfer::transfer(coin, admin);
            //return_owned(test, cap);
        };  
        
        // admin swaps SUI for MANAGED using mutable shared Pool object
        next_tx(test, &admin);{
            let sui = take_owned<Coin<SUI>>(test); 
            let pool = take_shared<Pool>(test);   
            let pool_ref = test_scenario::borrow_mut(&mut pool); 
            let managed = swap_for_managed(pool_ref, sui, ctx(test)); 
            transfer::transfer(managed, admin); 
            return_shared(test, pool); 
        }
    }
}      
