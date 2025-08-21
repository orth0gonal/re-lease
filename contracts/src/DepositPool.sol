// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./PropertyNFT.sol";

/**
 * @title DepositPool
 * @dev ERC-4626 Vault for rental deposits with KRW→cKRW conversion and landlord distribution choices
 * Gas optimization target: <200,000 gas for deposit submission
 */
contract DepositPool is ERC4626, AccessControl, Pausable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    // Role definitions
    bytes32 public constant POOL_MANAGER_ROLE = keccak256("POOL_MANAGER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant YIELD_MANAGER_ROLE = keccak256("YIELD_MANAGER_ROLE");

    // Deposit status enumeration
    enum DepositStatus {
        PENDING,      // Deposit submitted, waiting for confirmation
        ACTIVE,       // Deposit confirmed and active
        SETTLEMENT,   // In settlement process
        COMPLETED,    // Settlement completed successfully
        DEFAULTED,    // Default occurred, moved to P2P marketplace
        RECOVERED     // Tenant recovered deposit
    }

    // Deposit information structure
    struct DepositInfo {
        uint256 propertyTokenId;         // Associated property NFT token ID
        address tenant;                  // Tenant who submitted deposit
        address landlord;                // Property landlord
        uint256 krwAmount;              // Original KRW deposit amount
        uint256 cKRWShares;             // cKRW vault shares for this deposit
        uint256 yieldEarned;            // Additional yield earned
        DepositStatus status;           // Current deposit status
        PropertyNFT.DistributionChoice distributionChoice; // Landlord's choice
        uint256 submissionTime;         // Deposit submission timestamp
        uint256 expectedReturnTime;     // Expected contract end time
        bool isInPool;                  // Whether deposit is retained in pool for yield
        uint256 lastYieldCalculation;   // Last yield calculation timestamp
    }

    // State variables
    PropertyNFT public immutable propertyNFT;
    
    mapping(uint256 => DepositInfo) public deposits;
    mapping(address => uint256[]) public tenantDeposits;
    mapping(address => uint256[]) public landlordDeposits;
    
    uint256 public totalActiveDeposits;
    uint256 public totalYieldDistributed;
    uint256 public annualYieldRate; // Annual yield rate in basis points (e.g., 500 = 5%)
    uint256 public constant MIN_DEPOSIT_AMOUNT = 1000 * 1e18; // 1,000 KRW minimum
    uint256 public constant MAX_DEPOSIT_AMOUNT = 10000000 * 1e18; // 10M KRW maximum
    uint256 public constant YIELD_CALCULATION_INTERVAL = 1 days;

    // Events
    event DepositSubmitted(
        uint256 indexed propertyTokenId,
        address indexed tenant,
        address indexed landlord,
        uint256 krwAmount,
        uint256 cKRWShares,
        PropertyNFT.DistributionChoice distributionChoice
    );

    event DepositActivated(
        uint256 indexed propertyTokenId,
        address indexed tenant,
        uint256 expectedReturnTime
    );

    event DepositDistributed(
        uint256 indexed propertyTokenId,
        address indexed landlord,
        uint256 krwAmount,
        PropertyNFT.DistributionChoice distributionChoice
    );

    event DepositRetainedInPool(
        uint256 indexed propertyTokenId,
        uint256 cKRWShares,
        uint256 expectedYield
    );

    event YieldCalculated(
        uint256 indexed propertyTokenId,
        uint256 yieldAmount,
        uint256 totalAccumulated
    );

    event DepositRecovered(
        uint256 indexed propertyTokenId,
        address indexed tenant,
        uint256 krwAmount,
        uint256 yieldAmount
    );

    event YieldRateUpdated(
        uint256 oldRate,
        uint256 newRate
    );

    event DepositDefaultHandled(
        uint256 indexed propertyTokenId,
        address indexed tenant,
        uint256 krwAmount
    );

    /**
     * @dev Constructor initializes the ERC-4626 vault
     * @param _propertyNFT PropertyNFT contract address
     * @param _krwToken KRW stablecoin contract address (underlying asset)
     * @param _initialYieldRate Initial annual yield rate in basis points
     */
    constructor(
        address _propertyNFT,
        address _krwToken,
        uint256 _initialYieldRate
    ) ERC4626(IERC20(_krwToken)) ERC20("cKRW Deposit Vault", "cKRW") {
        require(_propertyNFT != address(0), "DepositPool: Invalid PropertyNFT address");
        require(_krwToken != address(0), "DepositPool: Invalid KRW token address");
        require(_initialYieldRate <= 10000, "DepositPool: Yield rate too high"); // Max 100%

        propertyNFT = PropertyNFT(_propertyNFT);
        annualYieldRate = _initialYieldRate;

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(POOL_MANAGER_ROLE, msg.sender);
        _grantRole(PAUSER_ROLE, msg.sender);
        _grantRole(YIELD_MANAGER_ROLE, msg.sender);
    }

    /**
     * @dev Submit deposit for a verified rental contract
     * @param propertyTokenId The property token ID
     * @param krwAmount Amount of KRW to deposit
     */
    function submitDeposit(
        uint256 propertyTokenId,
        uint256 krwAmount
    ) external nonReentrant whenNotPaused {
        require(krwAmount >= MIN_DEPOSIT_AMOUNT, "DepositPool: Deposit amount too low");
        require(krwAmount <= MAX_DEPOSIT_AMOUNT, "DepositPool: Deposit amount too high");
        
        // Get property information
        PropertyNFT.Property memory property = propertyNFT.getProperty(propertyTokenId);
        require(property.status == PropertyNFT.PropertyStatus.CONTRACT_VERIFIED, "DepositPool: Contract not verified");
        require(property.proposedTenant == msg.sender, "DepositPool: Only proposed tenant can submit deposit");
        require(property.proposedDepositAmount == krwAmount, "DepositPool: Incorrect deposit amount");
        require(deposits[propertyTokenId].tenant == address(0), "DepositPool: Deposit already exists");

        // Handle distribution choice
        uint256 cKRWShares = 0;
        bool retainInPool = (property.distributionChoice == PropertyNFT.DistributionChoice.POOL);

        if (retainInPool) {
            // POOL choice: Convert KRW to cKRW vault shares for yield generation
            // Transfer KRW from tenant to vault
            IERC20(asset()).safeTransferFrom(msg.sender, address(this), krwAmount);
            
            // Deposit into vault and mint cKRW shares to this contract
            cKRWShares = deposit(krwAmount, address(this));
            
            emit DepositRetainedInPool(propertyTokenId, cKRWShares, _calculateExpectedYield(krwAmount, property.contractEndTime));
        } else {
            // DIRECT choice: Transfer KRW directly to landlord
            IERC20(asset()).safeTransferFrom(msg.sender, property.landlord, krwAmount);
            
            emit DepositDistributed(propertyTokenId, property.landlord, krwAmount, property.distributionChoice);
        }

        // Store deposit information
        deposits[propertyTokenId] = DepositInfo({
            propertyTokenId: propertyTokenId,
            tenant: msg.sender,
            landlord: property.landlord,
            krwAmount: krwAmount,
            cKRWShares: cKRWShares,
            yieldEarned: 0,
            status: DepositStatus.PENDING,
            distributionChoice: property.distributionChoice,
            submissionTime: block.timestamp,
            expectedReturnTime: property.contractEndTime,
            isInPool: retainInPool,
            lastYieldCalculation: block.timestamp
        });

        // Update tracking
        tenantDeposits[msg.sender].push(propertyTokenId);
        landlordDeposits[property.landlord].push(propertyTokenId);
        totalActiveDeposits++;

        emit DepositSubmitted(propertyTokenId, msg.sender, property.landlord, krwAmount, cKRWShares, property.distributionChoice);
    }

    /**
     * @dev Activate deposit after admin verification
     * @param propertyTokenId The property token ID
     * @param expectedReturnTime Expected contract end time
     */
    function activateDeposit(
        uint256 propertyTokenId,
        uint256 expectedReturnTime
    ) external onlyRole(POOL_MANAGER_ROLE) {
        DepositInfo storage depositInfo = deposits[propertyTokenId];
        require(depositInfo.tenant != address(0), "DepositPool: Deposit does not exist");
        require(depositInfo.status == DepositStatus.PENDING, "DepositPool: Deposit not pending");
        require(expectedReturnTime > block.timestamp, "DepositPool: Invalid return time");

        depositInfo.status = DepositStatus.ACTIVE;
        depositInfo.expectedReturnTime = expectedReturnTime;

        emit DepositActivated(propertyTokenId, depositInfo.tenant, expectedReturnTime);
    }

    /**
     * @dev Calculate and update yield for pool deposits
     * @param propertyTokenId The property token ID
     * @return yieldAmount The calculated yield amount
     */
    function calculateYield(uint256 propertyTokenId) public returns (uint256 yieldAmount) {
        DepositInfo storage depositInfo = deposits[propertyTokenId];
        require(depositInfo.tenant != address(0), "DepositPool: Deposit does not exist");
        require(depositInfo.isInPool, "DepositPool: Deposit not in yield pool");
        require(depositInfo.status == DepositStatus.ACTIVE, "DepositPool: Deposit not active");

        uint256 timeElapsed = block.timestamp - depositInfo.lastYieldCalculation;
        if (timeElapsed < YIELD_CALCULATION_INTERVAL) {
            return 0;
        }

        // Calculate yield based on vault appreciation and additional yield rate
        uint256 vaultYield = _calculateVaultAppreciation(depositInfo.cKRWShares, depositInfo.krwAmount);
        uint256 additionalYield = _calculateAdditionalYield(depositInfo.krwAmount, timeElapsed);
        
        yieldAmount = vaultYield + additionalYield;

        if (yieldAmount > 0) {
            depositInfo.yieldEarned += yieldAmount;
            depositInfo.lastYieldCalculation = block.timestamp;
            totalYieldDistributed += yieldAmount;

            emit YieldCalculated(propertyTokenId, yieldAmount, depositInfo.yieldEarned);
        }

        return yieldAmount;
    }

    /**
     * @dev Recover deposit after settlement
     * @param propertyTokenId The property token ID
     */
    function recoverDeposit(uint256 propertyTokenId) external nonReentrant {
        DepositInfo storage depositInfo = deposits[propertyTokenId];
        require(depositInfo.tenant == msg.sender, "DepositPool: Only tenant can recover deposit");
        require(depositInfo.status == DepositStatus.COMPLETED, "DepositPool: Settlement not completed");

        uint256 totalRecoveryAmount = depositInfo.krwAmount;
        uint256 yieldAmount = 0;

        if (depositInfo.isInPool) {
            // Calculate final yield
            yieldAmount = calculateYield(propertyTokenId);
            
            // Redeem cKRW shares from vault
            uint256 assetsReceived = redeem(depositInfo.cKRWShares, address(this), address(this));
            totalRecoveryAmount = assetsReceived + depositInfo.yieldEarned;
        }

        // Transfer recovery amount to tenant
        IERC20(asset()).safeTransfer(msg.sender, totalRecoveryAmount);

        // Update status
        depositInfo.status = DepositStatus.RECOVERED;
        totalActiveDeposits--;

        emit DepositRecovered(propertyTokenId, msg.sender, totalRecoveryAmount, depositInfo.yieldEarned);
    }

    /**
     * @dev Handle deposit default and prepare for P2P marketplace
     * @param propertyTokenId The property token ID
     */
    function handleDefault(uint256 propertyTokenId) external onlyRole(POOL_MANAGER_ROLE) {
        DepositInfo storage depositInfo = deposits[propertyTokenId];
        require(depositInfo.tenant != address(0), "DepositPool: Deposit does not exist");
        require(depositInfo.status == DepositStatus.ACTIVE || depositInfo.status == DepositStatus.SETTLEMENT, "DepositPool: Invalid status for default");

        depositInfo.status = DepositStatus.DEFAULTED;

        emit DepositDefaultHandled(propertyTokenId, depositInfo.tenant, depositInfo.krwAmount);
    }

    /**
     * @dev Process settlement completion
     * @param propertyTokenId The property token ID
     */
    function processSettlement(uint256 propertyTokenId) external onlyRole(POOL_MANAGER_ROLE) {
        DepositInfo storage depositInfo = deposits[propertyTokenId];
        require(depositInfo.tenant != address(0), "DepositPool: Deposit does not exist");
        require(depositInfo.status == DepositStatus.SETTLEMENT, "DepositPool: Not in settlement");

        depositInfo.status = DepositStatus.COMPLETED;
        
        // Calculate final yield for pool deposits
        if (depositInfo.isInPool) {
            calculateYield(propertyTokenId);
        }
    }

    /**
     * @dev Update annual yield rate
     * @param newYieldRate New yield rate in basis points
     */
    function updateYieldRate(uint256 newYieldRate) external onlyRole(YIELD_MANAGER_ROLE) {
        require(newYieldRate <= 10000, "DepositPool: Yield rate too high");
        
        uint256 oldRate = annualYieldRate;
        annualYieldRate = newYieldRate;
        
        emit YieldRateUpdated(oldRate, newYieldRate);
    }

    /**
     * @dev Calculate expected yield for a deposit amount over contract period
     * @param amount Deposit amount
     * @param contractEndTime Contract end timestamp
     * @return expectedYield Expected yield amount
     */
    function _calculateExpectedYield(uint256 amount, uint256 contractEndTime) internal view returns (uint256 expectedYield) {
        if (contractEndTime <= block.timestamp) return 0;
        
        uint256 timeToMaturity = contractEndTime - block.timestamp;
        uint256 annualYield = (amount * annualYieldRate) / 10000;
        expectedYield = (annualYield * timeToMaturity) / 365 days;
        
        return expectedYield;
    }

    /**
     * @dev Calculate vault appreciation for cKRW shares
     * @param shares Amount of cKRW shares
     * @param originalAmount Original deposit amount
     * @return appreciation Vault appreciation amount
     */
    function _calculateVaultAppreciation(uint256 shares, uint256 originalAmount) internal view returns (uint256 appreciation) {
        if (shares == 0) return 0;
        
        uint256 currentValue = convertToAssets(shares);
        if (currentValue > originalAmount) {
            appreciation = currentValue - originalAmount;
        }
        
        return appreciation;
    }

    /**
     * @dev Calculate additional yield based on time elapsed
     * @param amount Deposit amount
     * @param timeElapsed Time elapsed since last calculation
     * @return additionalYield Additional yield amount
     */
    function _calculateAdditionalYield(uint256 amount, uint256 timeElapsed) internal view returns (uint256 additionalYield) {
        uint256 annualYield = (amount * annualYieldRate) / 10000;
        additionalYield = (annualYield * timeElapsed) / 365 days;
        
        return additionalYield;
    }

    /**
     * @dev Get deposit information
     * @param propertyTokenId The property token ID
     * @return DepositInfo struct
     */
    function getDeposit(uint256 propertyTokenId) external view returns (DepositInfo memory) {
        return deposits[propertyTokenId];
    }

    /**
     * @dev Get tenant deposits
     * @param tenant Tenant address
     * @return Array of property token IDs
     */
    function getTenantDeposits(address tenant) external view returns (uint256[] memory) {
        return tenantDeposits[tenant];
    }

    /**
     * @dev Get landlord deposits
     * @param landlord Landlord address
     * @return Array of property token IDs
     */
    function getLandlordDeposits(address landlord) external view returns (uint256[] memory) {
        return landlordDeposits[landlord];
    }

    /**
     * @dev Get total vault statistics
     * @return vaultAssets Total assets in vault
     * @return vaultShares Total shares outstanding
     * @return sharePrice Current share price
     */
    function getVaultStats() external view returns (uint256 vaultAssets, uint256 vaultShares, uint256 sharePrice) {
        vaultAssets = totalAssets();
        vaultShares = totalSupply();
        sharePrice = vaultShares > 0 ? (vaultAssets * 1e18) / vaultShares : 1e18;
        
        return (vaultAssets, vaultShares, sharePrice);
    }

    /**
     * @dev Override to add pause functionality
     */
    function _update(address from, address to, uint256 value) internal override whenNotPaused {
        super._update(from, to, value);
    }

    /**
     * @dev Pause contract functionality
     */
    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    /**
     * @dev Unpause contract functionality
     */
    function unpause() external onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    /**
     * @dev See {IERC165-supportsInterface}
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}