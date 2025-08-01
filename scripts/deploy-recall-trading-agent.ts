import { ethers } from "hardhat";
import { Contract } from "ethers";

interface DeploymentConfig {
  deploymentFee: string;
  feeRecipient: string;
  initialStrategies?: TradingStrategy[];
  riskParameters?: RiskParameters;
}

interface TradingStrategy {
  strategyId: string;
  isActive: boolean;
  maxTradeAmount: string;
  riskThreshold: number;
  cooldownPeriod: number;
  lastExecutionTime: number;
}

interface RiskParameters {
  maxLeverage: number;
  stopLossThreshold: number;
  maxDrawdown: number;
  volatilityThreshold: number;
}

interface DeploymentResult {
  implementation: Contract;
  factory: Contract;
  implementationAddress: string;
  factoryAddress: string;
  deploymentTx: string;
  gasUsed: string;
}

async function main(): Promise<DeploymentResult> {
  console.log("🚀 Starting Recall Trading Agent deployment...");
  
  const [deployer] = await ethers.getSigners();
  console.log("📝 Deploying with account:", deployer.address);
  
  const balance = await deployer.getBalance();
  console.log("💰 Account balance:", ethers.utils.formatEther(balance), "ETH");

  // Default deployment configuration
  const config: DeploymentConfig = {
    deploymentFee: ethers.utils.parseEther("0.01").toString(), // 0.01 ETH
    feeRecipient: deployer.address, // Use deployer as fee recipient by default
  };

  // Load custom config if available
  try {
    const customConfig = require("../config/recall-agent-config.json");
    Object.assign(config, customConfig);
    console.log("📋 Loaded custom deployment config");
  } catch (error) {
    console.log("📋 Using default deployment config");
  }

  console.log("⚙️  Deployment Configuration:");
  console.log("  - Deployment Fee:", ethers.utils.formatEther(config.deploymentFee), "ETH");
  console.log("  - Fee Recipient:", config.feeRecipient);

  // Step 1: Deploy RecallTradingAgent implementation
  console.log("\n🔨 Deploying RecallTradingAgent implementation...");
  const RecallTradingAgent = await ethers.getContractFactory("RecallTradingAgent");
  const implementation = await RecallTradingAgent.deploy();
  await implementation.deployed();
  
  console.log("✅ Implementation deployed at:", implementation.address);
  console.log("🧾 Implementation deployment tx:", implementation.deployTransaction.hash);

  // Step 2: Deploy RecallTradingAgentFactory
  console.log("\n🔨 Deploying RecallTradingAgentFactory...");
  const RecallTradingAgentFactory = await ethers.getContractFactory("RecallTradingAgentFactory");
  const factory = await RecallTradingAgentFactory.deploy(
    implementation.address,
    config.deploymentFee,
    config.feeRecipient
  );
  await factory.deployed();
  
  console.log("✅ Factory deployed at:", factory.address);
  console.log("🧾 Factory deployment tx:", factory.deployTransaction.hash);

  // Step 3: Verify deployment
  console.log("\n🔍 Verifying deployment...");
  
  const factoryImplementation = await factory.implementation();
  const factoryDeploymentFee = await factory.deploymentFee();
  const factoryFeeRecipient = await factory.feeRecipient();
  
  console.log("✅ Factory verification:");
  console.log("  - Implementation address matches:", factoryImplementation === implementation.address);
  console.log("  - Deployment fee matches:", factoryDeploymentFee.toString() === config.deploymentFee);
  console.log("  - Fee recipient matches:", factoryFeeRecipient === config.feeRecipient);

  // Step 4: Calculate gas usage
  const implementationReceipt = await implementation.deployTransaction.wait();
  const factoryReceipt = await factory.deployTransaction.wait();
  const totalGasUsed = implementationReceipt.gasUsed.add(factoryReceipt.gasUsed);
  
  console.log("\n⛽ Gas Usage:");
  console.log("  - Implementation:", implementationReceipt.gasUsed.toString());
  console.log("  - Factory:", factoryReceipt.gasUsed.toString());
  console.log("  - Total:", totalGasUsed.toString());

  // Step 5: Display deployment summary
  console.log("\n📊 Deployment Summary:");
  console.log("==========================================");
  console.log("🎯 RecallTradingAgent Implementation:", implementation.address);
  console.log("🏭 RecallTradingAgentFactory:", factory.address);
  console.log("💸 Total Gas Used:", totalGasUsed.toString());
  console.log("🔗 Network:", (await ethers.provider.getNetwork()).name);
  console.log("👤 Deployer:", deployer.address);
  console.log("==========================================");

  // Step 6: Save deployment addresses to file
  const deploymentInfo = {
    network: (await ethers.provider.getNetwork()).name,
    chainId: (await ethers.provider.getNetwork()).chainId,
    deployer: deployer.address,
    timestamp: new Date().toISOString(),
    contracts: {
      RecallTradingAgent: {
        address: implementation.address,
        deploymentTx: implementation.deployTransaction.hash,
        gasUsed: implementationReceipt.gasUsed.toString(),
      },
      RecallTradingAgentFactory: {
        address: factory.address,
        deploymentTx: factory.deployTransaction.hash,
        gasUsed: factoryReceipt.gasUsed.toString(),
      },
    },
    config: {
      deploymentFee: config.deploymentFee,
      feeRecipient: config.feeRecipient,
    },
    totalGasUsed: totalGasUsed.toString(),
  };

  // Save to deployments directory
  const fs = require("fs");
  const path = require("path");
  
  const deploymentsDir = path.join(__dirname, "../deployments");
  if (!fs.existsSync(deploymentsDir)) {
    fs.mkdirSync(deploymentsDir, { recursive: true });
  }
  
  const networkName = (await ethers.provider.getNetwork()).name;
  const deploymentFile = path.join(deploymentsDir, `recall-agent-${networkName}.json`);
  
  fs.writeFileSync(deploymentFile, JSON.stringify(deploymentInfo, null, 2));
  console.log("💾 Deployment info saved to:", deploymentFile);

  // Step 7: Optional - Deploy a sample agent
  if (process.env.DEPLOY_SAMPLE_AGENT === "true") {
    console.log("\n🤖 Deploying sample agent...");
    await deploySampleAgent(factory, deployer);
  }

  console.log("\n🎉 Deployment completed successfully!");
  
  return {
    implementation,
    factory,
    implementationAddress: implementation.address,
    factoryAddress: factory.address,
    deploymentTx: factory.deployTransaction.hash,
    gasUsed: totalGasUsed.toString(),
  };
}

