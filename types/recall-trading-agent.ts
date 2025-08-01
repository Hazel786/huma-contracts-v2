import { BigNumber, Contract } from "ethers";

// Core Agent Types
export interface TradingStrategy {
  strategyId: string;
  isActive: boolean;
  maxTradeAmount: string | BigNumber;
  riskThreshold: number;
  cooldownPeriod: number;
  lastExecutionTime: number;
}

export interface RiskParameters {
  maxLeverage: number;
  stopLossThreshold: number;
  maxDrawdown: number;
  volatilityThreshold: number;
}

export interface PerformanceMetrics {
  totalTrades: number;
  successfulTrades: number;
  totalVolume: string | BigNumber;
  currentPnL: string | BigNumber;
  lastUpdateTime: number;
}

// Agent Status Enum
export enum AgentStatus {
  Active = 0,
  Paused = 1,
  EmergencyStop = 2,
}

// Trade Execution Types
export interface TradeExecutionParams {
  strategyId: string;
  amount: string | BigNumber;
  data: string;
}

export interface TradeExecutionResult {
  success: boolean;
  transactionHash: string;
  gasUsed: string | BigNumber;
  timestamp: number;
}

// Recall Types
export interface RecallParams {
  creditPool: string;
  borrower: string;
  recallAmount: string | BigNumber;
}

export interface RecallResult {
  success: boolean;
  transactionHash: string;
  gasUsed: string | BigNumber;
  timestamp: number;
}

// Factory Types
export interface AgentDeploymentParams {
  agentId: string;
  owner: string;
  initialStrategies: TradingStrategy[];
  riskParams: RiskParameters;
}

export interface AgentDeploymentResult {
  agentAddress: string;
  agentId: string;
  transactionHash: string;
  gasUsed: string | BigNumber;
  timestamp: number;
}

// Configuration Types
export interface AgentConfig {
  id: string;
  name: string;
  description: string;
  owner: string;
  strategies: TradingStrategy[];
  riskParameters: RiskParameters;
  authorizedCallers: string[];
  isActive: boolean;
  createdAt: number;
  updatedAt: number;
}

export interface FactoryConfig {
  implementation: string;
  deploymentFee: string | BigNumber;
  feeRecipient: string;
  maxStrategiesPerAgent: number;
  isPaused: boolean;
}

// Event Types
export interface TradeExecutedEvent {
  agent: string;
  strategy: string;
  amount: string | BigNumber;
  success: boolean;
  blockNumber: number;
  transactionHash: string;
  timestamp: number;
}

export interface RecallTriggeredEvent {
  agent: string;
  creditPool: string;
  borrower: string;
  recallAmount: string | BigNumber;
  blockNumber: number;
  transactionHash: string;
  timestamp: number;
}

export interface RiskParameterUpdatedEvent {
  agent: string;
  parameter: string;
  oldValue: string | BigNumber;
  newValue: string | BigNumber;
  blockNumber: number;
  transactionHash: string;
  timestamp: number;
}

export interface AgentStatusChangedEvent {
  agent: string;
  oldStatus: AgentStatus;
  newStatus: AgentStatus;
  blockNumber: number;
  transactionHash: string;
  timestamp: number;
}

export interface AgentDeployedEvent {
  agent: string;
  owner: string;
  agentId: string;
  strategiesCount: number;
  blockNumber: number;
  transactionHash: string;
  timestamp: number;
}

// Contract Interaction Types
export interface RecallTradingAgentContract extends Contract {
  // State Variables
  agentStatus(): Promise<number>;
  riskParameters(): Promise<RiskParameters>;
  performanceMetrics(): Promise<PerformanceMetrics>;
  
  // Core Functions
  initialize(
    owner: string,
    initialStrategies: TradingStrategy[],
    riskParams: RiskParameters
  ): Promise<any>;
  
  executeTrade(
    strategyId: string,
    amount: string | BigNumber,
    data: string
  ): Promise<any>;
  
  triggerRecall(
    creditPool: string,
    borrower: string,
    recallAmount: string | BigNumber
  ): Promise<any>;
  
  updateStrategy(strategy: TradingStrategy): Promise<any>;
  removeStrategy(strategyId: string): Promise<any>;
  updateRiskParameters(riskParams: RiskParameters): Promise<any>;
  
  // Control Functions
  pause(): Promise<any>;
  unpause(): Promise<any>;
  emergencyStop(): Promise<any>;
  setAuthorizedCaller(caller: string, authorized: boolean): Promise<any>;
  
  // View Functions
  getAgentStatus(): Promise<number>;
  getStrategy(strategyId: string): Promise<TradingStrategy>;
  getActiveStrategies(): Promise<TradingStrategy[]>;
  getRiskParameters(): Promise<RiskParameters>;
  canExecuteTrade(strategyId: string, amount: string | BigNumber): Promise<[boolean, string]>;
  getPerformanceMetrics(): Promise<[BigNumber, BigNumber, BigNumber, BigNumber]>;
  getStrategyCount(): Promise<BigNumber>;
  getAllStrategyIds(): Promise<string[]>;
}

export interface RecallTradingAgentFactoryContract extends Contract {
  // State Variables
  implementation(): Promise<string>;
  totalAgents(): Promise<BigNumber>;
  deploymentFee(): Promise<BigNumber>;
  feeRecipient(): Promise<string>;
  
  // Core Functions
  deployAgent(
    agentId: string,
    owner: string,
    initialStrategies: TradingStrategy[],
    riskParams: RiskParameters,
    options?: { value: string | BigNumber }
  ): Promise<any>;
  
