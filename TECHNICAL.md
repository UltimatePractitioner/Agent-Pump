# AgentPump - Technical Architecture

> **Deep dive into the bonding curve mechanics, smart contract design, and system architecture.**

---

## System Overview

AgentPump consists of four core on-chain programs that work together to provide a complete token launch platform for AI agents.

```
┌─────────────────────────────────────────────────────────────────┐
│                        USER INTERFACE                            │
│                   (dApp / SDK / Direct Calls)                    │
└─────────────────────────────┬───────────────────────────────────┘
                              │
┌─────────────────────────────▼───────────────────────────────────┐
│                      AGENTPUMP CORE                              │
├───────────────┬───────────────┬───────────────┬─────────────────┤
│ BondingCurve  │ AgentRegistry │ TokenFactory  │ TradingEngine   │
│    Program    │    Program    │    Program    │    Program      │
├───────────────┼───────────────┼───────────────┼─────────────────┤
│ • Price calc  │ • Identity    │ • Launch coord│ • Order match   │
│ • Curve math  │ • Reputation  │ • Token deploy│ • Slippage      │
│ • Liquidity   │ • Verification│ • Metadata    │ • Settlement    │
└───────┬───────┴───────┬───────┴───────┬───────┴────────┬────────┘
        │               │               │                │
        └───────────────┴───────┬───────┴────────────────┘
                                │
                    ┌───────────▼───────────┐
                    │     Solana Runtime    │
                    │  • SPL Token Program  │
                    │  • System Program     │
                    │  • Associated Token   │
                    └───────────────────────┘
```

---

## Core Programs

### 1. BondingCurve Program

**Purpose**: Mathematical price discovery and liquidity management.

#### Account Structure

```rust
#[account]
pub struct Curve {
    pub token_mint: Pubkey,
    pub curve_type: CurveType,
    pub base_price: u64,           // Starting price (lamports)
    pub slope: u64,                // Growth rate
    pub current_supply: u64,       // Tokens minted
    pub reserve_balance: u64,      // SOL in curve
    pub migration_threshold: u64,  // When to migrate to AMM
    pub is_migrated: bool,
    pub created_at: i64,
    pub bump: u8,
}

#[derive(AnchorSerialize, AnchorDeserialize, Clone, PartialEq)]
pub enum CurveType {
    Linear,      // P = base + slope * supply
    Exponential, // P = base * (1 + slope) ^ supply
    Sigmoid,     // P = max / (1 + e^(-slope * (supply - mid)))
}
```

#### Price Calculation

**Linear Curve**:
```rust
pub fn calculate_price_linear(&self, supply: u64, amount: u64) -> u64 {
    let start_price = self.base_price + (self.slope * supply);
    let end_price = self.base_price + (self.slope * (supply + amount));
    (start_price + end_price) * amount / 2  // Trapezoidal integration
}
```

**Exponential Curve**:
```rust
pub fn calculate_price_exponential(&self, supply: u64, amount: u64) -> u64 {
    // Approximation for small steps
    let current_price = self.base_price * (1 + self.slope).pow(supply);
    let avg_price = current_price * (1 + self.slope / 2).pow(amount);
    avg_price * amount
}
```

**Sigmoid Curve**:
```rust
pub fn calculate_price_sigmoid(&self, supply: u64, amount: u64) -> u64 {
    let max_price = self.base_price * 100; // 100x max
    let midpoint = self.migration_threshold / 2;
    
    // Sigmoid integral approximation
    let k = self.slope;
    let x1 = supply as f64;
    let x2 = (supply + amount) as f64;
    let m = midpoint as f64;
    
    let integral = |x: f64| -> f64 {
        max_price as f64 * (x + (1.0/k) * ((k*(m-x)).exp() + 1.0).ln())
    };
    
    (integral(x2) - integral(x1)) as u64
}
```

#### Instructions

```rust
/// Initialize a new bonding curve
pub fn initialize_curve(
    ctx: Context<InitializeCurve>,
    curve_type: CurveType,
    base_price: u64,
    slope: u64,
    migration_threshold: u64,
) -> Result<()>;

/// Buy tokens from curve
pub fn buy(
    ctx: Context<Buy>,
    amount: u64,
    max_price: u64,  // Slippage protection
) -> Result<()>;

/// Sell tokens to curve
pub fn sell(
    ctx: Context<Sell>,
    amount: u64,
    min_price: u64,  // Slippage protection
) -> Result<()>;

/// Migrate to AMM when threshold reached
pub fn migrate_to_amm(ctx: Context<MigrateToAmm>) -> Result<()>;
```

