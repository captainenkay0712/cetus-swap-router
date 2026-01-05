# Cetus Swap Router

A Move-based swap router implementation for Cetus CLMM (Concentrated Liquidity Market Maker) protocol on Sui blockchain.

## Overview

This project provides router functions for performing token swaps in Cetus CLMM pools with support for both exact input and exact output swap modes. The router handles coin management, slippage protection, and bidirectional swaps.

## Project Structure

```
cetus/
├── sources/
│   ├── swap_router.move      # Main swap router implementation
│   ├── calculator.move        # Price and amount calculations
│   ├── fetcher.move          # Data fetching utilities
│   ├── liquidity.move        # Liquidity management
│   └── rewarder.move         # Reward distribution
├── tests/
│   ├── swap_router_tests.move # Comprehensive test suite
│   ├── cetus_tests.move       # Integration tests
│   └── README.md              # Test documentation
├── Move.toml                  # Package manifest
└── README.md                  # This file
```

## Features

### Swap Router (`sources/swap_router.move`)

The swap router provides four main functions for token swaps:

#### 1. **exact_input**
Swap with exact input amount, receive variable output.

```move
public fun exact_input<CoinTypeA, CoinTypeB>(
    config: &GlobalConfig,
    pool: &mut Pool<CoinTypeA, CoinTypeB>,
    coin_in_a: Coin<CoinTypeA>,
    coin_in_b: Coin<CoinTypeB>,
    a2b: bool,
    amount: u64,
    amount_min_out: u64,
    sqrt_price_limit: u128,
    clock: &Clock,
    ctx: &mut TxContext
): (Coin<CoinTypeA>, Coin<CoinTypeB>, u64)
```

**Use Case**: "I want to sell exactly 1M CETUS"
- Input: Exact amount to swap
- Output: Variable amount received (protected by `amount_min_out`)
- Returns: Both coins and the actual amount swapped

#### 2. **exact_output**
Swap to receive exact output amount, pay variable input.

```move
public fun exact_output<CoinTypeA, CoinTypeB>(
    config: &GlobalConfig,
    pool: &mut Pool<CoinTypeA, CoinTypeB>,
    coin_in_a: Coin<CoinTypeA>,
    coin_in_b: Coin<CoinTypeB>,
    a2b: bool,
    amount: u64,
    amount_max_in: u64,
    sqrt_price_limit: u128,
    clock: &Clock,
    ctx: &mut TxContext
): (Coin<CoinTypeA>, Coin<CoinTypeB>, u64)
```

**Use Case**: "I want to buy exactly 10M USDC"
- Input: Variable amount paid (capped by `amount_max_in`)
- Output: Exact amount to receive
- Returns: Both coins and the actual amount paid

#### 3. **exact_input_for_router_one**
Simplified exact input swap for single-pool routes.

```move
public fun exact_input_for_router_one<CoinTypeA, CoinTypeB>(
    config: &GlobalConfig,
    pool: &mut Pool<CoinTypeA, CoinTypeB>,
    coin_a: Coin<CoinTypeA>,
    coin_b: Coin<CoinTypeB>,
    a2b: bool,
    amount: u64,
    amount_min_out: u64,
    clock: &Clock,
    ctx: &mut TxContext
): (Coin<CoinTypeA>, Coin<CoinTypeB>)
```

**Features**:
- Automatically merges output with existing balance
- Handles zero coin destruction
- Simplified interface without sqrt_price_limit

#### 4. **exact_output_for_router_one**
Simplified exact output swap for single-pool routes.

```move
public fun exact_output_for_router_one<CoinTypeA, CoinTypeB>(
    config: &GlobalConfig,
    pool: &mut Pool<CoinTypeA, CoinTypeB>,
    coin_a: Coin<CoinTypeA>,
    coin_b: Coin<CoinTypeB>,
    a2b: bool,
    amount: u64,
    amount_max_in: u64,
    clock: &Clock,
    ctx: &mut TxContext
): (Coin<CoinTypeA>, Coin<CoinTypeB>)
```

**Features**:
- Uses flash swap mechanism for exact output
- Automatically splits input coins for repayment
- Merges output with existing balance

### Key Capabilities

1. **Bidirectional Swaps**: Support both A→B and B→A in the same function
2. **Slippage Protection**: Built-in min/max amount checks
3. **Coin Management**: Automatic merging and zero coin handling
4. **Flash Swaps**: Efficient capital usage with flash swap mechanism
5. **Type Safety**: Generic type parameters ensure compile-time safety

## Error Codes

```move
const ERR_SWAP_AMOUNT_INCORRECT: u64 = 2;
const ERR_INSUFFICIENT_OUT_AMOUNT: u64 = 3;
const ERR_INSUFFICIENT_IN_AMOUNT: u64 = 4;
```

- **ERR_SWAP_AMOUNT_INCORRECT**: Actual swap amount doesn't match expected
- **ERR_INSUFFICIENT_OUT_AMOUNT**: Output amount below minimum (`amount_min_out`)
- **ERR_INSUFFICIENT_IN_AMOUNT**: Input amount exceeds maximum (`amount_max_in`)

## Installation

Add to your `Move.toml`:

```toml
[dependencies]
cetus = { git = "https://github.com/your-org/cetus.git", subdir = "", rev = "main" }
CetusClmm = { git = "https://github.com/CetusProtocol/cetus-clmm.git", subdir = "sui/cetus_clmm", rev = "main" }
Sui = { git = "https://github.com/MystenLabs/sui.git", subdir = "crates/sui-framework/packages/sui-framework", rev = "framework/testnet" }
```

