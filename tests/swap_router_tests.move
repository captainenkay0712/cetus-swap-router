#[test_only]
module cetus::swap_router_tests {
    use cetus::swap_router::{
        exact_input_for_router_one, 
        exact_output_for_router_one, 
        exact_input_for_router_two, 
        exact_output_for_router_two,
        exact_input_for_router_three, 
        exact_output_for_router_three
    };
    use cetus_clmm::config::{
        Self,
        GlobalConfig,
    };
    use cetus_clmm::pool::{Self, add_liquidity_fix_coin, Pool};
    use cetus_clmm::tick_math::get_sqrt_price_at_tick;
    use integer_mate::i32;
    use std::string;
    use std::unit_test::assert_eq;

    use sui::balance;
    use sui::clock::{Self, Clock};
    use sui::coin;
    use sui::test_scenario;

    public struct A has drop {}
    public struct X has drop {}
    public struct Y has drop {}
    public struct B has drop {}

    // rate 1 A = 10 B
    // rate 1 A = 5 X
    // rate 1 X = 1 Y
    // rate 1 X = 2 B
    // rate 1 Y = 2 B
    fun setup_pool_with_liquidity(
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        let (admin_cap, config) = config::new_global_config_for_test(ctx, 2000);
        
        // Pool 1: A/B - rate 1 A = 10 B
        let mut pool_A_B = pool::new_for_test<A, B>(
            2,
            get_sqrt_price_at_tick(i32::from(23027)),
            100,
            string::utf8(b""),
            0,
            clock,
            ctx,
        );
        let mut pos_A_B = pool::open_position(
            &config,
            &mut pool_A_B,
            i32::neg_from(443636).as_u32(),
            i32::from(443636).as_u32(),
            ctx,
        );
        let receipt_A_B = add_liquidity_fix_coin(
            &config,
            &mut pool_A_B,
            &mut pos_A_B,
            1000000000,
            false,
            clock,
        );
        let (pay_A_1, pay_B_1) = receipt_A_B.add_liquidity_pay_amount();
        let balance_A_1 = balance::create_for_testing<A>(pay_A_1);
        let balance_B_1 = balance::create_for_testing<B>(pay_B_1);
        pool::repay_add_liquidity(&config, &mut pool_A_B, balance_A_1, balance_B_1, receipt_A_B);

        // Pool 2: A/X - rate 1 A = 5 X
        let mut pool_A_X = pool::new_for_test<A, X>(
            2,
            get_sqrt_price_at_tick(i32::from(16094)),
            100,
            string::utf8(b""),
            0,
            clock,
            ctx,
        );
        let mut pos_A_X = pool::open_position(
            &config,
            &mut pool_A_X,
            i32::neg_from(443636).as_u32(),
            i32::from(443636).as_u32(),
            ctx,
        );
        let receipt_A_X = add_liquidity_fix_coin(
            &config,
            &mut pool_A_X,
            &mut pos_A_X,
            1000000000,
            false,
            clock,
        );
        let (pay_A_2, pay_X_2) = receipt_A_X.add_liquidity_pay_amount();
        let balance_A_2 = balance::create_for_testing<A>(pay_A_2);
        let balance_X_2 = balance::create_for_testing<X>(pay_X_2);
        pool::repay_add_liquidity(&config, &mut pool_A_X, balance_A_2, balance_X_2, receipt_A_X);

        // Pool 3: X/B - rate 1 X = 2 B
        let mut pool_X_B = pool::new_for_test<X, B>(
            2,
            get_sqrt_price_at_tick(i32::from(6931)),
            100,
            string::utf8(b""),
            0,
            clock,
            ctx,
        );
        let mut pos_X_B = pool::open_position(
            &config,
            &mut pool_X_B,
            i32::neg_from(443636).as_u32(),
            i32::from(443636).as_u32(),
            ctx,
        );
        let receipt_X_B = add_liquidity_fix_coin(
            &config,
            &mut pool_X_B,
            &mut pos_X_B,
            1000000000,
            false,
            clock,
        );
        let (pay_X_3, pay_B_3) = receipt_X_B.add_liquidity_pay_amount();
        let balance_X_3 = balance::create_for_testing<X>(pay_X_3);
        let balance_B_3 = balance::create_for_testing<B>(pay_B_3);
        pool::repay_add_liquidity(&config, &mut pool_X_B, balance_X_3, balance_B_3, receipt_X_B);

        // Pool 4: X/Y - rate 1 X = 1 Y
        let mut pool_X_Y = pool::new_for_test<X, Y>(
            2,
            get_sqrt_price_at_tick(i32::from(0)),
            100,
            string::utf8(b""),
            0,
            clock,
            ctx,
        );
        let mut pos_X_Y = pool::open_position(
            &config,
            &mut pool_X_Y,
            i32::neg_from(443636).as_u32(),
            i32::from(443636).as_u32(),
            ctx,
        );
        let receipt_X_Y = add_liquidity_fix_coin(
            &config,
            &mut pool_X_Y,
            &mut pos_X_Y,
            1000000000,
            false,
            clock,
        );
        let (pay_X_4, pay_Y_4) = receipt_X_Y.add_liquidity_pay_amount();
        let balance_X_4 = balance::create_for_testing<X>(pay_X_4);
        let balance_Y_4 = balance::create_for_testing<Y>(pay_Y_4);
        pool::repay_add_liquidity(&config, &mut pool_X_Y, balance_X_4, balance_Y_4, receipt_X_Y);

        // Pool 5: Y/B - rate 1 Y = 2 B
        let mut pool_Y_B = pool::new_for_test<Y, B>(
            2,
            get_sqrt_price_at_tick(i32::from(6931)),
            100,
            string::utf8(b""),
            0,
            clock,
            ctx,
        );
        let mut pos_Y_B = pool::open_position(
            &config,
            &mut pool_Y_B,
            i32::neg_from(443636).as_u32(),
            i32::from(443636).as_u32(),
            ctx,
        );
        let receipt_Y_B = add_liquidity_fix_coin(
            &config,
            &mut pool_Y_B,
            &mut pos_Y_B,
            1000000000,
            false,
            clock,
        );
        let (pay_Y_5, pay_B_5) = receipt_Y_B.add_liquidity_pay_amount();
        let balance_Y_5 = balance::create_for_testing<Y>(pay_Y_5);
        let balance_B_5 = balance::create_for_testing<B>(pay_B_5);
        pool::repay_add_liquidity(&config, &mut pool_Y_B, balance_Y_5, balance_B_5, receipt_Y_B);

        // Share all pools and config
        transfer::public_transfer(admin_cap, @0x52);
        transfer::public_share_object(pool_A_B);
        transfer::public_share_object(pool_A_X);
        transfer::public_share_object(pool_X_B);
        transfer::public_share_object(pool_X_Y);
        transfer::public_share_object(pool_Y_B);
        transfer::public_share_object(config);
        transfer::public_transfer(pos_A_B, @0x52);
        transfer::public_transfer(pos_A_X, @0x52);
        transfer::public_transfer(pos_X_B, @0x52);
        transfer::public_transfer(pos_X_Y, @0x52);
        transfer::public_transfer(pos_Y_B, @0x52);
    }