---

### 2. AgentRegistry Program

**Purpose**: Agent identity verification and reputation tracking.

#### Account Structure

```rust
#[account]
pub struct Agent {
    pub id: String,                    // Unique agent ID
    pub owner: Pubkey,                 // Wallet address
    pub said_proof: Option<Pubkey>,    // SAID verification
    pub created_at: i64,
    pub reputation_score: u64,         // 0-10000
    pub total_launches: u32,
    pub total_volume: u64,
    pub unique_holders: u32,
    pub uptime_score: u16,             // 0-100
    pub last_active: i64,
    pub bump: u8,
}

#[account]
pub struct ReputationSnapshot {
    pub agent: Pubkey,
    pub timestamp: i64,
    pub score: u64,
    pub metrics: ReputationMetrics,
}

#[derive(AnchorSerialize, AnchorDeserialize, Clone)]
pub struct ReputationMetrics {
    pub age_weight: u64,
    pub transaction_weight: u64,
    pub holder_weight: u64,
    pub uptime_weight: u64,
    pub community_weight: u64,
}
```

#### Reputation Algorithm

```rust
impl Agent {
    pub fn calculate_reputation(&self, now: i64) -> u64 {
        // Age score (20% weight) - max at 1 year
        let age_days = ((now - self.created_at) / 86400) as u64;
        let age_score = min(age_days, 365) * 10000 / 365;
        
        // Transaction score (25% weight) - logarithmic
        let tx_score = (self.total_volume as f64).ln().min(10000.0) as u64;
        
        // Holder score (20% weight) - diminishing returns
        let holder_score = (self.unique_holders as u64 * 100)
            .min(10000); // Cap at 100 holders
        
        // Uptime score (15% weight) - direct percentage
        let uptime_score = (self.uptime_score as u64) * 100;
        
        // Community score (20% weight) - off-chain oracle
        let community_score = self.get_community_score();
        
        // Weighted average
        (age_score * 20 + 
         tx_score * 25 + 
         holder_score * 20 + 
         uptime_score * 15 + 
         community_score * 20) / 100
    }
}
```

#### Verification Methods

**SAID (Solana Agent ID)**:
```rust
pub fn verify_said(
    ctx: Context<VerifySaid>,
    proof: SAIDProof,
) -> Result<()> {
    // Verify cryptographic proof
    let hash = hash_proof(&proof);
    require!(
        verify_ed25519(&proof.public_key, &hash, &proof.signature),
        ErrorCode::InvalidProof
    );
    
    // Check SAID registry
    let said_account = fetch_said_registry(&proof.said_id)?;
    require!(
        said_account.owner == ctx.accounts.agent.owner,
        ErrorCode::OwnershipMismatch
    );
    
    ctx.accounts.agent.said_proof = Some(proof.said_id);
    Ok(())
}
```

**ERC-8004 Bridge**:
```rust
pub fn verify_erc8004(
    ctx: Context<VerifyErc8004>,
    wormhole_proof: WormholeProof,
) -> Result<()> {
    // Verify Wormhole VAA
    let vaa = verify_wormhole_vaa(&wormhole_proof)?;
    
    // Extract ERC-8004 attestation
    let attestation = parse_erc8004_attestation(&vaa.payload)?;
    
    // Link to agent
    ctx.accounts.agent.erc8004_id = Some(attestation.agent_id);
    Ok(())
}
```

---

### 3. TokenFactory Program

**Purpose**: Coordinate token deployment with bonding curves.

#### Account Structure

```rust
#[account]
pub struct LaunchConfig {
    pub agent: Pubkey,
    pub token_mint: Pubkey,
    pub curve: Pubkey,
    pub metadata: TokenMetadata,
    pub launch_status: LaunchStatus,
    pub created_at: i64,
    pub bump: u8,
}

#[derive(AnchorSerialize, AnchorDeserialize, Clone)]
pub struct TokenMetadata {
    pub name: String,
    pub symbol: String,
    pub uri: String,           // IPFS/Arweave link
    pub description: String,
    pub socials: SocialLinks,
}

#[derive(AnchorSerialize, AnchorDeserialize, Clone, PartialEq)]
pub enum LaunchStatus {
    Pending,      // Awaiting initialization
    Active,       // Trading live
    Migrated,     // Moved to AMM
    Paused,       // Emergency stop
}
```

#### Launch Flow

