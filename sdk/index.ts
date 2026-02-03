import { 
  Connection, 
  PublicKey, 
  Transaction, 
  Keypair,
  SystemProgram,
  LAMPORTS_PER_SOL
} from '@solana/web3.js';
import {
  TOKEN_PROGRAM_ID,
  ASSOCIATED_TOKEN_PROGRAM_ID,
  getAssociatedTokenAddress,
  createAssociatedTokenAccountInstruction,
  createMintToInstruction
} from '@solana/spl-token';
import { AnchorProvider, Program, Wallet, BN } from '@coral-xyz/anchor';
import { AgentPump } from './idl/agent_pump';

export type CurveType = 'linear' | 'exponential' | 'sigmoid';

export interface CurveConfig {
  curveType: CurveType;
  basePrice: number;           // In SOL
  slope: number;
  maxSupply: number;
  migrationThreshold: number;
}

export interface LaunchParams {
  name: string;
  symbol: string;
  agentId: string;
  curveConfig: CurveConfig;
  metadata?: {
    description?: string;
    image?: string;
    twitter?: string;
    discord?: string;
  };
}

export interface TokenInfo {
  mint: PublicKey;
  agentId: string;
  name: string;
  symbol: string;
  curve: PublicKey;
  supply: number;
  price: number;
  isMigrated: boolean;
}

export interface AgentInfo {
  id: string;
  owner: PublicKey;
  name: string;
  reputation: number;
  totalLaunches: number;
  totalVolume: number;
  isVerified: boolean;
}

/**
 * AgentPump SDK - Bonding curve token launches for AI agents
 */
export class AgentPumpSDK {
  private program: Program<AgentPump>;
  private provider: AnchorProvider;
  
  constructor(
    connection: Connection,
    wallet: Wallet,
    programId?: PublicKey
  ) {
    this.provider = new AnchorProvider(connection, wallet, {
      commitment: 'confirmed'
    });
    
    const defaultProgramId = new PublicKey(
      'Pump111111111111111111111111111111111111111'
    );
    
    this.program = new Program(
      require('./idl/agent_pump.json'),
      programId || defaultProgramId,
      this.provider
    );
  }
  
  /**
   * Launch a new agent token
   */
  async launchToken(params: LaunchParams): Promise<{
    mint: PublicKey;
    curve: PublicKey;
    signature: string;
  }> {
    const mintKeypair = Keypair.generate();
    
    // Convert curve type
    const curveTypeMap = {
      linear: { linear: {} },
      exponential: { exponential: {} },
      sigmoid: { sigmoid: {} }
    };
    
    const tx = await this.program.methods
      .launchToken(
        params.name,
        params.symbol,
        params.agentId,
        {
          curveType: curveTypeMap[params.curveConfig.curveType],
          basePrice: new BN(params.curveConfig.basePrice * LAMPORTS_PER_SOL),
          slope: new BN(params.curveConfig.slope * 1000),
          maxSupply: new BN(params.curveConfig.maxSupply),
          migrationThreshold: new BN(params.curveConfig.migrationThreshold)
        }
      )
      .accounts({
        payer: this.provider.wallet.publicKey,
        mint: mintKeypair.publicKey,
        // ... other accounts
      })
      .signers([mintKeypair])
      .rpc();
    
    return {
      mint: mintKeypair.publicKey,
      curve: await this.getCurveAddress(mintKeypair.publicKey),
      signature: tx
    };
  }
  
  /**
   * Buy tokens from bonding curve
   */
  async buy(
    mint: PublicKey,
    amount: number,
    maxPrice?: number
  ): Promise<string> {
    const curve = await this.getCurveAddress(mint);
    const buyerTokenAccount = await getAssociatedTokenAddress(
      mint,
      this.provider.wallet.publicKey
    );
    
    // Get current price if maxPrice not specified
    const currentPrice = await this.getPrice(mint, amount);
    const maxSlippage = maxPrice || currentPrice * 1.05; // 5% default slippage
    
    const tx = await this.program.methods
      .buy(new BN(amount), new BN(maxSlippage))
      .accounts({
        buyer: this.provider.wallet.publicKey,
        curve,
        mint,
        buyerTokenAccount,
        tokenProgram: TOKEN_PROGRAM_ID,
        systemProgram: SystemProgram.programId
      })
      .rpc();
    
    return tx;
  }
  
  /**
   * Sell tokens to bonding curve
   */
  async sell(
    mint: PublicKey,
    amount: number,
    minPrice?: number
  ): Promise<string> {
    const curve = await this.getCurveAddress(mint);
    const sellerTokenAccount = await getAssociatedTokenAddress(
      mint,
      this.provider.wallet.publicKey
    );
    
    // Get current price if minPrice not specified
    const currentPrice = await this.getSellPrice(mint, amount);
    const minSlippage = minPrice || currentPrice * 0.95; // 5% default slippage
    
    const tx = await this.program.methods
      .sell(new BN(amount), new BN(minSlippage))
      .accounts({
        seller: this.provider.wallet.publicKey,
        curve,
        mint,
        sellerTokenAccount,
        tokenProgram: TOKEN_PROGRAM_ID
      })
      .rpc();
    
    return tx;
  }
  
  /**
   * Get current buy price for tokens
   */
  async getPrice(mint: PublicKey, amount: number): Promise<number> {
    const curve = await this.getCurveAddress(mint);
    const curveAccount = await this.program.account.curve.fetch(curve);
    
    // Calculate price based on curve type
    const supply = curveAccount.currentSupply.toNumber();
    const basePrice = curveAccount.basePrice.toNumber() / LAMPORTS_PER_SOL;
    const slope = curveAccount.slope.toNumber() / 1000;
    
    switch (Object.keys(curveAccount.curveType)[0]) {
      case 'linear':
        return this.calculateLinearPrice(supply, amount, basePrice, slope);
      case 'exponential':
        return this.calculateExponentialPrice(supply, amount, basePrice, slope);
      case 'sigmoid':
        return this.calculateSigmoidPrice(supply, amount, basePrice, slope, curveAccount);
      default:
        return 0;
    }
  }
  