    #[test]
    fun test_swap_exact_input_for_router_one_for_A_to_B() {
        let mut scenario = test_scenario::begin(@0x52);
        let clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));
        setup_pool_with_liquidity(&clock, test_scenario::ctx(&mut scenario));
        
        scenario.next_tx(@0x52);
        
        let config = test_scenario::take_shared<GlobalConfig>(&scenario);
        let mut pool_A_B = test_scenario::take_shared<Pool<A, B>>(&scenario);

        let swap_amount = 1000000;
        let min_out = 9000000;
        
        let coin_A = coin::from_balance(
            balance::create_for_testing<A>(10000000),
            test_scenario::ctx(&mut scenario)
        );
        let coin_B = coin::from_balance(
            balance::create_for_testing<B>(0),
            test_scenario::ctx(&mut scenario)
        );
        
        let initial_A = coin::value(&coin_A);
        let initial_B = coin::value(&coin_B);
        
        let (coin_A_after, coin_B_after) = exact_input_for_router_one(
            &config,
            &mut pool_A_B,
            coin_A,
            coin_B,
            true, // a2b = true (swap A -> B)
            swap_amount,
            min_out,
            &clock,
            test_scenario::ctx(&mut scenario)
        );
        
        let final_A = coin::value(&coin_A_after);
        let final_B = coin::value(&coin_B_after);
        
        std::debug::print(&initial_A);
        std::debug::print(&initial_B);
        
        std::debug::print(&final_A);
        std::debug::print(&final_B);
        
        assert_eq!(final_A, initial_A - swap_amount);
        assert!(final_B >= min_out, 1);
        assert!(final_B >= 9000000 && final_B <= 11000000, 2);
        
        coin::burn_for_testing(coin_A_after);
        coin::burn_for_testing(coin_B_after);
        
        test_scenario::return_shared(config);
        test_scenario::return_shared(pool_A_B);
        
        clock.destroy_for_testing();
        scenario.end();
    }

    #[test]
    fun test_swap_exact_input_for_router_one_for_B_to_A() {
        let mut scenario = test_scenario::begin(@0x52);
        let clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));
        setup_pool_with_liquidity(&clock, test_scenario::ctx(&mut scenario));
        
        scenario.next_tx(@0x52);
        
        let config = test_scenario::take_shared<GlobalConfig>(&scenario);
        let mut pool_A_B = test_scenario::take_shared<Pool<A, B>>(&scenario);

        let swap_amount = 10000000;
        let min_out = 900000;
        
        let coin_A = coin::from_balance(
            balance::create_for_testing<A>(0),
            test_scenario::ctx(&mut scenario)
        );
        let coin_B = coin::from_balance(
            balance::create_for_testing<B>(100000000),
            test_scenario::ctx(&mut scenario)
        );
        
        let initial_A = coin::value(&coin_A);
        let initial_B = coin::value(&coin_B);
        
        let (coin_A_after, coin_B_after) = exact_input_for_router_one(
            &config,
            &mut pool_A_B,
            coin_A,
            coin_B,
            false, // a2b = false (swap B -> A)
            swap_amount,
            min_out,
            &clock,
            test_scenario::ctx(&mut scenario)
        );
        
        let final_A = coin::value(&coin_A_after);
        let final_B = coin::value(&coin_B_after);
        
        std::debug::print(&initial_A);
        std::debug::print(&initial_B);
        std::debug::print(&final_A);
        std::debug::print(&final_B);
        
        assert_eq!(final_B, initial_B - swap_amount);
        assert!(final_A >= min_out, 1);
        assert!(final_A >= 900000 && final_A <= 1100000, 2);
        
        coin::burn_for_testing(coin_A_after);
        coin::burn_for_testing(coin_B_after);
        
        test_scenario::return_shared(config);
        test_scenario::return_shared(pool_A_B);
        
        clock.destroy_for_testing();
        scenario.end();
    }

    #[test]
    fun test_swap_exact_output_for_router_one_for_A_to_B() {
        let mut scenario = test_scenario::begin(@0x52);
        let clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));
        setup_pool_with_liquidity(&clock, test_scenario::ctx(&mut scenario));
        
        scenario.next_tx(@0x52);
        
        let config = test_scenario::take_shared<GlobalConfig>(&scenario);
        let mut pool_A_B = test_scenario::take_shared<Pool<A, B>>(&scenario);

        let amount_out = 10000000;
        let amount_max_in = 1500000;
        
        let coin_A = coin::from_balance(
            balance::create_for_testing<A>(10000000),
            test_scenario::ctx(&mut scenario)
        );
        let coin_B = coin::from_balance(
            balance::create_for_testing<B>(0),
            test_scenario::ctx(&mut scenario)
        );
        
        let initial_A = coin::value(&coin_A);
        let initial_B = coin::value(&coin_B);
        
        let (coin_A_after, coin_B_after) = exact_output_for_router_one(
            &config,
            &mut pool_A_B,
            coin_A,
            coin_B,
            true, // a2b = true (swap A -> B)
            amount_out,
            amount_max_in,
            &clock,
            test_scenario::ctx(&mut scenario)
        );
        
        let final_A = coin::value(&coin_A_after);
        let final_B = coin::value(&coin_B_after);
        
        std::debug::print(&initial_A);
        std::debug::print(&initial_B);
        std::debug::print(&final_A);
        std::debug::print(&final_B);
        
        assert_eq!(final_B, initial_B + amount_out);
        let paid = initial_A - final_A;
        assert!(paid <= amount_max_in, 1);
        assert!(paid >= 900000 && paid <= 1200000, 2);
        
        coin::burn_for_testing(coin_A_after);
        coin::burn_for_testing(coin_B_after);
        
        test_scenario::return_shared(config);
        test_scenario::return_shared(pool_A_B);
        
        clock.destroy_for_testing();
        scenario.end();
    }

    #[test]
    fun test_swap_exact_output_for_router_one_for_B_to_A() {
        let mut scenario = test_scenario::begin(@0x52);
        let clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));
        setup_pool_with_liquidity(&clock, test_scenario::ctx(&mut scenario));
        
        scenario.next_tx(@0x52);
        
        let config = test_scenario::take_shared<GlobalConfig>(&scenario);
        let mut pool_A_B = test_scenario::take_shared<Pool<A, B>>(&scenario);

        let amount_out = 1000000;
        let amount_max_in = 12000000;
        
        let coin_A = coin::from_balance(
            balance::create_for_testing<A>(0),
            test_scenario::ctx(&mut scenario)
        );
        let coin_B = coin::from_balance(
            balance::create_for_testing<B>(100000000), // 100M B
            test_scenario::ctx(&mut scenario)
        );
        
        let initial_A = coin::value(&coin_A);
        let initial_B = coin::value(&coin_B);
        
        let (coin_A_after, coin_B_after) = exact_output_for_router_one(
            &config,
            &mut pool_A_B,
            coin_A,
            coin_B,
            false, // a2b = false (swap B -> A)
            amount_out,
            amount_max_in,
            &clock,
            test_scenario::ctx(&mut scenario)
        );
        
        let final_A = coin::value(&coin_A_after);
        let final_B = coin::value(&coin_B_after);
        
        std::debug::print(&initial_A);
        std::debug::print(&initial_B);
        std::debug::print(&final_A);
        std::debug::print(&final_B);
        
        assert_eq!(final_A, initial_A + amount_out);
        let paid = initial_B - final_B;
        assert!(paid <= amount_max_in, 1);
        assert!(paid >= 9000000 && paid <= 11000000, 2);
        
        coin::burn_for_testing(coin_A_after);
        coin::burn_for_testing(coin_B_after);
        
        test_scenario::return_shared(config);
        test_scenario::return_shared(pool_A_B);
        
        clock.destroy_for_testing();
        scenario.end();
    }

    #[test]
    fun test_swap_exact_input_for_router_two_for_A_to_X_to_B() {
        let mut scenario = test_scenario::begin(@0x52);
        let clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));
        setup_pool_with_liquidity(&clock, test_scenario::ctx(&mut scenario));
        
        scenario.next_tx(@0x52);
        
        let config = test_scenario::take_shared<GlobalConfig>(&scenario);
        let mut pool_A_X = test_scenario::take_shared<Pool<A, X>>(&scenario);
        let mut pool_X_B = test_scenario::take_shared<Pool<X, B>>(&scenario);

        let swap_amount = 1000000;
        let min_out = 9000000;
        
        let coin_a = coin::from_balance(
            balance::create_for_testing<A>(10000000),
            test_scenario::ctx(&mut scenario)
        );
        let coin_b = coin::from_balance(
            balance::create_for_testing<B>(0),
            test_scenario::ctx(&mut scenario)
        );
        
        let initial_a = coin::value(&coin_a);
        let initial_b = coin::value(&coin_b);
        
        let (coin_a_after, coin_b_after) = exact_input_for_router_two(
            &config,
            &mut pool_A_X,
            &mut pool_X_B,
            coin_a,
            coin_b,
            true, // a2b = true (swap A -> B)
            swap_amount,
            min_out,
            &clock,
            test_scenario::ctx(&mut scenario)
        );
        
        let final_a = coin::value(&coin_a_after);
        let final_b = coin::value(&coin_b_after);
        
        std::debug::print(&initial_a);
        std::debug::print(&initial_b);
        
        std::debug::print(&final_a);
        std::debug::print(&final_b);
        
        assert_eq!(final_a, initial_a - swap_amount);
        assert!(final_b >= min_out, 1);
        assert!(final_b >= 9000000 && final_b <= 11000000, 2);
        
        coin::burn_for_testing(coin_a_after);
        coin::burn_for_testing(coin_b_after);
        
        test_scenario::return_shared(config);
        test_scenario::return_shared(pool_A_X);
        test_scenario::return_shared(pool_X_B);
        
        clock.destroy_for_testing();
        scenario.end();
    }

    #[test]
    fun test_swap_exact_input_for_router_two_for_B_to_X_to_A() {
        let mut scenario = test_scenario::begin(@0x52);
        let clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));
        setup_pool_with_liquidity(&clock, test_scenario::ctx(&mut scenario));
        
        scenario.next_tx(@0x52);
        
        let config = test_scenario::take_shared<GlobalConfig>(&scenario);
        let mut pool_A_X = test_scenario::take_shared<Pool<A, X>>(&scenario);
        let mut pool_X_B = test_scenario::take_shared<Pool<X, B>>(&scenario);

        let swap_amount = 10000000;
        let min_out = 900000;
        
        let coin_A = coin::from_balance(
            balance::create_for_testing<A>(0),
            test_scenario::ctx(&mut scenario)
        );
        let coin_B = coin::from_balance(
            balance::create_for_testing<B>(100000000),
            test_scenario::ctx(&mut scenario)
        );
        
        let initial_A = coin::value(&coin_A);
        let initial_B = coin::value(&coin_B);
        
        let (coin_A_after, coin_B_after) = exact_input_for_router_two(
            &config,
            &mut pool_A_X,
            &mut pool_X_B,
            coin_A,
            coin_B,
            false, // a2b = false (swap B -> A)
            swap_amount,
            min_out,
            &clock,
            test_scenario::ctx(&mut scenario)
        );
        
        let final_A = coin::value(&coin_A_after);
        let final_B = coin::value(&coin_B_after);
        
        std::debug::print(&initial_A);
        std::debug::print(&initial_B);
        std::debug::print(&final_A);
        std::debug::print(&final_B);
        
        assert_eq!(final_B, initial_B - swap_amount);
        assert!(final_A >= min_out, 1);
        assert!(final_A >= 900000 && final_A <= 1100000, 2);
        
        coin::burn_for_testing(coin_A_after);
        coin::burn_for_testing(coin_B_after);
        
        test_scenario::return_shared(config);
        test_scenario::return_shared(pool_A_X);
        test_scenario::return_shared(pool_X_B);
        
        clock.destroy_for_testing();
        scenario.end();
    }

    #[test]
    fun test_swap_exact_output_for_router_two_for_A_to_X_to_B() {
        let mut scenario = test_scenario::begin(@0x52);
        let clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));
        setup_pool_with_liquidity(&clock, test_scenario::ctx(&mut scenario));
        
        scenario.next_tx(@0x52);
        
        let config = test_scenario::take_shared<GlobalConfig>(&scenario);
        let mut pool_A_X = test_scenario::take_shared<Pool<A, X>>(&scenario);
        let mut pool_X_B = test_scenario::take_shared<Pool<X, B>>(&scenario);

        let amount_out = 10000000;
        let amount_max_in = 1500000;
        
        let coin_A = coin::from_balance(
            balance::create_for_testing<A>(10000000),
            test_scenario::ctx(&mut scenario)
        );
        let coin_B = coin::from_balance(
            balance::create_for_testing<B>(0),
            test_scenario::ctx(&mut scenario)
        );
        
        let initial_A = coin::value(&coin_A);
        let initial_B = coin::value(&coin_B);
        
        let (coin_A_after, coin_B_after) = exact_output_for_router_two(
            &config,
            &mut pool_A_X,
            &mut pool_X_B,
            coin_A,
            coin_B,
            true, // a2b = true (swap A -> B)
            amount_out,
            amount_max_in,
            &clock,
            test_scenario::ctx(&mut scenario)
        );
        
        let final_A = coin::value(&coin_A_after);
        let final_B = coin::value(&coin_B_after);
        
        std::debug::print(&initial_A);
        std::debug::print(&initial_B);
        std::debug::print(&final_A);
        std::debug::print(&final_B);
        
        assert_eq!(final_B, initial_B + amount_out);
        let paid = initial_A - final_A;
        assert!(paid <= amount_max_in, 1);
        assert!(paid >= 900000 && paid <= 1200000, 2);
        
        coin::burn_for_testing(coin_A_after);
        coin::burn_for_testing(coin_B_after);
        
        test_scenario::return_shared(config);
        test_scenario::return_shared(pool_A_X);
        test_scenario::return_shared(pool_X_B);
        
        clock.destroy_for_testing();
        scenario.end();
    }

    #[test]
    fun test_swap_exact_output_for_router_one_for_B_to_X_to_A() {
        let mut scenario = test_scenario::begin(@0x52);
        let clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));
        setup_pool_with_liquidity(&clock, test_scenario::ctx(&mut scenario));
        
        scenario.next_tx(@0x52);
        
        let config = test_scenario::take_shared<GlobalConfig>(&scenario);
        let mut pool_A_X = test_scenario::take_shared<Pool<A, X>>(&scenario);
        let mut pool_X_B = test_scenario::take_shared<Pool<X, B>>(&scenario);

        let amount_out = 1000000;
        let amount_max_in = 12000000;
        
        let coin_A = coin::from_balance(
            balance::create_for_testing<A>(0),
            test_scenario::ctx(&mut scenario)
        );
        let coin_B = coin::from_balance(
            balance::create_for_testing<B>(100000000), // 100M B
            test_scenario::ctx(&mut scenario)
        );
        
        let initial_A = coin::value(&coin_A);
        let initial_B = coin::value(&coin_B);
        
        let (coin_A_after, coin_B_after) = exact_output_for_router_two(
            &config,
            &mut pool_A_X,
            &mut pool_X_B,
            coin_A,
            coin_B,
            false, // a2b = false (swap B -> A)
            amount_out,
            amount_max_in,
            &clock,
            test_scenario::ctx(&mut scenario)
        );
        
        let final_A = coin::value(&coin_A_after);
        let final_B = coin::value(&coin_B_after);
        
        std::debug::print(&initial_A);
        std::debug::print(&initial_B);
        std::debug::print(&final_A);
        std::debug::print(&final_B);
        
        assert_eq!(final_A, initial_A + amount_out);
        let paid = initial_B - final_B;
        assert!(paid <= amount_max_in, 1);
        assert!(paid >= 9000000 && paid <= 11000000, 2);
        
        coin::burn_for_testing(coin_A_after);
        coin::burn_for_testing(coin_B_after);
        
        test_scenario::return_shared(config);
        test_scenario::return_shared(pool_A_X);
        test_scenario::return_shared(pool_X_B);
        
        clock.destroy_for_testing();
        scenario.end();
    }

    #[test]
    fun test_swap_exact_input_for_router_three_for_A_to_X_to_Y_to_B() {
        let mut scenario = test_scenario::begin(@0x52);
        let clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));
        setup_pool_with_liquidity(&clock, test_scenario::ctx(&mut scenario));
        
        scenario.next_tx(@0x52);
        
        let config = test_scenario::take_shared<GlobalConfig>(&scenario);
        let mut pool_A_X = test_scenario::take_shared<Pool<A, X>>(&scenario);
        let mut pool_X_Y = test_scenario::take_shared<Pool<X, Y>>(&scenario);
        let mut pool_Y_B = test_scenario::take_shared<Pool<Y, B>>(&scenario);

        let swap_amount = 1000000;
        let min_out = 9000000;
        
        let coin_a = coin::from_balance(
            balance::create_for_testing<A>(10000000),
            test_scenario::ctx(&mut scenario)
        );
        let coin_b = coin::from_balance(
            balance::create_for_testing<B>(0),
            test_scenario::ctx(&mut scenario)
        );
        
        let initial_a = coin::value(&coin_a);
        let initial_b = coin::value(&coin_b);
        
        let (coin_a_after, coin_b_after) = exact_input_for_router_three(
            &config,
            &mut pool_A_X,
            &mut pool_X_Y,
            &mut pool_Y_B,
            coin_a,
            coin_b,
            true, // a2b = true (swap A -> B)
            swap_amount,
            min_out,
            &clock,
            test_scenario::ctx(&mut scenario)
        );
        
        let final_a = coin::value(&coin_a_after);
        let final_b = coin::value(&coin_b_after);
        
        std::debug::print(&initial_a);
        std::debug::print(&initial_b);
        
        std::debug::print(&final_a);
        std::debug::print(&final_b);
        
        assert_eq!(final_a, initial_a - swap_amount);
        assert!(final_b >= min_out, 1);
        assert!(final_b >= 9000000 && final_b <= 11000000, 2);
        
        coin::burn_for_testing(coin_a_after);
        coin::burn_for_testing(coin_b_after);
        
        test_scenario::return_shared(config);
        test_scenario::return_shared(pool_A_X);
        test_scenario::return_shared(pool_X_Y);
        test_scenario::return_shared(pool_Y_B);
        
        clock.destroy_for_testing();
        scenario.end();
    }

    #[test]
    fun test_swap_exact_input_for_router_three_for_B_to_Y_to_X_to_A() {
        let mut scenario = test_scenario::begin(@0x52);
        let clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));
        setup_pool_with_liquidity(&clock, test_scenario::ctx(&mut scenario));
        
        scenario.next_tx(@0x52);
        
        let config = test_scenario::take_shared<GlobalConfig>(&scenario);
        let mut pool_A_X = test_scenario::take_shared<Pool<A, X>>(&scenario);
        let mut pool_X_Y = test_scenario::take_shared<Pool<X, Y>>(&scenario);
        let mut pool_Y_B = test_scenario::take_shared<Pool<Y, B>>(&scenario);

        let swap_amount = 10000000;
        let min_out = 900000;
        
        let coin_A = coin::from_balance(
            balance::create_for_testing<A>(0),
            test_scenario::ctx(&mut scenario)
        );
        let coin_B = coin::from_balance(
            balance::create_for_testing<B>(100000000),
            test_scenario::ctx(&mut scenario)
        );
        
        let initial_A = coin::value(&coin_A);
        let initial_B = coin::value(&coin_B);
        
        let (coin_A_after, coin_B_after) = exact_input_for_router_three(
            &config,
            &mut pool_A_X,
            &mut pool_X_Y,
            &mut pool_Y_B,
            coin_A,
            coin_B,
            false, // a2b = false (swap B -> A)
            swap_amount,
            min_out,
            &clock,
            test_scenario::ctx(&mut scenario)
        );
        
        let final_A = coin::value(&coin_A_after);
        let final_B = coin::value(&coin_B_after);
        
        std::debug::print(&initial_A);
        std::debug::print(&initial_B);
        std::debug::print(&final_A);
        std::debug::print(&final_B);
        
        assert_eq!(final_B, initial_B - swap_amount);
        assert!(final_A >= min_out, 1);
        assert!(final_A >= 900000 && final_A <= 1100000, 2);
        
        coin::burn_for_testing(coin_A_after);
        coin::burn_for_testing(coin_B_after);
        
        test_scenario::return_shared(config);
        test_scenario::return_shared(pool_A_X);
        test_scenario::return_shared(pool_X_Y);
        test_scenario::return_shared(pool_Y_B);
        
        clock.destroy_for_testing();
        scenario.end();
    }

    #[test]
    fun test_swap_exact_output_for_router_three_for_A_to_X_to_Y_to_B() {
        let mut scenario = test_scenario::begin(@0x52);
        let clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));
        setup_pool_with_liquidity(&clock, test_scenario::ctx(&mut scenario));
        
        scenario.next_tx(@0x52);
        
        let config = test_scenario::take_shared<GlobalConfig>(&scenario);
        let mut pool_A_X = test_scenario::take_shared<Pool<A, X>>(&scenario);
        let mut pool_X_Y = test_scenario::take_shared<Pool<X, Y>>(&scenario);
        let mut pool_Y_B = test_scenario::take_shared<Pool<Y, B>>(&scenario);

        let amount_out = 10000000;
        let amount_max_in = 1500000;
        
        let coin_A = coin::from_balance(
            balance::create_for_testing<A>(10000000),
            test_scenario::ctx(&mut scenario)
        );
        let coin_B = coin::from_balance(
            balance::create_for_testing<B>(0),
            test_scenario::ctx(&mut scenario)
        );
        
        let initial_A = coin::value(&coin_A);
        let initial_B = coin::value(&coin_B);
        
        let (coin_A_after, coin_B_after) = exact_output_for_router_three(
            &config,
            &mut pool_A_X,
            &mut pool_X_Y,
            &mut pool_Y_B,
            coin_A,
            coin_B,
            true, // a2b = true (swap A -> B)
            amount_out,
            amount_max_in,
            &clock,
            test_scenario::ctx(&mut scenario)
        );
        
        let final_A = coin::value(&coin_A_after);
        let final_B = coin::value(&coin_B_after);
        
        std::debug::print(&initial_A);
        std::debug::print(&initial_B);
        std::debug::print(&final_A);
        std::debug::print(&final_B);
        
        assert_eq!(final_B, initial_B + amount_out);
        let paid = initial_A - final_A;
        assert!(paid <= amount_max_in, 1);
        assert!(paid >= 900000 && paid <= 1200000, 2);
        
        coin::burn_for_testing(coin_A_after);
        coin::burn_for_testing(coin_B_after);
        
        test_scenario::return_shared(config);
        test_scenario::return_shared(pool_A_X);
        test_scenario::return_shared(pool_X_Y);
        test_scenario::return_shared(pool_Y_B);
        
        clock.destroy_for_testing();
        scenario.end();
    }

    #[test]
    fun test_swap_exact_output_for_router_one_for_B_to_Y_to_X_to_A() {
        let mut scenario = test_scenario::begin(@0x52);
        let clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));
        setup_pool_with_liquidity(&clock, test_scenario::ctx(&mut scenario));
        
        scenario.next_tx(@0x52);
        
        let config = test_scenario::take_shared<GlobalConfig>(&scenario);
        let mut pool_A_X = test_scenario::take_shared<Pool<A, X>>(&scenario);
        let mut pool_X_Y = test_scenario::take_shared<Pool<X, Y>>(&scenario);
        let mut pool_Y_B = test_scenario::take_shared<Pool<Y, B>>(&scenario);

        let amount_out = 1000000;
        let amount_max_in = 12000000;
        
        let coin_A = coin::from_balance(
            balance::create_for_testing<A>(0),
            test_scenario::ctx(&mut scenario)
        );
        let coin_B = coin::from_balance(
            balance::create_for_testing<B>(100000000), // 100M B
            test_scenario::ctx(&mut scenario)
        );
        
        let initial_A = coin::value(&coin_A);
        let initial_B = coin::value(&coin_B);
        
        let (coin_A_after, coin_B_after) = exact_output_for_router_three(
            &config,
            &mut pool_A_X,
            &mut pool_X_Y,
            &mut pool_Y_B,
            coin_A,
            coin_B,
            false, // a2b = false (swap B -> A)
            amount_out,
            amount_max_in,
            &clock,
            test_scenario::ctx(&mut scenario)
        );
        
        let final_A = coin::value(&coin_A_after);
        let final_B = coin::value(&coin_B_after);
        
        std::debug::print(&initial_A);
        std::debug::print(&initial_B);
        std::debug::print(&final_A);
        std::debug::print(&final_B);
        
        assert_eq!(final_A, initial_A + amount_out);
        let paid = initial_B - final_B;
        assert!(paid <= amount_max_in, 1);
        assert!(paid >= 9000000 && paid <= 11000000, 2);
        
        coin::burn_for_testing(coin_A_after);
        coin::burn_for_testing(coin_B_after);
        
        test_scenario::return_shared(config);
        test_scenario::return_shared(pool_A_X);
        test_scenario::return_shared(pool_X_Y);
        test_scenario::return_shared(pool_Y_B);
        
        clock.destroy_for_testing();
        scenario.end();
    }
}