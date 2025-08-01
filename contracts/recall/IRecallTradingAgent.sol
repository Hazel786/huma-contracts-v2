// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.23;

/**
 * @title IRecallTradingAgent
 * @notice Interface for the Recall Trading Agent that handles automated trading decisions
 * @dev This interface defines the core functionality for a trading agent that can:
 *      - Monitor market conditions
 *      - Execute trades based on predefined strategies
 *      - Manage risk parameters
 *      - Handle recall scenarios for credit positions
 */
interface IRecallTradingAgent {
    /**
     * @notice Emitted when a trading strategy is executed
     * @param agent The address of the trading agent
     * @param strategy The strategy identifier
     * @param amount The amount traded
     * @param success Whether the trade was successful
     */
    event TradeExecuted(
        address indexed agent,
        bytes32 indexed strategy,
        uint256 amount,
        bool success
    );

    /**
     * @notice Emitted when a recall is triggered
     * @param agent The address of the trading agent
     * @param creditPool The credit pool address
     * @param borrower The borrower address
     * @param recallAmount The amount being recalled
     */
    event RecallTriggered(
        address indexed agent,
        address indexed creditPool,
        address indexed borrower,
        uint256 recallAmount
    );

    /**
     * @notice Emitted when risk parameters are updated
     * @param agent The address of the trading agent
     * @param parameter The parameter name
     * @param oldValue The old parameter value
     * @param newValue The new parameter value
     */
    event RiskParameterUpdated(
        address indexed agent,
        string parameter,
        uint256 oldValue,
        uint256 newValue
    );

    /**
     * @notice Emitted when the agent's status changes
     * @param agent The address of the trading agent
     * @param oldStatus The old status
     * @param newStatus The new status
     */
    event AgentStatusChanged(
        address indexed agent,
        uint8 oldStatus,
        uint8 newStatus
    );

    /**
     * @notice Strategy configuration structure
     * @param strategyId Unique identifier for the strategy
     * @param isActive Whether the strategy is currently active
     * @param maxTradeAmount Maximum amount per trade
     * @param riskThreshold Risk threshold for the strategy
     * @param cooldownPeriod Minimum time between trades
     */
    struct TradingStrategy {
        bytes32 strategyId;
        bool isActive;
        uint256 maxTradeAmount;
        uint256 riskThreshold;
        uint256 cooldownPeriod;
        uint256 lastExecutionTime;
    }

    /**
     * @notice Risk management parameters
     * @param maxLeverage Maximum leverage allowed
     * @param stopLossThreshold Stop loss threshold percentage
     * @param maxDrawdown Maximum drawdown allowed
     * @param volatilityThreshold Volatility threshold for risk assessment
     */
    struct RiskParameters {
        uint256 maxLeverage;
        uint256 stopLossThreshold;
        uint256 maxDrawdown;
        uint256 volatilityThreshold;
    }

    /**
     * @notice Initialize the trading agent with initial parameters
     * @param owner The owner of the trading agent
     * @param initialStrategies Array of initial trading strategies
     * @param riskParams Initial risk parameters
     */
    function initialize(
        address owner,
        TradingStrategy[] calldata initialStrategies,
        RiskParameters calldata riskParams
    ) external;

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
    ) external returns (bool success);

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
    ) external returns (bool success);

    /**
     * @notice Add or update a trading strategy
     * @param strategy The strategy configuration
     */
    function updateStrategy(TradingStrategy calldata strategy) external;

    /**
     * @notice Remove a trading strategy
     * @param strategyId The strategy to remove
     */
    function removeStrategy(bytes32 strategyId) external;

    /**
     * @notice Update risk parameters
     * @param riskParams New risk parameters
     */
    function updateRiskParameters(RiskParameters calldata riskParams) external;

    /**
     * @notice Pause the trading agent
     */
    function pause() external;

    /**
     * @notice Unpause the trading agent
     */
    function unpause() external;

    /**
     * @notice Emergency stop all trading activities
     */
    function emergencyStop() external;

    /**
     * @notice Get the current status of the agent
     * @return status The current status (0: Active, 1: Paused, 2: Emergency Stop)
     */
    function getAgentStatus() external view returns (uint8 status);

    /**
     * @notice Get a trading strategy by ID
     * @param strategyId The strategy identifier
     * @return strategy The strategy configuration
     */
    function getStrategy(bytes32 strategyId)
        external
        view
        returns (TradingStrategy memory strategy);

    /**
     * @notice Get all active strategies
     * @return strategies Array of active strategies
     */
    function getActiveStrategies()
        external
        view
        returns (TradingStrategy[] memory strategies);

    /**
     * @notice Get current risk parameters
     * @return riskParams The current risk parameters
     */
    function getRiskParameters()
        external
        view
        returns (RiskParameters memory riskParams);

    /**
     * @notice Check if a trade can be executed based on risk parameters
     * @param strategyId The strategy to check
     * @param amount The trade amount
     * @return canExecute Whether the trade can be executed
     * @return reason Reason if trade cannot be executed
     */
    function canExecuteTrade(bytes32 strategyId, uint256 amount)
        external
        view
        returns (bool canExecute, string memory reason);

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
        returns (
            uint256 totalTrades,
            uint256 successfulTrades,
            uint256 totalVolume,
            int256 currentPnL
        );
}