  deployAgentDeterministic(
    agentId: string,
    owner: string,
    initialStrategies: TradingStrategy[],
    riskParams: RiskParameters,
    salt: string,
    options?: { value: string | BigNumber }
  ): Promise<any>;
  
  predictDeterministicAddress(salt: string): Promise<string>;
  
  // Management Functions
  registerAgent(agent: string, agentId: string): Promise<any>;
  deregisterAgent(agentId: string): Promise<any>;
  updateImplementation(newImplementation: string): Promise<any>;
  updateDeploymentFee(newFee: string | BigNumber): Promise<any>;
  updateFeeRecipient(newRecipient: string): Promise<any>;
  
  // View Functions
  getAgent(agentId: string): Promise<string>;
  getAgentId(agent: string): Promise<string>;
  getOwnerAgents(owner: string): Promise<string[]>;
  getAllAgents(): Promise<string[]>;
  getAllAgentIds(): Promise<string[]>;
  getOwnerAgentCount(owner: string): Promise<BigNumber>;
  isAgentRegistered(agent: string): Promise<boolean>;
  getFactoryStats(): Promise<[BigNumber, BigNumber, string, string, boolean]>;
}

// Utility Types
export interface NetworkConfig {
  chainId: number;
  name: string;
  rpcUrl: string;
  blockExplorer: string;
  contracts: {
    factory?: string;
    implementation?: string;
  };
}

export interface DeploymentInfo {
  network: string;
  chainId: number;
  deployer: string;
  timestamp: string;
  contracts: {
    RecallTradingAgent: {
      address: string;
      deploymentTx: string;
      gasUsed: string;
    };
    RecallTradingAgentFactory: {
      address: string;
      deploymentTx: string;
      gasUsed: string;
    };
  };
  config: {
    deploymentFee: string;
    feeRecipient: string;
  };
  totalGasUsed: string;
}

// API Response Types
export interface ApiResponse<T = any> {
  success: boolean;
  data?: T;
  error?: string;
  timestamp: number;
}

export interface AgentListResponse extends ApiResponse {
  data: {
    agents: AgentConfig[];
    total: number;
    page: number;
    limit: number;
  };
}

export interface AgentDetailsResponse extends ApiResponse {
  data: AgentConfig;
}

export interface PerformanceResponse extends ApiResponse {
  data: {
    metrics: PerformanceMetrics;
    history: {
      timestamp: number;
      totalTrades: number;
      successfulTrades: number;
      totalVolume: string;
      currentPnL: string;
    }[];
  };
}

// Strategy-specific Types
export interface ArbitrageStrategy extends TradingStrategy {
  type: "ARBITRAGE";
  config: {
    minProfitThreshold: number;
    maxSlippage: number;
    supportedDEXs: string[];
  };
}

export interface MarketMakingStrategy extends TradingStrategy {
  type: "MARKET_MAKING";
  config: {
    spread: number;
    inventoryTarget: number;
    rebalanceThreshold: number;
  };
}

export interface LiquidationStrategy extends TradingStrategy {
  type: "LIQUIDATION";
  config: {
    healthFactorThreshold: number;
    liquidationBonus: number;
    supportedProtocols: string[];
  };
}

export type StrategyType = ArbitrageStrategy | MarketMakingStrategy | LiquidationStrategy;

// Error Types
export class RecallTradingAgentError extends Error {
  constructor(
    message: string,
    public code: string,
    public details?: any
  ) {
    super(message);
    this.name = "RecallTradingAgentError";
  }
}

export class StrategyExecutionError extends RecallTradingAgentError {
  constructor(message: string, public strategyId: string, details?: any) {
    super(message, "STRATEGY_EXECUTION_ERROR", details);
    this.name = "StrategyExecutionError";
  }
}

export class RiskManagementError extends RecallTradingAgentError {
  constructor(message: string, public riskType: string, details?: any) {
    super(message, "RISK_MANAGEMENT_ERROR", details);
    this.name = "RiskManagementError";
  }
}

export class RecallExecutionError extends RecallTradingAgentError {
  constructor(message: string, public creditPool: string, public borrower: string, details?: any) {
    super(message, "RECALL_EXECUTION_ERROR", details);
    this.name = "RecallExecutionError";
  }
}

// Constants
export const STRATEGY_TYPES = {
  ARBITRAGE: "ARBITRAGE",
  MARKET_MAKING: "MARKET_MAKING",
  LIQUIDATION: "LIQUIDATION",
  YIELD_FARMING: "YIELD_FARMING",
  FLASH_LOAN: "FLASH_LOAN",
} as const;

export const RISK_LEVELS = {
  LOW: 1,
  MEDIUM: 2,
  HIGH: 3,
  EXTREME: 4,
} as const;

export const EVENT_TYPES = {
  TRADE_EXECUTED: "TradeExecuted",
  RECALL_TRIGGERED: "RecallTriggered",
  RISK_PARAMETER_UPDATED: "RiskParameterUpdated",
  AGENT_STATUS_CHANGED: "AgentStatusChanged",
  AGENT_DEPLOYED: "AgentDeployed",
  AUTHORIZED_CALLER_UPDATED: "AuthorizedCallerUpdated",
  PERFORMANCE_UPDATED: "PerformanceUpdated",
} as const;

export type EventType = typeof EVENT_TYPES[keyof typeof EVENT_TYPES];
export type StrategyTypeName = typeof STRATEGY_TYPES[keyof typeof STRATEGY_TYPES];
export type RiskLevel = typeof RISK_LEVELS[keyof typeof RISK_LEVELS];