```rust
pub fn launch_token(
    ctx: Context<LaunchToken>,
    params: LaunchParams,
) -> Result<Pubkey> {
    // 1. Verify agent is registered
    require!(
        ctx.accounts.agent.reputation_score >= MIN_REPUTATION,
        ErrorCode::InsufficientReputation
    );
    
    // 2. Create SPL token mint
    let mint = create_mint(
        &ctx.accounts.payer,
        &ctx.accounts.mint_authority,
        params.decimals,
    )?;
    
    // 3. Initialize bonding curve
    let curve = initialize_curve(
        &ctx.accounts.curve_program,
        &mint,
        params.curve_config,
    )?;
    
    // 4. Create metadata account
    let metadata = create_metadata_account(
        &ctx.accounts.metadata_program,
        &mint,
        params.metadata,
    )?;
    
    // 5. Store launch config
    ctx.accounts.launch_config.set_inner(LaunchConfig {
        agent: ctx.accounts.agent.key(),
        token_mint: mint,
        curve,
        metadata,
        launch_status: LaunchStatus::Active,
        created_at: Clock::get()?.unix_timestamp,
        bump: ctx.bumps.launch_config,
    });
    
    // 6. Emit event
    emit!(TokenLaunched {
        agent: ctx.accounts.agent.key(),
        mint,
        curve,
        timestamp: Clock::get()?.unix_timestamp,
    });
    
    Ok(mint)
}
```

---

### 4. TradingEngine Program

**Purpose**: Execute buy/sell orders with slippage protection.

#### Account Structure

```rust
#[account]
pub struct Order {
    pub trader: Pubkey,
    pub token_mint: Pubkey,
    pub order_type: OrderType,
    pub amount: u64,
    pub limit_price: u64,
    pub status: OrderStatus,
    pub created_at: i64,
    pub expires_at: i64,
}

#[derive(AnchorSerialize, AnchorDeserialize, Clone, PartialEq)]
pub enum OrderType {
    MarketBuy,
    MarketSell,
    LimitBuy { price: u64 },
    LimitSell { price: u64 },
}
```

#### Trade Execution

```rust
pub fn execute_buy(
    ctx: Context<ExecuteBuy>,
    amount: u64,
    max_slippage_bps: u16,  // Basis points (e.g., 50 = 0.5%)
) -> Result<()> {
    // 1. Get current price from curve
    let curve = &ctx.accounts.curve;
    let current_price = curve.calculate_price(amount);
    
    // 2. Check slippage
    let max_acceptable = current_price * (10000 + max_slippage_bps as u64) / 10000;
    require!(
        ctx.accounts.order.limit_price <= max_acceptable,
        ErrorCode::SlippageExceeded
    );
    
    // 3. Transfer SOL to curve
    invoke(
        &system_instruction::transfer(
            &ctx.accounts.buyer.key(),
            &ctx.accounts.curue.key(),
            current_price,
        ),
        &[
            ctx.accounts.buyer.to_account_info(),
            ctx.accounts.curve.to_account_info(),
        ],
    )?;
    
    // 4. Mint tokens to buyer
    token::mint_to(
        CpiContext::new(
            ctx.accounts.token_program.to_account_info(),
            MintTo {
                mint: ctx.accounts.token_mint.to_account_info(),
                to: ctx.accounts.buyer_token_account.to_account_info(),
                authority: ctx.accounts.mint_authority.to_account_info(),
            },
        ),
        amount,
    )?;
    
    // 5. Update curve state
    ctx.accounts.curve.current_supply += amount;
    ctx.accounts.curve.reserve_balance += current_price;
    
    // 6. Check migration threshold
    if ctx.accounts.curve.current_supply >= ctx.accounts.curve.migration_threshold {
        ctx.accounts.curve.is_migrated = true;
        // Trigger migration logic...
    }
    
    // 7. Emit trade event
    emit!(TradeExecuted {
        trader: ctx.accounts.buyer.key(),
        token_mint: ctx.accounts.token_mint.key(),
        amount,
        price: current_price,
        is_buy: true,
        timestamp: Clock::get()?.unix_timestamp,
    });
    
    Ok(())
}
```

---

## Data Flow

### Token Launch Sequence

```
1. AGENT → TokenFactory::launch_token
   ├── 2. Creates SPL Mint
   ├── 3. Calls BondingCurve::initialize_curve
   ├── 4. Creates Metadata
   └── 5. Emits TokenLaunched event

6. USER → TradingEngine::execute_buy
   ├── 7. Queries BondingCurve for price
   ├── 8. Transfers SOL to curve
   ├── 9. Mints tokens to user
   └── 10. Updates curve state
```

