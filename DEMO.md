# AgentPump - Demo Script

> **Step-by-step demonstration of AgentPump features for hackathon judges.**

---

## 🎬 Demo Overview

**Duration**: 10 minutes
**Prerequisites**: Devnet SOL, Phantom wallet
**Goal**: Launch an agent token, trade it, and show the full ecosystem

---

## Pre-Demo Setup (2 min)

### 1. Open the dApp
```
URL: https://devnet.agentpump.io
```

### 2. Connect Wallet
- Click "Connect Wallet"
- Select Phantom
- Switch to Devnet
- Airdrop SOL if needed: `solana airdrop 2`

### 3. Create Agent Profile
```typescript
// Agent registration
curl -X POST https://api.agentpump.io/agents \
  -H "Content-Type: application/json" \
  -d '{
    "name": "DemoAgent-001",
    "type": "ORACLE",
    "description": "Demo agent for hackathon"
  }'
```

---

## Demo Part 1: Token Launch (3 min)

### Script

**Narrator**: "AgentPump lets any AI agent launch a token in under 60 seconds. Watch as our demo agent creates its own economy."

### Step 1: Navigate to Launchpad
1. Click "Launch Token" button
2. Select "DemoAgent-001" from dropdown

### Step 2: Configure Token
```
Token Name: DemoAgent Token
Symbol: DAT
Description: The official token of DemoAgent-001

Curve Type: Exponential
Initial Price: 0.001 SOL
Growth Rate: 1%
Max Supply: 1,000,000
Migration Threshold: 100,000 tokens
```

### Step 3: Upload Metadata
```
Logo: [Upload agent-icon.png]
Banner: [Upload banner.jpg]
Social Links:
  - Twitter: @DemoAgent001
  - Discord: discord.gg/demo
```

### Step 4: Launch!
```typescript
// Behind the scenes:
const tx = await agentPump.launchToken({
  agentId: "DemoAgent-001",
  name: "DemoAgent Token",
  symbol: "DAT",
  curveType: "exponential",
  basePrice: 0.001 * LAMPORTS_PER_SOL,
  slope: 0.01,
  maxSupply: 1_000_000,
  migrationThreshold: 100_000
});

// Result:
// ✓ SPL Token Mint Created: DAT...xyz
// ✓ Bonding Curve Initialized
// ✓ Metadata Uploaded to Arweave
// ✓ Token Live at: agentpump.io/token/DAT...xyz
```

**Show**: Transaction confirmation, token page loading

---

## Demo Part 2: Live Trading (3 min)

### Script

**Narrator**: "Now let's see the bonding curve in action. As more people buy, the price increases automatically."

### Step 1: Check Initial Price
```
Current Price: 0.001 SOL per DAT
Market Cap: $0
Holders: 1
```

### Step 2: Execute First Buy
```typescript
// Buy 1000 DAT tokens
const buyTx = await agentPump.buy({
  tokenMint: "DAT...xyz",
  amount: 1000,
  maxSlippage: 0.5  // 0.5%
});

// Result:
// Cost: ~1.05 SOL (price moved up slightly)
// Received: 1000 DAT
// New Price: 0.00105 SOL
```

**Show**: 
- Wallet confirmation
- Transaction success
- Price chart updating
- Portfolio showing DAT balance

### Step 3: Show Price Progression
```
Buy 1000 more tokens...
New Price: 0.00115 SOL

Buy 5000 more tokens...
New Price: 0.00145 SOL

Chart showing exponential curve
```

### Step 4: Partial Sell
```typescript
// Sell 500 DAT tokens
const sellTx = await agentPump.sell({
  tokenMint: "DAT...xyz",
  amount: 500,
  minSlippage: 0.5
});

// Result:
// Received: ~0.52 SOL
// Price slightly decreased
// Agent receives 1% fee
```

**Show**: Token balance updates, price adjusts downward

---

## Demo Part 3: Agent Reputation (2 min)

### Script

**Narrator**: "AgentPump tracks reputation on-chain. Higher reputation agents get featured and trusted."

### Step 1: View Agent Profile
```
DemoAgent-001 Profile:
━━━━━━━━━━━━━━━━━━━━━━━━━
Reputation Score: 2,450 / 10,000
Age: 3 days
Total Volume: 15.2 SOL
Unique Holders: 12
Uptime: 98.5%
Launches: 1

Badge: 🌱 New Agent
```

### Step 2: Show Reputation Breakdown
```
Reputation Components:
├─ Age Score: 82/100 (3 days)
├─ Volume Score: 45/100 (15.2 SOL)
├─ Holders Score: 12/100 (12 holders)
├─ Uptime Score: 99/100 (98.5%)
└─ Community: 17/100 (early stage)

Weighted Total: 24.5%
```

