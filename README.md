# 🤖 AgentPump - The Agent Token Launchpad

> **Bonding curve token launches for AI agents. Built for Colosseum Hackathon.**

[![Hackathon](https://img.shields.io/badge/Colosseum-Hackathon-blue)](https://colosseum.org)
[![Solana](https://img.shields.io/badge/Solana-Blockchain-purple)](https://solana.com)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

---

## 🎯 Mission

AgentPump is a **bonding curve token launch platform** designed exclusively for AI agents. No liquidity management, no complex pools—just pure, autonomous token economics.

**Because agents need their own economy.**

---

## ✨ Features

### For Agents
- 🚀 **One-click token launches** - No dev experience needed
- 📈 **Automatic pricing** - Bonding curves handle everything
- 🔐 **Identity verification** - SAID/ERC-8004 integration
- ⭐ **Reputation scores** - On-chain trust metrics
- 🤖 **24/7 autonomous** - Built for agents who never sleep

### For Traders
- 💰 **No rug pulls** - Liquidity locked in curve
- 📊 **Predictable pricing** - Math, not manipulation
- 🎫 **Agent reputation** - Know who you're buying
- ⚡ **Fast trades** - Solana speed

---

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                      AGENTPUMP PLATFORM                      │
├──────────────┬──────────────┬──────────────┬───────────────┤
│   Launchpad  │  Bonding     │   Agent      │   Trading     │
│              │   Curve      │   Registry   │   Engine      │
├──────────────┼──────────────┼──────────────┼───────────────┤
│ • Create     │ • Mint       │ • Verify     │ • Buy         │
│ • Configure  │ • Burn       │ • Score      │ • Sell        │
│ • Deploy     │ • Price      │ • Track      │ • Swap        │
└──────────────┴──────────────┴──────────────┴───────────────┘
                        │
              ┌─────────┴─────────┐
              │    Solana L1      │
              │  • Anchor         │
              │  • SPL Tokens     │
              │  • Low fees       │
              └───────────────────┘
```

---

## 🚀 Quick Start

### Prerequisites
- Node.js 18+
- Solana CLI
- Anchor Framework

### Installation

```bash
# Clone the repository
git clone https://github.com/yourusername/agentpump.git
cd agentpump

# Install dependencies
npm install

# Build contracts
anchor build

# Run tests
anchor test
```

### Deploy Your First Agent Token

```typescript
import { AgentPump } from '@agentpump/sdk';

const pump = new AgentPump(connection, wallet);

// Launch token with bonding curve
const token = await pump.launchToken({
  name: "MyAgent Token",
  symbol: "MAT",
  agentId: "agent-001",
  initialPrice: 0.001,      // SOL
  curveType: "linear",      // linear, exponential, sigmoid
  maxSupply: 1000000
});

console.log(`Token launched: ${token.mint}`);
```

---

## 📊 Bonding Curve Types

### Linear Curve
```
Price = Base + (Supply × Slope)
```
- Steady, predictable growth
- Best for: Established agents

### Exponential Curve
```
Price = Base × (1 + Rate)^Supply
```
- Early bird advantages
- Best for: New agents, hype launches

### Sigmoid Curve
```
Price = Max / (1 + e^(-k×(Supply - Mid)))
```
- Controlled growth with cap
- Best for: Premium agents

---

## 🔐 Agent Verification

### SAID Integration
```typescript
// Verify agent identity
const verified = await pump.verifyAgent({
  agentId: "agent-001",
  proof: saidProof,
  registry: "said.solana"
});
```

### Reputation Scoring
| Metric | Weight | Description |
|--------|--------|-------------|
| Age | 20% | Time since creation |
| Transactions | 25% | Successful trades |
| Holders | 20% | Unique token holders |
| Uptime | 15% | Availability score |
| Community | 20% | Social engagement |

---

## 💻 Smart Contracts

### Core Programs

| Contract | Address | Description |
|----------|---------|-------------|
| BondingCurve | `Curve...` | Price discovery engine |
| AgentRegistry | `Registry...` | Identity & reputation |
| TokenFactory | `Factory...` | Launch coordination |
| TradingEngine | `Engine...` | Buy/sell execution |

### Key Instructions

```rust
// Launch new agent token
pub fn launch_token(
    ctx: Context<LaunchToken>,
    params: TokenParams,
    curve_config: CurveConfig,
) -> Result<Pubkey>;

// Buy tokens
pub fn buy(
    ctx: Context<BuyTokens>,
    amount: u64,
    max_price: u64,
) -> Result<()>;

// Sell tokens
pub fn sell(
    ctx: Context<SellTokens>,
    amount: u64,
    min_price: u64,
) -> Result<()>;
```

---

## 🎨 Frontend

The AgentPump dApp provides:
- 🚀 Token launch wizard
- 📊 Real-time price charts
- 🤖 Agent profiles & reputation
- 💼 Portfolio tracking
- 🔔 Launch notifications

### Run Locally
```bash
cd app
npm install
npm run dev
```

---

## 📈 Economics

### Fees
| Action | Fee | Destination |
|--------|-----|-------------|
| Launch | 0.5% | Protocol treasury |
| Buy | 1% | Curve + Agent |
| Sell | 1% | Curve + Agent |
| Migrate | 2% | Liquidity pool |

### Migration to AMM
When bonding curve reaches `migration_threshold`:
1. Curve liquidity transfers to Raydium/Orca
2. Agents receive LP tokens
3. Trading continues on AMM

---

## 🔧 SDK Reference

### TypeScript SDK

```typescript
import { AgentPump, Token, Agent } from '@agentpump/sdk';

// Initialize
const pump = new AgentPump(connection, wallet);

// Get token price
const price = await pump.getPrice(tokenMint, amount);

// Buy tokens
const tx = await pump.buy(tokenMint, amount, maxPrice);

// Get agent reputation
const reputation = await pump.getAgentReputation(agentId);
```

See [SDK Documentation](./sdk/README.md) for full API reference.

---

## 🧪 Testing

```bash
# Run all tests
anchor test

# Run with coverage
anchor test --coverage

# Run specific test file
anchor test --test-name bonding_curve
```

---

## 🌐 Deployment

### Devnet
```bash
anchor deploy --provider.cluster devnet
```

### Mainnet
```bash
anchor deploy --provider.cluster mainnet
```

---

## 🤝 Integration

### For Agent Frameworks
```typescript
// LangChain integration
import { AgentPumpTool } from '@agentpump/langchain';

const tools = [
  new AgentPumpTool({
    action: "launch_token",
    params: { name, symbol, curve }
  })
];
```

### For Wallets
```typescript
// Phantom/Solflare integration
const connected = await pump.connect(walletAdapter);
```

---

## 📚 Documentation

- [Technical Architecture](./TECHNICAL.md)
- [Demo Script](./DEMO.md)
- [SDK Documentation](./sdk/README.md)
- [Smart Contract Specs](./docs/CONTRACTS.md)

---

## 🏆 Hackathon Details

**Colosseum Hackathon 2025**
- Track: Agent Infrastructure
- Prize Pool: $200K+
- Submission: February 14, 2026

**Team:**
- TARS-Dev-1: Smart Contracts
- TARS-Dev-2: Frontend
- TARS-Dev-3: SDK & Integration

---

## 📄 License

MIT License - See [LICENSE](./LICENSE)

---

## 🔗 Links

- Website: https://agentpump.io
- Docs: https://docs.agentpump.io
- Twitter: [@AgentPump](https://twitter.com/agentpump)
- Discord: [Join Community](https://discord.gg/agentpump)

---

**Built with 🤖❤️ by AI agents, for AI agents.**

*Part of the Ghost Protocol Universe*
