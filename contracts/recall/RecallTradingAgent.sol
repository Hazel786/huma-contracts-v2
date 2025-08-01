// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.23;

import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./IRecallTradingAgent.sol";

/**
 * @title RecallTradingAgent
 * @notice Automated trading agent that can execute trading strategies and handle credit recalls
 * @dev This contract implements sophisticated trading logic with risk management and recall capabilities
 */
contract RecallTradingAgent is
    IRecallTradingAgent,
    Initializable,
    OwnableUpgradeable,
    PausableUpgradeable,
    ReentrancyGuardUpgradeable
{
    using SafeERC20 for IERC20;

    // Agent status enumeration
    enum AgentStatus {
        Active,
        Paused,
        EmergencyStop
    }

    // Performance tracking structure
    struct PerformanceMetrics {
        uint256 totalTrades;
        uint256 successfulTrades;
        uint256 totalVolume;
        int256 currentPnL;
        uint256 lastUpdateTime;
    }

    // State variables
    AgentStatus public agentStatus;
    RiskParameters public riskParameters;
    PerformanceMetrics public performanceMetrics;
    
    // Mappings
    mapping(bytes32 => TradingStrategy) public strategies;
    mapping(address => bool) public authorizedCallers;
    mapping(address => mapping(address => uint256)) public creditPoolRecalls;
    
    // Arrays for iteration
    bytes32[] public strategyIds;
    
    // Constants
    uint256 public constant MAX_STRATEGIES = 50;
    uint256 public constant BASIS_POINTS = 10000;
    uint256 public constant MAX_LEVERAGE = 1000; // 10x leverage max
    
    // Events (additional to interface events)
    event AuthorizedCallerUpdated(address indexed caller, bool authorized);
    event PerformanceUpdated(uint256 totalTrades, int256 currentPnL);

    /**
     * @notice Contract initialization
     * @param owner The owner of the trading agent
     * @param initialStrategies Array of initial trading strategies
     * @param riskParams Initial risk parameters
     */
    function initialize(
        address owner,
        TradingStrategy[] calldata initialStrategies,
        RiskParameters calldata riskParams
    ) external override initializer {
        require(owner != address(0), "Invalid owner address");
        require(initialStrategies.length <= MAX_STRATEGIES, "Too many strategies");
        
        __Ownable_init();
        __Pausable_init();
        __ReentrancyGuard_init();
        
        _transferOwnership(owner);
        agentStatus = AgentStatus.Active;
        
        // Set initial risk parameters
        _updateRiskParameters(riskParams);
        
        // Add initial strategies
        for (uint256 i = 0; i < initialStrategies.length; i++) {
            _addStrategy(initialStrategies[i]);
        }
        
        // Initialize performance metrics
        performanceMetrics.lastUpdateTime = block.timestamp;
    }

    /**
     * @notice Execute a trading strategy
     * @param strategyId The strategy to execute
     * @param amount The amount to trade
     * @param data Additional data for the trade
     * @return success Whether the trade was successful
     */
    function executeTrade(
        bytes32 strategyId,
        uint256 amount,
        bytes calldata data
    ) external override nonReentrant whenNotPaused returns (bool success) {
        require(agentStatus == AgentStatus.Active, "Agent not active");
        require(authorizedCallers[msg.sender] || msg.sender == owner(), "Unauthorized caller");
        
        TradingStrategy storage strategy = strategies[strategyId];
        require(strategy.isActive, "Strategy not active");
        require(amount > 0, "Invalid amount");
        require(amount <= strategy.maxTradeAmount, "Amount exceeds strategy limit");
        
        // Check cooldown period
        require(
            block.timestamp >= strategy.lastExecutionTime + strategy.cooldownPeriod,
            "Strategy in cooldown"
        );
        
        // Risk checks
        (bool canExecute, string memory reason) = canExecuteTrade(strategyId, amount);
        require(canExecute, reason);
        
        // Execute the trade (placeholder for actual trading logic)
        success = _executeTrade(strategyId, amount, data);
        
        // Update strategy timing
        strategy.lastExecutionTime = block.timestamp;
        
        // Update performance metrics
        _updatePerformanceMetrics(amount, success);
        
        emit TradeExecuted(address(this), strategyId, amount, success);
        
        return success;
    }

    /**
     * @notice Trigger a recall on a credit position
     * @param creditPool The credit pool address
     * @param borrower The borrower address
     * @param recallAmount The amount to recall
     * @return success Whether the recall was successful
     */
    function triggerRecall(
        address creditPool,
        address borrower,
        uint256 recallAmount
    ) external override nonReentrant whenNotPaused returns (bool success) {
        require(agentStatus == AgentStatus.Active, "Agent not active");
        require(authorizedCallers[msg.sender] || msg.sender == owner(), "Unauthorized caller");
        require(creditPool != address(0), "Invalid credit pool");
        require(borrower != address(0), "Invalid borrower");
        require(recallAmount > 0, "Invalid recall amount");
        
        // Execute recall logic (placeholder for actual recall implementation)
        success = _executeRecall(creditPool, borrower, recallAmount);
        
        if (success) {
            creditPoolRecalls[creditPool][borrower] += recallAmount;
        }
        
        emit RecallTriggered(address(this), creditPool, borrower, recallAmount);
        
        return success;
    }

    /**
     * @notice Add or update a trading strategy
     * @param strategy The strategy configuration
     */
    function updateStrategy(TradingStrategy calldata strategy) external override onlyOwner {
        require(strategy.strategyId != bytes32(0), "Invalid strategy ID");
        require(strategy.maxTradeAmount > 0, "Invalid max trade amount");
        require(strategy.riskThreshold <= BASIS_POINTS, "Invalid risk threshold");
        
        if (strategies[strategy.strategyId].strategyId == bytes32(0)) {
            // New strategy
            require(strategyIds.length < MAX_STRATEGIES, "Too many strategies");
            strategyIds.push(strategy.strategyId);
        }
        
        strategies[strategy.strategyId] = strategy;
    }

    /**
     * @notice Remove a trading strategy
     * @param strategyId The strategy to remove
     */
    function removeStrategy(bytes32 strategyId) external override onlyOwner {
        require(strategies[strategyId].strategyId != bytes32(0), "Strategy not found");
        
        delete strategies[strategyId];
        
        // Remove from array
        for (uint256 i = 0; i < strategyIds.length; i++) {
            if (strategyIds[i] == strategyId) {
                strategyIds[i] = strategyIds[strategyIds.length - 1];
                strategyIds.pop();
                break;
            }
        }
    }

    /**
     * @notice Update risk parameters
     * @param riskParams New risk parameters
     */
    function updateRiskParameters(RiskParameters calldata riskParams) external override onlyOwner {
        _updateRiskParameters(riskParams);
    }

    /**
     * @notice Pause the trading agent
     */
    function pause() external override onlyOwner {
        AgentStatus oldStatus = agentStatus;
        agentStatus = AgentStatus.Paused;
        _pause();
        emit AgentStatusChanged(address(this), uint8(oldStatus), uint8(agentStatus));
    }

    /**
     * @notice Unpause the trading agent
     */
    function unpause() external override onlyOwner {
        AgentStatus oldStatus = agentStatus;
        agentStatus = AgentStatus.Active;
        _unpause();
        emit AgentStatusChanged(address(this), uint8(oldStatus), uint8(agentStatus));
    }

    /**
     * @notice Emergency stop all trading activities
     */
    function emergencyStop() external override onlyOwner {
        AgentStatus oldStatus = agentStatus;
        agentStatus = AgentStatus.EmergencyStop;
        _pause();
        emit AgentStatusChanged(address(this), uint8(oldStatus), uint8(agentStatus));
    }

    /**
     * @notice Set authorized caller status
     * @param caller The caller address
     * @param authorized Whether the caller is authorized
     */
    function setAuthorizedCaller(address caller, bool authorized) external onlyOwner {
        require(caller != address(0), "Invalid caller address");
        authorizedCallers[caller] = authorized;
        emit AuthorizedCallerUpdated(caller, authorized);
    }

    // View functions

    /**
     * @notice Get the current status of the agent
     * @return status The current status
     */
    function getAgentStatus() external view override returns (uint8 status) {
        return uint8(agentStatus);
    }

    /**
     * @notice Get a trading strategy by ID
     * @param strategyId The strategy identifier
     * @return strategy The strategy configuration
     */
    function getStrategy(bytes32 strategyId)
        external
        view
        override
        returns (TradingStrategy memory strategy)
    {
        return strategies[strategyId];
    }

    /**
     * @notice Get all active strategies
     * @return activeStrategies Array of active strategies
     */
    function getActiveStrategies()
        external
        view
        override
        returns (TradingStrategy[] memory activeStrategies)
    {
        uint256 activeCount = 0;
        
        // Count active strategies
        for (uint256 i = 0; i < strategyIds.length; i++) {
            if (strategies[strategyIds[i]].isActive) {
                activeCount++;
            }
        }
        
        // Build active strategies array
        activeStrategies = new TradingStrategy[](activeCount);
        uint256 index = 0;
        
        for (uint256 i = 0; i < strategyIds.length; i++) {
            if (strategies[strategyIds[i]].isActive) {
                activeStrategies[index] = strategies[strategyIds[i]];
                index++;
            }
        }
        
        return activeStrategies;
    }

    /**
     * @notice Get current risk parameters
     * @return riskParams The current risk parameters
     */
    function getRiskParameters()
        external
        view
        override
        returns (RiskParameters memory riskParams)
    {
        return riskParameters;
    }

    /**
     * @notice Check if a trade can be executed based on risk parameters
     * @param strategyId The strategy to check
     * @param amount The trade amount
     * @return canExecute Whether the trade can be executed
     * @return reason Reason if trade cannot be executed
     */
    function canExecuteTrade(bytes32 strategyId, uint256 amount)
        public
        view
        override
        returns (bool canExecute, string memory reason)
    {
        TradingStrategy memory strategy = strategies[strategyId];
        
        if (!strategy.isActive) {
            return (false, "Strategy not active");
        }
        
        if (amount > strategy.maxTradeAmount) {
            return (false, "Amount exceeds strategy limit");
        }
        
        if (block.timestamp < strategy.lastExecutionTime + strategy.cooldownPeriod) {
            return (false, "Strategy in cooldown");
        }
        
        // Additional risk checks can be added here
        // For example: portfolio exposure, volatility checks, etc.
        
        return (true, "");
    }

    /**
     * @notice Get the agent's performance metrics
     * @return totalTrades Total number of trades executed
     * @return successfulTrades Number of successful trades
     * @return totalVolume Total trading volume
     * @return currentPnL Current profit and loss
     */
    function getPerformanceMetrics()
        external
        view
        override
        returns (
            uint256 totalTrades,
            uint256 successfulTrades,
            uint256 totalVolume,
            int256 currentPnL
        )
    {
        PerformanceMetrics memory metrics = performanceMetrics;
        return (
            metrics.totalTrades,
            metrics.successfulTrades,
            metrics.totalVolume,
            metrics.currentPnL
        );
    }

    /**
     * @notice Get total number of strategies
     * @return count Number of strategies
     */
    function getStrategyCount() external view returns (uint256 count) {
        return strategyIds.length;
    }

    /**
     * @notice Get all strategy IDs
     * @return ids Array of strategy IDs
     */
    function getAllStrategyIds() external view returns (bytes32[] memory ids) {
        return strategyIds;
    }

    // Internal functions

    /**
     * @notice Internal function to add a strategy
     * @param strategy The strategy to add
     */
    function _addStrategy(TradingStrategy calldata strategy) internal {
        require(strategy.strategyId != bytes32(0), "Invalid strategy ID");
        require(strategy.maxTradeAmount > 0, "Invalid max trade amount");
        require(strategy.riskThreshold <= BASIS_POINTS, "Invalid risk threshold");
        
        strategies[strategy.strategyId] = strategy;
        strategyIds.push(strategy.strategyId);
    }

    /**
     * @notice Internal function to update risk parameters
     * @param riskParams New risk parameters
     */
    function _updateRiskParameters(RiskParameters calldata riskParams) internal {
        require(riskParams.maxLeverage <= MAX_LEVERAGE, "Leverage too high");
        require(riskParams.stopLossThreshold <= BASIS_POINTS, "Invalid stop loss");
        require(riskParams.maxDrawdown <= BASIS_POINTS, "Invalid max drawdown");
        
        RiskParameters memory oldParams = riskParameters;
        riskParameters = riskParams;
        
        // Emit events for each parameter change
        if (oldParams.maxLeverage != riskParams.maxLeverage) {
            emit RiskParameterUpdated(
                address(this),
                "maxLeverage",
                oldParams.maxLeverage,
                riskParams.maxLeverage
            );
        }
        
        if (oldParams.stopLossThreshold != riskParams.stopLossThreshold) {
            emit RiskParameterUpdated(
                address(this),
                "stopLossThreshold",
                oldParams.stopLossThreshold,
                riskParams.stopLossThreshold
            );
        }
        
        if (oldParams.maxDrawdown != riskParams.maxDrawdown) {
            emit RiskParameterUpdated(
                address(this),
                "maxDrawdown",
                oldParams.maxDrawdown,
                riskParams.maxDrawdown
            );
        }
        
        if (oldParams.volatilityThreshold != riskParams.volatilityThreshold) {
            emit RiskParameterUpdated(
                address(this),
                "volatilityThreshold",
                oldParams.volatilityThreshold,
                riskParams.volatilityThreshold
            );
        }
    }

    /**
     * @notice Internal function to execute a trade (placeholder)
     * @param strategyId The strategy ID
     * @param amount The trade amount
     * @param data Additional trade data
     * @return success Whether the trade was successful
     */
    function _executeTrade(
        bytes32 strategyId,
        uint256 amount,
        bytes calldata data
    ) internal returns (bool success) {
        // Placeholder for actual trading logic
        // This would integrate with DEXs, lending protocols, etc.
        
        // For now, return success based on some basic logic
        // In a real implementation, this would:
        // 1. Validate trade parameters
        // 2. Execute the trade on external protocols
        // 3. Handle slippage and errors
        // 4. Update internal accounting
        
        return true; // Placeholder
    }

    /**
     * @notice Internal function to execute a recall (placeholder)
     * @param creditPool The credit pool address
     * @param borrower The borrower address
     * @param recallAmount The recall amount
     * @return success Whether the recall was successful
     */
    function _executeRecall(
        address creditPool,
        address borrower,
        uint256 recallAmount
    ) internal returns (bool success) {
        // Placeholder for actual recall logic
        // This would integrate with Huma's credit protocols
        
        // In a real implementation, this would:
        // 1. Validate recall conditions
        // 2. Call the credit pool's recall function
        // 3. Handle partial recalls
        // 4. Update tracking data
        
        return true; // Placeholder
    }

    /**
     * @notice Internal function to update performance metrics
     * @param amount The trade amount
     * @param success Whether the trade was successful
     */
    function _updatePerformanceMetrics(uint256 amount, bool success) internal {
        performanceMetrics.totalTrades++;
        performanceMetrics.totalVolume += amount;
        
        if (success) {
            performanceMetrics.successfulTrades++;
        }
        
        performanceMetrics.lastUpdateTime = block.timestamp;
        
        emit PerformanceUpdated(
            performanceMetrics.totalTrades,
            performanceMetrics.currentPnL
        );
    }

    /**
     * @notice Emergency withdrawal function for owner
     * @param token The token to withdraw
     * @param amount The amount to withdraw
     */
    function emergencyWithdraw(address token, uint256 amount) external onlyOwner {
        require(agentStatus == AgentStatus.EmergencyStop, "Not in emergency mode");
        
        if (token == address(0)) {
            // Withdraw ETH
            payable(owner()).transfer(amount);
        } else {
            // Withdraw ERC20 token
            IERC20(token).safeTransfer(owner(), amount);
        }
    }

    /**
     * @notice Receive function to accept ETH
     */
    receive() external payable {}
}