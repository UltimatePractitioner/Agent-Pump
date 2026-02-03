// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title AgentRegistry
 * @notice On-chain identity and reputation for AI agents
 */
contract AgentRegistry is Ownable {
    
    struct Agent {
        string id;
        address owner;
        string name;
        string metadataURI;
        uint256 createdAt;
        uint256 reputationScore;
        uint256 totalLaunches;
        uint256 totalVolume;
        uint256 uniqueHolders;
        uint16 uptimeBps;  // Basis points (10000 = 100%)
        uint256 lastActive;
        bool isVerified;
        bytes32 saidHash;  // SAID verification hash
    }
    
    mapping(string => Agent) public agents;
    mapping(address => string[]) public ownerAgents;
    
    string[] public allAgentIds;
    
    uint256 public constant REPUTATION_MAX = 10000;
    uint256 public constant MIN_REPUTATION_TO_FEATURE = 2500;
    
    event AgentRegistered(string indexed agentId, address indexed owner, string name);
    event ReputationUpdated(string indexed agentId, uint256 newScore);
    event AgentVerified(string indexed agentId, bytes32 saidHash);
    event ActivityRecorded(string indexed agentId, uint256 timestamp);
    
    modifier onlyAgentOwner(string memory agentId) {
        require(msg.sender == agents[agentId].owner, "Not agent owner");
        _;
    }
    
    /**
     * @notice Register a new agent
     */
    function registerAgent(
        string memory agentId,
        string memory name,
        string memory metadataURI
    ) external returns (bool) {
        require(bytes(agents[agentId].id).length == 0, "Agent already exists");
        require(bytes(agentId).length >= 3 && bytes(agentId).length <= 32, "Invalid ID length");
        require(bytes(name).length >= 2 && bytes(name).length <= 64, "Invalid name length");
        
        Agent memory newAgent = Agent({
            id: agentId,
            owner: msg.sender,
            name: name,
            metadataURI: metadataURI,
            createdAt: block.timestamp,
            reputationScore: 0,
            totalLaunches: 0,
            totalVolume: 0,
            uniqueHolders: 0,
            uptimeBps: 10000, // Start at 100%
            lastActive: block.timestamp,
            isVerified: false,
            saidHash: bytes32(0)
        });
        
        agents[agentId] = newAgent;
        ownerAgents[msg.sender].push(agentId);
        allAgentIds.push(agentId);
        
        emit AgentRegistered(agentId, msg.sender, name);
        return true;
    }
    
    /**
     * @notice Verify agent with SAID proof
     */
    function verifyAgent(string memory agentId, bytes32 saidHash) external onlyOwner {
        require(bytes(agents[agentId].id).length > 0, "Agent not found");
        
        agents[agentId].isVerified = true;
        agents[agentId].saidHash = saidHash;
        
        // Verification boosts reputation
        _updateReputation(agentId);
        
        emit AgentVerified(agentId, saidHash);
    }
    
    /**
     * @notice Record token launch for agent
     */
    function recordLaunch(string memory agentId) external {
        require(bytes(agents[agentId].id).length > 0, "Agent not found");
        // In production, verify caller is BondingCurveFactory
        
        agents[agentId].totalLaunches += 1;
        _updateReputation(agentId);
    }
    
    /**
     * @notice Record trading activity
     */
    function recordActivity(
        string memory agentId,
        uint256 volume,
        uint256 newHolders
    ) external {
        require(bytes(agents[agentId].id).length > 0, "Agent not found");
        
        agents[agentId].totalVolume += volume;
        agents[agentId].uniqueHolders = newHolders;
        agents[agentId].lastActive = block.timestamp;
        
        _updateReputation(agentId);
        
        emit ActivityRecorded(agentId, block.timestamp);
    }
    
    /**
     * @notice Update uptime score
     */
    function updateUptime(string memory agentId, uint16 newUptimeBps) external onlyOwner {
        require(newUptimeBps <= 10000, "Invalid uptime");
        agents[agentId].uptimeBps = newUptimeBps;
        _updateReputation(agentId);
    }
    
    /**
     * @notice Calculate and update reputation score
     */
    function _updateReputation(string memory agentId) internal {
        Agent storage agent = agents[agentId];
        
        // Age score (20% weight) - max at 365 days
        uint256 ageDays = (block.timestamp - agent.createdAt) / 1 days;
        uint256 ageScore = (ageDays > 365 ? 365 : ageDays) * 10000 / 365;
        
        // Volume score (25% weight) - logarithmic scale
        uint256 volumeScore = _logScore(agent.totalVolume, 1000 ether);
        
        // Holder score (20% weight)
        uint256 holderScore = agent.uniqueHolders > 100 ? 10000 : agent.uniqueHolders * 100;
        
        // Uptime score (15% weight)
        uint256 uptimeScore = uint256(agent.uptimeBps) * 100;
        
        // Launches score (20% weight)
        uint256 launchScore = agent.totalLaunches > 10 ? 10000 : agent.totalLaunches * 1000;
        
        // Verification bonus
        uint256 verificationBonus = agent.isVerified ? 500 : 0;
        
        // Weighted average
        uint256 newScore = (
            ageScore * 20 +
            volumeScore * 25 +
            holderScore * 20 +
            uptimeScore * 15 +
            launchScore * 20
        ) / 100 + verificationBonus;
        
        if (newScore > REPUTATION_MAX) newScore = REPUTATION_MAX;
        
        agent.reputationScore = newScore;
        
        emit ReputationUpdated(agentId, newScore);
    }
    
    function _logScore(uint256 value, uint256 target) internal pure returns (uint256) {
        if (value == 0) return 0;
        if (value >= target) return 10000;
        
        // Approximate log: value/target * 10000 for small values
        // Scale non-linearly for larger values
        uint256 ratio = (value * 10000) / target;
        if (ratio < 1000) return ratio;
        if (ratio < 5000) return 1000 + (ratio - 1000) * 2;
        return 5000 + (ratio - 5000);
    }
    
    /**
     * @notice Get featured agents (high reputation)
     */
    function getFeaturedAgents(uint256 count) external view returns (string[] memory) {
        uint256 resultCount = 0;
        
        // Count qualifying agents
        for (uint256 i = 0; i < allAgentIds.length; i++) {
            if (agents[allAgentIds[i]].reputationScore >= MIN_REPUTATION_TO_FEATURE) {
                resultCount++;
            }
        }
        
        if (resultCount == 0) return new string[](0);
        if (resultCount > count) resultCount = count;
        
        string[] memory featured = new string[](resultCount);
        uint256 index = 0;
        
        for (uint256 i = 0; i < allAgentIds.length && index < resultCount; i++) {
            if (agents[allAgentIds[i]].reputationScore >= MIN_REPUTATION_TO_FEATURE) {
                featured[index] = allAgentIds[i];
                index++;
            }
        }
        
        return featured;
    }
    
    /**
     * @notice Get agent by ID
     */
    function getAgent(string memory agentId) external view returns (Agent memory) {
        require(bytes(agents[agentId].id).length > 0, "Agent not found");
        return agents[agentId];
    }
    
    /**
     * @notice Get all agents for an owner
     */
    function getOwnerAgents(address owner) external view returns (string[] memory) {
        return ownerAgents[owner];
    }
}
