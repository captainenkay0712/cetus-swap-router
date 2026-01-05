module cetus::swap_router {
    use sui::coin::{Self, Coin};
    use sui::clock::Clock;
    use cetus_clmm::config::GlobalConfig;
    use cetus_clmm::tick_math::{min_sqrt_price, max_sqrt_price};
    use cetus_clmm::pool::{Pool, flash_swap, repay_flash_swap, FlashSwapReceipt, swap_pay_amount};

    // Swap amount incorrect
    const ERR_SWAP_AMOUNT_INCORRECT: u64 = 2;
    // Insufficient output amount
    const ERR_INSUFFICIENT_OUT_AMOUNT: u64 = 3;
    /// Insufficient amount out
    const ERR_INSUFFICIENT_IN_AMOUNT: u64 = 4;

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
        
        let (balance_swaped_a, balance_swaped_b, receipt) = flash_swap<CoinTypeA, CoinTypeB>(
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
            coin::destroy_zero(coin::from_balance(balance_swaped_a, ctx));
            (coin::zero<CoinTypeA>(ctx), coin::from_balance(balance_swaped_b, ctx))
        } else {
            coin::destroy_zero(coin_in_a);
            repay_flash_swap<CoinTypeA, CoinTypeB>(
                config,
                pool,
                coin::into_balance(coin::zero<CoinTypeA>(ctx)),
                coin::into_balance(coin_in_b),
                receipt
            );
            coin::destroy_zero(coin::from_balance(balance_swaped_b, ctx));
            (coin::from_balance(balance_swaped_a, ctx), coin::zero<CoinTypeB>(ctx))
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
        let coin_a: Coin<CoinTypeA>;
        let coin_b: Coin<CoinTypeB>;

        if (a2b) {
            let swap_coin = coin::split(&mut coin_in_a, amount, ctx);
            (coin_a, coin_b) =  exact_input<CoinTypeA, CoinTypeB>(
                config,
                pool,
                swap_coin,
                coin::zero<CoinTypeB>(ctx),
                a2b,
                amount,
                clock,
                ctx
            );
            coin::destroy_zero(coin_a);

            let amount_out = coin::value(&coin_b);
            assert!(amount_out >= amount_min_out, ERR_INSUFFICIENT_OUT_AMOUNT);

            coin::join(&mut coin_in_b, coin_b);
        } else {
            let swap_coin = coin::split(&mut coin_in_b, amount, ctx);
            (coin_a, coin_b) =  exact_input<CoinTypeA, CoinTypeB>(
                config,
                pool,
                coin::zero<CoinTypeA>(ctx),
                swap_coin,
                a2b,
                amount,
                clock,
                ctx
            );
            coin::destroy_zero(coin_b);

            let amount_out = coin::value(&coin_a);
            assert!(amount_out >= amount_min_out, ERR_INSUFFICIENT_OUT_AMOUNT);

            coin::join(&mut coin_in_a, coin_a);
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
            coin_swaped_a,
            coin_swaped_b,
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
            coin::destroy_zero(coin_swaped_a);
            let swap_coin = coin::split(&mut coin_in_a, pay_amount, ctx);

            repay_flash_swap<CoinTypeA, CoinTypeB>(
                config,
                pool,
                coin::into_balance(swap_coin),
                coin::into_balance(coin::zero<CoinTypeB>(ctx)),
                receipt
            );

            coin::join(&mut coin_in_b, coin_swaped_b);
        } else {
            coin::destroy_zero(coin_swaped_b);
            let swap_coin = coin::split(&mut coin_in_b, pay_amount, ctx);

            repay_flash_swap<CoinTypeA, CoinTypeB>(
                config,
                pool,
                coin::into_balance(coin::zero<CoinTypeA>(ctx)),
                coin::into_balance(swap_coin),
                receipt
            );

            coin::join(&mut coin_in_a, coin_swaped_a);
        };

        (coin_in_a, coin_in_b)
    }
}