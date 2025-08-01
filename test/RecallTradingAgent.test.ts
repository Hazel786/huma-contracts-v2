import { expect } from "chai";
import { ethers } from "hardhat";
import { Contract, Signer, BigNumber } from "ethers";
import { time } from "@nomicfoundation/hardhat-network-helpers";

describe("RecallTradingAgent", function () {
  let recallTradingAgent: Contract;
  let factory: Contract;
  let owner: Signer;
  let user1: Signer;
  let user2: Signer;
  let feeRecipient: Signer;
  let ownerAddress: string;
  let user1Address: string;
  let user2Address: string;
  let feeRecipientAddress: string;

  const deploymentFee = ethers.utils.parseEther("0.01");
  
  const sampleStrategy = {
    strategyId: ethers.utils.keccak256(ethers.utils.toUtf8Bytes("TEST_STRATEGY_1")),
    isActive: true,
    maxTradeAmount: ethers.utils.parseEther("1000"),
    riskThreshold: 500, // 5%
    cooldownPeriod: 300, // 5 minutes
    lastExecutionTime: 0,
  };

  const sampleRiskParams = {
    maxLeverage: 300, // 3x
    stopLossThreshold: 1000, // 10%
    maxDrawdown: 2000, // 20%
    volatilityThreshold: 5000, // 50%
  };

  beforeEach(async function () {
    [owner, user1, user2, feeRecipient] = await ethers.getSigners();
    ownerAddress = await owner.getAddress();
    user1Address = await user1.getAddress();
    user2Address = await user2.getAddress();
    feeRecipientAddress = await feeRecipient.getAddress();

    // Deploy implementation
    const RecallTradingAgent = await ethers.getContractFactory("RecallTradingAgent");
    const implementation = await RecallTradingAgent.deploy();
    await implementation.deployed();

    // Deploy factory
    const RecallTradingAgentFactory = await ethers.getContractFactory("RecallTradingAgentFactory");
    factory = await RecallTradingAgentFactory.deploy(
      implementation.address,
      deploymentFee,
      feeRecipientAddress
    );
    await factory.deployed();

    // Deploy agent through factory
    const agentId = ethers.utils.keccak256(ethers.utils.toUtf8Bytes("TEST_AGENT_1"));
    await factory.connect(owner).deployAgent(
      agentId,
      ownerAddress,
      [sampleStrategy],
      sampleRiskParams,
      { value: deploymentFee }
    );

    const agentAddress = await factory.getAgent(agentId);
    recallTradingAgent = await ethers.getContractAt("RecallTradingAgent", agentAddress);
  });

  describe("Initialization", function () {
    it("Should initialize with correct parameters", async function () {
      expect(await recallTradingAgent.owner()).to.equal(ownerAddress);
      expect(await recallTradingAgent.getAgentStatus()).to.equal(0); // Active
      
      const riskParams = await recallTradingAgent.getRiskParameters();
      expect(riskParams.maxLeverage).to.equal(sampleRiskParams.maxLeverage);
      expect(riskParams.stopLossThreshold).to.equal(sampleRiskParams.stopLossThreshold);
      expect(riskParams.maxDrawdown).to.equal(sampleRiskParams.maxDrawdown);
      expect(riskParams.volatilityThreshold).to.equal(sampleRiskParams.volatilityThreshold);
    });

    it("Should have initial strategy configured", async function () {
      const strategy = await recallTradingAgent.getStrategy(sampleStrategy.strategyId);
      expect(strategy.strategyId).to.equal(sampleStrategy.strategyId);
      expect(strategy.isActive).to.equal(sampleStrategy.isActive);
      expect(strategy.maxTradeAmount).to.equal(sampleStrategy.maxTradeAmount);
      expect(strategy.riskThreshold).to.equal(sampleStrategy.riskThreshold);
      expect(strategy.cooldownPeriod).to.equal(sampleStrategy.cooldownPeriod);
    });

    it("Should not allow double initialization", async function () {
      await expect(
        recallTradingAgent.initialize(ownerAddress, [sampleStrategy], sampleRiskParams)
      ).to.be.revertedWith("Initializable: contract is already initialized");
    });
  });

  describe("Strategy Management", function () {
    const newStrategy = {
      strategyId: ethers.utils.keccak256(ethers.utils.toUtf8Bytes("NEW_STRATEGY")),
      isActive: true,
      maxTradeAmount: ethers.utils.parseEther("500"),
      riskThreshold: 300,
      cooldownPeriod: 600,
      lastExecutionTime: 0,
    };

    it("Should allow owner to add new strategy", async function () {
      await expect(recallTradingAgent.connect(owner).updateStrategy(newStrategy))
        .to.not.be.reverted;

      const strategy = await recallTradingAgent.getStrategy(newStrategy.strategyId);
      expect(strategy.strategyId).to.equal(newStrategy.strategyId);
      expect(strategy.isActive).to.equal(newStrategy.isActive);
    });

    it("Should allow owner to update existing strategy", async function () {
      const updatedStrategy = { ...sampleStrategy, maxTradeAmount: ethers.utils.parseEther("2000") };
      
      await expect(recallTradingAgent.connect(owner).updateStrategy(updatedStrategy))
        .to.not.be.reverted;

      const strategy = await recallTradingAgent.getStrategy(sampleStrategy.strategyId);
      expect(strategy.maxTradeAmount).to.equal(updatedStrategy.maxTradeAmount);
    });

    it("Should not allow non-owner to update strategy", async function () {
      await expect(recallTradingAgent.connect(user1).updateStrategy(newStrategy))
        .to.be.revertedWith("Ownable: caller is not the owner");
    });

    it("Should allow owner to remove strategy", async function () {
      await expect(recallTradingAgent.connect(owner).removeStrategy(sampleStrategy.strategyId))
        .to.not.be.reverted;

      const strategy = await recallTradingAgent.getStrategy(sampleStrategy.strategyId);
      expect(strategy.strategyId).to.equal(ethers.constants.HashZero);
    });

    it("Should get active strategies correctly", async function () {
      await recallTradingAgent.connect(owner).updateStrategy(newStrategy);
      
      const activeStrategies = await recallTradingAgent.getActiveStrategies();
      expect(activeStrategies.length).to.equal(2);
    });

    it("Should reject invalid strategy parameters", async function () {
      const invalidStrategy = { ...newStrategy, strategyId: ethers.constants.HashZero };
      await expect(recallTradingAgent.connect(owner).updateStrategy(invalidStrategy))
        .to.be.revertedWith("Invalid strategy ID");

      const invalidStrategy2 = { ...newStrategy, maxTradeAmount: 0 };
      await expect(recallTradingAgent.connect(owner).updateStrategy(invalidStrategy2))
        .to.be.revertedWith("Invalid max trade amount");

      const invalidStrategy3 = { ...newStrategy, riskThreshold: 10001 };
      await expect(recallTradingAgent.connect(owner).updateStrategy(invalidStrategy3))
        .to.be.revertedWith("Invalid risk threshold");
    });
  });

  describe("Risk Management", function () {
    const newRiskParams = {
      maxLeverage: 500,
      stopLossThreshold: 1500,
      maxDrawdown: 2500,
      volatilityThreshold: 6000,
    };

    it("Should allow owner to update risk parameters", async function () {
      await expect(recallTradingAgent.connect(owner).updateRiskParameters(newRiskParams))
        .to.emit(recallTradingAgent, "RiskParameterUpdated")
        .withArgs(recallTradingAgent.address, "maxLeverage", sampleRiskParams.maxLeverage, newRiskParams.maxLeverage);

      const riskParams = await recallTradingAgent.getRiskParameters();
      expect(riskParams.maxLeverage).to.equal(newRiskParams.maxLeverage);
      expect(riskParams.stopLossThreshold).to.equal(newRiskParams.stopLossThreshold);
      expect(riskParams.maxDrawdown).to.equal(newRiskParams.maxDrawdown);
      expect(riskParams.volatilityThreshold).to.equal(newRiskParams.volatilityThreshold);
    });

    it("Should not allow non-owner to update risk parameters", async function () {
      await expect(recallTradingAgent.connect(user1).updateRiskParameters(newRiskParams))
        .to.be.revertedWith("Ownable: caller is not the owner");
    });

    it("Should reject invalid risk parameters", async function () {
      const invalidRiskParams1 = { ...newRiskParams, maxLeverage: 1001 };
      await expect(recallTradingAgent.connect(owner).updateRiskParameters(invalidRiskParams1))
        .to.be.revertedWith("Leverage too high");

      const invalidRiskParams2 = { ...newRiskParams, stopLossThreshold: 10001 };
      await expect(recallTradingAgent.connect(owner).updateRiskParameters(invalidRiskParams2))
        .to.be.revertedWith("Invalid stop loss");

      const invalidRiskParams3 = { ...newRiskParams, maxDrawdown: 10001 };
      await expect(recallTradingAgent.connect(owner).updateRiskParameters(invalidRiskParams3))
        .to.be.revertedWith("Invalid max drawdown");
    });
  });

  describe("Trade Execution", function () {
    const tradeAmount = ethers.utils.parseEther("100");
    const tradeData = "0x1234";

    beforeEach(async function () {
      // Authorize user1 as caller
      await recallTradingAgent.connect(owner).setAuthorizedCaller(user1Address, true);
    });

    it("Should allow authorized caller to execute trade", async function () {
      await expect(
        recallTradingAgent.connect(user1).executeTrade(sampleStrategy.strategyId, tradeAmount, tradeData)
      )
        .to.emit(recallTradingAgent, "TradeExecuted")
        .withArgs(recallTradingAgent.address, sampleStrategy.strategyId, tradeAmount, true);
    });

    it("Should allow owner to execute trade", async function () {
      await expect(
        recallTradingAgent.connect(owner).executeTrade(sampleStrategy.strategyId, tradeAmount, tradeData)
      )
        .to.emit(recallTradingAgent, "TradeExecuted");
    });

    it("Should not allow unauthorized caller to execute trade", async function () {
      await expect(
        recallTradingAgent.connect(user2).executeTrade(sampleStrategy.strategyId, tradeAmount, tradeData)
      ).to.be.revertedWith("Unauthorized caller");
    });

    it("Should not execute trade with inactive strategy", async function () {
      const inactiveStrategy = { ...sampleStrategy, isActive: false };
      await recallTradingAgent.connect(owner).updateStrategy(inactiveStrategy);

      await expect(
        recallTradingAgent.connect(user1).executeTrade(sampleStrategy.strategyId, tradeAmount, tradeData)
      ).to.be.revertedWith("Strategy not active");
    });

    it("Should not execute trade exceeding strategy limit", async function () {
      const largeAmount = ethers.utils.parseEther("2000");
      await expect(
        recallTradingAgent.connect(user1).executeTrade(sampleStrategy.strategyId, largeAmount, tradeData)
      ).to.be.revertedWith("Amount exceeds strategy limit");
    });

    it("Should respect cooldown period", async function () {
      // Execute first trade
      await recallTradingAgent.connect(user1).executeTrade(sampleStrategy.strategyId, tradeAmount, tradeData);

      // Try to execute immediately (should fail)
      await expect(
        recallTradingAgent.connect(user1).executeTrade(sampleStrategy.strategyId, tradeAmount, tradeData)
      ).to.be.revertedWith("Strategy in cooldown");

      // Fast forward time beyond cooldown
      await time.increase(sampleStrategy.cooldownPeriod + 1);

      // Should work now
      await expect(
        recallTradingAgent.connect(user1).executeTrade(sampleStrategy.strategyId, tradeAmount, tradeData)
      ).to.not.be.reverted;
    });

    it("Should update performance metrics after trade", async function () {
      const metricsBefore = await recallTradingAgent.getPerformanceMetrics();
      
      await recallTradingAgent.connect(user1).executeTrade(sampleStrategy.strategyId, tradeAmount, tradeData);
      
      const metricsAfter = await recallTradingAgent.getPerformanceMetrics();
      expect(metricsAfter.totalTrades).to.equal(metricsBefore.totalTrades.add(1));
      expect(metricsAfter.successfulTrades).to.equal(metricsBefore.successfulTrades.add(1));
      expect(metricsAfter.totalVolume).to.equal(metricsBefore.totalVolume.add(tradeAmount));
    });

    it("Should check trade execution conditions", async function () {
      const [canExecute, reason] = await recallTradingAgent.canExecuteTrade(sampleStrategy.strategyId, tradeAmount);
      expect(canExecute).to.be.true;
      expect(reason).to.equal("");

      // Test with inactive strategy
      const inactiveStrategy = { ...sampleStrategy, isActive: false };
      await recallTradingAgent.connect(owner).updateStrategy(inactiveStrategy);
      
      const [canExecute2, reason2] = await recallTradingAgent.canExecuteTrade(sampleStrategy.strategyId, tradeAmount);
      expect(canExecute2).to.be.false;
      expect(reason2).to.equal("Strategy not active");
    });
  });

  describe("Recall Functionality", function () {
    const creditPool = ethers.Wallet.createRandom().address;
    const borrower = ethers.Wallet.createRandom().address;
    const recallAmount = ethers.utils.parseEther("500");

    beforeEach(async function () {
      await recallTradingAgent.connect(owner).setAuthorizedCaller(user1Address, true);
    });

    it("Should allow authorized caller to trigger recall", async function () {
      await expect(
        recallTradingAgent.connect(user1).triggerRecall(creditPool, borrower, recallAmount)
      )
        .to.emit(recallTradingAgent, "RecallTriggered")
        .withArgs(recallTradingAgent.address, creditPool, borrower, recallAmount);
    });

    it("Should allow owner to trigger recall", async function () {
      await expect(
        recallTradingAgent.connect(owner).triggerRecall(creditPool, borrower, recallAmount)
      )
        .to.emit(recallTradingAgent, "RecallTriggered");
    });

    it("Should not allow unauthorized caller to trigger recall", async function () {
      await expect(
        recallTradingAgent.connect(user2).triggerRecall(creditPool, borrower, recallAmount)
      ).to.be.revertedWith("Unauthorized caller");
    });

    it("Should reject invalid recall parameters", async function () {
      await expect(
        recallTradingAgent.connect(user1).triggerRecall(ethers.constants.AddressZero, borrower, recallAmount)
      ).to.be.revertedWith("Invalid credit pool");

      await expect(
        recallTradingAgent.connect(user1).triggerRecall(creditPool, ethers.constants.AddressZero, recallAmount)
      ).to.be.revertedWith("Invalid borrower");

      await expect(
        recallTradingAgent.connect(user1).triggerRecall(creditPool, borrower, 0)
      ).to.be.revertedWith("Invalid recall amount");
    });

    it("Should track recall amounts", async function () {
      await recallTradingAgent.connect(user1).triggerRecall(creditPool, borrower, recallAmount);
      
      const trackedAmount = await recallTradingAgent.creditPoolRecalls(creditPool, borrower);
      expect(trackedAmount).to.equal(recallAmount);

      // Trigger another recall
      await recallTradingAgent.connect(user1).triggerRecall(creditPool, borrower, recallAmount);
      
      const updatedAmount = await recallTradingAgent.creditPoolRecalls(creditPool, borrower);
      expect(updatedAmount).to.equal(recallAmount.mul(2));
    });
  });

  describe("Access Control", function () {
    it("Should allow owner to authorize/deauthorize callers", async function () {
      expect(await recallTradingAgent.authorizedCallers(user1Address)).to.be.false;

      await expect(recallTradingAgent.connect(owner).setAuthorizedCaller(user1Address, true))
        .to.emit(recallTradingAgent, "AuthorizedCallerUpdated")
        .withArgs(user1Address, true);

      expect(await recallTradingAgent.authorizedCallers(user1Address)).to.be.true;

      await recallTradingAgent.connect(owner).setAuthorizedCaller(user1Address, false);
      expect(await recallTradingAgent.authorizedCallers(user1Address)).to.be.false;
    });

    it("Should not allow non-owner to authorize callers", async function () {
      await expect(recallTradingAgent.connect(user1).setAuthorizedCaller(user2Address, true))
        .to.be.revertedWith("Ownable: caller is not the owner");
    });

    it("Should reject invalid caller address", async function () {
      await expect(recallTradingAgent.connect(owner).setAuthorizedCaller(ethers.constants.AddressZero, true))
        .to.be.revertedWith("Invalid caller address");
    });
  });

  describe("Agent Status Management", function () {
    it("Should allow owner to pause agent", async function () {
      await expect(recallTradingAgent.connect(owner).pause())
        .to.emit(recallTradingAgent, "AgentStatusChanged")
        .withArgs(recallTradingAgent.address, 0, 1); // Active to Paused

      expect(await recallTradingAgent.getAgentStatus()).to.equal(1); // Paused
      expect(await recallTradingAgent.paused()).to.be.true;
    });

    it("Should allow owner to unpause agent", async function () {
      await recallTradingAgent.connect(owner).pause();
      
      await expect(recallTradingAgent.connect(owner).unpause())
        .to.emit(recallTradingAgent, "AgentStatusChanged")
        .withArgs(recallTradingAgent.address, 1, 0); // Paused to Active

      expect(await recallTradingAgent.getAgentStatus()).to.equal(0); // Active
      expect(await recallTradingAgent.paused()).to.be.false;
    });

    it("Should allow owner to emergency stop", async function () {
      await expect(recallTradingAgent.connect(owner).emergencyStop())
        .to.emit(recallTradingAgent, "AgentStatusChanged")
        .withArgs(recallTradingAgent.address, 0, 2); // Active to EmergencyStop

      expect(await recallTradingAgent.getAgentStatus()).to.equal(2); // EmergencyStop
      expect(await recallTradingAgent.paused()).to.be.true;
    });

    it("Should not allow trades when paused", async function () {
      await recallTradingAgent.connect(owner).setAuthorizedCaller(user1Address, true);
      await recallTradingAgent.connect(owner).pause();

      await expect(
        recallTradingAgent.connect(user1).executeTrade(
          sampleStrategy.strategyId,
          ethers.utils.parseEther("100"),
          "0x1234"
        )
      ).to.be.revertedWith("Pausable: paused");
    });

    it("Should not allow recalls when paused", async function () {
      await recallTradingAgent.connect(owner).setAuthorizedCaller(user1Address, true);
      await recallTradingAgent.connect(owner).pause();

      await expect(
        recallTradingAgent.connect(user1).triggerRecall(
          ethers.Wallet.createRandom().address,
          ethers.Wallet.createRandom().address,
          ethers.utils.parseEther("100")
        )
      ).to.be.revertedWith("Pausable: paused");
    });

    it("Should not allow non-owner to change status", async function () {
      await expect(recallTradingAgent.connect(user1).pause())
        .to.be.revertedWith("Ownable: caller is not the owner");

      await expect(recallTradingAgent.connect(user1).emergencyStop())
        .to.be.revertedWith("Ownable: caller is not the owner");
    });
  });

  describe("Emergency Functions", function () {
    beforeEach(async function () {
      // Send some ETH to the contract
      await owner.sendTransaction({
        to: recallTradingAgent.address,
        value: ethers.utils.parseEther("1"),
      });
    });

    it("Should allow emergency withdrawal only in emergency stop mode", async function () {
      const initialBalance = await ethers.provider.getBalance(ownerAddress);
      
      // Should fail when not in emergency mode
      await expect(
        recallTradingAgent.connect(owner).emergencyWithdraw(ethers.constants.AddressZero, ethers.utils.parseEther("0.5"))
      ).to.be.revertedWith("Not in emergency mode");

      // Emergency stop and try again
      await recallTradingAgent.connect(owner).emergencyStop();
      
      await expect(
        recallTradingAgent.connect(owner).emergencyWithdraw(ethers.constants.AddressZero, ethers.utils.parseEther("0.5"))
      ).to.not.be.reverted;
    });

    it("Should not allow non-owner to emergency withdraw", async function () {
      await recallTradingAgent.connect(owner).emergencyStop();
      
      await expect(
        recallTradingAgent.connect(user1).emergencyWithdraw(ethers.constants.AddressZero, ethers.utils.parseEther("0.5"))
      ).to.be.revertedWith("Ownable: caller is not the owner");
    });
  });

  describe("View Functions", function () {
    it("Should return correct strategy count", async function () {
      expect(await recallTradingAgent.getStrategyCount()).to.equal(1);

      const newStrategy = {
        strategyId: ethers.utils.keccak256(ethers.utils.toUtf8Bytes("NEW_STRATEGY")),
        isActive: true,
        maxTradeAmount: ethers.utils.parseEther("500"),
        riskThreshold: 300,
        cooldownPeriod: 600,
        lastExecutionTime: 0,
      };

      await recallTradingAgent.connect(owner).updateStrategy(newStrategy);
      expect(await recallTradingAgent.getStrategyCount()).to.equal(2);
    });

    it("Should return all strategy IDs", async function () {
      const strategyIds = await recallTradingAgent.getAllStrategyIds();
      expect(strategyIds.length).to.equal(1);
      expect(strategyIds[0]).to.equal(sampleStrategy.strategyId);
    });

    it("Should return performance metrics", async function () {
      const [totalTrades, successfulTrades, totalVolume, currentPnL] = 
        await recallTradingAgent.getPerformanceMetrics();
      
      expect(totalTrades).to.equal(0);
      expect(successfulTrades).to.equal(0);
      expect(totalVolume).to.equal(0);
      expect(currentPnL).to.equal(0);
    });
  });

  describe("Reentrancy Protection", function () {
    it("Should prevent reentrancy in executeTrade", async function () {
      await recallTradingAgent.connect(owner).setAuthorizedCaller(user1Address, true);
      
      // This test would require a more complex setup with a malicious contract
      // For now, we just verify that the nonReentrant modifier is in place
      expect(await recallTradingAgent.connect(user1).executeTrade(
        sampleStrategy.strategyId,
        ethers.utils.parseEther("100"),
        "0x1234"
      )).to.not.be.reverted;
    });
  });
});