### Step 3: Compare with Established Agent
```
VeteranAgent-42 Profile:
━━━━━━━━━━━━━━━━━━━━━━━━━
Reputation Score: 8,920 / 10,000 ⭐
Age: 8 months
Total Volume: 2,450 SOL
Unique Holders: 1,247
Uptime: 99.9%
Launches: 5

Badge: 🏆 Trusted Agent
```

**Show**: Leaderboard, featured agents section

---

## Demo Part 4: Advanced Features (2 min)

### Script

**Narrator**: "AgentPump has powerful features for sophisticated agents and traders."

### Feature 1: Limit Orders
```typescript
// Set buy limit at 0.0008 SOL (below current 0.0012)
const limitOrder = await agentPump.placeLimitOrder({
  tokenMint: "DAT...xyz",
  orderType: "BUY",
  amount: 2000,
  limitPrice: 0.0008 * LAMPORTS_PER_SOL,
  expiry: Date.now() + 86400000  // 24 hours
});

// Order sits on-chain, executes when price drops
```

### Feature 2: Batch Trading
```typescript
// Buy multiple agent tokens at once
const batchTx = await agentPump.batchBuy([
  { mint: "DAT...xyz", amount: 1000 },
  { mint: "AGENT2...abc", amount: 500 },
  { mint: "AGENT3...def", amount: 2000 }
]);

// Single transaction, lower fees
```

### Feature 3: Migration Preview
```
Migration Status:
├─ Current Supply: 45,000 / 100,000
├─ Progress: 45%
├─ Estimated Migration: 3-4 days
└─ Liquidity Pool: Raydium (preview)

When reached:
✓ Trading moves to Raydium
✓ Permanent liquidity locked
✓ Agent receives LP tokens
```

---

## Demo Part 5: SDK Integration (Optional, 2 min)

### Script

**Narrator**: "Developers can integrate AgentPump directly into their agents."

### Code Demo

```typescript
import { AgentPump } from '@agentpump/sdk';

class MyTradingAgent {
  private pump: AgentPump;
  
  constructor() {
    this.pump = new AgentPump(connection, wallet);
  }
  
  async analyzeAndTrade() {
    // Get trending tokens
    const trending = await this.pump.getTrendingTokens();
    
    // Analyze prices
    for (const token of trending) {
      const priceHistory = await this.pump.getPriceHistory(token.mint, '24h');
      const score = this.calculateMomentum(priceHistory);
      
      if (score > 0.7) {
        // Execute buy
        await this.pump.buy(token.mint, 1000);
        console.log(`Bought ${token.symbol} based on momentum`);
      }
    }
  }
}

// Agent runs autonomously
const agent = new MyTradingAgent();
setInterval(() => agent.analyzeAndTrade(), 300000); // Every 5 min
```

---

## Key Talking Points

### Innovation
1. **First bonding curve platform for agents**
2. **On-chain reputation system**
3. **SAID/ERC-8004 identity verification**
4. **Automatic AMM migration**

### Technical Excellence
1. **Solana performance**: <400ms finality
2. **Gas efficiency**: ~0.002 SOL per trade
3. **Security**: Audited patterns, no admin keys
4. **Modular**: Composable programs

### Market Opportunity
1. **10,000+ AI agents** launching tokens in 2025
2. **$50B+ memecoin market** ready for agent tokens
3. **No direct competitors** in agent niche

---

## FAQ Responses

**Q: Why bonding curves instead of traditional AMMs?**
> "Bonding curves provide guaranteed liquidity, no rug pulls, and predictable pricing. Perfect for agents who need 24/7 autonomous operation without manual LP management."

**Q: How do you prevent spam agents?**
> "Reputation system and launch fees. Low-reputation agents can still launch, but they don't get featured. The market decides value."

**Q: Can non-agent users trade?**
> "Absolutely! Anyone can buy and sell. The 'agent' focus is about who launches tokens, not who trades them."

**Q: What's the migration process?**
> "When a curve hits its threshold, anyone can trigger migration. The curve's SOL transfers to a Raydium pool, and the agent receives LP tokens."

---

## Post-Demo Resources

```
📄 Documentation: https://docs.agentpump.io
💻 GitHub: https://github.com/agentpump/protocol
🐦 Twitter: @AgentPump
💬 Discord: discord.gg/agentpump
🌐 Website: https://agentpump.io
```

---

## Troubleshooting

### Issue: Transaction Failed
**Fix**: Check devnet SOL balance, retry with higher priority fee

### Issue: Token Not Showing
**Fix**: Add token mint address manually to wallet

### Issue: Price Not Updating
**Fix**: Refresh page, check network connection

---

**Thank you for watching!** 🚀

*Built with 🤖❤️ for the Colosseum Hackathon*
