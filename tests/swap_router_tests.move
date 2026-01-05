#[test_only]
module cetus::swap_router_tests {
    use cetus::swap_router::{exact_input_for_router_one, exact_output_for_router_one};
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

    public struct CETUS has drop {}
    public struct USDC has drop {}

    fun setup_pool_with_liquidity(
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        let (admin_cap, config) = config::new_global_config_for_test(ctx, 2000);
        let mut pool = pool::new_for_test<CETUS, USDC>(
            2,
            get_sqrt_price_at_tick(i32::from(23027)),
            100,
            string::utf8(b""),
            0,
            clock,
            ctx,
        );
        let mut pos = pool::open_position(
            &config,
            &mut pool,
            i32::neg_from(443636).as_u32(),
            i32::from(443636).as_u32(),
            ctx,
        );
        let receipt = add_liquidity_fix_coin(
            &config,
            &mut pool,
            &mut pos,
            1000000000,
            false, // false = fix coin B (USDC)
            clock,
        );
        let (pay_a, pay_b) = receipt.add_liquidity_pay_amount();
        std::debug::print(&pay_a);
        std::debug::print(&pay_b);
        let balance_a = balance::create_for_testing<CETUS>(pay_a);
        let balance_b = balance::create_for_testing<USDC>(pay_b);
        pool::repay_add_liquidity(&config, &mut pool, balance_a, balance_b, receipt);

        transfer::public_transfer(admin_cap, @0x52);
        transfer::public_share_object(pool);
        transfer::public_share_object(config);
        transfer::public_transfer(pos, @0x52);
    }

