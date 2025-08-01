// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.23;

import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title MockSOLPriceOracle
 * @notice Mock price oracle for testing SOL price drops and strategy execution
 * @dev This contract simulates a price oracle that can be manually updated for testing
 */
contract MockSOLPriceOracle is Ownable {
    // Price data structure
    struct PriceData {
        uint256 price;
        uint256 timestamp;
        bool isValid;
    }

    // Current price data
    PriceData public currentPrice;
    
    // Historical prices for testing
    mapping(uint256 => PriceData) public historicalPrices;
    uint256[] public priceTimestamps;
    
    // Events
    event PriceUpdated(uint256 indexed price, uint256 timestamp);
    event HistoricalPriceSet(uint256 indexed timestamp, uint256 price);

    // Constants
    uint256 public constant DECIMALS = 8; // Chainlink standard
    uint256 public constant MAX_PRICE_AGE = 3600; // 1 hour max age
    
    /**
     * @notice Constructor - sets initial SOL price
     */
    constructor() {
        // Set initial price to $100 SOL
        currentPrice = PriceData({
            price: 100 * 10**DECIMALS, // $100.00000000
            timestamp: block.timestamp,
            isValid: true
        });
        
        emit PriceUpdated(currentPrice.price, currentPrice.timestamp);
    }

    /**
     * @notice Get current SOL price
     * @return price Current SOL price in USD (8 decimals)
     * @return timestamp Price timestamp
     */
    function getSOLPrice() external view returns (uint256 price, uint256 timestamp) {
        require(currentPrice.isValid, "Invalid price data");
        require(block.timestamp - currentPrice.timestamp <= MAX_PRICE_AGE, "Price too stale");
        
        return (currentPrice.price, currentPrice.timestamp);
    }

    /**
     * @notice Get historical price at specific timestamp
     * @param timestamp Timestamp to get price for
     * @return price Historical price
     */
    function getHistoricalPrice(uint256 timestamp) external view returns (uint256 price) {
        PriceData memory historicalPrice = historicalPrices[timestamp];
        require(historicalPrice.isValid, "No price data for timestamp");
        
        return historicalPrice.price;
    }

    /**
     * @notice Update current SOL price (owner only)
     * @param newPrice New price in USD (8 decimals)
     */
    function updatePrice(uint256 newPrice) external onlyOwner {
        require(newPrice > 0, "Invalid price");
        
        // Store old price as historical
        if (currentPrice.isValid) {
            historicalPrices[currentPrice.timestamp] = currentPrice;
            priceTimestamps.push(currentPrice.timestamp);
        }
        
        // Update current price
        currentPrice = PriceData({
            price: newPrice,
            timestamp: block.timestamp,
            isValid: true
        });
        
        emit PriceUpdated(newPrice, block.timestamp);
    }

    /**
     * @notice Set historical price for testing (owner only)
     * @param timestamp Timestamp for the price
     * @param price Price at that timestamp
     */
    function setHistoricalPrice(uint256 timestamp, uint256 price) external onlyOwner {
        require(price > 0, "Invalid price");
        require(timestamp < block.timestamp, "Cannot set future price");
        
        historicalPrices[timestamp] = PriceData({
            price: price,
            timestamp: timestamp,
            isValid: true
        });
        
        // Add to timestamps array if not exists
        bool exists = false;
        for (uint256 i = 0; i < priceTimestamps.length; i++) {
            if (priceTimestamps[i] == timestamp) {
                exists = true;
                break;
            }
        }
        
        if (!exists) {
            priceTimestamps.push(timestamp);
        }
        
        emit HistoricalPriceSet(timestamp, price);
    }

    /**
     * @notice Simulate a price drop scenario for testing
     * @param dropPercentage Percentage drop (500 = 5%)
     */
    function simulatePriceDrop(uint256 dropPercentage) external onlyOwner {
        require(dropPercentage > 0 && dropPercentage <= 5000, "Invalid drop percentage"); // Max 50%
        
        uint256 newPrice = (currentPrice.price * (10000 - dropPercentage)) / 10000;
        updatePrice(newPrice);
        
        emit PriceUpdated(newPrice, block.timestamp);
    }

    /**
     * @notice Simulate price recovery for testing
     * @param recoveryPercentage Percentage recovery (500 = 5%)
     */
    function simulatePriceRecovery(uint256 recoveryPercentage) external onlyOwner {
        require(recoveryPercentage > 0 && recoveryPercentage <= 5000, "Invalid recovery percentage");
        
        uint256 newPrice = (currentPrice.price * (10000 + recoveryPercentage)) / 10000;
        updatePrice(newPrice);
        
        emit PriceUpdated(newPrice, block.timestamp);
    }

    /**
     * @notice Create a realistic price history for testing (1 hour of data)
     * @param startPrice Starting price
     * @param endPrice Ending price (should be 5%+ lower for drop detection)
     */
    function createPriceHistory(uint256 startPrice, uint256 endPrice) external onlyOwner {
        require(startPrice > 0 && endPrice > 0, "Invalid prices");
        require(endPrice < startPrice, "End price should be lower");
        
        uint256 currentTime = block.timestamp;
        uint256 hourAgo = currentTime - 3600; // 1 hour ago
        
        // Create 12 price points over 1 hour (every 5 minutes)
        uint256 priceStep = (startPrice - endPrice) / 12;
        uint256 timeStep = 300; // 5 minutes
        
        for (uint256 i = 0; i < 12; i++) {
            uint256 timestamp = hourAgo + (i * timeStep);
            uint256 price = startPrice - (i * priceStep);
            
            historicalPrices[timestamp] = PriceData({
                price: price,
                timestamp: timestamp,
                isValid: true
            });
            
            priceTimestamps.push(timestamp);
            emit HistoricalPriceSet(timestamp, price);
        }
        
        // Set current price to end price
        updatePrice(endPrice);
    }

    /**
     * @notice Get all historical timestamps
     * @return timestamps Array of all price timestamps
     */
    function getAllTimestamps() external view returns (uint256[] memory timestamps) {
        return priceTimestamps;
    }

    /**
     * @notice Get price data for multiple timestamps
     * @param timestamps Array of timestamps to get prices for
     * @return prices Array of prices
     * @return validFlags Array indicating if each price is valid
     */
    function getBatchPrices(uint256[] calldata timestamps) 
        external 
        view 
        returns (uint256[] memory prices, bool[] memory validFlags) 
    {
        prices = new uint256[](timestamps.length);
        validFlags = new bool[](timestamps.length);
        
        for (uint256 i = 0; i < timestamps.length; i++) {
            PriceData memory priceData = historicalPrices[timestamps[i]];
            prices[i] = priceData.price;
            validFlags[i] = priceData.isValid;
        }
        
        return (prices, validFlags);
    }

    /**
     * @notice Calculate percentage change between two prices
     * @param oldPrice Old price
     * @param newPrice New price
     * @return changePercentage Percentage change (negative for drops)
     */
    function calculatePriceChange(uint256 oldPrice, uint256 newPrice) 
        external 
        pure 
        returns (int256 changePercentage) 
    {
        require(oldPrice > 0, "Invalid old price");
        
        if (newPrice >= oldPrice) {
            changePercentage = int256(((newPrice - oldPrice) * 10000) / oldPrice);
        } else {
            changePercentage = -int256(((oldPrice - newPrice) * 10000) / oldPrice);
        }
        
        return changePercentage;
    }

    /**
     * @notice Check if price has dropped by threshold in time window
     * @param dropThreshold Minimum drop percentage (500 = 5%)
     * @param timeWindow Time window in seconds (3600 = 1 hour)
     * @return hasDropped Whether drop condition is met
     * @return actualDrop Actual drop percentage detected
     */
    function checkPriceDrop(uint256 dropThreshold, uint256 timeWindow) 
        external 
        view 
        returns (bool hasDropped, uint256 actualDrop) 
    {
        uint256 targetTime = block.timestamp - timeWindow;
        uint256 pastPrice = 0;
        
        // Find closest historical price to target time
        for (uint256 i = 0; i < priceTimestamps.length; i++) {
            uint256 timestamp = priceTimestamps[i];
            if (timestamp <= targetTime) {
                pastPrice = historicalPrices[timestamp].price;
            }
        }
        
        if (pastPrice == 0) {
            return (false, 0);
        }
        
        if (currentPrice.price >= pastPrice) {
            return (false, 0);
        }
        
        actualDrop = ((pastPrice - currentPrice.price) * 10000) / pastPrice;
        hasDropped = actualDrop >= dropThreshold;
        
        return (hasDropped, actualDrop);
    }

    /**
     * @notice Reset all price data (owner only)
     */
    function resetPriceData() external onlyOwner {
        // Clear historical prices
        for (uint256 i = 0; i < priceTimestamps.length; i++) {
            delete historicalPrices[priceTimestamps[i]];
        }
        delete priceTimestamps;
        
        // Reset current price
        currentPrice = PriceData({
            price: 100 * 10**DECIMALS, // Reset to $100
            timestamp: block.timestamp,
            isValid: true
        });
        
        emit PriceUpdated(currentPrice.price, currentPrice.timestamp);
    }
}