## Usage Examples

### Example 1: Swap 1M CETUS for USDC (Exact Input)

```move
use cetus::swap_router::exact_input_for_router_one;

public fun swap_cetus_to_usdc(
    config: &GlobalConfig,
    pool: &mut Pool<CETUS, USDC>,
    cetus_coin: Coin<CETUS>,
    clock: &Clock,
    ctx: &mut TxContext
) {
    let usdc_coin = coin::zero(ctx);
    let (cetus_remaining, usdc_received) = exact_input_for_router_one(
        config,
        pool,
        cetus_coin,
        usdc_coin,
        true,              // a2b = true (CETUS → USDC)
        1_000_000,         // Swap 1M CETUS
        9_000_000,         // Expect at least 9M USDC (10% slippage)
        clock,
        ctx
    );
    
    // Handle coins...
    transfer::public_transfer(cetus_remaining, tx_context::sender(ctx));
    transfer::public_transfer(usdc_received, tx_context::sender(ctx));
}
```

### Example 2: Buy Exactly 10M USDC (Exact Output)

```move
use cetus::swap_router::exact_output_for_router_one;

public fun buy_exact_usdc(
    config: &GlobalConfig,
    pool: &mut Pool<CETUS, USDC>,
    cetus_coin: Coin<CETUS>,
    clock: &Clock,
    ctx: &mut TxContext
) {
    let usdc_coin = coin::zero(ctx);
    let (cetus_remaining, usdc_received) = exact_output_for_router_one(
        config,
        pool,
        cetus_coin,
        usdc_coin,
        true,              // a2b = true (CETUS → USDC)
        10_000_000,        // Want exactly 10M USDC
        1_500_000,         // Pay at most 1.5M CETUS
        clock,
        ctx
    );
    
    // usdc_received will be exactly 10M
    assert!(coin::value(&usdc_received) == 10_000_000, 0);
    
    // Handle coins...
    transfer::public_transfer(cetus_remaining, tx_context::sender(ctx));
    transfer::public_transfer(usdc_received, tx_context::sender(ctx));
}
```

## Testing

Run the comprehensive test suite:

```bash
# Run all tests
sui move test

# Run specific test
sui move test test_swap_exact_input_for_router_one_for_a_to_b

# Run with verbose output
sui move test --verbose

# Run with gas profiling
sui move test --gas-limit 1000000000
```

### Test Coverage

The test suite includes:
- ✅ Exact input swaps (A→B, B→A)
- ✅ Exact output swaps (A→B, B→A)
- ✅ Slippage protection validation
- ✅ Coin balance verification
- ✅ Price ratio validation

See [tests/README.md](tests/README.md) for detailed test documentation.

## Development

### Building

```bash
sui move build
```

### Testing

```bash
sui move test
```

### Publishing

```bash
sui client publish --gas-budget 100000000
```

## Design Principles

1. **Safety First**: Comprehensive error checking and slippage protection
2. **Type Safety**: Generic types prevent mixing incompatible tokens
3. **Efficiency**: Flash swaps minimize capital requirements
4. **Developer-Friendly**: Clear function names and intuitive parameters
5. **Composability**: Functions can be easily integrated into larger DeFi protocols

## Technical Details

### Flash Swap Mechanism

Exact output swaps use flash swaps to:
1. Borrow the exact output amount from the pool
2. Calculate required input amount
3. Repay the pool with input tokens
4. Return remaining coins to user

This approach is more capital-efficient than pre-calculating required input.

### Price Impact

Price impact depends on:
- Swap amount relative to pool liquidity
- Current tick and price
- Pool fee (typically 0.3%)

Larger swaps have higher price impact. Use slippage protection to prevent unexpected losses.

### Precision

All amounts are in base units (e.g., 1 USDC = 1_000_000 units if 6 decimals).
The router maintains precision through integer arithmetic.

## Dependencies

- **CetusClmm**: Core CLMM protocol (pools, positions, swaps)
- **Sui Framework**: Standard library and coin management
- **IntegerMate**: Integer math utilities

## Security Considerations

1. **Slippage Protection**: Always set appropriate `amount_min_out` or `amount_max_in`
2. **Price Oracle**: Use trusted price feeds for critical operations
3. **Front-Running**: Large swaps may be front-run; consider private transactions
4. **Testing**: Thoroughly test with realistic pool conditions

## Gas Optimization

- Use `exact_input_for_router_one` and `exact_output_for_router_one` for single swaps (lower gas)
- Batch multiple operations when possible
- Monitor gas usage with `sui move test --gas-limit`

## Contributing

Contributions are welcome! Please:
1. Fork the repository
2. Create a feature branch
3. Add tests for new functionality
4. Ensure all tests pass
5. Submit a pull request

## License

[Add your license here]

## Resources

- [Cetus Protocol Documentation](https://docs.cetus.zone/)
- [Sui Move Book](https://move-book.com/)
- [CLMM Concepts](https://docs.uniswap.org/concepts/protocol/concentrated-liquidity)
- [Sui Developer Portal](https://docs.sui.io/)

## Support

- Discord: [Cetus Community](https://discord.gg/cetus)
- Twitter: [@CetusProtocol](https://twitter.com/CetusProtocol)
- Documentation: [docs.cetus.zone](https://docs.cetus.zone/)

---

**Note**: This is a development version. Always audit smart contracts before production use.
