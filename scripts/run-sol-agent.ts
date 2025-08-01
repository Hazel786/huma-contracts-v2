import { ethers } from "hardhat";
import { Contract } from "ethers";

interface AgentContracts {
  agent: Contract;
  solStrategy: Contract;
  priceOracle: Contract;
  mockUSDC?: Contract;
}

interface MonitoringConfig {
  checkInterval: number; // milliseconds
  enableAutoExecution: boolean;
  maxRunTime: number; // milliseconds, 0 = run forever
  logLevel: 'minimal' | 'detailed';
}

class SOLAgentRunner {
  private contracts: AgentContracts;
  private config: MonitoringConfig;
  private isRunning: boolean = false;
  private startTime: number = 0;
  private stats = {
    checksPerformed: 0,
    tradesExecuted: 0,
    totalSOLBought: ethers.BigNumber.from(0),
    totalUSDCSpent: ethers.BigNumber.from(0),
    lastTradeTime: 0,
  };

  constructor(contracts: AgentContracts, config: MonitoringConfig) {
    this.contracts = contracts;
    this.config = config;
  }

  /**
   * Start monitoring and running the SOL agent
   */
  async start(): Promise<void> {
    console.log("🚀 Starting SOL Drop Buy Agent...");
    console.log("⚙️  Configuration:");
    console.log(`   - Check Interval: ${this.config.checkInterval / 1000}s`);
    console.log(`   - Auto Execution: ${this.config.enableAutoExecution ? 'ON' : 'OFF'}`);
    console.log(`   - Max Run Time: ${this.config.maxRunTime ? `${this.config.maxRunTime / 1000}s` : 'Unlimited'}`);
    console.log(`   - Log Level: ${this.config.logLevel}`);
    
    this.isRunning = true;
    this.startTime = Date.now();

    // Display initial status
    await this.displayStatus();

    // Start monitoring loop
    while (this.isRunning) {
      try {
        await this.performCheck();
        
        // Check if we should stop based on max run time
        if (this.config.maxRunTime > 0) {
          const elapsed = Date.now() - this.startTime;
          if (elapsed >= this.config.maxRunTime) {
            console.log("⏰ Max run time reached, stopping agent...");
            break;
          }
        }
        
        // Wait for next check
        await this.sleep(this.config.checkInterval);
        
      } catch (error) {
        console.error("❌ Error during check:", error);
        await this.sleep(this.config.checkInterval);
      }
    }

    console.log("🛑 SOL Agent stopped");
    this.displayFinalStats();
  }

  /**
   * Stop the agent
   */
  stop(): void {
    console.log("🛑 Stopping SOL Agent...");
    this.isRunning = false;
  }

  /**
   * Perform a single check cycle
   */
  private async performCheck(): Promise<void> {
    this.stats.checksPerformed++;
    
    if (this.config.logLevel === 'detailed') {
      console.log(`\n🔍 Check #${this.stats.checksPerformed} - ${new Date().toLocaleTimeString()}`);
    }

    // Get current price and check conditions
    const [currentPrice, timestamp] = await this.contracts.priceOracle.getCurrentPrice();
    const [canBuy, reason, dropPercentage] = await this.contracts.solStrategy.canExecuteBuy();

    if (this.config.logLevel === 'detailed') {
      console.log(`📊 Current SOL Price: $${ethers.utils.formatUnits(currentPrice, 8)}`);
      console.log(`📉 Drop Detected: ${dropPercentage / 100}%`);
      console.log(`✅ Can Execute: ${canBuy ? 'YES' : 'NO'} ${!canBuy ? `(${reason})` : ''}`);
    }

    // Execute buy if conditions are met and auto-execution is enabled
    if (canBuy && this.config.enableAutoExecution) {
      console.log(`\n🎯 EXECUTING BUY - SOL dropped ${dropPercentage / 100}%!`);
      await this.executeBuy();
    } else if (canBuy && !this.config.enableAutoExecution) {
      console.log(`\n⚠️  BUY CONDITION MET but auto-execution is disabled`);
      console.log(`   Drop: ${dropPercentage / 100}% - Manual execution required`);
    }

    // Log minimal status every 10 checks
    if (this.config.logLevel === 'minimal' && this.stats.checksPerformed % 10 === 0) {
      console.log(`📊 Check ${this.stats.checksPerformed}: SOL $${ethers.utils.formatUnits(currentPrice, 8)}, Drop: ${dropPercentage / 100}%, Trades: ${this.stats.tradesExecuted}`);
    }
  }

