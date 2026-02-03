// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./BondingCurveToken.sol";
import "./AgentRegistry.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title TokenFactory
 * @notice Factory for launching agent tokens with bonding curves
 */
contract TokenFactory is Ownable {
    
    AgentRegistry public registry;
    
    struct LaunchParams {
        string name;
        string symbol;
        BondingCurveToken.CurveConfig curveConfig;
        string agentId;
        string metadataURI;
    }
    
    mapping(address => address[]) public agentTokens;
    mapping(string => address[]) public agentIdTokens;
    address[] public allTokens;
    
    uint256 public launchFee = 0.01 ether;
    uint256 public minReputationToLaunch = 0;
    
    event TokenLaunched(
        address indexed token,
        string indexed agentId,
        address indexed agent,
        string name,
        string symbol,
        uint256 timestamp
    );
    
    constructor(address _registry) Ownable(msg.sender) {
        registry = AgentRegistry(_registry);
    }
    
    /**
     * @notice Launch a new agent token with bonding curve
     */
    function launchToken(LaunchParams memory params) external payable returns (address) {
        require(msg.value >= launchFee, "Insufficient launch fee");
        
        // Verify agent exists and caller is owner
        AgentRegistry.Agent memory agent = registry.getAgent(params.agentId);
        require(agent.owner == msg.sender, "Not agent owner");
        require(agent.reputationScore >= minReputationToLaunch, "Reputation too low");
        
        // Create token
        BondingCurveToken token = new BondingCurveToken(
            params.name,
            params.symbol,
            params.curveConfig,
            msg.sender,
            params.agentId
        );
        
        address tokenAddress = address(token);
        
        // Track token
        agentTokens[msg.sender].push(tokenAddress);
        agentIdTokens[params.agentId].push(tokenAddress);
        allTokens.push(tokenAddress);
        
        // Update registry
        registry.recordLaunch(params.agentId);
        
        // Transfer launch fee to owner
        (bool success, ) = payable(owner()).call{value: launchFee}("");
        require(success, "Fee transfer failed");
        
        // Refund excess
        if (msg.value > launchFee) {
            (success, ) = payable(msg.sender).call{value: msg.value - launchFee}("");
            require(success, "Refund failed");
        }
        
        emit TokenLaunched(
            tokenAddress,
            params.agentId,
            msg.sender,
            params.name,
            params.symbol,
            block.timestamp
        );
        
        return tokenAddress;
    }
    
    /**
     * @notice Get all tokens for an agent
     */
    function getAgentTokens(string memory agentId) external view returns (address[] memory) {
        return agentIdTokens[agentId];
    }
    
    /**
     * @notice Get all tokens launched by an address
     */
    function getTokensByOwner(address owner) external view returns (address[] memory) {
        return agentTokens[owner];
    }
    
    /**
     * @notice Get paginated list of all tokens
     */
    function getAllTokens(uint256 start, uint256 count) external view returns (address[] memory) {
        uint256 end = start + count;
        if (end > allTokens.length) end = allTokens.length;
        require(start < end, "Invalid range");
        
        address[] memory result = new address[](end - start);
        for (uint256 i = start; i < end; i++) {
            result[i - start] = allTokens[i];
        }
        return result;
    }
    
    /**
     * @notice Get total token count
     */
    function getTokenCount() external view returns (uint256) {
        return allTokens.length;
    }
    
    /**
     * @notice Update launch fee
     */
    function setLaunchFee(uint256 newFee) external onlyOwner {
        launchFee = newFee;
    }
    
    /**
     * @notice Update minimum reputation requirement
     */
    function setMinReputation(uint256 newMin) external onlyOwner {
        minReputationToLaunch = newMin;
    }
    
    /**
     * @notice Update registry address
     */
    function setRegistry(address newRegistry) external onlyOwner {
        registry = AgentRegistry(newRegistry);
    }
}
