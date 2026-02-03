// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/**
 * @title AgentPump Bonding Curve
 * @notice Bonding curve token with automatic price discovery
 * @dev Implements linear, exponential, and sigmoid curve types
 */
contract BondingCurveToken is ERC20, Ownable, ReentrancyGuard {
    
    enum CurveType { Linear, Exponential, Sigmoid }
    
    struct CurveConfig {
        CurveType curveType;
        uint256 basePrice;          // Starting price in wei
        uint256 slope;              // Growth parameter
        uint256 maxSupply;          // Maximum token supply
        uint256 migrationThreshold; // Supply to trigger AMM migration
    }
    
    CurveConfig public config;
    
    uint256 public constant FEE_BPS = 100;        // 1% fee
    uint256 public constant MAX_SLIPPAGE_BPS = 500; // 5% max slippage
    
    uint256 public reserveBalance;
    bool public isMigrated;
    
    address public agent;
    string public agentId;
    
    event TokensPurchased(address indexed buyer, uint256 amount, uint256 cost);
    event TokensSold(address indexed seller, uint256 amount, uint256 refund);
    event CurveMigrated(uint256 finalSupply, uint256 finalReserve);
    
    constructor(
        string memory name,
        string memory symbol,
        CurveConfig memory _config,
        address _agent,
        string memory _agentId
    ) ERC20(name, symbol) Ownable(msg.sender) {
        config = _config;
        agent = _agent;
        agentId = _agentId;
        isMigrated = false;
    }
    
    /**
     * @notice Calculate price for buying tokens
     */
    function calculateBuyPrice(uint256 amount) public view returns (uint256) {
        uint256 currentSupply = totalSupply();
        
        if (config.curveType == CurveType.Linear) {
            return _linearPrice(currentSupply, amount);
        } else if (config.curveType == CurveType.Exponential) {
            return _exponentialPrice(currentSupply, amount);
        } else {
            return _sigmoidPrice(currentSupply, amount);
        }
    }
    
    /**
     * @notice Calculate refund for selling tokens
     */
    function calculateSellRefund(uint256 amount) public view returns (uint256) {
        require(amount <= totalSupply(), "Amount exceeds supply");
        uint256 currentSupply = totalSupply();
        
        // Selling uses the same curve logic in reverse
        if (config.curveType == CurveType.Linear) {
            return _linearPrice(currentSupply - amount, amount);
        } else if (config.curveType == CurveType.Exponential) {
            return _exponentialPriceReverse(currentSupply, amount);
        } else {
            return _sigmoidPriceReverse(currentSupply, amount);
        }
    }
    
    /**
     * @notice Buy tokens with ETH
     */
    function buyTokens(uint256 amount, uint256 maxPrice) external payable nonReentrant {
        require(!isMigrated, "Curve migrated");
        require(totalSupply() + amount <= config.maxSupply, "Exceeds max supply");
        
        uint256 cost = calculateBuyPrice(amount);
        require(cost <= maxPrice, "Slippage exceeded");
        require(msg.value >= cost, "Insufficient ETH");
        
        // Apply fee
        uint256 fee = (cost * FEE_BPS) / 10000;
        uint256 reserveIncrease = cost - fee;
        
        // Update state before external calls (CEI)
        reserveBalance += reserveIncrease;
        _mint(msg.sender, amount);
        
        // Transfer fee to agent
        (bool success, ) = payable(agent).call{value: fee}("");
        require(success, "Fee transfer failed");
        
        // Refund excess
        if (msg.value > cost) {
            (success, ) = payable(msg.sender).call{value: msg.value - cost}("");
            require(success, "Refund failed");
        }
        
        // Check migration
        if (totalSupply() >= config.migrationThreshold) {
            isMigrated = true;
            emit CurveMigrated(totalSupply(), reserveBalance);
        }
        
        emit TokensPurchased(msg.sender, amount, cost);
    }
    
    /**
     * @notice Sell tokens for ETH
     */
    function sellTokens(uint256 amount, uint256 minRefund) external nonReentrant {
        require(!isMigrated, "Curve migrated");
        require(balanceOf(msg.sender) >= amount, "Insufficient balance");
        
        uint256 refund = calculateSellRefund(amount);
        require(refund >= minRefund, "Slippage exceeded");
        require(refund <= reserveBalance, "Insufficient reserve");
        
        // Update state before external calls
        reserveBalance -= refund;
        _burn(msg.sender, amount);
        
        // Transfer ETH
        (bool success, ) = payable(msg.sender).call{value: refund}("");
        require(success, "Transfer failed");
        
        emit TokensSold(msg.sender, amount, refund);
    }
    
    // ============ Curve Math ============
    
    function _linearPrice(uint256 supply, uint256 amount) internal view returns (uint256) {
        // Price = base + slope * supply
        // Total cost = integral from supply to supply+amount
        uint256 startPrice = config.basePrice + (config.slope * supply);
        uint256 endPrice = config.basePrice + (config.slope * (supply + amount));
        return ((startPrice + endPrice) * amount) / 2;
    }
    
    function _exponentialPrice(uint256 supply, uint256 amount) internal view returns (uint256) {
        // Simplified exponential for demonstration
        // P = base * (1 + slope)^supply
        uint256 avgMultiplier = 1000 + (config.slope * (supply + amount / 2)) / 1000;
        return (config.basePrice * avgMultiplier * amount) / 1000;
    }
    
    function _exponentialPriceReverse(uint256 supply, uint256 amount) internal view returns (uint256) {
        uint256 avgMultiplier = 1000 + (config.slope * (supply - amount / 2)) / 1000;
        return (config.basePrice * avgMultiplier * amount) / 1000;
    }
    
    function _sigmoidPrice(uint256 supply, uint256 amount) internal view returns (uint256) {
        // Simplified sigmoid
        uint256 midpoint = config.migrationThreshold / 2;
        uint256 growth = config.slope;
        
        uint256 currentFactor = _sigmoidFactor(supply, midpoint, growth);
        uint256 futureFactor = _sigmoidFactor(supply + amount, midpoint, growth);
        
        return config.basePrice * 10 * (futureFactor - currentFactor) / 1000;
    }
    
    function _sigmoidPriceReverse(uint256 supply, uint256 amount) internal view returns (uint256) {
        uint256 midpoint = config.migrationThreshold / 2;
        uint256 growth = config.slope;
        
        uint256 currentFactor = _sigmoidFactor(supply, midpoint, growth);
        uint256 pastFactor = _sigmoidFactor(supply - amount, midpoint, growth);
        
        return config.basePrice * 10 * (currentFactor - pastFactor) / 1000;
    }
    
    function _sigmoidFactor(uint256 x, uint256 midpoint, uint256 growth) internal pure returns (uint256) {
        // Approximation: x / (midpoint + |x - midpoint|/growth)
        if (x >= midpoint) {
            return 500 + (500 * (x - midpoint)) / (midpoint + (x - midpoint) / growth);
        } else {
            return 500 * x / (midpoint + (midpoint - x) / growth);
        }
    }
    
    receive() external payable {
        revert("Use buyTokens function");
    }
}