  /**
   * Execute a SOL buy
   */
  private async executeBuy(): Promise<void> {
    try {
      const tx = await this.contracts.solStrategy.checkAndExecuteBuy();
      const receipt = await tx.wait();
      
      // Parse events to get trade details
      const purchaseEvent = receipt.events?.find((e: any) => e.event === 'SOLPurchased');
      
      if (purchaseEvent) {
        const { solAmount, usdcSpent } = purchaseEvent.args;
        
        this.stats.tradesExecuted++;
        this.stats.totalSOLBought = this.stats.totalSOLBought.add(solAmount);
        this.stats.totalUSDCSpent = this.stats.totalUSDCSpent.add(usdcSpent);
        this.stats.lastTradeTime = Date.now();
        
        console.log("✅ BUY EXECUTED SUCCESSFULLY!");
        console.log(`   SOL Bought: ${ethers.utils.formatUnits(solAmount, 9)} SOL`);
        console.log(`   USDC Spent: $${ethers.utils.formatUnits(usdcSpent, 6)}`);
        console.log(`   Gas Used: ${receipt.gasUsed.toString()}`);
        console.log(`   Tx Hash: ${receipt.transactionHash}`);
        
        // Send notification if configured
        await this.sendNotification(`SOL Buy Executed: ${ethers.utils.formatUnits(solAmount, 9)} SOL for $${ethers.utils.formatUnits(usdcSpent, 6)}`);
      }
      
    } catch (error) {
      console.error("❌ Failed to execute buy:", error);
    }
  }

  /**
   * Display current agent status
   */
  private async displayStatus(): Promise<void> {
    console.log("\n📊 AGENT STATUS");
    console.log("==========================================");
    
    try {
      // Agent info
      const agentStatus = await this.contracts.agent.getAgentStatus();
      const statusNames = ['Active', 'Paused', 'Emergency Stop'];
      console.log(`🤖 Agent Status: ${statusNames[agentStatus] || 'Unknown'}`);
      
      // Strategy info
      const strategyConfig = await this.contracts.solStrategy.strategyConfig();
      console.log(`📈 Strategy: ${strategyConfig.isActive ? 'Active' : 'Inactive'}`);
      console.log(`📉 Drop Threshold: ${strategyConfig.dropThreshold / 100}%`);
      console.log(`⏱️  Time Window: ${strategyConfig.timeWindow / 60} minutes`);
      console.log(`💰 Max Buy: $${ethers.utils.formatUnits(strategyConfig.maxBuyAmount, 6)}`);
      console.log(`⏳ Cooldown: ${strategyConfig.cooldownPeriod / 60} minutes`);
      
      // Current price
      const [currentPrice] = await this.contracts.priceOracle.getCurrentPrice();
      console.log(`💲 Current SOL Price: $${ethers.utils.formatUnits(currentPrice, 8)}`);
      
      // Check conditions
      const [canBuy, reason, dropPercentage] = await this.contracts.solStrategy.canExecuteBuy();
      console.log(`✅ Can Execute Buy: ${canBuy ? 'YES' : `NO (${reason})`}`);
      if (dropPercentage > 0) {
        console.log(`📉 Current Drop: ${dropPercentage / 100}%`);
      }
      
      // Balance info (if mock USDC is available)
      if (this.contracts.mockUSDC) {
        const usdcBalance = await this.contracts.mockUSDC.balanceOf(this.contracts.solStrategy.address);
        console.log(`💵 USDC Balance: $${ethers.utils.formatUnits(usdcBalance, 6)}`);
      }
      
    } catch (error) {
      console.error("❌ Error displaying status:", error);
    }
    
    console.log("==========================================");
  }

  /**
   * Display final statistics
   */
  private displayFinalStats(): void {
    const runTime = (Date.now() - this.startTime) / 1000;
    
    console.log("\n📊 FINAL STATISTICS");
    console.log("==========================================");
    console.log(`⏱️  Total Runtime: ${Math.floor(runTime / 60)}m ${Math.floor(runTime % 60)}s`);
    console.log(`🔍 Total Checks: ${this.stats.checksPerformed}`);
    console.log(`💰 Trades Executed: ${this.stats.tradesExecuted}`);
    
    if (this.stats.tradesExecuted > 0) {
      console.log(`🪙 Total SOL Bought: ${ethers.utils.formatUnits(this.stats.totalSOLBought, 9)} SOL`);
      console.log(`💵 Total USDC Spent: $${ethers.utils.formatUnits(this.stats.totalUSDCSpent, 6)}`);
      console.log(`📅 Last Trade: ${new Date(this.stats.lastTradeTime).toLocaleString()}`);
      
      const avgPrice = this.stats.totalUSDCSpent.mul(ethers.utils.parseUnits("1", 9)).div(this.stats.totalSOLBought);
      console.log(`📊 Average Buy Price: $${ethers.utils.formatUnits(avgPrice, 6)} per SOL`);
    }
    
    console.log("==========================================");
  }