  /**
   * Get sell price for tokens
   */
  async getSellPrice(mint: PublicKey, amount: number): Promise<number> {
    const curve = await this.getCurveAddress(mint);
    const curveAccount = await this.program.account.curve.fetch(curve);
    
    const supply = curveAccount.currentSupply.toNumber();
    const basePrice = curveAccount.basePrice.toNumber() / LAMPORTS_PER_SOL;
    const slope = curveAccount.slope.toNumber() / 1000;
    
    // Sell price uses supply - amount as starting point
    switch (Object.keys(curveAccount.curveType)[0]) {
      case 'linear':
        return this.calculateLinearPrice(supply - amount, amount, basePrice, slope);
      default:
        return this.getPrice(mint, amount) * 0.99; // 1% sell fee
    }
  }
  
  /**
   * Get token info
   */
  async getTokenInfo(mint: PublicKey): Promise<TokenInfo> {
    const curve = await this.getCurveAddress(mint);
    const curveAccount = await this.program.account.curve.fetch(curve);
    
    return {
      mint,
      agentId: curveAccount.agentId,
      name: curveAccount.name,
      symbol: curveAccount.symbol,
      curve,
      supply: curveAccount.currentSupply.toNumber(),
      price: await this.getPrice(mint, 1),
      isMigrated: curveAccount.isMigrated
    };
  }
  
  /**
   * Register a new agent
   */
  async registerAgent(
    agentId: string,
    name: string,
    metadata?: string
  ): Promise<string> {
    const tx = await this.program.methods
      .registerAgent(agentId, name, metadata || '')
      .accounts({
        owner: this.provider.wallet.publicKey,
        // ... other accounts
      })
      .rpc();
    
    return tx;
  }
  
  /**
   * Get agent info
   */
  async getAgent(agentId: string): Promise<AgentInfo> {
    const agent = await this.program.account.agent.fetch(
      await this.getAgentAddress(agentId)
    );
    
    return {
      id: agent.id,
      owner: agent.owner,
      name: agent.name,
      reputation: agent.reputationScore.toNumber(),
      totalLaunches: agent.totalLaunches,
      totalVolume: agent.totalVolume.toNumber(),
      isVerified: agent.isVerified
    };
  }
  
  /**
   * Get trending tokens
   */
  async getTrendingTokens(limit: number = 10): Promise<TokenInfo[]> {
    // Fetch all tokens and sort by activity
    const tokens = await this.program.account.curve.all();
    
    const tokenInfos = await Promise.all(
      tokens.map(t => this.getTokenInfo(t.publicKey))
    );
    
    // Sort by some metric (e.g., recent volume)
    return tokenInfos
      .sort((a, b) => b.supply - a.supply)
      .slice(0, limit);
  }
  
  /**
   * Get featured agents (high reputation)
   */
  async getFeaturedAgents(limit: number = 10): Promise<AgentInfo[]> {
    const agents = await this.program.account.agent.all();
    
    return agents
      .filter(a => a.account.reputationScore.toNumber() >= 2500)
      .sort((a, b) => 
        b.account.reputationScore.toNumber() - a.account.reputationScore.toNumber()
      )
      .slice(0, limit)
      .map(a => ({
        id: a.account.id,
        owner: a.account.owner,
        name: a.account.name,
        reputation: a.account.reputationScore.toNumber(),
        totalLaunches: a.account.totalLaunches,
        totalVolume: a.account.totalVolume.toNumber(),
        isVerified: a.account.isVerified
      }));
  }
  
  // ============ Helper Methods ============
  
  private async getCurveAddress(mint: PublicKey): Promise<PublicKey> {
    const [curve] = PublicKey.findProgramAddressSync(
      [Buffer.from('curve'), mint.toBuffer()],
      this.program.programId
    );
    return curve;
  }
  
  private async getAgentAddress(agentId: string): Promise<PublicKey> {
    const [agent] = PublicKey.findProgramAddressSync(
      [Buffer.from('agent'), Buffer.from(agentId)],
      this.program.programId
    );
    return agent;
  }
  
  private calculateLinearPrice(
    supply: number,
    amount: number,
    basePrice: number,
    slope: number
  ): number {
    const startPrice = basePrice + (slope * supply);
    const endPrice = basePrice + (slope * (supply + amount));
    return ((startPrice + endPrice) * amount) / 2;
  }
  
  private calculateExponentialPrice(
    supply: number,
    amount: number,
    basePrice: number,
    slope: number
  ): number {
    const avgMultiplier = 1 + (slope * (supply + amount / 2)) / 1000;
    return basePrice * avgMultiplier * amount;
  }
  
  private calculateSigmoidPrice(
    supply: number,
    amount: number,
    basePrice: number,
    slope: number,
    curve: any
  ): number {
    // Simplified sigmoid calculation
    const midpoint = curve.migrationThreshold.toNumber() / 2;
    const currentFactor = this.sigmoidFactor(supply, midpoint, slope);
    const futureFactor = this.sigmoidFactor(supply + amount, midpoint, slope);
    return basePrice * 10 * (futureFactor - currentFactor);
  }
  
  private sigmoidFactor(x: number, midpoint: number, growth: number): number {
    if (x >= midpoint) {
      return 500 + (500 * (x - midpoint)) / (midpoint + (x - midpoint) / growth);
    } else {
      return 500 * x / (midpoint + (midpoint - x) / growth);
    }
  }
}

export default AgentPumpSDK;
