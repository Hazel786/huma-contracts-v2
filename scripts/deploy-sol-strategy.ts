import { ethers } from "hardhat";
import { Contract } from "ethers";

interface SOLStrategyDeployment {
  agent: Contract;
  solStrategy: Contract;
  priceOracle: Contract;
  agentAddress: string;
  strategyAddress: string;
  oracleAddress: string;
}

async function main(): Promise<SOLStrategyDeployment> {
  console.log("🚀 Deploying SOL Drop Buy Strategy...");
  
  const [deployer] = await ethers.getSigners();
  console.log("📝 Deploying with account:", deployer.address);
  
  const balance = await deployer.getBalance();
  console.log("💰 Account balance:", ethers.utils.formatEther(balance), "ETH");

  // Step 1: Deploy Mock Price Oracle (for testing)
  console.log("\n🔨 Deploying Mock Price Oracle...");
  const MockPriceOracle = await ethers.getContractFactory("MockSOLPriceOracle");
  const priceOracle = await MockPriceOracle.deploy();
  await priceOracle.deployed();
  console.log("✅ Price Oracle deployed at:", priceOracle.address);

  // Step 2: Deploy SOL Drop Buy Strategy
  console.log("\n🔨 Deploying SOL Drop Buy Strategy...");
  const SOLDropBuyStrategy = await ethers.getContractFactory("SOLDropBuyStrategy");
  const solStrategy = await SOLDropBuyStrategy.deploy(priceOracle.address);
  await solStrategy.deployed();
  console.log("✅ SOL Strategy deployed at:", solStrategy.address);

  // Step 3: Deploy Trading Agent with SOL strategy
  console.log("\n🔨 Deploying Trading Agent...");
  
  // Get or deploy factory first
  let factoryAddress: string;
  try {
    // Try to load existing factory from deployments
    const deploymentInfo = require("../deployments/recall-agent-localhost.json");
    factoryAddress = deploymentInfo.contracts.RecallTradingAgentFactory.address;
    console.log("📋 Using existing factory at:", factoryAddress);
  } catch {
    // Deploy new factory if not exists
    console.log("📋 No existing factory found, deploying new one...");
    const { factory } = await deployFactory();
    factoryAddress = factory.address;
  }

  const factory = await ethers.getContractAt("RecallTradingAgentFactory", factoryAddress);

  // Configure SOL strategy for the agent
  const solStrategyConfig = {
    strategyId: ethers.utils.keccak256(ethers.utils.toUtf8Bytes("SOL_DROP_BUY_V1")),
    isActive: true,
    maxTradeAmount: ethers.utils.parseEther("10000"), // $10,000 USDC max per trade
    riskThreshold: 500, // 5% drop threshold
    cooldownPeriod: 1800, // 30 minutes cooldown
    lastExecutionTime: 0,
  };

  const riskParams = {
    maxLeverage: 100, // 1x leverage (no leverage for spot buying)
    stopLossThreshold: 1000, // 10% stop loss
    maxDrawdown: 2000, // 20% max drawdown
    volatilityThreshold: 3000, // 30% volatility threshold
  };

  // Deploy agent through factory
  const agentId = ethers.utils.keccak256(ethers.utils.toUtf8Bytes(`SOL_AGENT_${Date.now()}`));
  const deploymentFee = await factory.deploymentFee();
  
  console.log("💸 Deployment fee:", ethers.utils.formatEther(deploymentFee), "ETH");
  
  const deployTx = await factory.deployAgent(
    agentId,
    deployer.address,
    [solStrategyConfig],
    riskParams,
    { value: deploymentFee }
  );
  
  await deployTx.wait();
  const agentAddress = await factory.getAgent(agentId);
  const agent = await ethers.getContractAt("RecallTradingAgent", agentAddress);
  
  console.log("✅ Trading Agent deployed at:", agentAddress);

  // Step 4: Configure the agent to work with SOL strategy
  console.log("\n⚙️  Configuring agent for SOL strategy...");
  
  // Authorize the SOL strategy contract to trigger trades
  await agent.setAuthorizedCaller(solStrategy.address, true);
  console.log("✅ Authorized SOL strategy as caller");

  // Step 5: Set up initial SOL price (for testing)
  console.log("\n📊 Setting initial SOL price...");
  await priceOracle.updatePrice(ethers.utils.parseUnits("100", 8)); // $100 SOL price
  console.log("✅ Set initial SOL price to $100");

  // Step 6: Display setup summary
  console.log("\n📊 Deployment Summary:");
  console.log("==========================================");
  console.log("🏭 Factory Address:", factoryAddress);
  console.log("🤖 Trading Agent:", agentAddress);
  console.log("📈 SOL Strategy:", solStrategy.address);
  console.log("🔮 Price Oracle:", priceOracle.address);
  console.log("🆔 Agent ID:", agentId);
  console.log("==========================================");

  // Step 7: Save deployment info
  const deploymentInfo = {
    network: (await ethers.provider.getNetwork()).name,
    chainId: (await ethers.provider.getNetwork()).chainId,
    deployer: deployer.address,
    timestamp: new Date().toISOString(),
    contracts: {
      TradingAgent: {
        address: agentAddress,
        agentId: agentId,
      },
      SOLDropBuyStrategy: {
        address: solStrategy.address,
      },
      MockSOLPriceOracle: {
        address: priceOracle.address,
      },
      Factory: {
        address: factoryAddress,
      },
    },
    configuration: {
      solStrategy: solStrategyConfig,
      riskParams: riskParams,
    },
  };

  const fs = require("fs");
  const path = require("path");
  
  const deploymentsDir = path.join(__dirname, "../deployments");
  if (!fs.existsSync(deploymentsDir)) {
    fs.mkdirSync(deploymentsDir, { recursive: true });
  }
  
  const networkName = (await ethers.provider.getNetwork()).name;
  const deploymentFile = path.join(deploymentsDir, `sol-strategy-${networkName}.json`);
  
  fs.writeFileSync(deploymentFile, JSON.stringify(deploymentInfo, null, 2));
  console.log("💾 Deployment info saved to:", deploymentFile);

  console.log("\n🎉 SOL Drop Buy Strategy deployed successfully!");
  console.log("\n📋 Next Steps:");
  console.log("1. Fund the agent with USDC for buying SOL");
  console.log("2. Run the monitoring script to watch for price drops");
  console.log("3. The agent will automatically buy SOL when it drops 5% in 1 hour");

  return {
    agent,
    solStrategy,
    priceOracle,
    agentAddress,
    strategyAddress: solStrategy.address,
    oracleAddress: priceOracle.address,
  };
}

async function deployFactory() {
  console.log("🔨 Deploying new factory...");
  
  // Deploy implementation
  const RecallTradingAgent = await ethers.getContractFactory("RecallTradingAgent");
  const implementation = await RecallTradingAgent.deploy();
  await implementation.deployed();
  
  // Deploy factory
  const RecallTradingAgentFactory = await ethers.getContractFactory("RecallTradingAgentFactory");
  const factory = await RecallTradingAgentFactory.deploy(
    implementation.address,
    ethers.utils.parseEther("0.001"), // 0.001 ETH fee
    (await ethers.getSigners())[0].address // Fee recipient
  );
  await factory.deployed();
  
  console.log("✅ New factory deployed at:", factory.address);
  
  return { factory, implementation };
}

// Run the deployment
if (require.main === module) {
  main()
    .then(() => process.exit(0))
    .catch((error) => {
      console.error("❌ Deployment failed:", error);
      process.exit(1);
    });
}

export { main as deploySOLStrategy };