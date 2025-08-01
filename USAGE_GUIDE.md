# SOL Drop Buy Agent - Usage Guide

This guide shows you exactly how to run the Recall Trading Agent that automatically buys $SOL when it drops 5% in 1 hour.

## 🚀 Quick Start (5 Minutes)

### Prerequisites
- Node.js 16+ installed
- Git installed
- Basic terminal/command line knowledge

### Step 1: Setup Project
```bash
# Clone and setup
git clone <your-repo>
cd recall-trading-agent
npm install

# Compile contracts
npx hardhat compile
```

### Step 2: Start Local Blockchain
```bash
# Terminal 1 - Start Hardhat network
npx hardhat node
```

### Step 3: Deploy SOL Strategy
```bash
# Terminal 2 - Deploy the SOL strategy
npx hardhat run scripts/deploy-sol-strategy.ts --network localhost
```

You should see output like:
```
🚀 Deploying SOL Drop Buy Strategy...
📝 Deploying with account: 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
💰 Account balance: 10000.0 ETH

🔨 Deploying Mock Price Oracle...
✅ Price Oracle deployed at: 0x5FbDB2315678afecb367f032d93F642f64180aa3

🔨 Deploying SOL Drop Buy Strategy...
✅ SOL Strategy deployed at: 0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512

🔨 Deploying Trading Agent...
✅ Trading Agent deployed at: 0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0

📊 Deployment Summary:
==========================================
🏭 Factory Address: 0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9
🤖 Trading Agent: 0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0
📈 SOL Strategy: 0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512
🔮 Price Oracle: 0x5FbDB2315678afecb367f032d93F642f64180aa3
==========================================

🎉 SOL Drop Buy Strategy deployed successfully!
```

### Step 4: Simulate Price Drop (Testing)
```bash
# Simulate a 6% SOL price drop over 1 hour
npx hardhat run scripts/run-sol-agent.ts --network localhost -- --simulate-drop
```

### Step 5: Run the Agent
```bash
# Run with auto-execution enabled
AUTO_EXECUTE=true npx hardhat run scripts/run-sol-agent.ts --network localhost
```

The agent will start monitoring and show:
```
🚀 Starting SOL Drop Buy Agent...
⚙️  Configuration:
   - Check Interval: 30s
   - Auto Execution: ON
   - Max Run Time: Unlimited
   - Log Level: detailed

📊 AGENT STATUS
==========================================
🤖 Agent Status: Active
📈 Strategy: Active
📉 Drop Threshold: 5%
⏱️  Time Window: 60 minutes
💰 Max Buy: $10,000.0
⏳ Cooldown: 30 minutes
💲 Current SOL Price: $94.00000000
✅ Can Execute Buy: YES
📉 Current Drop: 6%
==========================================

🎯 EXECUTING BUY - SOL dropped 6%!
✅ BUY EXECUTED SUCCESSFULLY!
   SOL Bought: 106.382978723 SOL
   USDC Spent: $10000.0
   Gas Used: 125043
   Tx Hash: 0x1234...
```

## 📋 Detailed Usage

### Environment Variables

Configure the agent behavior with environment variables:

```bash
# Enable/disable automatic execution
AUTO_EXECUTE=true              # true = auto-buy, false = monitor only

# Set maximum runtime (in seconds, 0 = unlimited)
MAX_RUN_TIME=3600             # Run for 1 hour then stop

# Set logging level
LOG_LEVEL=detailed            # 'detailed' or 'minimal'

# Example: Run for 10 minutes with minimal logging
MAX_RUN_TIME=600 LOG_LEVEL=minimal AUTO_EXECUTE=true npx hardhat run scripts/run-sol-agent.ts --network localhost
```

### Configuration Options

The agent uses these default settings (configurable in deployment):

- **Drop Threshold**: 5% (SOL must drop 5% to trigger buy)
- **Time Window**: 1 hour (price drop measured over 1 hour)
- **Max Buy Amount**: $10,000 USDC per trade
- **Min Buy Amount**: 1 SOL minimum purchase
- **Cooldown Period**: 30 minutes between purchases
- **Check Interval**: 30 seconds between price checks

### Manual Price Control (Testing)

You can manually control SOL prices for testing:

```javascript
// In Hardhat console
npx hardhat console --network localhost

// Load the price oracle
const oracle = await ethers.getContractAt("MockSOLPriceOracle", "ORACLE_ADDRESS");

// Set SOL price to $100
await oracle.updatePrice(ethers.utils.parseUnits("100", 8));

// Simulate 7% drop
await oracle.simulatePriceDrop(700); // 700 = 7%

// Create realistic price history (gradual drop over 1 hour)
await oracle.createPriceHistory(
  ethers.utils.parseUnits("100", 8), // Start: $100
  ethers.utils.parseUnits("93", 8)   // End: $93 (7% drop)
);
```

## 🔧 Advanced Usage

### Custom Strategy Configuration

Deploy with custom parameters:

```typescript
// Modify scripts/deploy-sol-strategy.ts
const solStrategyConfig = {
  strategyId: ethers.utils.keccak256(ethers.utils.toUtf8Bytes("SOL_DROP_BUY_V1")),
  isActive: true,
  maxTradeAmount: ethers.utils.parseEther("5000"),  // $5,000 max
  riskThreshold: 300,                               // 3% drop threshold
  cooldownPeriod: 900,                              // 15 minutes cooldown
  lastExecutionTime: 0,
};
```

### Monitor Multiple Strategies

You can deploy multiple agents with different parameters:

