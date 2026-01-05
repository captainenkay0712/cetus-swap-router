# Swap Router Tests

Test suite documentation for the `swap_router` module in Cetus CLMM protocol.

## Overview

The `swap_router` module provides wrapper functions for performing swaps in CLMM pools with two modes:
- **Exact Input**: Specify the input token amount, receive variable output amount
- **Exact Output**: Specify the desired output token amount, pay variable input amount

## Pool Configuration

Test cases use a pool with the following configuration:
- **Token Pair**: CETUS/USDC
- **Price Ratio**: 1 CETUS ≈ 10 USDC
- **Tick**: 23027
- **Liquidity**: ~100M CETUS : ~1000M USDC
- **Fee**: 0.3% (standard)

## Test Cases

### 1. `test_swap_exact_input_for_router_one_for_a_to_b`

**Description**: Test swap with exact input from CETUS → USDC

**Input**:
- Initial CETUS: 10M
- Initial USDC: 0
- Swap amount: 1M CETUS
- Min output: 9M USDC (10% slippage tolerance)

**Expected Output**:
- Final CETUS: 9M (decreased by 1M)
- Final USDC: ~9.9M (received ~10x with 0.3% fee)
- Exchange rate: ~1:9.9

**Assertions**:
```move
assert_eq!(final_a, initial_a - swap_amount);
assert!(final_b >= min_out);
assert!(final_b >= 9000000 && final_b <= 11000000);
```

---

### 2. `test_swap_exact_input_for_router_one_for_b_to_a`

**Description**: Test swap with exact input from USDC → CETUS (reverse direction)

**Input**:
- Initial CETUS: 0
- Initial USDC: 100M
- Swap amount: 10M USDC
- Min output: 0.9M CETUS (10% slippage tolerance)

**Expected Output**:
- Final CETUS: ~1M (received ~1/10 with fee)
- Final USDC: 90M (decreased by 10M)
- Exchange rate: ~10:1

**Assertions**:
```move
assert_eq!(final_b, initial_b - swap_amount);
assert!(final_a >= min_out);
assert!(final_a >= 900000 && final_a <= 1100000);
```

---

### 3. `test_swap_exact_output_for_router_one_for_a_to_b`

**Description**: Test swap with exact output, desire exact USDC amount, pay CETUS

**Input**:
- Initial CETUS: 10M
- Initial USDC: 0
- Desired output: 10M USDC (exact)
- Max input: 1.5M CETUS (50% buffer)

**Expected Output**:
- Final USDC: 10M (exact amount_out)
- Final CETUS: ~9M (paid ~1M CETUS)
- Paid amount: ~1.01M CETUS (includes fee)

**Assertions**:
```move
assert_eq!(final_b, initial_b + amount_out);
let paid = initial_a - final_a;
assert!(paid <= amount_max_in);
assert!(paid >= 900000 && paid <= 1200000);
```

**Use case**: 
- User wants to buy exactly 10M USDC
- Willing to pay up to 1.5M CETUS
- System calculates and takes only the necessary amount of CETUS (~1.01M)

---

### 4. `test_swap_exact_output_for_router_one_for_b_to_a`

**Description**: Test swap with exact output, desire exact CETUS amount, pay USDC

**Input**:
- Initial CETUS: 0
- Initial USDC: 100M
- Desired output: 1M CETUS (exact)
- Max input: 12M USDC (20% buffer)

**Expected Output**:
- Final CETUS: 1M (exact amount_out)
- Final USDC: ~90M (paid ~10M USDC)
- Paid amount: ~10.1M USDC (includes fee)

**Assertions**:
```move
assert_eq!(final_a, initial_a + amount_out);
let paid = initial_b - final_b;
assert!(paid <= amount_max_in);
assert!(paid >= 9000000 && paid <= 11000000);
```

**Use case**:
- User wants to buy exactly 1M CETUS
- Willing to pay up to 12M USDC
- System calculates and takes only the necessary amount of USDC (~10.1M)

---

## Key Concepts

### Exact Input vs Exact Output

| Feature | Exact Input | Exact Output |
|---------|-------------|--------------|
| **User specifies** | Input amount | Output amount |
| **Variable** | Output amount | Input amount |
| **Slippage control** | `min_out` | `max_in` |
| **Use case** | "I want to sell X tokens" | "I want to buy X tokens" |

### Price Impact & Slippage

- **Price Impact**: Price change due to large swap amount relative to liquidity
- **Slippage**: Difference between expected price and execution price
- **Fee**: 0.3% per swap (distributed to LPs)

### Test Tolerances

- Exact input: Allow 10% slippage range (9-11x for 1:10 ratio)
- Exact output: Allow 20% buffer on max input
- Reason: Pool fee + price impact + rounding

---

## Running Tests

```bash
# Run all tests
sui move test

# Run specific test
sui move test test_swap_exact_input_for_router_one_for_a_to_b

# Run with gas profiling
sui move test --gas-limit 1000000000
```

---

## Debug Output Format

Each test prints the following values:
```
[debug] initial_a  → Initial balance of token A
[debug] initial_b  → Initial balance of token B  
[debug] final_a    → Final balance of token A
[debug] final_b    → Final balance of token B
```

**Example Output**:
```
[debug] 10000000   → Start: 10M CETUS
[debug] 0          → Start: 0 USDC
[debug] 9000000    → End: 9M CETUS (-1M)
[debug] 9900007    → End: 9.9M USDC (+9.9M)
```

---

## Error Scenarios (Future Tests)

Test cases to add:

1. **Slippage exceeded**: `min_out` too high or `max_in` too low
2. **Insufficient balance**: Not enough coins to swap
3. **Zero amount**: Swap with amount = 0
4. **Price impact too high**: Swap amount too large causing price impact >50%

---

## Implementation Notes

### Router Functions

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

### Key Features

1. **Coin merging**: Automatically merges output coin with existing balance
2. **Zero handling**: Destroys zero coins to avoid errors
3. **Flash swap**: Uses flash swap internally, repays immediately after
4. **Bidirectional**: Supports both A→B and B→A in the same function

---

## References

- [Cetus CLMM Documentation](https://docs.cetus.zone/)
- [Uniswap V3 Whitepaper](https://uniswap.org/whitepaper-v3.pdf)
- [Sui Move Documentation](https://docs.sui.io/guides/developer/sui-101/move-overview)