### Migration Sequence

```
When supply >= migration_threshold:

1. ANYONE → BondingCurve::migrate_to_amm
   ├── 2. Create Raydium/Orca pool
   ├── 3. Transfer curve liquidity to pool
   ├── 4. Burn curve LP tokens to agent
   ├── 5. Mark curve as migrated
   └── 6. Emit MigrationCompleted event
```

---

## Security Considerations

### Reentrancy Protection

All state changes happen before external calls (CEI pattern):

```rust
// Correct: State first, then transfer
ctx.accounts.curve.reserve_balance += amount;  // Effect
invoke(&transfer_instruction, accounts)?;        // Interaction

// Events always last
emit!(TradeExecuted { ... });
```

### Integer Overflow

Using Solana's built-in overflow checks (Rust default in release):

```rust
// These will panic on overflow
curve.reserve_balance += amount;
let new_supply = curve.current_supply + amount;
```

### Access Control

```rust
// Only agent owner can launch tokens
require!(
    ctx.accounts.agent.owner == ctx.accounts.payer.key(),
    ErrorCode::Unauthorized
);

// Only curve can mint/burn
curve.signer_seeds = &[b"curve", &token_mint.key().to_bytes(), &[bump]];
```

---

## Gas Optimization

### Account Size Minimization

```rust
// Pack related fields into u128 where possible
pub struct CompactCurve {
    pub supply_and_reserve: u128,  // High 64: supply, Low 64: reserve
    pub price_params: u128,        // packed price data
}
```

### PDA Derivation

```rust
// Consistent seed patterns for easy lookup
pub fn find_curve_address(token_mint: &Pubkey) -> (Pubkey, u8) {
    Pubkey::find_program_address(
        &[b"curve", &token_mint.to_bytes()],
        &BONDING_CURVE_PROGRAM_ID,
    )
}
```

---

## Testing Strategy

### Unit Tests

```rust
#[cfg(test)]
mod curve_tests {
    use super::*;
    
    #[test]
    fn test_linear_price_calculation() {
        let curve = Curve {
            base_price: 1000,
            slope: 10,
            current_supply: 100,
            ..Default::default()
        };
        
        let price = curve.calculate_price_linear(100, 10);
        // P_start = 1000 + 10*100 = 2000
        // P_end = 1000 + 10*110 = 2100
        // Price = (2000 + 2100) * 10 / 2 = 20500
        assert_eq!(price, 20500);
    }
}
```

### Integration Tests

```rust
#[tokio::test]
async fn test_full_launch_and_trade() {
    // Setup
    let (mut banks_client, payer, recent_blockhash) = program_test().start().await;
    
    // Launch token
    let launch_tx = launch_token_transaction(&payer, &params);
    banks_client.process_transaction(launch_tx).await.unwrap();
    
    // Buy tokens
    let buy_tx = buy_transaction(&payer, &mint, 1000);
    banks_client.process_transaction(buy_tx).await.unwrap();
    
    // Verify state
    let curve = get_curve_account(&banks_client, &mint).await;
    assert_eq!(curve.current_supply, 1000);
}
```

---

## Deployment Configuration

### Devnet

```toml
[programs.devnet]
agentpump = "Pump111111111111111111111111111111111111111"

[provider]
cluster = "devnet"
wallet = "~/.config/solana/id.json"
```

### Mainnet

```toml
[programs.mainnet]
agentpump = "Pump222222222222222222222222222222222222222"

[provider]
cluster = "mainnet"
wallet = "~/.config/solana/id.json"
```

---

## Monitoring

### Key Metrics

| Metric | Program | Event |
|--------|---------|-------|
| Token Launches | TokenFactory | TokenLaunched |
| Trade Volume | TradingEngine | TradeExecuted |
| Price Changes | BondingCurve | PriceUpdate |
| Reputation | AgentRegistry | ReputationUpdated |
| Migrations | BondingCurve | MigrationCompleted |

### Alert Conditions

```rust
// Monitor for unusual activity
if trade.amount > THRESHOLD_LARGE_TRADE {
    alert("Large trade detected", trade);
}

if curve.price_change_24h > THRESHOLD_PUMP {
    alert("Potential pump detected", curve);
}
```

---

**Last Updated**: February 3, 2026
**Version**: 1.0.0
**Audit Status**: Pending (Hackathon submission)
