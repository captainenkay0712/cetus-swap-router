module cetus::calculator {
    use cetus_clmm::pool;

    public struct CalculatedSwapResult has key, store {
        id: UID,
        data: pool::CalculatedSwapResult
    }

    public fun calculate_swap_result<CoinTypeA, CoinTypeB>(
        pool: &pool::Pool<CoinTypeA, CoinTypeB>,
        a2b: bool,
        by_amount_in: bool,
        amount: u64,
        ctx: &mut TxContext,
    ): CalculatedSwapResult {
        let result = pool::calculate_swap_result<CoinTypeA, CoinTypeB>(
            pool,
            a2b,
            by_amount_in,
            amount
        );
        
        CalculatedSwapResult {
            id: object::new(ctx),
            data: result
        }
    }
}