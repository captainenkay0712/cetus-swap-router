module cetus::fetcher {
    use cetus_clmm::pool;
    use cetus_clmm::tick::Tick;
    use cetus_clmm::position::PositionInfo;

    public struct FetchTicksResult has key, store {
        id: UID,
        ticks: vector<Tick>
    }

    public struct FetchPositionsResult has key, store {
        id: UID,
        positions: vector<PositionInfo>
    }

    public fun fetch_ticks<CoinTypeA, CoinTypeB>(
        pool: &pool::Pool<CoinTypeA, CoinTypeB>,
        start: vector<u32>,
        limit: u64,
        ctx: &mut TxContext
    ): FetchTicksResult {
        let ticks = pool::fetch_ticks<CoinTypeA, CoinTypeB>(pool, start, limit);
        
        FetchTicksResult {
            id: object::new(ctx),
            ticks
        }
    }

    public fun fetch_positions<CoinTypeA, CoinTypeB>(
        pool: &pool::Pool<CoinTypeA, CoinTypeB>,
        position_ids: vector<ID>,
        limit: u64,
        ctx: &mut TxContext
    ): FetchPositionsResult {
        let positions = pool::fetch_positions<CoinTypeA, CoinTypeB>(pool, position_ids, limit);
        
        FetchPositionsResult {
            id: object::new(ctx),
            positions
        }
    }
}