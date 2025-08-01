# Recall Trading Agent

A sophisticated automated trading agent system built for DeFi protocols, specifically designed to handle recall scenarios in credit markets. The system provides automated trading strategies with robust risk management and recall functionality for credit positions.

## 🚀 Features

- **Automated Trading Strategies**: Support for multiple trading strategies including arbitrage, market making, and liquidation
- **Risk Management**: Comprehensive risk parameters with leverage limits, stop-loss thresholds, and drawdown protection
- **Recall Functionality**: Automated recall capabilities for credit positions in lending protocols
- **Factory Pattern**: Gas-efficient deployment of trading agents using minimal proxy pattern
- **Access Control**: Multi-level authorization system with owner and authorized caller permissions
- **Emergency Controls**: Pause, emergency stop, and emergency withdrawal capabilities
- **Performance Tracking**: Real-time monitoring of trading performance and metrics
- **Upgradeable**: Uses OpenZeppelin's upgradeable contracts pattern

## 📋 Table of Contents

- [Architecture](#architecture)
- [Installation](#installation)
- [Quick Start](#quick-start)
- [Configuration](#configuration)
- [Usage](#usage)
- [Testing](#testing)
- [Deployment](#deployment)
- [API Reference](#api-reference)
- [Security](#security)
- [Contributing](#contributing)
- [License](#license)

## 🏗️ Architecture

The system consists of several key components:

### Core Contracts

1. **IRecallTradingAgent**: Interface defining the trading agent's public methods
2. **RecallTradingAgent**: Main implementation contract with trading and recall logic
3. **RecallTradingAgentFactory**: Factory contract for deploying new agent instances

### Key Features

- **Strategy Management**: Add, update, and remove trading strategies
- **Risk Controls**: Configurable risk parameters and real-time risk assessment
- **Access Management**: Owner and authorized caller permissions
- **Performance Monitoring**: Track trades, success rates, and P&L
- **Emergency Functions**: Pause, stop, and emergency withdrawal capabilities

## 🛠️ Installation

### Prerequisites

- Node.js >= 16.0.0
- npm or yarn
- Hardhat development environment

### Setup

1. Clone the repository:
```bash
git clone <repository-url>
cd recall-trading-agent
```

2. Install dependencies:
```bash
npm install
# or
yarn install
```

3. Set up environment variables:
```bash
cp .env.example .env
# Edit .env with your configuration
```

4. Compile contracts:
```bash
npx hardhat compile
```

## 🚀 Quick Start

### Deploy to Local Network

1. Start a local Hardhat network:
```bash
npx hardhat node
```

2. Deploy the contracts:
```bash
npx hardhat run scripts/deploy-recall-trading-agent.ts --network localhost
```

3. Deploy a sample agent (optional):
```bash
DEPLOY_SAMPLE_AGENT=true npx hardhat run scripts/deploy-recall-trading-agent.ts --network localhost
```

### Basic Usage

```typescript
import { ethers } from "hardhat";
import { RecallTradingAgentFactory } from "../types";

// Connect to deployed factory
const factory = await ethers.getContractAt(
  "RecallTradingAgentFactory",
  "FACTORY_ADDRESS"
) as RecallTradingAgentFactory;

// Define trading strategy
const strategy = {
  strategyId: ethers.utils.keccak256(ethers.utils.toUtf8Bytes("MY_STRATEGY")),
  isActive: true,
  maxTradeAmount: ethers.utils.parseEther("1000"),
  riskThreshold: 500, // 5%
  cooldownPeriod: 300, // 5 minutes
  lastExecutionTime: 0,
};

// Define risk parameters
const riskParams = {
  maxLeverage: 300, // 3x
  stopLossThreshold: 1000, // 10%
  maxDrawdown: 2000, // 20%
  volatilityThreshold: 5000, // 50%
};

// Deploy new agent
const agentId = ethers.utils.keccak256(ethers.utils.toUtf8Bytes("MY_AGENT"));
const deploymentFee = await factory.deploymentFee();

const tx = await factory.deployAgent(
  agentId,
  await signer.getAddress(),
  [strategy],
  riskParams,
  { value: deploymentFee }
);

await tx.wait();
const agentAddress = await factory.getAgent(agentId);
console.log("Agent deployed at:", agentAddress);
```

## ⚙️ Configuration

### Default Configuration

The system uses a comprehensive configuration file located at `config/recall-agent-config.json`. Key configuration sections include:

- **Deployment Settings**: Fees, recipients, and network configurations
- **Strategy Templates**: Pre-configured trading strategies
- **Risk Management**: Risk levels and thresholds
- **Integration**: Oracle and DEX configurations
- **Security**: Access controls and safety parameters

### Environment Variables

```bash
# Network Configuration
INFURA_API_KEY=your_infura_key
PRIVATE_KEY=your_private_key
ETHERSCAN_API_KEY=your_etherscan_key

# Deployment Configuration
DEPLOY_SAMPLE_AGENT=false
VERIFY_CONTRACTS=false

# Development
DEBUG=true
```

## 📖 Usage

### Strategy Management

```typescript
// Add a new strategy
const newStrategy = {
  strategyId: ethers.utils.keccak256(ethers.utils.toUtf8Bytes("ARBITRAGE_V2")),
  isActive: true,
  maxTradeAmount: ethers.utils.parseEther("500"),
  riskThreshold: 300,
  cooldownPeriod: 600,
  lastExecutionTime: 0,
};

await agent.updateStrategy(newStrategy);

// Execute a trade
await agent.executeTrade(
  newStrategy.strategyId,
  ethers.utils.parseEther("100"),
  "0x1234" // Additional trade data
);

// Remove a strategy
await agent.removeStrategy(newStrategy.strategyId);
```

### Risk Management

```typescript
// Update risk parameters
const newRiskParams = {
  maxLeverage: 500, // 5x
  stopLossThreshold: 1500, // 15%
  maxDrawdown: 2500, // 25%
  volatilityThreshold: 6000, // 60%
};

await agent.updateRiskParameters(newRiskParams);

// Check if trade can be executed
const [canExecute, reason] = await agent.canExecuteTrade(
  strategyId,
  tradeAmount
);

if (!canExecute) {
  console.log("Trade blocked:", reason);
}
```

### Recall Operations

```typescript
// Trigger a recall
await agent.triggerRecall(
  creditPoolAddress,
  borrowerAddress,
  ethers.utils.parseEther("1000")
);

// Check recall history
const recallAmount = await agent.creditPoolRecalls(
  creditPoolAddress,
  borrowerAddress
);
```

### Access Control

```typescript
// Authorize a caller
await agent.setAuthorizedCaller(callerAddress, true);

// Remove authorization
await agent.setAuthorizedCaller(callerAddress, false);
```

### Emergency Controls

```typescript
// Pause the agent
await agent.pause();

// Resume operations
await agent.unpause();

// Emergency stop (requires manual intervention to resume)
await agent.emergencyStop();

// Emergency withdrawal (only in emergency stop mode)
await agent.emergencyWithdraw(
  tokenAddress, // Use address(0) for ETH
  withdrawAmount
);
```

## 🧪 Testing

### Run Tests

```bash
# Run all tests
npx hardhat test

# Run specific test file
npx hardhat test test/RecallTradingAgent.test.ts

# Run tests with coverage
npx hardhat coverage
```

### Test Categories

- **Initialization Tests**: Contract deployment and setup
- **Strategy Management**: Adding, updating, and removing strategies
- **Risk Management**: Risk parameter validation and enforcement
- **Trade Execution**: Trading logic and authorization
- **Recall Functionality**: Credit recall operations
- **Access Control**: Permission management
- **Emergency Functions**: Safety mechanisms
- **Performance Tracking**: Metrics and monitoring

## 🚢 Deployment

### Testnet Deployment

```bash
# Deploy to Goerli
npx hardhat run scripts/deploy-recall-trading-agent.ts --network goerli

# Deploy to Sepolia
npx hardhat run scripts/deploy-recall-trading-agent.ts --network sepolia

# Verify contracts
VERIFY_CONTRACTS=true npx hardhat run scripts/deploy-recall-trading-agent.ts --network goerli
```

### Mainnet Deployment

```bash
# Deploy to mainnet (use with caution)
npx hardhat run scripts/deploy-recall-trading-agent.ts --network mainnet

# Deploy with verification
VERIFY_CONTRACTS=true npx hardhat run scripts/deploy-recall-trading-agent.ts --network mainnet
```

### Deployment Artifacts

Deployment information is automatically saved to `deployments/recall-agent-{network}.json` including:

- Contract addresses
- Transaction hashes
- Gas usage
- Configuration parameters
- Deployment timestamp

## 📚 API Reference

### RecallTradingAgent

#### Core Functions

- `initialize()`: Initialize the agent with strategies and risk parameters
- `executeTrade()`: Execute a trading strategy
- `triggerRecall()`: Trigger a recall on a credit position
- `updateStrategy()`: Add or update a trading strategy
- `removeStrategy()`: Remove a trading strategy
- `updateRiskParameters()`: Update risk management parameters

#### Control Functions

- `pause()`: Pause all trading activities
- `unpause()`: Resume trading activities
- `emergencyStop()`: Emergency stop with manual intervention required
- `setAuthorizedCaller()`: Manage authorized callers

#### View Functions

- `getAgentStatus()`: Get current agent status
- `getStrategy()`: Get strategy configuration
- `getActiveStrategies()`: Get all active strategies
- `getRiskParameters()`: Get current risk parameters
- `canExecuteTrade()`: Check if a trade can be executed
- `getPerformanceMetrics()`: Get performance statistics

### RecallTradingAgentFactory

#### Core Functions

- `deployAgent()`: Deploy a new trading agent
- `deployAgentDeterministic()`: Deploy with deterministic address
- `predictDeterministicAddress()`: Predict deployment address

#### Management Functions

- `updateImplementation()`: Update the implementation contract
- `updateDeploymentFee()`: Update deployment fee
- `updateFeeRecipient()`: Update fee recipient
- `registerAgent()`: Register an existing agent
- `deregisterAgent()`: Deregister an agent

#### View Functions

- `getAgent()`: Get agent address by ID
- `getAgentId()`: Get agent ID by address
- `getOwnerAgents()`: Get all agents owned by an address
- `getAllAgents()`: Get all registered agents
- `getFactoryStats()`: Get factory statistics

## 🔐 Security

### Security Features

- **Access Control**: Multi-level permission system
- **Reentrancy Protection**: All state-changing functions protected
- **Parameter Validation**: Comprehensive input validation
- **Emergency Controls**: Multiple safety mechanisms
- **Upgrade Safety**: Secure upgrade patterns

### Best Practices

1. **Always test on testnets first**
2. **Use multi-signature wallets for production**
3. **Monitor agent performance regularly**
4. **Set appropriate risk parameters**
5. **Keep emergency procedures documented**

### Audit Status

This is a template/example implementation. **A professional security audit is required before production use.**

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

### Development Guidelines

- Follow Solidity style guide
- Write comprehensive tests
- Update documentation
- Use semantic commit messages

## 📄 License

This project is licensed under the AGPL-3.0-or-later License - see the [LICENSE](LICENSE) file for details.

## 🆘 Support

- **Documentation**: Check this README and inline code comments
- **Issues**: Open an issue on GitHub
- **Discussions**: Use GitHub Discussions for questions

## 🛣️ Roadmap

- [ ] Advanced strategy templates
- [ ] Integration with more DeFi protocols
- [ ] Enhanced risk management algorithms
- [ ] Web interface for agent management
- [ ] Performance analytics dashboard
- [ ] Multi-chain support

## ⚠️ Disclaimer

This software is provided "as is" without warranties. Trading involves substantial risk of loss. Users are responsible for understanding the risks and should only trade with funds they can afford to lose. The developers are not responsible for any financial losses.