    #[test]
    fun test_swap_exact_input_for_router_one_for_a_to_b() {
        let mut scenario = test_scenario::begin(@0x52);
        let clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));
        setup_pool_with_liquidity(&clock, test_scenario::ctx(&mut scenario));
        
        scenario.next_tx(@0x52);
        
        let config = test_scenario::take_shared<GlobalConfig>(&scenario);
        let mut pool = test_scenario::take_shared<Pool<CETUS, USDC>>(&scenario);

        let swap_amount = 1000000; // Swap 1M CETUS
        let min_out = 9000000; // Expect ít nhất 9M USDC (tỷ lệ 1:10 - 10% slippage)
        
        let coin_a = coin::from_balance(
            balance::create_for_testing<CETUS>(10000000),
            test_scenario::ctx(&mut scenario)
        );
        let coin_b = coin::from_balance(
            balance::create_for_testing<USDC>(0),
            test_scenario::ctx(&mut scenario)
        );
        
        let initial_a = coin::value(&coin_a);
        let initial_b = coin::value(&coin_b);
        
        let (coin_a_after, coin_b_after) = exact_input_for_router_one(
            &config,
            &mut pool,
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
        test_scenario::return_shared(pool);
        
        clock.destroy_for_testing();
        scenario.end();
    }

    #[test]
    fun test_swap_exact_input_for_router_one_for_b_to_a() {
        let mut scenario = test_scenario::begin(@0x52);
        let clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));
        setup_pool_with_liquidity(&clock, test_scenario::ctx(&mut scenario));
        
        scenario.next_tx(@0x52);
        
        let config = test_scenario::take_shared<GlobalConfig>(&scenario);
        let mut pool = test_scenario::take_shared<Pool<CETUS, USDC>>(&scenario);

        let swap_amount = 10000000; // Swap 10M USDC
        let min_out = 900000; // Expect ít nhất 0.9M CETUS (tỷ lệ 10:1 - 10% slippage)
        
        let coin_a = coin::from_balance(
            balance::create_for_testing<CETUS>(0), // 0 CETUS ban đầu
            test_scenario::ctx(&mut scenario)
        );
        let coin_b = coin::from_balance(
            balance::create_for_testing<USDC>(100000000), // 100M USDC
            test_scenario::ctx(&mut scenario)
        );
        
        let initial_a = coin::value(&coin_a);
        let initial_b = coin::value(&coin_b);
        
        let (coin_a_after, coin_b_after) = exact_input_for_router_one(
            &config,
            &mut pool,
            coin_a,
            coin_b,
            false, // a2b = false (swap B -> A)
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
        
        assert_eq!(final_b, initial_b - swap_amount);
        assert!(final_a >= min_out, 1);
        assert!(final_a >= 900000 && final_a <= 1100000, 2);
        
        coin::burn_for_testing(coin_a_after);
        coin::burn_for_testing(coin_b_after);
        
        test_scenario::return_shared(config);
        test_scenario::return_shared(pool);
        
        clock.destroy_for_testing();
        scenario.end();
    }

    #[test]
    fun test_swap_exact_output_for_router_one_for_a_to_b() {
        let mut scenario = test_scenario::begin(@0x52);
        let clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));
        setup_pool_with_liquidity(&clock, test_scenario::ctx(&mut scenario));
        
        scenario.next_tx(@0x52);
        
        let config = test_scenario::take_shared<GlobalConfig>(&scenario);
        let mut pool = test_scenario::take_shared<Pool<CETUS, USDC>>(&scenario);

        let amount_out = 10000000;
        let amount_max_in = 1500000;
        
        let coin_a = coin::from_balance(
            balance::create_for_testing<CETUS>(10000000),
            test_scenario::ctx(&mut scenario)
        );
        let coin_b = coin::from_balance(
            balance::create_for_testing<USDC>(0),
            test_scenario::ctx(&mut scenario)
        );
        
        let initial_a = coin::value(&coin_a);
        let initial_b = coin::value(&coin_b);
        
        let (coin_a_after, coin_b_after) = exact_output_for_router_one(
            &config,
            &mut pool,
            coin_a,
            coin_b,
            true, // a2b = true (swap A -> B)
            amount_out,
            amount_max_in,
            &clock,
            test_scenario::ctx(&mut scenario)
        );
        
        let final_a = coin::value(&coin_a_after);
        let final_b = coin::value(&coin_b_after);
        
        std::debug::print(&initial_a);
        std::debug::print(&initial_b);
        std::debug::print(&final_a);
        std::debug::print(&final_b);
        
        assert_eq!(final_b, initial_b + amount_out);
        let paid = initial_a - final_a;
        assert!(paid <= amount_max_in, 1);
        assert!(paid >= 900000 && paid <= 1200000, 2);
        
        coin::burn_for_testing(coin_a_after);
        coin::burn_for_testing(coin_b_after);
        
        test_scenario::return_shared(config);
        test_scenario::return_shared(pool);
        
        clock.destroy_for_testing();
        scenario.end();
    }

    #[test]
    fun test_swap_exact_output_for_router_one_for_b_to_a() {
        let mut scenario = test_scenario::begin(@0x52);
        let clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));
        setup_pool_with_liquidity(&clock, test_scenario::ctx(&mut scenario));
        
        scenario.next_tx(@0x52);
        
        let config = test_scenario::take_shared<GlobalConfig>(&scenario);
        let mut pool = test_scenario::take_shared<Pool<CETUS, USDC>>(&scenario);

        let amount_out = 1000000;
        let amount_max_in = 12000000;
        
        let coin_a = coin::from_balance(
            balance::create_for_testing<CETUS>(0),
            test_scenario::ctx(&mut scenario)
        );
        let coin_b = coin::from_balance(
            balance::create_for_testing<USDC>(100000000), // 100M USDC
            test_scenario::ctx(&mut scenario)
        );
        
        let initial_a = coin::value(&coin_a);
        let initial_b = coin::value(&coin_b);
        
        let (coin_a_after, coin_b_after) = exact_output_for_router_one(
            &config,
            &mut pool,
            coin_a,
            coin_b,
            false, // a2b = false (swap B -> A)
            amount_out,
            amount_max_in,
            &clock,
            test_scenario::ctx(&mut scenario)
        );
        
        let final_a = coin::value(&coin_a_after);
        let final_b = coin::value(&coin_b_after);
        
        std::debug::print(&initial_a);
        std::debug::print(&initial_b);
        std::debug::print(&final_a);
        std::debug::print(&final_b);
        
        assert_eq!(final_a, initial_a + amount_out);
        let paid = initial_b - final_b;
        assert!(paid <= amount_max_in, 1);
        assert!(paid >= 9000000 && paid <= 11000000, 2);
        
        coin::burn_for_testing(coin_a_after);
        coin::burn_for_testing(coin_b_after);
        
        test_scenario::return_shared(config);
        test_scenario::return_shared(pool);
        
        clock.destroy_for_testing();
        scenario.end();
    }
}