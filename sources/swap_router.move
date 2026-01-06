module cetus::swap_router {
    use sui::coin::{Self, Coin};
    use sui::clock::Clock;
    use cetus_clmm::config::GlobalConfig;
    use cetus_clmm::tick_math::{min_sqrt_price, max_sqrt_price};
    use cetus_clmm::pool::{Pool, flash_swap, repay_flash_swap, FlashSwapReceipt, swap_pay_amount};

    // Swap amount incorrect
    const ERR_SWAP_AMOUNT_INCORRECT: u64 = 1;
    // Insufficient output amount
    const ERR_INSUFFICIENT_OUT_AMOUNT: u64 = 2;
    /// Insufficient amount out
    const ERR_INSUFFICIENT_IN_AMOUNT: u64 = 3;

    public fun exact_input<CoinTypeA, CoinTypeB>(
        config: &GlobalConfig,
        pool: &mut Pool<CoinTypeA, CoinTypeB>,
        coin_in_a: Coin<CoinTypeA>,
        coin_in_b: Coin<CoinTypeB>,
        a2b: bool,
        amount: u64,
        clock: &Clock,
        ctx: &mut TxContext
    ): (Coin<CoinTypeA>, Coin<CoinTypeB>) {
        let sqrt_price_limit = if (a2b) {
            min_sqrt_price()
        } else {
            max_sqrt_price()
        };
        
        let (balance_swapped_a, balance_swapped_b, receipt) = flash_swap<CoinTypeA, CoinTypeB>(
            config,
            pool,
            a2b,
            true, // by_amount_in
            amount,
            sqrt_price_limit,
            clock
        );

        let pay_amount = swap_pay_amount(&receipt);
        assert!(pay_amount == amount, ERR_SWAP_AMOUNT_INCORRECT);
        
        if (a2b) {
            coin::destroy_zero(coin_in_b);
            repay_flash_swap<CoinTypeA, CoinTypeB>(
                config,
                pool,
                coin::into_balance(coin_in_a),
                coin::into_balance(coin::zero<CoinTypeB>(ctx)),
                receipt
            );
            coin::destroy_zero(coin::from_balance(balance_swapped_a, ctx));
            (coin::zero<CoinTypeA>(ctx), coin::from_balance(balance_swapped_b, ctx))
        } else {
            coin::destroy_zero(coin_in_a);
            repay_flash_swap<CoinTypeA, CoinTypeB>(
                config,
                pool,
                coin::into_balance(coin::zero<CoinTypeA>(ctx)),
                coin::into_balance(coin_in_b),
                receipt
            );
            coin::destroy_zero(coin::from_balance(balance_swapped_b, ctx));
            (coin::from_balance(balance_swapped_a, ctx), coin::zero<CoinTypeB>(ctx))
        }
    }

    public fun exact_output<CoinTypeA, CoinTypeB>(
        config: &GlobalConfig,
        pool: &mut Pool<CoinTypeA, CoinTypeB>,
        a2b: bool,
        amount: u64,
        clock: &Clock,
        ctx: &mut TxContext
    ): (Coin<CoinTypeA>, Coin<CoinTypeB>, FlashSwapReceipt<CoinTypeA, CoinTypeB>) {
        let sqrt_price_limit = if (a2b) {
            min_sqrt_price()
        } else {
            max_sqrt_price()
        };

        let (balance_a, balance_b, receipt) = flash_swap<CoinTypeA, CoinTypeB>(
            config,
            pool,
            a2b,
            false, // by_amount_in = false for exact_output
            amount,
            sqrt_price_limit,
            clock
        );

        (
            coin::from_balance(balance_a, ctx),
            coin::from_balance(balance_b, ctx),
            receipt
        )
    }

    public fun exact_input_for_router_one<CoinTypeA, CoinTypeB>(
        config: &GlobalConfig,
        pool: &mut Pool<CoinTypeA, CoinTypeB>,
        mut coin_in_a: Coin<CoinTypeA>,
        mut coin_in_b: Coin<CoinTypeB>,
        a2b: bool,
        amount: u64,
        amount_min_out: u64,
        clock: &Clock,
        ctx: &mut TxContext
    ): (Coin<CoinTypeA>, Coin<CoinTypeB>) {
        if (a2b) {
            let coin_a = coin::split(&mut coin_in_a, amount, ctx);
            let (swapped_coin_a, received_coin_b) = exact_input<CoinTypeA, CoinTypeB>(
                config,
                pool,
                coin_a,
                coin::zero<CoinTypeB>(ctx),
                true,
                amount,
                clock,
                ctx
            );
            coin::destroy_zero(swapped_coin_a);

            let amount_out = coin::value(&received_coin_b);
            assert!(amount_out >= amount_min_out, ERR_INSUFFICIENT_OUT_AMOUNT);

            coin::join(&mut coin_in_b, received_coin_b);
        } else {
            let coin_b = coin::split(&mut coin_in_b, amount, ctx);
            let (received_coin_a, swapped_coin_b) = exact_input<CoinTypeA, CoinTypeB>(
                config,
                pool,
                coin::zero<CoinTypeA>(ctx),
                coin_b,
                false,
                amount,
                clock,
                ctx
            );
            coin::destroy_zero(swapped_coin_b);

            let amount_out = coin::value(&received_coin_a);
            assert!(amount_out >= amount_min_out, ERR_INSUFFICIENT_OUT_AMOUNT);

            coin::join(&mut coin_in_a, received_coin_a);
        };

        (coin_in_a, coin_in_b)
    }

    public fun exact_output_for_router_one<CoinTypeA, CoinTypeB>(
        config: &GlobalConfig,
        pool: &mut Pool<CoinTypeA, CoinTypeB>,
        mut coin_in_a: Coin<CoinTypeA>,
        mut coin_in_b: Coin<CoinTypeB>,
        a2b: bool,
        amount: u64,
        amount_max_in: u64,
        clock: &Clock,
        ctx: &mut TxContext
    ): (Coin<CoinTypeA>, Coin<CoinTypeB>) {
        let (
            coin_swapped_a,
            coin_swapped_b,
            receipt
        ) = exact_output<CoinTypeA, CoinTypeB>(
            config,
            pool,
            a2b,
            amount,
            clock,
            ctx
        );

        let pay_amount = swap_pay_amount(&receipt);
        assert!(pay_amount <= amount_max_in, ERR_INSUFFICIENT_IN_AMOUNT);

        if (a2b) {
            coin::destroy_zero(coin_swapped_a);
            let coin_a = coin::split(&mut coin_in_a, pay_amount, ctx);

            repay_flash_swap<CoinTypeA, CoinTypeB>(
                config,
                pool,
                coin::into_balance(coin_a),
                coin::into_balance(coin::zero<CoinTypeB>(ctx)),
                receipt
            );

            coin::join(&mut coin_in_b, coin_swapped_b);
        } else {
            coin::destroy_zero(coin_swapped_b);
            let coin_b = coin::split(&mut coin_in_b, pay_amount, ctx);

            repay_flash_swap<CoinTypeA, CoinTypeB>(
                config,
                pool,
                coin::into_balance(coin::zero<CoinTypeA>(ctx)),
                coin::into_balance(coin_b),
                receipt
            );

            coin::join(&mut coin_in_a, coin_swapped_a);
        };

        (coin_in_a, coin_in_b)
    }

    public fun exact_input_for_router_two<CoinTypeA, CoinTypeX, CoinTypeB>(
        config: &GlobalConfig,
        pool_a_x: &mut Pool<CoinTypeA, CoinTypeX>,
        pool_x_b: &mut Pool<CoinTypeX, CoinTypeB>,
        mut coin_in_a: Coin<CoinTypeA>,
        mut coin_in_b: Coin<CoinTypeB>,
        a2b: bool,
        amount: u64,
        amount_min_out: u64,
        clock: &Clock,
        ctx: &mut TxContext
    ): (Coin<CoinTypeA>, Coin<CoinTypeB>) {
        if (a2b) {
            // Step 1: Swap A → X
            let coin_a = coin::split(&mut coin_in_a, amount, ctx);
            let (swapped_coin_a, received_coin_x) = exact_input<CoinTypeA, CoinTypeX>(
                config,
                pool_a_x,
                coin_a,
                coin::zero<CoinTypeX>(ctx),
                true,
                amount,
                clock,
                ctx
            );
            coin::destroy_zero(swapped_coin_a);
            
            // Step 2: Swap X → B
            let amount_x = coin::value(&received_coin_x);
            let (swapped_coin_x, received_coin_b) = exact_input<CoinTypeX, CoinTypeB>(
                config,
                pool_x_b,
                received_coin_x,
                coin::zero<CoinTypeB>(ctx),
                true,
                amount_x,
                clock,
                ctx
            );
            coin::destroy_zero(swapped_coin_x);
            
            let amount_out = coin::value(&received_coin_b);
            assert!(amount_out >= amount_min_out, ERR_INSUFFICIENT_OUT_AMOUNT);
            
            coin::join(&mut coin_in_b, received_coin_b);
        }  else {
            // Step 1: Swap B → X
            let coin_b = coin::split(&mut coin_in_b, amount, ctx);
            let (received_coin_x, swapped_coin_b) = exact_input<CoinTypeX, CoinTypeB>(
                config,
                pool_x_b,
                coin::zero<CoinTypeX>(ctx),
                coin_b,
                false,
                amount,
                clock,
                ctx
            );
            coin::destroy_zero(swapped_coin_b);
            
            // Step 2: Swap X → A
            let amount_x = coin::value(&received_coin_x);
            let (received_coin_a, swapped_coin_x) = exact_input<CoinTypeA, CoinTypeX>(
                config,
                pool_a_x,
                coin::zero<CoinTypeA>(ctx),
                received_coin_x,
                false,
                amount_x,
                clock,
                ctx
            );
            coin::destroy_zero(swapped_coin_x);
            
            let amount_out = coin::value(&received_coin_a);
            assert!(amount_out >= amount_min_out, ERR_INSUFFICIENT_OUT_AMOUNT);
            
            coin::join(&mut coin_in_a, received_coin_a);
        };

        (coin_in_a, coin_in_b)
    }

    public fun exact_output_for_router_two<CoinTypeA, CoinTypeX, CoinTypeB>(
        config: &GlobalConfig,
        pool_a_x: &mut Pool<CoinTypeA, CoinTypeX>,
        pool_x_b: &mut Pool<CoinTypeX, CoinTypeB>,        
        mut coin_in_a: Coin<CoinTypeA>,
        mut coin_in_b: Coin<CoinTypeB>,
        a2b: bool,
        amount: u64,
        amount_max_in: u64,
        clock: &Clock,
        ctx: &mut TxContext
    ): (Coin<CoinTypeA>, Coin<CoinTypeB>) {
        if (a2b){
            let (
                swapped_coin_x,
                received_coin_b,
                receipt_x_b
            ) = exact_output<CoinTypeX, CoinTypeB>(
                config,
                pool_x_b,
                true,
                amount,
                clock,
                ctx
            );
            coin::destroy_zero(swapped_coin_x);
            let pay_amount_x = swap_pay_amount(&receipt_x_b);

            let (
                swapped_coin_a,
                received_coin_x,
                receipt_a_x
            ) = exact_output<CoinTypeA, CoinTypeX>(
                config,
                pool_a_x,
                true,
                pay_amount_x,
                clock,
                ctx
            );
            coin::destroy_zero(swapped_coin_a);
            let pay_amount_a = swap_pay_amount(&receipt_a_x);
            assert!(pay_amount_a <= amount_max_in, ERR_INSUFFICIENT_IN_AMOUNT);

            repay_flash_swap<CoinTypeX, CoinTypeB>(
                config,
                pool_x_b,
                coin::into_balance(received_coin_x),
                coin::into_balance(coin::zero<CoinTypeB>(ctx)),
                receipt_x_b
            );

            let coin_a = coin::split(&mut coin_in_a, pay_amount_a, ctx);
            repay_flash_swap<CoinTypeA, CoinTypeX>(
                config,
                pool_a_x,
                coin::into_balance(coin_a),
                coin::into_balance(coin::zero<CoinTypeX>(ctx)),
                receipt_a_x
            );

            coin::join(&mut coin_in_b, received_coin_b);
        } else {
            let (
                received_coin_a,
                swapped_coin_x,
                receipt_x_a
            ) = exact_output<CoinTypeA, CoinTypeX>(
                config,
                pool_a_x,
                false,
                amount,
                clock,
                ctx
            );
            coin::destroy_zero(swapped_coin_x);
            let pay_amount_x = swap_pay_amount(&receipt_x_a);

            let (
                received_coin_x,
                swapped_coin_b,
                receipt_b_x
            ) = exact_output<CoinTypeX, CoinTypeB>(
                config,
                pool_x_b,
                false,
                pay_amount_x,
                clock,
                ctx
            );
            coin::destroy_zero(swapped_coin_b);
            let pay_amount_b = swap_pay_amount(&receipt_b_x);
            assert!(pay_amount_b <= amount_max_in, ERR_INSUFFICIENT_IN_AMOUNT);

            repay_flash_swap<CoinTypeA, CoinTypeX>(
                config,
                pool_a_x,
                coin::into_balance(coin::zero<CoinTypeA>(ctx)),
                coin::into_balance(received_coin_x),
                receipt_x_a
            );

            let coin_b = coin::split(&mut coin_in_b, pay_amount_b, ctx);
            repay_flash_swap<CoinTypeX, CoinTypeB>(
                config,
                pool_x_b,
                coin::into_balance(coin::zero<CoinTypeX>(ctx)),
                coin::into_balance(coin_b),
                receipt_b_x
            );

            coin::join(&mut coin_in_a, received_coin_a);
        };

        (coin_in_a, coin_in_b)
    }

    public fun exact_input_for_router_three<CoinTypeA, CoinTypeX, CoinTypeY, CoinTypeB>(
        config: &GlobalConfig,
        pool_a_x: &mut Pool<CoinTypeA, CoinTypeX>,
        pool_x_y: &mut Pool<CoinTypeX, CoinTypeY>,
        pool_y_b: &mut Pool<CoinTypeY, CoinTypeB>,
        mut coin_in_a: Coin<CoinTypeA>,
        mut coin_in_b: Coin<CoinTypeB>,
        a2b: bool,
        amount: u64,
        amount_min_out: u64,
        clock: &Clock,
        ctx: &mut TxContext
    ): (Coin<CoinTypeA>, Coin<CoinTypeB>) {
        if (a2b) {
            // Step 1: Swap A → X
            let coin_a = coin::split(&mut coin_in_a, amount, ctx);
            let (swapped_coin_a, received_coin_x) = exact_input<CoinTypeA, CoinTypeX>(
                config,
                pool_a_x,
                coin_a,
                coin::zero<CoinTypeX>(ctx),
                true,
                amount,
                clock,
                ctx
            );
            coin::destroy_zero(swapped_coin_a);
            
            // Step 2: Swap X → Y
            let amount_x = coin::value(&received_coin_x);
            let (swapped_coin_x, received_coin_y) = exact_input<CoinTypeX, CoinTypeY>(
                config,
                pool_x_y,
                received_coin_x,
                coin::zero<CoinTypeY>(ctx),
                true,
                amount_x,
                clock,
                ctx
            );
            coin::destroy_zero(swapped_coin_x);
            
            // Step 3: Swap Y → B
            let amount_y = coin::value(&received_coin_y);
            let (swapped_coin_y, received_coin_b) = exact_input<CoinTypeY, CoinTypeB>(
                config,
                pool_y_b,
                received_coin_y,
                coin::zero<CoinTypeB>(ctx),
                true,
                amount_y,
                clock,
                ctx
            );
            coin::destroy_zero(swapped_coin_y);
            
            let amount_out = coin::value(&received_coin_b);
            assert!(amount_out >= amount_min_out, ERR_INSUFFICIENT_OUT_AMOUNT);
            
            coin::join(&mut coin_in_b, received_coin_b);
        }  else {
            // Step 1: Swap B → Y
            let coin_b = coin::split(&mut coin_in_b, amount, ctx);
            let (received_coin_y, swapped_coin_b) = exact_input<CoinTypeY, CoinTypeB>(
                config,
                pool_y_b,
                coin::zero<CoinTypeY>(ctx),
                coin_b,
                false,
                amount,
                clock,
                ctx
            );
            coin::destroy_zero(swapped_coin_b);
            
            // Step 2: Swap Y → X
            let amount_y = coin::value(&received_coin_y);
            let (received_coin_x, swapped_coin_y) = exact_input<CoinTypeX, CoinTypeY>(
                config,
                pool_x_y,
                coin::zero<CoinTypeX>(ctx),
                received_coin_y,
                false,
                amount_y,
                clock,
                ctx
            );
            coin::destroy_zero(swapped_coin_y);
            
            // Step 3: Swap X → A
            let amount_x = coin::value(&received_coin_x);
            let (received_coin_a, swapped_coin_x) = exact_input<CoinTypeA, CoinTypeX>(
                config,
                pool_a_x,
                coin::zero<CoinTypeA>(ctx),
                received_coin_x,
                false,
                amount_x,
                clock,
                ctx
            );
            coin::destroy_zero(swapped_coin_x);
            
            let amount_out = coin::value(&received_coin_a);
            assert!(amount_out >= amount_min_out, ERR_INSUFFICIENT_OUT_AMOUNT);
            
            coin::join(&mut coin_in_a, received_coin_a);
        };

        (coin_in_a, coin_in_b)
    }

    public fun exact_output_for_router_three<CoinTypeA, CoinTypeX, CoinTypeY, CoinTypeB>(
        config: &GlobalConfig,
        pool_a_x: &mut Pool<CoinTypeA, CoinTypeX>,
        pool_x_y: &mut Pool<CoinTypeX, CoinTypeY>,  
        pool_y_b: &mut Pool<CoinTypeY, CoinTypeB>,      
        mut coin_in_a: Coin<CoinTypeA>,
        mut coin_in_b: Coin<CoinTypeB>,
        a2b: bool,
        amount: u64,
        amount_max_in: u64,
        clock: &Clock,
        ctx: &mut TxContext
    ): (Coin<CoinTypeA>, Coin<CoinTypeB>) {
        if (a2b){
            let (
                swapped_coin_y,
                received_coin_b,
                receipt_y_b
            ) = exact_output<CoinTypeY, CoinTypeB>(
                config,
                pool_y_b,
                true,
                amount,
                clock,
                ctx
            );
            coin::destroy_zero(swapped_coin_y);
            let pay_amount_y = swap_pay_amount(&receipt_y_b);

            let (
                swapped_coin_x,
                received_coin_y,
                receipt_x_y
            ) = exact_output<CoinTypeX, CoinTypeY>(
                config,
                pool_x_y,
                true,
                pay_amount_y,
                clock,
                ctx
            );
            coin::destroy_zero(swapped_coin_x);
            let pay_amount_x = swap_pay_amount(&receipt_x_y);

            let (
                swapped_coin_a,
                received_coin_x,
                receipt_a_x
            ) = exact_output<CoinTypeA, CoinTypeX>(
                config,
                pool_a_x,
                true,
                pay_amount_x,
                clock,
                ctx
            );
            coin::destroy_zero(swapped_coin_a);
            let pay_amount_a = swap_pay_amount(&receipt_a_x);
            assert!(pay_amount_a <= amount_max_in, ERR_INSUFFICIENT_IN_AMOUNT);

            repay_flash_swap<CoinTypeY, CoinTypeB>(
                config,
                pool_y_b,
                coin::into_balance(received_coin_y),
                coin::into_balance(coin::zero<CoinTypeB>(ctx)),
                receipt_y_b
            );

            repay_flash_swap<CoinTypeX, CoinTypeY>(
                config,
                pool_x_y,
                coin::into_balance(received_coin_x),
                coin::into_balance(coin::zero<CoinTypeY>(ctx)),
                receipt_x_y
            );

            let coin_a = coin::split(&mut coin_in_a, pay_amount_a, ctx);
            repay_flash_swap<CoinTypeA, CoinTypeX>(
                config,
                pool_a_x,
                coin::into_balance(coin_a),
                coin::into_balance(coin::zero<CoinTypeX>(ctx)),
                receipt_a_x
            );

            coin::join(&mut coin_in_b, received_coin_b);
        } 
        else {
            let (
                received_coin_a,
                swapped_coin_x,
                receipt_x_a
            ) = exact_output<CoinTypeA, CoinTypeX>(
                config,
                pool_a_x,
                false,
                amount,
                clock,
                ctx
            );
            coin::destroy_zero(swapped_coin_x);
            let pay_amount_x = swap_pay_amount(&receipt_x_a);

            let (
                received_coin_x,
                swapped_coin_y,
                receipt_y_x
            ) = exact_output<CoinTypeX, CoinTypeY>(
                config,
                pool_x_y,
                false,
                pay_amount_x,
                clock,
                ctx
            );
            coin::destroy_zero(swapped_coin_y);
            let pay_amount_y = swap_pay_amount(&receipt_y_x);

            let (
                received_coin_y,
                swapped_coin_b,
                receipt_b_y
            ) = exact_output<CoinTypeY, CoinTypeB>(
                config,
                pool_y_b,
                false,
                pay_amount_y,
                clock,
                ctx
            );
            coin::destroy_zero(swapped_coin_b);
            let pay_amount_b = swap_pay_amount(&receipt_b_y);
            assert!(pay_amount_b <= amount_max_in, ERR_INSUFFICIENT_IN_AMOUNT);

            repay_flash_swap<CoinTypeA, CoinTypeX>(
                config,
                pool_a_x,
                coin::into_balance(coin::zero<CoinTypeA>(ctx)),
                coin::into_balance(received_coin_x),
                receipt_x_a
            );

            repay_flash_swap<CoinTypeX, CoinTypeY>(
                config,
                pool_x_y,
                coin::into_balance(coin::zero<CoinTypeX>(ctx)),
                coin::into_balance(received_coin_y),
                receipt_y_x
            );

            let coin_b = coin::split(&mut coin_in_b, pay_amount_b, ctx);
            repay_flash_swap<CoinTypeY, CoinTypeB>(
                config,
                pool_y_b,
                coin::into_balance(coin::zero<CoinTypeY>(ctx)),
                coin::into_balance(coin_b),
                receipt_b_y
            );

            coin::join(&mut coin_in_a, received_coin_a);
        };

        (coin_in_a, coin_in_b)
    }
}