async function deploySampleAgent(factory: Contract, deployer: any): Promise<void> {
  try {
    // Sample trading strategies
    const sampleStrategies: TradingStrategy[] = [
      {
        strategyId: ethers.utils.keccak256(ethers.utils.toUtf8Bytes("ARBITRAGE_V1")),
        isActive: true,
        maxTradeAmount: ethers.utils.parseEther("1000").toString(),
        riskThreshold: 500, // 5%
        cooldownPeriod: 300, // 5 minutes
        lastExecutionTime: 0,
      },
      {
        strategyId: ethers.utils.keccak256(ethers.utils.toUtf8Bytes("MARKET_MAKING_V1")),
        isActive: true,
        maxTradeAmount: ethers.utils.parseEther("500").toString(),
        riskThreshold: 300, // 3%
        cooldownPeriod: 600, // 10 minutes
        lastExecutionTime: 0,
      },
    ];

    // Sample risk parameters
    const sampleRiskParams: RiskParameters = {
      maxLeverage: 300, // 3x leverage
      stopLossThreshold: 1000, // 10%
      maxDrawdown: 2000, // 20%
      volatilityThreshold: 5000, // 50%
    };

    const agentId = ethers.utils.keccak256(
      ethers.utils.toUtf8Bytes(`SAMPLE_AGENT_${Date.now()}`)
    );

    const deploymentFee = await factory.deploymentFee();
    
    const tx = await factory.deployAgent(
      agentId,
      deployer.address,
      sampleStrategies,
      sampleRiskParams,
      { value: deploymentFee }
    );

    const receipt = await tx.wait();
    const agentAddress = await factory.getAgent(agentId);

    console.log("✅ Sample agent deployed:");
    console.log("  - Agent ID:", agentId);
    console.log("  - Agent Address:", agentAddress);
    console.log("  - Deployment Tx:", tx.hash);
    console.log("  - Gas Used:", receipt.gasUsed.toString());
  } catch (error) {
    console.error("❌ Failed to deploy sample agent:", error);
  }
}

// Helper function to verify contracts on Etherscan
async function verifyContracts(
  implementationAddress: string,
  factoryAddress: string,
  config: DeploymentConfig
): Promise<void> {
  if (process.env.VERIFY_CONTRACTS !== "true") {
    console.log("⏭️  Skipping contract verification");
    return;
  }

  console.log("\n🔍 Verifying contracts on Etherscan...");
  
  try {
    // Verify implementation
    await ethers.run("verify:verify", {
      address: implementationAddress,
      constructorArguments: [],
    });
    console.log("✅ Implementation verified");

    // Verify factory
    await ethers.run("verify:verify", {
      address: factoryAddress,
      constructorArguments: [
        implementationAddress,
        config.deploymentFee,
        config.feeRecipient,
      ],
    });
    console.log("✅ Factory verified");
  } catch (error) {
    console.error("❌ Verification failed:", error);
  }
}

// Run the deployment
if (require.main === module) {
  main()
    .then((result) => {
      if (process.env.VERIFY_CONTRACTS === "true") {
        const config: DeploymentConfig = {
          deploymentFee: ethers.utils.parseEther("0.01").toString(),
          feeRecipient: result.factory.address,
        };
        return verifyContracts(result.implementationAddress, result.factoryAddress, config);
      }
    })
    .then(() => process.exit(0))
    .catch((error) => {
      console.error("❌ Deployment failed:", error);
      process.exit(1);
    });
}

export { main as deployRecallTradingAgent, DeploymentResult, DeploymentConfig };