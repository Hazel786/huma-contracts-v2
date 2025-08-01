// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.23;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../IRecallTradingAgent.sol";

/**
 * @title SOLDropBuyStrategy
 * @notice Strategy that monitors SOL price and executes buy orders when price drops 5% in 1 hour
 * @dev This contract integrates with price oracles and DEXs to execute SOL purchases
 */
contract SOLDropBuyStrategy is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // Price tracking structure
    struct PricePoint {
        uint256 price;
        uint256 timestamp;
        bool isValid;
    }

    // Strategy configuration
    struct StrategyConfig {
        uint256 dropThreshold; // 500 = 5%
        uint256 timeWindow; // 3600 = 1 hour
        uint256 maxBuyAmount; // Maximum SOL to buy per trigger
        uint256 minBuyAmount; // Minimum SOL to buy
        uint256 cooldownPeriod; // Cooldown between purchases
        bool isActive;
    }

    // DEX integration structure
    struct DEXConfig {
        address router; // DEX router address
        address factory; // DEX factory address
        uint256 slippageTolerance; // 100 = 1%
        uint24 poolFee; // Uniswap V3 pool fee
        bool isEnabled;
    }

    // Events
    event SOLPriceUpdated(uint256 indexed price, uint256 timestamp);
    event DropDetected(uint256 oldPrice, uint256 newPrice, uint256 dropPercentage);
    event SOLPurchased(uint256 solAmount, uint256 usdcSpent, address indexed buyer);
    event StrategyConfigUpdated(StrategyConfig newConfig);
    event DEXConfigUpdated(string indexed dexName, DEXConfig newConfig);
    event EmergencyWithdrawal(address indexed token, uint256 amount);

    // State variables
    StrategyConfig public strategyConfig;
    mapping(string => DEXConfig) public dexConfigs; // "uniswap", "sushiswap", etc.
    
    // Price tracking
    PricePoint[] public priceHistory;
    mapping(uint256 => uint256) public hourlyPrices; // timestamp => price
    uint256 public lastPriceUpdate;
    uint256 public lastPurchaseTime;
    
    // Token addresses
    address public constant USDC = 0xA0b86a33E6441b6b7d7C3e3E8e2D1F6B7C6E8F9D; // Placeholder
    address public constant WSOL = 0xB0c87a34F7442b7e8C3f4E9f2A1B6C5D4E3F2A1B; // Wrapped SOL on Ethereum
    
    // Oracle integration
    address public priceOracle;
    
    // Constants
    uint256 public constant BASIS_POINTS = 10000;
    uint256 public constant PRICE_DECIMALS = 8; // Chainlink price decimals
    uint256 public constant MAX_PRICE_AGE = 300; // 5 minutes max price age
    uint256 public constant MAX_HISTORY_SIZE = 168; // 1 week of hourly prices

    // Interfaces
    interface IPriceOracle {
        function getSOLPrice() external view returns (uint256 price, uint256 timestamp);
        function getHistoricalPrice(uint256 timestamp) external view returns (uint256 price);
    }

    interface IUniswapV3Router {
        struct ExactInputSingleParams {
            address tokenIn;
            address tokenOut;
            uint24 fee;
            address recipient;
            uint256 deadline;
            uint256 amountIn;
            uint256 amountOutMinimum;
            uint160 sqrtPriceLimitX96;
        }
        
        function exactInputSingle(ExactInputSingleParams calldata params) external returns (uint256 amountOut);
    }

    interface IUniswapV2Router {
        function swapExactTokensForTokens(
            uint256 amountIn,
            uint256 amountOutMin,
            address[] calldata path,
            address recipient,
            uint256 deadline
        ) external returns (uint256[] memory amounts);
        
        function getAmountsOut(uint256 amountIn, address[] calldata path)
            external view returns (uint256[] memory amounts);
    }

    /**
     * @notice Constructor
     * @param _priceOracle Address of the price oracle contract
     */
    constructor(address _priceOracle) {
        require(_priceOracle != address(0), "Invalid oracle address");
        
        priceOracle = _priceOracle;
        
        // Set default strategy configuration
        strategyConfig = StrategyConfig({
            dropThreshold: 500, // 5%
            timeWindow: 3600, // 1 hour
            maxBuyAmount: 100 * 10**9, // 100 SOL (SOL has 9 decimals)
            minBuyAmount: 1 * 10**9, // 1 SOL
            cooldownPeriod: 1800, // 30 minutes
            isActive: true
        });
        
        // Initialize DEX configurations
        _initializeDEXConfigs();
    }

    /**
     * @notice Update strategy configuration
     * @param _config New strategy configuration
     */
    function updateStrategyConfig(StrategyConfig calldata _config) external onlyOwner {
        require(_config.dropThreshold > 0 && _config.dropThreshold <= 2000, "Invalid drop threshold"); // Max 20%
        require(_config.timeWindow >= 300 && _config.timeWindow <= 86400, "Invalid time window"); // 5 min to 24 hours
        require(_config.maxBuyAmount > _config.minBuyAmount, "Invalid buy amounts");
        require(_config.cooldownPeriod >= 300, "Cooldown too short"); // Min 5 minutes
        
        strategyConfig = _config;
        emit StrategyConfigUpdated(_config);
    }

    /**
     * @notice Update DEX configuration
     * @param dexName Name of the DEX ("uniswap", "sushiswap", etc.)
     * @param _config New DEX configuration
     */
    function updateDEXConfig(string calldata dexName, DEXConfig calldata _config) external onlyOwner {
        require(_config.router != address(0), "Invalid router address");
        require(_config.slippageTolerance <= 1000, "Slippage too high"); // Max 10%
        
        dexConfigs[dexName] = _config;
        emit DEXConfigUpdated(dexName, _config);
    }

    /**
     * @notice Update price oracle address
     * @param _newOracle New oracle address
     */
    function updatePriceOracle(address _newOracle) external onlyOwner {
        require(_newOracle != address(0), "Invalid oracle address");
        priceOracle = _newOracle;
    }

    /**
     * @notice Main function to check for price drops and execute buy if conditions are met
     * @return executed Whether a purchase was executed
     * @return solAmount Amount of SOL purchased
     */
    function checkAndExecuteBuy() external nonReentrant returns (bool executed, uint256 solAmount) {
        require(strategyConfig.isActive, "Strategy is not active");
        require(block.timestamp >= lastPurchaseTime + strategyConfig.cooldownPeriod, "Still in cooldown");
        
        // Update current price
        _updatePrice();
        
        // Check for price drop
        (bool dropDetected, uint256 dropPercentage, uint256 currentPrice) = _checkPriceDrop();
        
        if (!dropDetected) {
            return (false, 0);
        }
        
        // Calculate buy amount based on drop severity
        uint256 buyAmount = _calculateBuyAmount(dropPercentage);
        
        if (buyAmount < strategyConfig.minBuyAmount) {
            return (false, 0);
        }
        
        // Execute the purchase
        solAmount = _executeBuy(buyAmount);
        
        if (solAmount > 0) {
            lastPurchaseTime = block.timestamp;
            executed = true;
            
            emit SOLPurchased(solAmount, buyAmount, msg.sender);
        }
        
        return (executed, solAmount);
    }

    /**
     * @notice Manual price update function
     */
    function updatePrice() external {
        _updatePrice();
    }

    /**
     * @notice Get current SOL price from oracle
     * @return price Current SOL price in USD (8 decimals)
     * @return timestamp Price timestamp
     */
    function getCurrentPrice() external view returns (uint256 price, uint256 timestamp) {
        return IPriceOracle(priceOracle).getSOLPrice();
    }

    /**
     * @notice Check if conditions are met for a buy
     * @return canBuy Whether conditions are met
     * @return reason Reason if cannot buy
     * @return dropPercentage Current drop percentage
     */
    function canExecuteBuy() external view returns (bool canBuy, string memory reason, uint256 dropPercentage) {
        if (!strategyConfig.isActive) {
            return (false, "Strategy inactive", 0);
        }
        
        if (block.timestamp < lastPurchaseTime + strategyConfig.cooldownPeriod) {
            return (false, "In cooldown period", 0);
        }
        
        (bool dropDetected, uint256 drop,) = _checkPriceDrop();
        
        if (!dropDetected) {
            return (false, "No significant drop detected", drop);
        }
        
        uint256 usdcBalance = IERC20(USDC).balanceOf(address(this));
        if (usdcBalance < strategyConfig.minBuyAmount) {
            return (false, "Insufficient USDC balance", drop);
        }
        
        return (true, "", drop);
    }

    /**
     * @notice Get price history for analysis
     * @param lookbackHours Number of hours to look back
     * @return prices Array of price points
     * @return timestamps Array of timestamps
     */
    function getPriceHistory(uint256 lookbackHours) external view returns (uint256[] memory prices, uint256[] memory timestamps) {
        require(lookbackHours <= MAX_HISTORY_SIZE, "Lookback too long");
        
        uint256 currentHour = block.timestamp / 3600;
        uint256 startHour = currentHour - lookbackHours;
        
        prices = new uint256[](lookbackHours);
        timestamps = new uint256[](lookbackHours);
        
        for (uint256 i = 0; i < lookbackHours; i++) {
            uint256 hour = startHour + i;
            prices[i] = hourlyPrices[hour];
            timestamps[i] = hour * 3600;
        }
        
        return (prices, timestamps);
    }

    /**
     * @notice Get strategy statistics
     * @return stats Strategy performance statistics
     */
    function getStrategyStats() external view returns (
        uint256 totalPurchases,
        uint256 totalSOLBought,
        uint256 totalUSDCSpent,
        uint256 lastPurchaseTimestamp,
        uint256 averagePurchaseSize
    ) {
        // This would be implemented with additional state tracking
        // For now, returning placeholder values
        return (0, 0, 0, lastPurchaseTime, 0);
    }

    /**
     * @notice Emergency withdrawal function
     * @param token Token to withdraw (address(0) for ETH)
     * @param amount Amount to withdraw
     */
    function emergencyWithdraw(address token, uint256 amount) external onlyOwner {
        if (token == address(0)) {
            payable(owner()).transfer(amount);
        } else {
            IERC20(token).safeTransfer(owner(), amount);
        }
        
        emit EmergencyWithdrawal(token, amount);
    }

    // Internal functions

    /**
     * @notice Update current price from oracle
     */
    function _updatePrice() internal {
        (uint256 price, uint256 timestamp) = IPriceOracle(priceOracle).getSOLPrice();
        
        require(block.timestamp - timestamp <= MAX_PRICE_AGE, "Price too stale");
        require(price > 0, "Invalid price");
        
        // Store hourly price
        uint256 currentHour = block.timestamp / 3600;
        hourlyPrices[currentHour] = price;
        
        // Add to price history
        priceHistory.push(PricePoint({
            price: price,
            timestamp: timestamp,
            isValid: true
        }));
        
        // Limit history size
        if (priceHistory.length > MAX_HISTORY_SIZE) {
            // Remove oldest entries (simplified approach)
            for (uint256 i = 0; i < priceHistory.length - MAX_HISTORY_SIZE; i++) {
                priceHistory[i] = priceHistory[i + 1];
            }
            priceHistory.pop();
        }
        
        lastPriceUpdate = timestamp;
        emit SOLPriceUpdated(price, timestamp);
    }

    /**
     * @notice Check if price has dropped by threshold in time window
     * @return dropDetected Whether a significant drop was detected
     * @return dropPercentage Percentage drop detected
     * @return currentPrice Current SOL price
     */
    function _checkPriceDrop() internal view returns (bool dropDetected, uint256 dropPercentage, uint256 currentPrice) {
        if (priceHistory.length == 0) {
            return (false, 0, 0);
        }
        
        currentPrice = priceHistory[priceHistory.length - 1].price;
        uint256 currentTime = block.timestamp;
        uint256 targetTime = currentTime - strategyConfig.timeWindow;
        
        // Find price from timeWindow ago
        uint256 pastPrice = 0;
        for (uint256 i = priceHistory.length; i > 0; i--) {
            if (priceHistory[i - 1].timestamp <= targetTime) {
                pastPrice = priceHistory[i - 1].price;
                break;
            }
        }
        
        if (pastPrice == 0) {
            return (false, 0, currentPrice);
        }
        
        // Calculate drop percentage
        if (currentPrice >= pastPrice) {
            return (false, 0, currentPrice);
        }
        
        dropPercentage = ((pastPrice - currentPrice) * BASIS_POINTS) / pastPrice;
        dropDetected = dropPercentage >= strategyConfig.dropThreshold;
        
        if (dropDetected) {
            emit DropDetected(pastPrice, currentPrice, dropPercentage);
        }
        
        return (dropDetected, dropPercentage, currentPrice);
    }

    /**
     * @notice Calculate buy amount based on drop severity
     * @param dropPercentage Percentage drop detected
     * @return buyAmount USDC amount to spend on SOL
     */
    function _calculateBuyAmount(uint256 dropPercentage) internal view returns (uint256 buyAmount) {
        // Base amount increases with drop severity
        uint256 baseAmount = strategyConfig.minBuyAmount;
        uint256 multiplier = (dropPercentage * 100) / strategyConfig.dropThreshold; // 100 = 1x multiplier
        
        buyAmount = (baseAmount * (100 + multiplier)) / 100;
        
        // Cap at maximum
        if (buyAmount > strategyConfig.maxBuyAmount) {
            buyAmount = strategyConfig.maxBuyAmount;
        }
        
        // Ensure we have enough USDC
        uint256 usdcBalance = IERC20(USDC).balanceOf(address(this));
        if (buyAmount > usdcBalance) {
            buyAmount = usdcBalance;
        }
        
        return buyAmount;
    }

    /**
     * @notice Execute SOL purchase through DEX
     * @param usdcAmount Amount of USDC to spend
     * @return solReceived Amount of SOL received
     */
    function _executeBuy(uint256 usdcAmount) internal returns (uint256 solReceived) {
        require(usdcAmount > 0, "Invalid buy amount");
        
        // Try Uniswap V3 first, then V2, then SushiSwap
        solReceived = _tryUniswapV3Buy(usdcAmount);
        
        if (solReceived == 0) {
            solReceived = _tryUniswapV2Buy(usdcAmount);
        }
        
        if (solReceived == 0) {
            solReceived = _trySushiSwapBuy(usdcAmount);
        }
        
        require(solReceived > 0, "All DEX purchases failed");
        
        return solReceived;
    }

    /**
     * @notice Try to buy SOL through Uniswap V3
     * @param usdcAmount Amount of USDC to spend
     * @return solReceived Amount of SOL received (0 if failed)
     */
    function _tryUniswapV3Buy(uint256 usdcAmount) internal returns (uint256 solReceived) {
        DEXConfig memory config = dexConfigs["uniswap_v3"];
        if (!config.isEnabled) return 0;
        
        try {
            IERC20(USDC).safeApprove(config.router, usdcAmount);
            
            IUniswapV3Router.ExactInputSingleParams memory params = IUniswapV3Router.ExactInputSingleParams({
                tokenIn: USDC,
                tokenOut: WSOL,
                fee: config.poolFee,
                recipient: address(this),
                deadline: block.timestamp + 300, // 5 minutes
                amountIn: usdcAmount,
                amountOutMinimum: _calculateMinimumOut(usdcAmount, config.slippageTolerance),
                sqrtPriceLimitX96: 0
            });
            
            solReceived = IUniswapV3Router(config.router).exactInputSingle(params);
        } catch {
            solReceived = 0;
        }
        
        return solReceived;
    }

    /**
     * @notice Try to buy SOL through Uniswap V2
     * @param usdcAmount Amount of USDC to spend
     * @return solReceived Amount of SOL received (0 if failed)
     */
    function _tryUniswapV2Buy(uint256 usdcAmount) internal returns (uint256 solReceived) {
        DEXConfig memory config = dexConfigs["uniswap_v2"];
        if (!config.isEnabled) return 0;
        
        try {
            IERC20(USDC).safeApprove(config.router, usdcAmount);
            
            address[] memory path = new address[](2);
            path[0] = USDC;
            path[1] = WSOL;
            
            uint256[] memory amounts = IUniswapV2Router(config.router).swapExactTokensForTokens(
                usdcAmount,
                _calculateMinimumOut(usdcAmount, config.slippageTolerance),
                path,
                address(this),
                block.timestamp + 300
            );
            
            solReceived = amounts[1];
        } catch {
            solReceived = 0;
        }
        
        return solReceived;
    }

    /**
     * @notice Try to buy SOL through SushiSwap
     * @param usdcAmount Amount of USDC to spend
     * @return solReceived Amount of SOL received (0 if failed)
     */
    function _trySushiSwapBuy(uint256 usdcAmount) internal returns (uint256 solReceived) {
        DEXConfig memory config = dexConfigs["sushiswap"];
        if (!config.isEnabled) return 0;
        
        // Similar implementation to Uniswap V2
        try {
            IERC20(USDC).safeApprove(config.router, usdcAmount);
            
            address[] memory path = new address[](2);
            path[0] = USDC;
            path[1] = WSOL;
            
            uint256[] memory amounts = IUniswapV2Router(config.router).swapExactTokensForTokens(
                usdcAmount,
                _calculateMinimumOut(usdcAmount, config.slippageTolerance),
                path,
                address(this),
                block.timestamp + 300
            );
            
            solReceived = amounts[1];
        } catch {
            solReceived = 0;
        }
        
        return solReceived;
    }

    /**
     * @notice Calculate minimum output amount considering slippage
     * @param inputAmount Input amount
     * @param slippageTolerance Slippage tolerance in basis points
     * @return minimumOut Minimum output amount
     */
    function _calculateMinimumOut(uint256 inputAmount, uint256 slippageTolerance) internal pure returns (uint256 minimumOut) {
        // This is a simplified calculation - in production, you'd get expected output from DEX
        // and apply slippage tolerance to that
        minimumOut = (inputAmount * (BASIS_POINTS - slippageTolerance)) / BASIS_POINTS;
        return minimumOut;
    }

    /**
     * @notice Initialize default DEX configurations
     */
    function _initializeDEXConfigs() internal {
        // Uniswap V3
        dexConfigs["uniswap_v3"] = DEXConfig({
            router: 0xE592427A0AEce92De3Edee1F18E0157C05861564, // Uniswap V3 Router
            factory: 0x1F98431c8aD98523631AE4a59f267346ea31F984, // Uniswap V3 Factory
            slippageTolerance: 200, // 2%
            poolFee: 3000, // 0.3%
            isEnabled: true
        });
        
        // Uniswap V2
        dexConfigs["uniswap_v2"] = DEXConfig({
            router: 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D, // Uniswap V2 Router
            factory: 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f, // Uniswap V2 Factory
            slippageTolerance: 300, // 3%
            poolFee: 0, // Not applicable for V2
            isEnabled: true
        });
        
        // SushiSwap
        dexConfigs["sushiswap"] = DEXConfig({
            router: 0xd9e1cE17f2641f24aE83637ab66a2cca9C378B9F, // SushiSwap Router
            factory: 0xC0AEe478e3658e2610c5F7A4A2E1777cE9e4f2Ac, // SushiSwap Factory
            slippageTolerance: 300, // 3%
            poolFee: 0, // Not applicable
            isEnabled: true
        });
    }

    /**
     * @notice Receive function to accept ETH
     */
    receive() external payable {}
}