  /**
   * Send notification (placeholder for webhook/email integration)
   */
  private async sendNotification(message: string): Promise<void> {
    // Placeholder for notification integration
    // Could integrate with Discord, Slack, Email, etc.
    console.log(`🔔 Notification: ${message}`);
  }

  /**
   * Sleep utility
   */
  private sleep(ms: number): Promise<void> {
    return new Promise(resolve => setTimeout(resolve, ms));
  }
}

/**
 * Load deployed contracts from deployment file
 */
async function loadContracts(): Promise<AgentContracts> {
  try {
    const deploymentInfo = require("../deployments/sol-strategy-localhost.json");
    
    const agent = await ethers.getContractAt(
      "RecallTradingAgent", 
      deploymentInfo.contracts.TradingAgent.address
    );
    
    const solStrategy = await ethers.getContractAt(
      "SOLDropBuyStrategy", 
      deploymentInfo.contracts.SOLDropBuyStrategy.address
    );
    
    const priceOracle = await ethers.getContractAt(
      "MockSOLPriceOracle", 
      deploymentInfo.contracts.MockSOLPriceOracle.address
    );
    
    return { agent, solStrategy, priceOracle };
    
  } catch (error) {
    throw new Error(`Failed to load contracts: ${error}. Make sure to deploy first with: npx hardhat run scripts/deploy-sol-strategy.ts --network localhost`);
  }
}

/**
 * Main function to run the SOL agent
 */
async function main(): Promise<void> {
  console.log("🔄 Loading deployed contracts...");
  const contracts = await loadContracts();
  
  // Configuration
  const config: MonitoringConfig = {
    checkInterval: 30000, // 30 seconds
    enableAutoExecution: process.env.AUTO_EXECUTE === 'true',
    maxRunTime: process.env.MAX_RUN_TIME ? parseInt(process.env.MAX_RUN_TIME) * 1000 : 0,
    logLevel: (process.env.LOG_LEVEL as 'minimal' | 'detailed') || 'detailed',
  };
  
  // Create and start agent runner
  const runner = new SOLAgentRunner(contracts, config);
  
  // Handle graceful shutdown
  process.on('SIGINT', () => {
    console.log('\n🛑 Received SIGINT, shutting down gracefully...');
    runner.stop();
  });
  
  process.on('SIGTERM', () => {
    console.log('\n🛑 Received SIGTERM, shutting down gracefully...');
    runner.stop();
  });
  
  // Start the agent
  await runner.start();
}

/**
 * Utility function to simulate a price drop for testing
 */
async function simulatePriceDrop(): Promise<void> {
  console.log("🧪 Simulating SOL price drop for testing...");
  
  const contracts = await loadContracts();
  
  // Create price history showing gradual decline
  const startPrice = ethers.utils.parseUnits("100", 8); // $100
  const endPrice = ethers.utils.parseUnits("94", 8);    // $94 (6% drop)
  
  await contracts.priceOracle.createPriceHistory(startPrice, endPrice);
  
  console.log("✅ Price drop simulation complete!");
  console.log("   Start Price: $100");
  console.log("   End Price: $94 (6% drop)");
  console.log("   Time Window: 1 hour");
  console.log("\nNow run the agent to see it detect and act on the drop:");
  console.log("npx hardhat run scripts/run-sol-agent.ts --network localhost");
}

// Export functions for use in other scripts
export { SOLAgentRunner, loadContracts, simulatePriceDrop };

// Run based on command line arguments
if (require.main === module) {
  const args = process.argv.slice(2);
  
  if (args.includes('--simulate-drop')) {
    simulatePriceDrop()
      .then(() => process.exit(0))
      .catch((error) => {
        console.error("❌ Simulation failed:", error);
        process.exit(1);
      });
  } else {
    main()
      .then(() => process.exit(0))
      .catch((error) => {
        console.error("❌ Agent failed:", error);
        process.exit(1);
      });
  }
}