```bash
# Deploy conservative agent (3% drop, smaller amounts)
STRATEGY_TYPE=conservative npx hardhat run scripts/deploy-sol-strategy.ts --network localhost

# Deploy aggressive agent (7% drop, larger amounts)  
STRATEGY_TYPE=aggressive npx hardhat run scripts/deploy-sol-strategy.ts --network localhost
```

### Production Deployment

For mainnet deployment:

1. **Set up environment variables:**
```bash
# .env file
INFURA_API_KEY=your_infura_key
PRIVATE_KEY=your_private_key
ETHERSCAN_API_KEY=your_etherscan_key
```

2. **Deploy to mainnet:**
```bash
npx hardhat run scripts/deploy-sol-strategy.ts --network mainnet
```

3. **Use real price oracle:**
```solidity
// Replace MockSOLPriceOracle with Chainlink SOL/USD feed
address constant SOL_USD_FEED = 0x4ffC43a60e009B551865A93d232E33Fce9f01507;
```

## 📊 Monitoring & Analytics

### Real-time Monitoring

The agent provides detailed logging:

```
🔍 Check #42 - 2:30:15 PM
📊 Current SOL Price: $98.45000000
📉 Drop Detected: 1.55%
✅ Can Execute: NO (No significant drop detected)
```

### Performance Statistics

At the end of each run:

```
📊 FINAL STATISTICS
==========================================
⏱️  Total Runtime: 45m 30s
🔍 Total Checks: 91
💰 Trades Executed: 3
🪙 Total SOL Bought: 425.123456789 SOL
💵 Total USDC Spent: $39,500.0
📅 Last Trade: 12/15/2023, 2:45:30 PM
📊 Average Buy Price: $92.95 per SOL
==========================================
```

### Export Data

Trading data is automatically saved to deployment files for analysis.

## 🛠️ Troubleshooting

### Common Issues

**"Failed to load contracts" error:**
```bash
# Make sure you deployed first
npx hardhat run scripts/deploy-sol-strategy.ts --network localhost
```

**"Price too stale" error:**
```bash
# Update the price oracle
npx hardhat console --network localhost
# Then: await oracle.updatePrice(ethers.utils.parseUnits("100", 8))
```

**"Insufficient USDC balance" error:**
```bash
# The strategy needs USDC to buy SOL
# In production, fund the strategy contract with USDC
# For testing, this is handled automatically
```

**Agent not detecting drops:**
```bash
# Check if price history exists
npx hardhat run scripts/run-sol-agent.ts --network localhost -- --simulate-drop
```

### Debug Mode

Run with detailed logging:

```bash
DEBUG=true LOG_LEVEL=detailed npx hardhat run scripts/run-sol-agent.ts --network localhost
```

### Reset Everything

To start fresh:

```bash
# Kill hardhat node (Ctrl+C)
# Restart hardhat node
npx hardhat node

# Redeploy
npx hardhat run scripts/deploy-sol-strategy.ts --network localhost
```

## 🚨 Safety Features

### Built-in Protections

- **Cooldown Periods**: Prevents rapid-fire trading
- **Maximum Trade Limits**: Caps maximum purchase amount
- **Price Staleness Checks**: Rejects old price data
- **Emergency Stop**: Owner can halt all trading
- **Access Control**: Only authorized addresses can trigger trades

### Emergency Controls

```javascript
// Emergency stop (stops all trading)
await agent.emergencyStop();

// Pause (can be resumed)
await agent.pause();

// Resume after pause
await agent.unpause();

// Emergency withdrawal (only in emergency stop mode)
await agent.emergencyWithdraw(tokenAddress, amount);
```

## 📈 Strategy Optimization

### Backtesting

Test different parameters:

```bash
# Test 3% threshold
DROP_THRESHOLD=300 npx hardhat run scripts/deploy-sol-strategy.ts --network localhost

# Test 2-hour time window  
TIME_WINDOW=7200 npx hardhat run scripts/deploy-sol-strategy.ts --network localhost
```

### Performance Tuning

- **Lower thresholds** = More frequent trades, higher gas costs
- **Higher thresholds** = Fewer trades, potentially missing opportunities
- **Shorter time windows** = More sensitive to short-term drops
- **Longer time windows** = Less sensitive, fewer false signals

## 🔗 Integration

### Webhook Notifications

Modify `sendNotification()` in `run-sol-agent.ts`:

```typescript
private async sendNotification(message: string): Promise<void> {
  // Discord webhook
  await fetch('YOUR_DISCORD_WEBHOOK', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ content: message })
  });
}
```

### External Price Feeds

Replace mock oracle with Chainlink:

```solidity
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract ChainlinkSOLOracle {
    AggregatorV3Interface internal priceFeed;
    
    constructor() {
        priceFeed = AggregatorV3Interface(0x4ffC43a60e009B551865A93d232E33Fce9f01507);
    }
    
    function getSOLPrice() external view returns (uint256 price, uint256 timestamp) {
        (,int256 price,,,uint256 updatedAt) = priceFeed.latestRoundData();
        return (uint256(price), updatedAt);
    }
}
```

## 🎯 Next Steps

1. **Test thoroughly** on localhost before mainnet
2. **Start with small amounts** for initial mainnet testing  
3. **Monitor performance** and adjust parameters
4. **Set up notifications** for trade alerts
5. **Consider multiple strategies** for diversification

---

**⚠️ Important**: This is for educational purposes. Trading involves risk. Only trade with funds you can afford to lose. Test extensively before using real money.