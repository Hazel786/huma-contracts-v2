// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.23;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";
import "./RecallTradingAgent.sol";
import "./IRecallTradingAgent.sol";

/**
 * @title RecallTradingAgentFactory
 * @notice Factory contract for deploying and managing RecallTradingAgent instances
 * @dev Uses minimal proxy pattern for gas-efficient deployment of trading agents
 */
contract RecallTradingAgentFactory is Ownable, Pausable {
    using Clones for address;

    // Events
    event AgentDeployed(
        address indexed agent,
        address indexed owner,
        bytes32 indexed agentId,
        uint256 strategiesCount
    );
    
    event ImplementationUpdated(
        address indexed oldImplementation,
        address indexed newImplementation
    );
    
    event AgentRegistered(address indexed agent, bytes32 indexed agentId);
    event AgentDeregistered(address indexed agent, bytes32 indexed agentId);

    // State variables
    address public implementation;
    uint256 public totalAgents;
    uint256 public deploymentFee;
    address public feeRecipient;
    
    // Mappings
    mapping(bytes32 => address) public agents; // agentId => agent address
    mapping(address => bytes32) public agentIds; // agent address => agentId
    mapping(address => bool) public isRegisteredAgent;
    mapping(address => address[]) public ownerAgents; // owner => agent addresses
    
    // Arrays for iteration
    address[] public allAgents;
    bytes32[] public allAgentIds;

    // Constants
    uint256 public constant MAX_DEPLOYMENT_FEE = 1 ether;
    uint256 public constant MAX_STRATEGIES_PER_AGENT = 50;

    /**
     * @notice Constructor
     * @param _implementation Address of the RecallTradingAgent implementation
     * @param _deploymentFee Fee required to deploy a new agent
     * @param _feeRecipient Address to receive deployment fees
     */
    constructor(
        address _implementation,
        uint256 _deploymentFee,
        address _feeRecipient
    ) {
        require(_implementation != address(0), "Invalid implementation");
        require(_deploymentFee <= MAX_DEPLOYMENT_FEE, "Fee too high");
        require(_feeRecipient != address(0), "Invalid fee recipient");
        
        implementation = _implementation;
        deploymentFee = _deploymentFee;
        feeRecipient = _feeRecipient;
    }

    /**
     * @notice Deploy a new RecallTradingAgent
     * @param agentId Unique identifier for the agent
     * @param owner Owner of the new agent
     * @param initialStrategies Initial trading strategies
     * @param riskParams Initial risk parameters
     * @return agent Address of the deployed agent
     */
    function deployAgent(
        bytes32 agentId,
        address owner,
        IRecallTradingAgent.TradingStrategy[] calldata initialStrategies,
        IRecallTradingAgent.RiskParameters calldata riskParams
    ) external payable whenNotPaused returns (address agent) {
        require(agentId != bytes32(0), "Invalid agent ID");
        require(owner != address(0), "Invalid owner");
        require(agents[agentId] == address(0), "Agent ID already exists");
        require(initialStrategies.length <= MAX_STRATEGIES_PER_AGENT, "Too many strategies");
        require(msg.value >= deploymentFee, "Insufficient deployment fee");
        
        // Deploy minimal proxy
        agent = implementation.clone();
        
        // Initialize the agent
        RecallTradingAgent(agent).initialize(owner, initialStrategies, riskParams);
        
        // Register the agent
        _registerAgent(agent, agentId, owner);
        
        // Transfer deployment fee
        if (deploymentFee > 0) {
            payable(feeRecipient).transfer(deploymentFee);
        }
        
        // Refund excess payment
        if (msg.value > deploymentFee) {
            payable(msg.sender).transfer(msg.value - deploymentFee);
        }
        
        emit AgentDeployed(agent, owner, agentId, initialStrategies.length);
        
        return agent;
    }

    /**
     * @notice Deploy an agent with salt for deterministic address
     * @param agentId Unique identifier for the agent
     * @param owner Owner of the new agent
     * @param initialStrategies Initial trading strategies
     * @param riskParams Initial risk parameters
     * @param salt Salt for deterministic deployment
     * @return agent Address of the deployed agent
     */
    function deployAgentDeterministic(
        bytes32 agentId,
        address owner,
        IRecallTradingAgent.TradingStrategy[] calldata initialStrategies,
        IRecallTradingAgent.RiskParameters calldata riskParams,
        bytes32 salt
    ) external payable whenNotPaused returns (address agent) {
        require(agentId != bytes32(0), "Invalid agent ID");
        require(owner != address(0), "Invalid owner");
        require(agents[agentId] == address(0), "Agent ID already exists");
        require(initialStrategies.length <= MAX_STRATEGIES_PER_AGENT, "Too many strategies");
        require(msg.value >= deploymentFee, "Insufficient deployment fee");
        
        // Deploy minimal proxy with salt
        agent = implementation.cloneDeterministic(salt);
        
        // Initialize the agent
        RecallTradingAgent(agent).initialize(owner, initialStrategies, riskParams);
        
        // Register the agent
        _registerAgent(agent, agentId, owner);
        
        // Transfer deployment fee
        if (deploymentFee > 0) {
            payable(feeRecipient).transfer(deploymentFee);
        }
        
        // Refund excess payment
        if (msg.value > deploymentFee) {
            payable(msg.sender).transfer(msg.value - deploymentFee);
        }
        
        emit AgentDeployed(agent, owner, agentId, initialStrategies.length);
        
        return agent;
    }

    /**
     * @notice Predict the address of a deterministically deployed agent
     * @param salt Salt for deterministic deployment
     * @return predicted Predicted address of the agent
     */
    function predictDeterministicAddress(bytes32 salt)
        external
        view
        returns (address predicted)
    {
        return implementation.predictDeterministicAddress(salt, address(this));
    }

    /**
     * @notice Register an existing agent (owner only)
     * @param agent Address of the agent to register
     * @param agentId Unique identifier for the agent
     */
    function registerAgent(address agent, bytes32 agentId) external onlyOwner {
        require(agent != address(0), "Invalid agent address");
        require(agentId != bytes32(0), "Invalid agent ID");
        require(agents[agentId] == address(0), "Agent ID already exists");
        require(!isRegisteredAgent[agent], "Agent already registered");
        
        // Get the agent owner
        address agentOwner = Ownable(agent).owner();
        
        _registerAgent(agent, agentId, agentOwner);
        
        emit AgentRegistered(agent, agentId);
    }

    /**
     * @notice Deregister an agent (owner only)
     * @param agentId Agent ID to deregister
     */
    function deregisterAgent(bytes32 agentId) external onlyOwner {
        address agent = agents[agentId];
        require(agent != address(0), "Agent not found");
        
        _deregisterAgent(agent, agentId);
        
        emit AgentDeregistered(agent, agentId);
    }

    /**
     * @notice Update the implementation contract (owner only)
     * @param newImplementation Address of the new implementation
     */
    function updateImplementation(address newImplementation) external onlyOwner {
        require(newImplementation != address(0), "Invalid implementation");
        require(newImplementation != implementation, "Same implementation");
        
        address oldImplementation = implementation;
        implementation = newImplementation;
        
        emit ImplementationUpdated(oldImplementation, newImplementation);
    }

    /**
     * @notice Update deployment fee (owner only)
     * @param newFee New deployment fee
     */
    function updateDeploymentFee(uint256 newFee) external onlyOwner {
        require(newFee <= MAX_DEPLOYMENT_FEE, "Fee too high");
        deploymentFee = newFee;
    }

    /**
     * @notice Update fee recipient (owner only)
     * @param newRecipient New fee recipient address
     */
    function updateFeeRecipient(address newRecipient) external onlyOwner {
        require(newRecipient != address(0), "Invalid recipient");
        feeRecipient = newRecipient;
    }

    /**
     * @notice Pause the factory (owner only)
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @notice Unpause the factory (owner only)
     */
    function unpause() external onlyOwner {
        _unpause();
    }

    // View functions

    /**
     * @notice Get agent address by ID
     * @param agentId Agent identifier
     * @return agent Agent address
     */
    function getAgent(bytes32 agentId) external view returns (address agent) {
        return agents[agentId];
    }

    /**
     * @notice Get agent ID by address
     * @param agent Agent address
     * @return agentId Agent identifier
     */
    function getAgentId(address agent) external view returns (bytes32 agentId) {
        return agentIds[agent];
    }

    /**
     * @notice Get all agents owned by an address
     * @param owner Owner address
     * @return agentList Array of agent addresses
     */
    function getOwnerAgents(address owner) external view returns (address[] memory agentList) {
        return ownerAgents[owner];
    }

    /**
     * @notice Get all registered agents
     * @return agentList Array of all agent addresses
     */
    function getAllAgents() external view returns (address[] memory agentList) {
        return allAgents;
    }

    /**
     * @notice Get all agent IDs
     * @return idList Array of all agent IDs
     */
    function getAllAgentIds() external view returns (bytes32[] memory idList) {
        return allAgentIds;
    }

    /**
     * @notice Get agent count for an owner
     * @param owner Owner address
     * @return count Number of agents owned
     */
    function getOwnerAgentCount(address owner) external view returns (uint256 count) {
        return ownerAgents[owner].length;
    }

    /**
     * @notice Check if an agent is registered
     * @param agent Agent address
     * @return registered Whether the agent is registered
     */
    function isAgentRegistered(address agent) external view returns (bool registered) {
        return isRegisteredAgent[agent];
    }

    /**
     * @notice Get factory statistics
     * @return stats Factory statistics
     */
    function getFactoryStats()
        external
        view
        returns (
            uint256 totalAgentsCount,
            uint256 currentDeploymentFee,
            address currentImplementation,
            address currentFeeRecipient,
            bool isPaused
        )
    {
        return (
            totalAgents,
            deploymentFee,
            implementation,
            feeRecipient,
            paused()
        );
    }

    // Internal functions

    /**
     * @notice Internal function to register an agent
     * @param agent Agent address
     * @param agentId Agent identifier
     * @param owner Agent owner
     */
    function _registerAgent(address agent, bytes32 agentId, address owner) internal {
        agents[agentId] = agent;
        agentIds[agent] = agentId;
        isRegisteredAgent[agent] = true;
        ownerAgents[owner].push(agent);
        allAgents.push(agent);
        allAgentIds.push(agentId);
        totalAgents++;
    }

    /**
     * @notice Internal function to deregister an agent
     * @param agent Agent address
     * @param agentId Agent identifier
     */
    function _deregisterAgent(address agent, bytes32 agentId) internal {
        address owner = Ownable(agent).owner();
        
        // Remove from mappings
        delete agents[agentId];
        delete agentIds[agent];
        isRegisteredAgent[agent] = false;
        
        // Remove from owner's agent list
        address[] storage ownerAgentList = ownerAgents[owner];
        for (uint256 i = 0; i < ownerAgentList.length; i++) {
            if (ownerAgentList[i] == agent) {
                ownerAgentList[i] = ownerAgentList[ownerAgentList.length - 1];
                ownerAgentList.pop();
                break;
            }
        }
        
        // Remove from all agents array
        for (uint256 i = 0; i < allAgents.length; i++) {
            if (allAgents[i] == agent) {
                allAgents[i] = allAgents[allAgents.length - 1];
                allAgents.pop();
                break;
            }
        }
        
        // Remove from all agent IDs array
        for (uint256 i = 0; i < allAgentIds.length; i++) {
            if (allAgentIds[i] == agentId) {
                allAgentIds[i] = allAgentIds[allAgentIds.length - 1];
                allAgentIds.pop();
                break;
            }
        }
        
        totalAgents--;
    }

    /**
     * @notice Emergency withdrawal function (owner only)
     * @param token Token address (address(0) for ETH)
     * @param amount Amount to withdraw
     */
    function emergencyWithdraw(address token, uint256 amount) external onlyOwner {
        if (token == address(0)) {
            payable(owner()).transfer(amount);
        } else {
            IERC20(token).transfer(owner(), amount);
        }
    }

    /**
     * @notice Receive function to accept ETH
     */
    receive() external payable {}
}