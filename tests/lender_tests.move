#[test_only]
module quest_overmind::lending_tests {

    #[test_only]
    use sui::test_scenario;
    #[test_only]
    use sui::test_utils::{assert_eq, destroy};
    #[test_only]
    use sui::sui::SUI;

    use quest_overmind::lending::{Self, ProtocolState, AdminCap, Pool};

    use std::vector;
    use quest_overmind::dummy_oracle;
    use sui::table;
    use sui::coin;
    use sui::balance;

    //==============================================================================================
    // Tests - DO NOT MODIFY
    //==============================================================================================

    #[test_only]
    struct COIN1 has drop {}
    #[test_only]
    struct COIN2 has drop {}

    #[test]
    fun test_init_success_resources_created() {
        let module_owner = @0xa;

        let scenario_val = test_scenario::begin(module_owner);
        let scenario = &mut scenario_val;

        {
            lending::test_init(test_scenario::ctx(scenario));
        };
        let tx = test_scenario::next_tx(scenario, module_owner);
        let expected_created_objects = 2;
        let expected_shared_objects = 1;
        assert_eq(
            vector::length(&test_scenario::created(&tx)),
            expected_created_objects
        );
        assert_eq(
            vector::length(&test_scenario::shared(&tx)),
            expected_shared_objects
        );

        {
            let state = test_scenario::take_shared<ProtocolState>(scenario);

            assert_eq(lending::get_number_of_pools(&state), 0);

            assert_eq(table::length(lending::get_users(&state)), 0);

            test_scenario::return_shared(state);
        };
        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_create_pool_success_one_pool_created() {
        let module_owner = @0xa;

        let scenario_val = test_scenario::begin(module_owner);
        let scenario = &mut scenario_val;

        {
            lending::test_init(test_scenario::ctx(scenario));
        };
        test_scenario::next_tx(scenario, module_owner);


        {
            let admin_cap = test_scenario:: take_from_sender<AdminCap>(scenario);
            let state = test_scenario::take_shared<ProtocolState>(scenario);

            lending::create_pool<SUI>(
                &mut admin_cap, 
                &mut state, 
                test_scenario::ctx(scenario)
            );

            test_scenario::return_to_sender(scenario, admin_cap);
            test_scenario::return_shared(state);
        };
        let tx = test_scenario::next_tx(scenario, module_owner);
        let expected_created_objects = 1;
        let expected_shared_objects = 2;
        assert_eq(
            vector::length(&test_scenario::created(&tx)),
            expected_created_objects
        );
        assert_eq(
            vector::length(&test_scenario::shared(&tx)),
            expected_shared_objects
        );

        let expected_number_of_pools = 1;
        {
            let state = test_scenario::take_shared<ProtocolState>(scenario);

            assert_eq(lending::get_number_of_pools(&state), expected_number_of_pools);

            test_scenario::return_shared(state);
        };
        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_create_pool_success_multiple_pools_created() {
        let module_owner = @0xa;

        let scenario_val = test_scenario::begin(module_owner);
        let scenario = &mut scenario_val;

        {
            lending::test_init(test_scenario::ctx(scenario));
        };
        test_scenario::next_tx(scenario, module_owner);

        {
            let admin_cap = test_scenario:: take_from_sender<AdminCap>(scenario);
            let state = test_scenario::take_shared<ProtocolState>(scenario);

            lending::create_pool<SUI>(
                &mut admin_cap, 
                &mut state, 
                test_scenario::ctx(scenario)
            );

            lending::create_pool<COIN1>(
                &mut admin_cap, 
                &mut state, 
                test_scenario::ctx(scenario)
            );

            lending::create_pool<COIN2>(
                &mut admin_cap, 
                &mut state, 
                test_scenario::ctx(scenario)
            );

            test_scenario::return_to_sender(scenario, admin_cap);
            test_scenario::return_shared(state);
        };
        let tx = test_scenario::next_tx(scenario, module_owner);
        let expected_created_objects = 3;
        let expected_shared_objects = 4;
        assert_eq(
            vector::length(&test_scenario::created(&tx)),
            expected_created_objects
        );
        assert_eq(
            vector::length(&test_scenario::shared(&tx)),
            expected_shared_objects
        );

        let expected_number_of_pools = 3;
        {
            let state = test_scenario::take_shared<ProtocolState>(scenario);

            assert_eq(lending::get_number_of_pools(&state), expected_number_of_pools);

            test_scenario::return_shared(state);
        };
        test_scenario::end(scenario_val);

    }

    #[test]
    fun test_deposit_success_deposit_sui() {
        let module_owner = @0xa;
        let user = @0xb;

        let scenario_val = test_scenario::begin(module_owner);
        let scenario = &mut scenario_val;

        {
            lending::test_init(test_scenario::ctx(scenario));
        };
        test_scenario::next_tx(scenario, module_owner);

        {
            let admin_cap = test_scenario:: take_from_sender<AdminCap>(scenario);
            let state = test_scenario::take_shared<ProtocolState>(scenario);

            lending::create_pool<SUI>(
                &mut admin_cap, 
                &mut state, 
                test_scenario::ctx(scenario)
            );

            test_scenario::return_to_sender(scenario, admin_cap);
            test_scenario::return_shared(state);
        };
        test_scenario::next_tx(scenario, user);

        let deposit_amount = 100_000_000_000; // 100 SUI
        {
            let pool = test_scenario::take_shared<Pool<SUI>>(scenario);
            let state = test_scenario::take_shared<ProtocolState>(scenario);


            let coin = coin::mint_for_testing<SUI>(deposit_amount, test_scenario::ctx(scenario));

            lending::deposit(
                coin, 
                &mut pool, 
                &mut state, 
                test_scenario::ctx(scenario)
            );

            test_scenario::return_shared(pool);
            test_scenario::return_shared(state);
        };
        test_scenario::next_tx(scenario, user);

        let expected_users = 1;
        {
            let state = test_scenario::take_shared<ProtocolState>(scenario);
            let user_met = table::borrow(lending::get_users(&state), user);
            let pool = test_scenario::take_shared<Pool<SUI>>(scenario);

            assert_eq(table::length(lending::get_users(&state)), expected_users);
            assert_eq(balance::value(lending::get_pool_reserve(&pool)), deposit_amount);

            assert_eq(*table::borrow(lending::get_user_data_collateral_amount(user_met), 0), deposit_amount);

            test_scenario::return_shared(state);
            test_scenario::return_shared(pool);
        };
        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_deposit_success_multiple_deposits_sui_by_same_person() {
        let module_owner = @0xa;
        let user = @0xb;

        let scenario_val = test_scenario::begin(module_owner);
        let scenario = &mut scenario_val;

        {
            lending::test_init(test_scenario::ctx(scenario));
        };
        test_scenario::next_tx(scenario, module_owner);

        {
            let admin_cap = test_scenario:: take_from_sender<AdminCap>(scenario);
            let state = test_scenario::take_shared<ProtocolState>(scenario);

            lending::create_pool<SUI>(
                &mut admin_cap, 
                &mut state, 
                test_scenario::ctx(scenario)
            );

            test_scenario::return_to_sender(scenario, admin_cap);
            test_scenario::return_shared(state);
        };
        test_scenario::next_tx(scenario, user);

        let deposit_amount = 100_000_000_000; // 100 SUI
        {
            let pool = test_scenario::take_shared<Pool<SUI>>(scenario);
            let state = test_scenario::take_shared<ProtocolState>(scenario);

            let coin = coin::mint_for_testing<SUI>(deposit_amount, test_scenario::ctx(scenario));

            lending::deposit(
                coin, 
                &mut pool, 
                &mut state, 
                test_scenario::ctx(scenario)
            );

            let coin = coin::mint_for_testing<SUI>(deposit_amount, test_scenario::ctx(scenario));

            lending::deposit(
                coin, 
                &mut pool, 
                &mut state, 
                test_scenario::ctx(scenario)
            );

            test_scenario::return_shared(pool);
            test_scenario::return_shared(state);
        };
        test_scenario::next_tx(scenario, user);

        let expected_users = 1;
        {
            let state = test_scenario::take_shared<ProtocolState>(scenario);
            let user_met = table::borrow(lending::get_users(&state), user);
            let pool = test_scenario::take_shared<Pool<SUI>>(scenario);

            assert_eq(table::length(lending::get_users(&state)), expected_users);
            assert_eq(balance::value(lending::get_pool_reserve(&pool)), deposit_amount * 2);

            assert_eq(*table::borrow(lending::get_user_data_collateral_amount(user_met), 0), deposit_amount * 2);

            test_scenario::return_shared(state);
            test_scenario::return_shared(pool);
        };
        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_deposit_success_one_user_deposits_different_pools() {
        let module_owner = @0xa;
        let user = @0xb;

        let scenario_val = test_scenario::begin(module_owner);
        let scenario = &mut scenario_val;

        {
            lending::test_init(test_scenario::ctx(scenario));
        };
        test_scenario::next_tx(scenario, module_owner);

        {
            let admin_cap = test_scenario:: take_from_sender<AdminCap>(scenario);
            let state = test_scenario::take_shared<ProtocolState>(scenario);

            lending::create_pool<SUI>(
                &mut admin_cap, 
                &mut state, 
                test_scenario::ctx(scenario)
            );

            lending::create_pool<COIN1>(
                &mut admin_cap, 
                &mut state, 
                test_scenario::ctx(scenario)
            );

            test_scenario::return_to_sender(scenario, admin_cap);
            test_scenario::return_shared(state);
        };
        test_scenario::next_tx(scenario, user);

        let deposit_amount_sui = 100_000_000_000; // 100 SUI
        let deposit_amount_coin1 = 100_000;

        {
            let pool_sui = test_scenario::take_shared<Pool<SUI>>(scenario);
            let pool_coin1 = test_scenario::take_shared<Pool<COIN1>>(scenario);
            let state = test_scenario::take_shared<ProtocolState>(scenario);

            let coin_sui = coin::mint_for_testing<SUI>(deposit_amount_sui, test_scenario::ctx(scenario));

            lending::deposit(
                coin_sui, 
                &mut pool_sui, 
                &mut state, 
                test_scenario::ctx(scenario)
            );

            let coin_coin1 = coin::mint_for_testing<COIN1>(deposit_amount_coin1, test_scenario::ctx(scenario));

            lending::deposit(
                coin_coin1, 
                &mut pool_coin1, 
                &mut state, 
                test_scenario::ctx(scenario)
            );

            test_scenario::return_shared(pool_sui);
            test_scenario::return_shared(pool_coin1);
            test_scenario::return_shared(state);
        };
        test_scenario::next_tx(scenario, user);

        let expected_users = 1;
        {
            let state = test_scenario::take_shared<ProtocolState>(scenario);
            let user_met = table::borrow(lending::get_users(&state), user);
            let pool_sui = test_scenario::take_shared<Pool<SUI>>(scenario);
            let pool_coin1 = test_scenario::take_shared<Pool<COIN1>>(scenario);

            assert_eq(table::length(lending::get_users(&state)), expected_users);
            assert_eq(balance::value(lending::get_pool_reserve(&pool_sui)), deposit_amount_sui);
            assert_eq(balance::value(lending::get_pool_reserve(&pool_coin1)), deposit_amount_coin1);

            assert_eq(*table::borrow(lending::get_user_data_collateral_amount(user_met), 0), deposit_amount_sui);
            assert_eq(*table::borrow(lending::get_user_data_collateral_amount(user_met), 1), deposit_amount_coin1);

            test_scenario::return_shared(state);
            test_scenario::return_shared(pool_sui);
            test_scenario::return_shared(pool_coin1);
        };
        test_scenario::end(scenario_val);

    }

    #[test]
    fun test_deposit_success_multiple_users_deposit_same_pool() {
        let module_owner = @0xa;
        let user1 = @0xb;
        let user2 = @0xc;

        let scenario_val = test_scenario::begin(module_owner);
        let scenario = &mut scenario_val;

        {
            lending::test_init(test_scenario::ctx(scenario));
        };
        test_scenario::next_tx(scenario, module_owner);

        {
            let admin_cap = test_scenario:: take_from_sender<AdminCap>(scenario);
            let state = test_scenario::take_shared<ProtocolState>(scenario);

            lending::create_pool<SUI>(
                &mut admin_cap, 
                &mut state, 
                test_scenario::ctx(scenario)
            );

            test_scenario::return_to_sender(scenario, admin_cap);
            test_scenario::return_shared(state);
        };
        test_scenario::next_tx(scenario, user1);

        let deposit_amount = 100_000_000_000; // 100 SUI
        {
            let pool = test_scenario::take_shared<Pool<SUI>>(scenario);
            let state = test_scenario::take_shared<ProtocolState>(scenario);

            let coin = coin::mint_for_testing<SUI>(deposit_amount, test_scenario::ctx(scenario));

            lending::deposit(
                coin, 
                &mut pool, 
                &mut state, 
                test_scenario::ctx(scenario)
            );

            test_scenario::return_shared(pool);
            test_scenario::return_shared(state);
        };
        test_scenario::next_tx(scenario, user2);

        let deposit_amount_user2 = 200_000_000_000; // 200 SUI
        {
            let pool = test_scenario::take_shared<Pool<SUI>>(scenario);
            let state = test_scenario::take_shared<ProtocolState>(scenario);

            let coin = coin::mint_for_testing<SUI>(deposit_amount_user2, test_scenario::ctx(scenario));

            lending::deposit(
                coin, 
                &mut pool, 
                &mut state, 
                test_scenario::ctx(scenario)
            );

            test_scenario::return_shared(pool);
            test_scenario::return_shared(state);
        };
        test_scenario::next_tx(scenario, user1);

        let expected_users = 2;
        {
            let state = test_scenario::take_shared<ProtocolState>(scenario);
            let user_met1 = table::borrow(lending::get_users(&state), user1);
            let user_met2 = table::borrow(lending::get_users(&state), user2);
            let pool = test_scenario::take_shared<Pool<SUI>>(scenario);

            assert_eq(table::length(lending::get_users(&state)), expected_users);
            assert_eq(balance::value(lending::get_pool_reserve(&pool)), deposit_amount + deposit_amount_user2);

            assert_eq(*table::borrow(lending::get_user_data_collateral_amount(user_met1), 0), deposit_amount);
            assert_eq(*table::borrow(lending::get_user_data_collateral_amount(user_met2), 0), deposit_amount_user2);

            test_scenario::return_shared(state);
            test_scenario::return_shared(pool);
        };
        test_scenario::end(scenario_val);
    }
    
    #[test]
    fun test_withdraw_success_withdraw_from_pool_total_amount() {
        let module_owner = @0xa;
        let user = @0xb;

        let scenario_val = test_scenario::begin(module_owner);
        let scenario = &mut scenario_val;

        {
            lending::test_init(test_scenario::ctx(scenario));
        };
        test_scenario::next_tx(scenario, module_owner);

        {
            let admin_cap = test_scenario:: take_from_sender<AdminCap>(scenario);
            let state = test_scenario::take_shared<ProtocolState>(scenario);

            lending::create_pool<SUI>(
                &mut admin_cap, 
                &mut state, 
                test_scenario::ctx(scenario)
            );

            test_scenario::return_to_sender(scenario, admin_cap);
            test_scenario::return_shared(state);
        };
        test_scenario::next_tx(scenario, user);

        let deposit_amount = 100_000_000_000; // 100 SUI
        {
            let pool = test_scenario::take_shared<Pool<SUI>>(scenario);
            let state = test_scenario::take_shared<ProtocolState>(scenario);

            let coin = coin::mint_for_testing<SUI>(deposit_amount, test_scenario::ctx(scenario));

            lending::deposit(
                coin, 
                &mut pool, 
                &mut state, 
                test_scenario::ctx(scenario)
            );

            test_scenario::return_shared(pool);
            test_scenario::return_shared(state);
        };
        test_scenario::next_tx(scenario, user);

        let withdraw_amount = 100_000_000_000; // 100 SUI
        let coin = {
            let pool = test_scenario::take_shared<Pool<SUI>>(scenario);
            let state = test_scenario::take_shared<ProtocolState>(scenario);

            let coin = lending::withdraw(
                withdraw_amount, 
                &mut pool, 
                &mut state, 
                test_scenario::ctx(scenario)
            );

            test_scenario::return_shared(pool);
            test_scenario::return_shared(state);

            coin
        };
        test_scenario::next_tx(scenario, user);

        let expected_users = 1;
        {
            let state = test_scenario::take_shared<ProtocolState>(scenario);
            let user_met = table::borrow(lending::get_users(&state), user);
            let pool = test_scenario::take_shared<Pool<SUI>>(scenario);

            assert_eq(table::length(lending::get_users(&state)), expected_users);
            assert_eq(balance::value(lending::get_pool_reserve(&pool)), deposit_amount - withdraw_amount);

            assert_eq(*table::borrow(lending::get_user_data_collateral_amount(user_met), 0), deposit_amount - withdraw_amount);

            assert_eq(coin::value(&coin), withdraw_amount);

            test_scenario::return_shared(state);
            test_scenario::return_shared(pool);
        };
        test_scenario::end(scenario_val);

        destroy(coin);
    }

    #[test]
    fun test_withdraw_success_withdraw_partial_amount() {
        let module_owner = @0xa;
        let user = @0xb;

        let scenario_val = test_scenario::begin(module_owner);
        let scenario = &mut scenario_val;

        {
            lending::test_init(test_scenario::ctx(scenario));
        };
        test_scenario::next_tx(scenario, module_owner);

        {
            let admin_cap = test_scenario:: take_from_sender<AdminCap>(scenario);
            let state = test_scenario::take_shared<ProtocolState>(scenario);

            lending::create_pool<SUI>(
                &mut admin_cap, 
                &mut state, 
                test_scenario::ctx(scenario)
            );

            test_scenario::return_to_sender(scenario, admin_cap);
            test_scenario::return_shared(state);
        };
        test_scenario::next_tx(scenario, user);

        let deposit_amount = 100_000_000_000; // 100 SUI
        {
            let pool = test_scenario::take_shared<Pool<SUI>>(scenario);
            let state = test_scenario::take_shared<ProtocolState>(scenario);

            let coin = coin::mint_for_testing<SUI>(deposit_amount, test_scenario::ctx(scenario));

            lending::deposit(
                coin, 
                &mut pool, 
                &mut state, 
                test_scenario::ctx(scenario)
            );

            test_scenario::return_shared(pool);
            test_scenario::return_shared(state);
        };
        test_scenario::next_tx(scenario, user);

        let withdraw_amount = 50_000_000_000; // 50 SUI
        let coin = {
            let pool = test_scenario::take_shared<Pool<SUI>>(scenario);
            let state = test_scenario::take_shared<ProtocolState>(scenario);

            let coin = lending::withdraw(
                withdraw_amount, 
                &mut pool, 
                &mut state, 
                test_scenario::ctx(scenario)
            );

            test_scenario::return_shared(pool);
            test_scenario::return_shared(state);

            coin
        };
        test_scenario::next_tx(scenario, user);

        let expected_users = 1;
        {
            let state = test_scenario::take_shared<ProtocolState>(scenario);
            let user_met = table::borrow(lending::get_users(&state), user);
            let pool = test_scenario::take_shared<Pool<SUI>>(scenario);

            assert_eq(table::length(lending::get_users(&state)), expected_users);
            assert_eq(balance::value(lending::get_pool_reserve(&pool)), deposit_amount - withdraw_amount);

            assert_eq(*table::borrow(lending::get_user_data_collateral_amount(user_met), 0), deposit_amount - withdraw_amount);

            assert_eq(coin::value(&coin), withdraw_amount);

            test_scenario::return_shared(state);
            test_scenario::return_shared(pool);
        };
        test_scenario::end(scenario_val);
        
        destroy(coin);
    }

    #[test]
    fun test_borrow_success_user_borrow_partial_balance_of_pool() {
        let module_owner = @0xa;
        let user = @0xb;

        let scenario_val = test_scenario::begin(module_owner);
        let scenario = &mut scenario_val;

        {
            lending::test_init(test_scenario::ctx(scenario));
        };
        test_scenario::next_tx(scenario, module_owner);

        {
            let admin_cap = test_scenario:: take_from_sender<AdminCap>(scenario);
            let state = test_scenario::take_shared<ProtocolState>(scenario);

            lending::create_pool<SUI>(
                &mut admin_cap, 
                &mut state, 
                test_scenario::ctx(scenario)
            );

            test_scenario::return_to_sender(scenario, admin_cap);
            test_scenario::return_shared(state);
        };
        test_scenario::next_tx(scenario, user);

        let deposit_amount = 100_000_000_000; // 100 SUI
        {
            let pool = test_scenario::take_shared<Pool<SUI>>(scenario);
            let state = test_scenario::take_shared<ProtocolState>(scenario);

            let coin = coin::mint_for_testing<SUI>(deposit_amount, test_scenario::ctx(scenario));

            lending::deposit(
                coin, 
                &mut pool, 
                &mut state, 
                test_scenario::ctx(scenario)
            );

            test_scenario::return_shared(pool);
            test_scenario::return_shared(state);
        };
        test_scenario::next_tx(scenario, user);

        let borrow_amount = 50_000_000_000; // 50 SUI
        let coin = {
            let pool = test_scenario::take_shared<Pool<SUI>>(scenario);
            let state = test_scenario::take_shared<ProtocolState>(scenario);

            let coin = lending::borrow(
                borrow_amount, 
                &mut pool, 
                &mut state, 
                test_scenario::ctx(scenario)
            );

            test_scenario::return_shared(pool);
            test_scenario::return_shared(state);

            coin
        };
        test_scenario::next_tx(scenario, user);

        let expected_users = 1;
        {
            let state = test_scenario::take_shared<ProtocolState>(scenario);
            let user_met = table::borrow(lending::get_users(&state), user);
            let pool = test_scenario::take_shared<Pool<SUI>>(scenario);

            assert_eq(table::length(lending::get_users(&state)), expected_users);
            assert_eq(balance::value(lending::get_pool_reserve(&pool)), deposit_amount - borrow_amount);

            assert_eq(*table::borrow(lending::get_user_data_borrowed_amount(user_met), 0), borrow_amount);

            assert_eq(coin::value(&coin), borrow_amount);

            test_scenario::return_shared(state);
            test_scenario::return_shared(pool);
        };
        test_scenario::end(scenario_val);

        destroy(coin);
    }

    #[test]
    fun test_borrow_success_borrow_whole_pool_amount() {
        let module_owner = @0xa;
        let user = @0xb;

        let scenario_val = test_scenario::begin(module_owner);
        let scenario = &mut scenario_val;

        {
            lending::test_init(test_scenario::ctx(scenario));
        };
        test_scenario::next_tx(scenario, module_owner);

        {
            let admin_cap = test_scenario:: take_from_sender<AdminCap>(scenario);
            let state = test_scenario::take_shared<ProtocolState>(scenario);

            lending::create_pool<SUI>(
                &mut admin_cap, 
                &mut state, 
                test_scenario::ctx(scenario)
            );

            test_scenario::return_to_sender(scenario, admin_cap);
            test_scenario::return_shared(state);
        };
        test_scenario::next_tx(scenario, user);

        let deposit_amount = 100_000_000_000; // 100 SUI
        {
            let pool = test_scenario::take_shared<Pool<SUI>>(scenario);
            let state = test_scenario::take_shared<ProtocolState>(scenario);

            let coin = coin::mint_for_testing<SUI>(deposit_amount, test_scenario::ctx(scenario));

            lending::deposit(
                coin, 
                &mut pool, 
                &mut state, 
                test_scenario::ctx(scenario)
            );

            test_scenario::return_shared(pool);
            test_scenario::return_shared(state);
        };
        test_scenario::next_tx(scenario, user);

        let borrow_amount = 100_000_000_000; // 100 SUI
        let coin = {
            let pool = test_scenario::take_shared<Pool<SUI>>(scenario);
            let state = test_scenario::take_shared<ProtocolState>(scenario);

            let coin = lending::borrow(
                borrow_amount, 
                &mut pool, 
                &mut state, 
                test_scenario::ctx(scenario)
            );

            test_scenario::return_shared(pool);
            test_scenario::return_shared(state);

            coin
        };
        test_scenario::next_tx(scenario, user);

        let expected_users = 1;
        {
            let state = test_scenario::take_shared<ProtocolState>(scenario);
            let user_met = table::borrow(lending::get_users(&state), user);
            let pool = test_scenario::take_shared<Pool<SUI>>(scenario);

            assert_eq(table::length(lending::get_users(&state)), expected_users);
            assert_eq(balance::value(lending::get_pool_reserve(&pool)), deposit_amount - borrow_amount);

            assert_eq(*table::borrow(lending::get_user_data_borrowed_amount(user_met), 0), borrow_amount);

            assert_eq(coin::value(&coin), borrow_amount);

            test_scenario::return_shared(state);
            test_scenario::return_shared(pool);
        };
        test_scenario::end(scenario_val);

        destroy(coin);
    }

    #[test]
    fun test_repay_success_repay_users_full_borrowed_amount() {
        let module_owner = @0xa;
        let user = @0xb;

        let scenario_val = test_scenario::begin(module_owner);
        let scenario = &mut scenario_val;

        {
            lending::test_init(test_scenario::ctx(scenario));
        };
        test_scenario::next_tx(scenario, module_owner);

        {
            let admin_cap = test_scenario:: take_from_sender<AdminCap>(scenario);
            let state = test_scenario::take_shared<ProtocolState>(scenario);

            lending::create_pool<SUI>(
                &mut admin_cap, 
                &mut state, 
                test_scenario::ctx(scenario)
            );

            test_scenario::return_to_sender(scenario, admin_cap);
            test_scenario::return_shared(state);
        };
        test_scenario::next_tx(scenario, user);

        let deposit_amount = 100_000_000_000; // 100 SUI
        {
            let pool = test_scenario::take_shared<Pool<SUI>>(scenario);
            let state = test_scenario::take_shared<ProtocolState>(scenario);

            let coin = coin::mint_for_testing<SUI>(deposit_amount, test_scenario::ctx(scenario));

            lending::deposit(
                coin, 
                &mut pool, 
                &mut state, 
                test_scenario::ctx(scenario)
            );

            test_scenario::return_shared(pool);
            test_scenario::return_shared(state);
        };
        test_scenario::next_tx(scenario, user);

        let borrow_amount = 100_000_000_000; // 100 SUI
        let coin = {
            let pool = test_scenario::take_shared<Pool<SUI>>(scenario);
            let state = test_scenario::take_shared<ProtocolState>(scenario);

            let coin = lending::borrow(
                borrow_amount, 
                &mut pool, 
                &mut state, 
                test_scenario::ctx(scenario)
            );

            test_scenario::return_shared(pool);
            test_scenario::return_shared(state);

            coin
        };
        test_scenario::next_tx(scenario, user);

        {
            let pool = test_scenario::take_shared<Pool<SUI>>(scenario);
            let state = test_scenario::take_shared<ProtocolState>(scenario);

            lending::repay(
                coin, 
                &mut pool, 
                &mut state, 
                test_scenario::ctx(scenario)
            );

            test_scenario::return_shared(pool);
            test_scenario::return_shared(state);
        };
        test_scenario::next_tx(scenario, user);

        let expected_users = 1;
        {
            let state = test_scenario::take_shared<ProtocolState>(scenario);
            let user_met = table::borrow(lending::get_users(&state), user);
            let pool = test_scenario::take_shared<Pool<SUI>>(scenario);

            assert_eq(table::length(lending::get_users(&state)), expected_users);
            assert_eq(balance::value(lending::get_pool_reserve(&pool)), deposit_amount);

            assert_eq(*table::borrow(lending::get_user_data_borrowed_amount(user_met), 0), 0);

            test_scenario::return_shared(state);
            test_scenario::return_shared(pool);
        };
        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_repay_success_repay_users_partial_borrowed_amount() {
        let module_owner = @0xa;
        let user = @0xb;

        let scenario_val = test_scenario::begin(module_owner);
        let scenario = &mut scenario_val;

        {
            lending::test_init(test_scenario::ctx(scenario));
        };
        test_scenario::next_tx(scenario, module_owner);

        {
            let admin_cap = test_scenario:: take_from_sender<AdminCap>(scenario);
            let state = test_scenario::take_shared<ProtocolState>(scenario);

            lending::create_pool<SUI>(
                &mut admin_cap, 
                &mut state, 
                test_scenario::ctx(scenario)
            );

            test_scenario::return_to_sender(scenario, admin_cap);
            test_scenario::return_shared(state);
        };
        test_scenario::next_tx(scenario, user);

        let deposit_amount = 100_000_000_000; // 100 SUI
        {
            let pool = test_scenario::take_shared<Pool<SUI>>(scenario);
            let state = test_scenario::take_shared<ProtocolState>(scenario);

            let coin = coin::mint_for_testing<SUI>(deposit_amount, test_scenario::ctx(scenario));

            lending::deposit(
                coin, 
                &mut pool, 
                &mut state, 
                test_scenario::ctx(scenario)
            );

            test_scenario::return_shared(pool);
            test_scenario::return_shared(state);
        };
        test_scenario::next_tx(scenario, user);

        let borrow_amount = 100_000_000_000; // 100 SUI
        let coin = {
            let pool = test_scenario::take_shared<Pool<SUI>>(scenario);
            let state = test_scenario::take_shared<ProtocolState>(scenario);

            let coin = lending::borrow(
                borrow_amount, 
                &mut pool, 
                &mut state, 
                test_scenario::ctx(scenario)
            );

            test_scenario::return_shared(pool);
            test_scenario::return_shared(state);

            coin
        };
        test_scenario::next_tx(scenario, user);

        let repay_amount = 50_000_000_000; // 50 SUI
        {
            let pool = test_scenario::take_shared<Pool<SUI>>(scenario);
            let state = test_scenario::take_shared<ProtocolState>(scenario);

            lending::repay(
                coin::split(&mut coin, repay_amount, test_scenario::ctx(scenario)), 
                &mut pool, 
                &mut state,
                test_scenario::ctx(scenario)
            );

            test_scenario::return_shared(pool);
            test_scenario::return_shared(state);
        };
        test_scenario::next_tx(scenario, user);

        let expected_users = 1;
        {
            let state = test_scenario::take_shared<ProtocolState>(scenario);
            let user_met = table::borrow(lending::get_users(&state), user);
            let pool = test_scenario::take_shared<Pool<SUI>>(scenario);

            assert_eq(table::length(lending::get_users(&state)), expected_users);
            assert_eq(balance::value(lending::get_pool_reserve(&pool)), deposit_amount - repay_amount);

            assert_eq(*table::borrow(lending::get_user_data_borrowed_amount(user_met), 0), borrow_amount - repay_amount);

            test_scenario::return_shared(state);
            test_scenario::return_shared(pool);
        };
        test_scenario::end(scenario_val);

        destroy(coin);
    }
    #[test]
    fun test_calculate_health_factor_success_one_coin() {
        let deposit_amount_sui = 100_000_000_000; // 100 SUI
        let borrow_amount_sui = 50_000_000_000; // 50 SUI

        let module_owner = @0xa;
        let user = @0xb;

        let scenario_val = test_scenario::begin(module_owner);
        let scenario = &mut scenario_val;

        {
            lending::test_init(test_scenario::ctx(scenario));
        };
        test_scenario::next_tx(scenario, module_owner);

        {
            let admin_cap = test_scenario:: take_from_sender<AdminCap>(scenario);
            let state = test_scenario::take_shared<ProtocolState>(scenario);

            lending::create_pool<SUI>(
                &mut admin_cap, 
                &mut state, 
                test_scenario::ctx(scenario)
            );

            test_scenario::return_to_sender(scenario, admin_cap);
            test_scenario::return_shared(state);
        };
        test_scenario::next_tx(scenario, user);

        {
            let pool = test_scenario::take_shared<Pool<SUI>>(scenario);
            let state = test_scenario::take_shared<ProtocolState>(scenario);

            let coin = coin::mint_for_testing<SUI>(deposit_amount_sui, test_scenario::ctx(scenario));

            lending::deposit(
                coin, 
                &mut pool, 
                &mut state, 
                test_scenario::ctx(scenario)
            );

            let coin = lending::borrow(
                borrow_amount_sui, 
                &mut pool, 
                &mut state, 
                test_scenario::ctx(scenario)
            );

            test_scenario::return_shared(pool);
            test_scenario::return_shared(state);

            destroy(coin);
        };
        test_scenario::next_tx(scenario, user);

        let sui_price = 100; // 1 SUI = 1.00 USD
        {
            dummy_oracle::init_module(test_scenario::ctx(scenario));
        };
        test_scenario::next_tx(scenario, module_owner);

        {
            let feed = test_scenario::take_shared<dummy_oracle::PriceFeed>(scenario);

            dummy_oracle::add_new_coin(
                sui_price, 
                9, 
                &mut feed
            );

            test_scenario::return_shared(feed);
        };
        test_scenario::next_tx(scenario, user);

        let expected_health_factor = 160;
        {
            let state = test_scenario::take_shared<ProtocolState>(scenario);
            let feed = test_scenario::take_shared<dummy_oracle::PriceFeed>(scenario);


            let health_factor = lending::calculate_health_factor(
                user,
                &state, 
                &feed
            );

            assert_eq(health_factor, expected_health_factor);

            test_scenario::return_shared(state);
            test_scenario::return_shared(feed);
        };
        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_calculate_health_factor_success_two_coins_same_price_same_amount() {
        let deposit_amount_sui = 100_000_000_000; // 100 SUI
        let deposit_amount_coin1 = 100_000; // 100 coin1
        let borrow_amount_sui = 50_000_000_000; // 50 SUI


        let module_owner = @0xa;
        let user = @0xb;

        let scenario_val = test_scenario::begin(module_owner);
        let scenario = &mut scenario_val;

        {
            lending::test_init(test_scenario::ctx(scenario));
        };
        test_scenario::next_tx(scenario, module_owner);

        {
            let admin_cap = test_scenario:: take_from_sender<AdminCap>(scenario);
            let state = test_scenario::take_shared<ProtocolState>(scenario);

            lending::create_pool<SUI>(
                &mut admin_cap, 
                &mut state, 
                test_scenario::ctx(scenario)
            );

            lending::create_pool<COIN1>(
                &mut admin_cap, 
                &mut state, 
                test_scenario::ctx(scenario)
            );

            test_scenario::return_to_sender(scenario, admin_cap);
            test_scenario::return_shared(state);
        };
        test_scenario::next_tx(scenario, user);

        {
            let sui_pool = test_scenario::take_shared<Pool<SUI>>(scenario);
            let coin1_pool = test_scenario::take_shared<Pool<COIN1>>(scenario);
            let state = test_scenario::take_shared<ProtocolState>(scenario);

            let sui_coin = coin::mint_for_testing<SUI>(deposit_amount_sui, test_scenario::ctx(scenario));

            lending::deposit(
                sui_coin, 
                &mut sui_pool, 
                &mut state, 
                test_scenario::ctx(scenario)
            );

            let coin1_coin = coin::mint_for_testing<COIN1>(deposit_amount_coin1, test_scenario::ctx(scenario));

            lending::deposit(
                coin1_coin, 
                &mut coin1_pool, 
                &mut state, 
                test_scenario::ctx(scenario)
            );

            let borrow_coin = lending::borrow(
                borrow_amount_sui, 
                &mut sui_pool, 
                &mut state, 
                test_scenario::ctx(scenario)
            );

            test_scenario::return_shared(sui_pool);
            test_scenario::return_shared(coin1_pool);
            test_scenario::return_shared(state);

            destroy(borrow_coin);
        };
        test_scenario::next_tx(scenario, user);

        let sui_price = 100; // 1 SUI = 1.00 USD
        let coin1_price = 100; // 1 coin1 = 1.00 USD
        {
            dummy_oracle::init_module(test_scenario::ctx(scenario));
        };
        test_scenario::next_tx(scenario, module_owner);

        {
            let feed = test_scenario::take_shared<dummy_oracle::PriceFeed>(scenario);

            dummy_oracle::add_new_coin(
                sui_price, 
                9, 
                &mut feed
            );

            dummy_oracle::add_new_coin(
                coin1_price, 
                3, 
                &mut feed
            );

            test_scenario::return_shared(feed);
        };
        test_scenario::next_tx(scenario, user);

        let expected_health_factor = 2 * 160;
        {
            let state = test_scenario::take_shared<ProtocolState>(scenario);
            let feed = test_scenario::take_shared<dummy_oracle::PriceFeed>(scenario);


            let health_factor = lending::calculate_health_factor(
                user,
                &state, 
                &feed
            );

            assert_eq(health_factor, expected_health_factor);

            test_scenario::return_shared(state);
            test_scenario::return_shared(feed);
        };
        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_calculate_health_factor_success_two_coins_same_price_different_amount() {
        let deposit_amount_sui = 100_000_000_000; // 100 SUI
        let deposit_amount_coin1 = 50_000; // 100 coin1
        let borrow_amount_sui = 50_000_000_000; // 50 SUI


        let module_owner = @0xa;
        let user = @0xb;

        let scenario_val = test_scenario::begin(module_owner);
        let scenario = &mut scenario_val;

        {
            lending::test_init(test_scenario::ctx(scenario));
        };
        test_scenario::next_tx(scenario, module_owner);

        {
            let admin_cap = test_scenario:: take_from_sender<AdminCap>(scenario);
            let state = test_scenario::take_shared<ProtocolState>(scenario);

            lending::create_pool<SUI>(
                &mut admin_cap, 
                &mut state, 
                test_scenario::ctx(scenario)
            );

            lending::create_pool<COIN1>(
                &mut admin_cap, 
                &mut state, 
                test_scenario::ctx(scenario)
            );

            test_scenario::return_to_sender(scenario, admin_cap);
            test_scenario::return_shared(state);
        };
        test_scenario::next_tx(scenario, user);

        {
            let sui_pool = test_scenario::take_shared<Pool<SUI>>(scenario);
            let coin1_pool = test_scenario::take_shared<Pool<COIN1>>(scenario);
            let state = test_scenario::take_shared<ProtocolState>(scenario);

            let sui_coin = coin::mint_for_testing<SUI>(deposit_amount_sui, test_scenario::ctx(scenario));

            lending::deposit(
                sui_coin, 
                &mut sui_pool, 
                &mut state, 
                test_scenario::ctx(scenario)
            );

            let coin1_coin = coin::mint_for_testing<COIN1>(deposit_amount_coin1, test_scenario::ctx(scenario));

            lending::deposit(
                coin1_coin, 
                &mut coin1_pool, 
                &mut state, 
                test_scenario::ctx(scenario)
            );

            let borrow_coin = lending::borrow(
                borrow_amount_sui, 
                &mut sui_pool, 
                &mut state, 
                test_scenario::ctx(scenario)
            );

            test_scenario::return_shared(sui_pool);
            test_scenario::return_shared(coin1_pool);
            test_scenario::return_shared(state);

            destroy(borrow_coin);
        };
        test_scenario::next_tx(scenario, user);

        let sui_price = 100; // 1 SUI = 1.00 USD
        let coin1_price = 100; // 1 coin1 = 1.00 USD
        {
            dummy_oracle::init_module(test_scenario::ctx(scenario));
        };
        test_scenario::next_tx(scenario, module_owner);

        {
            let feed = test_scenario::take_shared<dummy_oracle::PriceFeed>(scenario);

            dummy_oracle::add_new_coin(
                sui_price, 
                9, 
                &mut feed
            );

            dummy_oracle::add_new_coin(
                coin1_price, 
                3, 
                &mut feed
            );

            test_scenario::return_shared(feed);
        };
        test_scenario::next_tx(scenario, user);

        let expected_health_factor = 240;
        {
            let state = test_scenario::take_shared<ProtocolState>(scenario);
            let feed = test_scenario::take_shared<dummy_oracle::PriceFeed>(scenario);


            let health_factor = lending::calculate_health_factor(
                user,
                &state, 
                &feed
            );

            assert_eq(health_factor, expected_health_factor);

            test_scenario::return_shared(state);
            test_scenario::return_shared(feed);
        };
        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_calculate_health_factor_success_two_coins_different_price_same_amount() {
        let deposit_amount_sui = 100_000_000_000; // 100 SUI
        let deposit_amount_coin1 = 100_000; // 100 coin1
        let borrow_amount_sui = 50_000_000_000; // 50 SUI


        let module_owner = @0xa;
        let user = @0xb;

        let scenario_val = test_scenario::begin(module_owner);
        let scenario = &mut scenario_val;

        {
            lending::test_init(test_scenario::ctx(scenario));
        };
        test_scenario::next_tx(scenario, module_owner);

        {
            let admin_cap = test_scenario:: take_from_sender<AdminCap>(scenario);
            let state = test_scenario::take_shared<ProtocolState>(scenario);

            lending::create_pool<SUI>(
                &mut admin_cap, 
                &mut state, 
                test_scenario::ctx(scenario)
            );

            lending::create_pool<COIN1>(
                &mut admin_cap, 
                &mut state, 
                test_scenario::ctx(scenario)
            );

            test_scenario::return_to_sender(scenario, admin_cap);
            test_scenario::return_shared(state);
        };
        test_scenario::next_tx(scenario, user);

        {
            let sui_pool = test_scenario::take_shared<Pool<SUI>>(scenario);
            let coin1_pool = test_scenario::take_shared<Pool<COIN1>>(scenario);
            let state = test_scenario::take_shared<ProtocolState>(scenario);

            let sui_coin = coin::mint_for_testing<SUI>(deposit_amount_sui, test_scenario::ctx(scenario));

            lending::deposit(
                sui_coin, 
                &mut sui_pool, 
                &mut state, 
                test_scenario::ctx(scenario)
            );

            let coin1_coin = coin::mint_for_testing<COIN1>(deposit_amount_coin1, test_scenario::ctx(scenario));

            lending::deposit(
                coin1_coin, 
                &mut coin1_pool, 
                &mut state, 
                test_scenario::ctx(scenario)
            );

            let borrow_coin = lending::borrow(
                borrow_amount_sui, 
                &mut sui_pool, 
                &mut state, 
                test_scenario::ctx(scenario)
            );

            test_scenario::return_shared(sui_pool);
            test_scenario::return_shared(coin1_pool);
            test_scenario::return_shared(state);

            destroy(borrow_coin);
        };
        test_scenario::next_tx(scenario, user);

        let sui_price = 150; // 1 SUI = 1.00 USD
        let coin1_price = 4530; // 1 coin1 = 1.00 USD
        {
            dummy_oracle::init_module(test_scenario::ctx(scenario));
        };
        test_scenario::next_tx(scenario, module_owner);

        {
            let feed = test_scenario::take_shared<dummy_oracle::PriceFeed>(scenario);

            dummy_oracle::add_new_coin(
                sui_price, 
                9, 
                &mut feed
            );

            dummy_oracle::add_new_coin(
                coin1_price, 
                3, 
                &mut feed
            );

            test_scenario::return_shared(feed);
        };
        test_scenario::next_tx(scenario, user);

        let expected_health_factor = 4992;
        {
            let state = test_scenario::take_shared<ProtocolState>(scenario);
            let feed = test_scenario::take_shared<dummy_oracle::PriceFeed>(scenario);


            let health_factor = lending::calculate_health_factor(
                user,
                &state, 
                &feed
            );

            assert_eq(health_factor, expected_health_factor);

            test_scenario::return_shared(state);
            test_scenario::return_shared(feed);
        };
        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_calculate_health_factor_success_two_coins_bad_health() {
        let deposit_amount_sui = 100_000_000_000; // 100 SUI
        let deposit_amount_coin1 = 100_000; // 100 coin1
        let borrow_amount_sui = 50_000_000_000; // 50 SUI
        let borrow_amount_coin1 = 90_000; // 50 coin1


        let module_owner = @0xa;
        let user = @0xb;

        let scenario_val = test_scenario::begin(module_owner);
        let scenario = &mut scenario_val;

        {
            lending::test_init(test_scenario::ctx(scenario));
        };
        test_scenario::next_tx(scenario, module_owner);

        {
            let admin_cap = test_scenario:: take_from_sender<AdminCap>(scenario);
            let state = test_scenario::take_shared<ProtocolState>(scenario);

            lending::create_pool<SUI>(
                &mut admin_cap, 
                &mut state, 
                test_scenario::ctx(scenario)
            );

            lending::create_pool<COIN1>(
                &mut admin_cap, 
                &mut state, 
                test_scenario::ctx(scenario)
            );

            test_scenario::return_to_sender(scenario, admin_cap);
            test_scenario::return_shared(state);
        };
        test_scenario::next_tx(scenario, user);

        {
            let sui_pool = test_scenario::take_shared<Pool<SUI>>(scenario);
            let coin1_pool = test_scenario::take_shared<Pool<COIN1>>(scenario);
            let state = test_scenario::take_shared<ProtocolState>(scenario);

            let sui_coin = coin::mint_for_testing<SUI>(deposit_amount_sui, test_scenario::ctx(scenario));

            lending::deposit(
                sui_coin, 
                &mut sui_pool, 
                &mut state, 
                test_scenario::ctx(scenario)
            );

            let coin1_coin = coin::mint_for_testing<COIN1>(deposit_amount_coin1, test_scenario::ctx(scenario));

            lending::deposit(
                coin1_coin, 
                &mut coin1_pool, 
                &mut state, 
                test_scenario::ctx(scenario)
            );

            let borrow_coin_sui = lending::borrow(
                borrow_amount_sui, 
                &mut sui_pool, 
                &mut state, 
                test_scenario::ctx(scenario)
            );

            let borrow_coin_coin1 = lending::borrow(
                borrow_amount_coin1, 
                &mut coin1_pool, 
                &mut state, 
                test_scenario::ctx(scenario)
            );

            test_scenario::return_shared(sui_pool);
            test_scenario::return_shared(coin1_pool);
            test_scenario::return_shared(state);

            destroy(borrow_coin_sui);
            destroy(borrow_coin_coin1);
        };
        test_scenario::next_tx(scenario, user);

        let sui_price = 150; // 1 SUI = 1.00 USD
        let coin1_price = 4530; // 1 coin1 = 45.30 USD
        {
            dummy_oracle::init_module(test_scenario::ctx(scenario));
        };
        test_scenario::next_tx(scenario, module_owner);

        {
            let feed = test_scenario::take_shared<dummy_oracle::PriceFeed>(scenario);

            dummy_oracle::add_new_coin(
                sui_price, 
                9, 
                &mut feed
            );

            dummy_oracle::add_new_coin(
                coin1_price, 
                3, 
                &mut feed
            );

            test_scenario::return_shared(feed);
        };
        test_scenario::next_tx(scenario, user);

        let expected_health_factor = 90;
        {
            let state = test_scenario::take_shared<ProtocolState>(scenario);
            let feed = test_scenario::take_shared<dummy_oracle::PriceFeed>(scenario);


            let health_factor = lending::calculate_health_factor(
                user,
                &state, 
                &feed
            );

            assert_eq(health_factor, expected_health_factor);

            test_scenario::return_shared(state);
            test_scenario::return_shared(feed);
        };
        test_scenario::end(scenario_val);
    }
}