// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./PropertyNFT.sol";
import "./DepositPool.sol";
import "./P2PDebtMarketplace.sol";

/**
 * @title SettlementManager
 * @dev Manages rental contract settlements with automated monitoring and grace period handling
 * Gas optimization target: <120,000 gas for settlement processing
 */
contract SettlementManager is AccessControl, Pausable, ReentrancyGuard {
    
    // Role definitions
    bytes32 public constant SETTLEMENT_MANAGER_ROLE = keccak256("SETTLEMENT_MANAGER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant MONITOR_ROLE = keccak256("MONITOR_ROLE");

    // Settlement status enumeration
    enum SettlementStatus {
        ACTIVE,           // Contract is active, no settlement needed
        PENDING,          // Settlement period started
        GRACE_PERIOD,     // In grace period, warning issued
        OVERDUE,          // Grace period expired, escalation needed
        SETTLED,          // Successfully settled
        DEFAULTED         // Settlement failed, moved to marketplace
    }

    // Contract monitoring structure
    struct ContractStatus {
        uint256 propertyTokenId;        // Associated property NFT token ID
        address tenant;                 // Tenant address
        address landlord;               // Landlord address
        uint256 contractEndTime;        // Original contract end timestamp
        uint256 settlementDeadline;     // Settlement deadline (end + grace period)
        uint256 gracePeriodStart;       // Grace period start timestamp
        uint256 warningsSent;           // Number of warnings sent
        uint256 lastStatusUpdate;       // Last status update timestamp
        SettlementStatus status;        // Current settlement status
        bool autoProcessingEnabled;    // Whether automatic processing is enabled
        string notes;                   // Additional notes for the settlement
    }

    // Warning configuration
    struct WarningConfig {
        uint256 firstWarningDays;       // Days before deadline for first warning
        uint256 secondWarningDays;      // Days before deadline for second warning
        uint256 finalWarningDays;       // Days before deadline for final warning
        uint256 gracePeriodDays;        // Grace period duration in days
        bool autoEscalationEnabled;    // Whether to auto-escalate to marketplace
    }

    // State variables
    PropertyNFT public immutable propertyNFT;
    DepositPool public immutable depositPool;
    P2PDebtMarketplace public immutable debtMarketplace;

    mapping(uint256 => ContractStatus) public contractStatuses;    // propertyTokenId => ContractStatus
    mapping(address => uint256[]) public tenantContracts;          // tenant => propertyTokenIds[]
    mapping(address => uint256[]) public landlordContracts;        // landlord => propertyTokenIds[]
    mapping(uint256 => bool) public registeredContracts;          // propertyTokenId => registered

    WarningConfig public warningConfig;
    uint256 public totalActiveContracts;
    uint256 public totalSettledContracts;
    uint256 public totalDefaultedContracts;

    // Constants
    uint256 public constant SECONDS_PER_DAY = 86400;
    uint256 public constant DEFAULT_GRACE_PERIOD = 30 days;
    uint256 public constant MAX_GRACE_PERIOD = 90 days;
    uint256 public constant WARNING_THRESHOLD = 30; // Max warnings per contract

    // Events
    event ContractRegistered(
        uint256 indexed propertyTokenId,
        address indexed tenant,
        address indexed landlord,
        uint256 contractEndTime,
        uint256 settlementDeadline
    );

    event SettlementStatusUpdated(
        uint256 indexed propertyTokenId,
        SettlementStatus oldStatus,
        SettlementStatus newStatus,
        uint256 timestamp
    );

    event WarningIssued(
        uint256 indexed propertyTokenId,
        address indexed tenant,
        uint256 warningNumber,
        uint256 daysRemaining,
        uint256 timestamp
    );

    event SettlementCompleted(
        uint256 indexed propertyTokenId,
        address indexed tenant,
        uint256 completionTime
    );

    event ContractDefaulted(
        uint256 indexed propertyTokenId,
        address indexed tenant,
        uint256 defaultTime,
        bool escalatedToMarketplace
    );

    event BatchProcessingCompleted(
        uint256 contractsProcessed,
        uint256 warningsIssued,
        uint256 escalations
    );

    event GracePeriodExtended(
        uint256 indexed propertyTokenId,
        uint256 newDeadline,
        string reason
    );

    /**
     * @dev Constructor initializes the manager with required dependencies
     * @param _propertyNFT PropertyNFT contract address
     * @param _depositPool DepositPool contract address
     * @param _debtMarketplace P2PDebtMarketplace contract address
     */
    constructor(
        address _propertyNFT,
        address _depositPool,
        address _debtMarketplace
    ) {
        require(_propertyNFT != address(0), "SettlementManager: Invalid PropertyNFT address");
        require(_depositPool != address(0), "SettlementManager: Invalid DepositPool address");
        require(_debtMarketplace != address(0), "SettlementManager: Invalid marketplace address");

        propertyNFT = PropertyNFT(_propertyNFT);
        depositPool = DepositPool(_depositPool);
        debtMarketplace = P2PDebtMarketplace(_debtMarketplace);

        // Initialize warning configuration
        warningConfig = WarningConfig({
            firstWarningDays: 14,          // 14 days before deadline
            secondWarningDays: 7,          // 7 days before deadline
            finalWarningDays: 1,           // 1 day before deadline
            gracePeriodDays: 30,           // 30 day grace period
            autoEscalationEnabled: true
        });

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(SETTLEMENT_MANAGER_ROLE, msg.sender);
        _grantRole(PAUSER_ROLE, msg.sender);
        _grantRole(MONITOR_ROLE, msg.sender);
    }

    /**
     * @dev Register a rental contract for monitoring
     * @param propertyTokenId Property NFT token ID
     * @param tenant Tenant address
     * @param contractEndTime Contract end timestamp
     * @param autoProcessing Whether to enable automatic processing
     */
    function registerContract(
        uint256 propertyTokenId,
        address tenant,
        uint256 contractEndTime,
        bool autoProcessing
    ) external onlyRole(SETTLEMENT_MANAGER_ROLE) whenNotPaused {
        require(tenant != address(0), "SettlementManager: Invalid tenant address");
        require(contractEndTime > block.timestamp, "SettlementManager: End time in the past");
        require(!registeredContracts[propertyTokenId], "SettlementManager: Contract already registered");

        // Get property information
        PropertyNFT.Property memory property = propertyNFT.getProperty(propertyTokenId);
        require(property.status == PropertyNFT.PropertyStatus.RENTED, "SettlementManager: Property not rented");
        require(property.currentTenant == tenant, "SettlementManager: Tenant mismatch");

        uint256 gracePeriod = warningConfig.gracePeriodDays * SECONDS_PER_DAY;
        uint256 settlementDeadline = contractEndTime + gracePeriod;

        // Create contract status
        contractStatuses[propertyTokenId] = ContractStatus({
            propertyTokenId: propertyTokenId,
            tenant: tenant,
            landlord: property.landlord,
            contractEndTime: contractEndTime,
            settlementDeadline: settlementDeadline,
            gracePeriodStart: 0,
            warningsSent: 0,
            lastStatusUpdate: block.timestamp,
            status: SettlementStatus.ACTIVE,
            autoProcessingEnabled: autoProcessing,
            notes: ""
        });

        // Update mappings
        registeredContracts[propertyTokenId] = true;
        tenantContracts[tenant].push(propertyTokenId);
        landlordContracts[property.landlord].push(propertyTokenId);
        totalActiveContracts++;

        emit ContractRegistered(
            propertyTokenId,
            tenant,
            property.landlord,
            contractEndTime,
            settlementDeadline
        );
    }

    /**
     * @dev Check and update settlement status for a specific contract
     * @param propertyTokenId Property NFT token ID
     */
    function checkSettlementStatus(uint256 propertyTokenId) external {
        require(registeredContracts[propertyTokenId], "SettlementManager: Contract not registered");
        _updateContractStatus(propertyTokenId);
    }

    /**
     * @dev Process batch settlement monitoring for all active contracts
     * @param maxContracts Maximum number of contracts to process in this batch
     * @return processed Number of contracts processed
     * @return warnings Number of warnings issued
     * @return escalations Number of escalations to marketplace
     */
    function batchProcessSettlements(uint256 maxContracts) 
        external 
        onlyRole(MONITOR_ROLE) 
        whenNotPaused 
        returns (uint256 processed, uint256 warnings, uint256 escalations) 
    {
        uint256 contractsToProcess = maxContracts == 0 ? type(uint256).max : maxContracts;
        
        // Simple iteration approach - in production, would use more sophisticated indexing
        for (uint256 tokenId = 1; tokenId <= propertyNFT.getCurrentTokenId() && processed < contractsToProcess; tokenId++) {
            if (registeredContracts[tokenId]) {
                ContractStatus storage contractStatus = contractStatuses[tokenId];
                
                if (contractStatus.status == SettlementStatus.ACTIVE || 
                    contractStatus.status == SettlementStatus.PENDING ||
                    contractStatus.status == SettlementStatus.GRACE_PERIOD) {
                    
                    SettlementStatus oldStatus = contractStatus.status;
                    _updateContractStatus(tokenId);
                    
                    // Count warnings and escalations
                    if (contractStatus.warningsSent > contractStatuses[tokenId].warningsSent) {
                        warnings++;
                    }
                    
                    if (contractStatus.status == SettlementStatus.DEFAULTED && oldStatus != SettlementStatus.DEFAULTED) {
                        escalations++;
                    }
                    
                    processed++;
                }
            }
        }

        emit BatchProcessingCompleted(processed, warnings, escalations);
        return (processed, warnings, escalations);
    }

    /**
     * @dev Complete settlement for a contract
     * @param propertyTokenId Property NFT token ID
     */
    function completeSettlement(uint256 propertyTokenId) external onlyRole(SETTLEMENT_MANAGER_ROLE) {
        ContractStatus storage contractStatus = contractStatuses[propertyTokenId];
        require(
            contractStatus.status == SettlementStatus.PENDING || 
            contractStatus.status == SettlementStatus.GRACE_PERIOD,
            "SettlementManager: Invalid status for settlement"
        );

        _updateSettlementStatus(propertyTokenId, SettlementStatus.SETTLED);
        totalActiveContracts--;
        totalSettledContracts++;

        // Trigger DepositPool settlement processing
        depositPool.processSettlement(propertyTokenId);

        emit SettlementCompleted(propertyTokenId, contractStatus.tenant, block.timestamp);
    }

    /**
     * @dev Extend grace period for a contract
     * @param propertyTokenId Property NFT token ID
     * @param additionalDays Additional days to extend
     * @param reason Reason for extension
     */
    function extendGracePeriod(
        uint256 propertyTokenId,
        uint256 additionalDays,
        string calldata reason
    ) external onlyRole(SETTLEMENT_MANAGER_ROLE) {
        require(additionalDays > 0 && additionalDays <= 30, "SettlementManager: Invalid extension period");
        
        ContractStatus storage contractStatus = contractStatuses[propertyTokenId];
        require(
            contractStatus.status == SettlementStatus.GRACE_PERIOD,
            "SettlementManager: Not in grace period"
        );

        uint256 extension = additionalDays * SECONDS_PER_DAY;
        contractStatus.settlementDeadline += extension;
        contractStatus.notes = reason;

        emit GracePeriodExtended(propertyTokenId, contractStatus.settlementDeadline, reason);
    }

    /**
     * @dev Internal function to update contract status based on current time
     * @param propertyTokenId Property NFT token ID
     */
    function _updateContractStatus(uint256 propertyTokenId) internal {
        ContractStatus storage contractStatus = contractStatuses[propertyTokenId];
        SettlementStatus currentStatus = contractStatus.status;
        uint256 currentTime = block.timestamp;

        // Skip if already settled or defaulted
        if (currentStatus == SettlementStatus.SETTLED || currentStatus == SettlementStatus.DEFAULTED) {
            return;
        }

        // Check if contract has ended and settlement period started
        if (currentTime >= contractStatus.contractEndTime && currentStatus == SettlementStatus.ACTIVE) {
            _updateSettlementStatus(propertyTokenId, SettlementStatus.PENDING);
            currentStatus = SettlementStatus.PENDING;
        }

        // Issue warnings if in pending status
        if (currentStatus == SettlementStatus.PENDING) {
            _checkAndIssueWarnings(propertyTokenId);
        }

        // Check if grace period should start
        uint256 warningPeriodEnd = contractStatus.contractEndTime + (warningConfig.firstWarningDays * SECONDS_PER_DAY);
        if (currentTime >= warningPeriodEnd && currentStatus == SettlementStatus.PENDING) {
            contractStatus.gracePeriodStart = currentTime;
            _updateSettlementStatus(propertyTokenId, SettlementStatus.GRACE_PERIOD);
            currentStatus = SettlementStatus.GRACE_PERIOD;
        }

        // Check if contract is overdue
        if (currentTime >= contractStatus.settlementDeadline && currentStatus == SettlementStatus.GRACE_PERIOD) {
            _updateSettlementStatus(propertyTokenId, SettlementStatus.OVERDUE);
            
            // Auto-escalate to marketplace if enabled
            if (warningConfig.autoEscalationEnabled && contractStatus.autoProcessingEnabled) {
                _escalateToMarketplace(propertyTokenId);
            }
        }

        contractStatus.lastStatusUpdate = currentTime;
    }

    /**
     * @dev Internal function to check and issue warnings
     * @param propertyTokenId Property NFT token ID
     */
    function _checkAndIssueWarnings(uint256 propertyTokenId) internal {
        ContractStatus storage contractStatus = contractStatuses[propertyTokenId];
        uint256 currentTime = block.timestamp;
        uint256 timeUntilDeadline = contractStatus.settlementDeadline > currentTime ? 
            contractStatus.settlementDeadline - currentTime : 0;
        
        uint256 daysUntilDeadline = timeUntilDeadline / SECONDS_PER_DAY;
        
        // Check for warning thresholds
        bool shouldWarn = false;
        uint256 warningNumber = 0;
        
        if (daysUntilDeadline <= warningConfig.finalWarningDays && contractStatus.warningsSent < 3) {
            shouldWarn = true;
            warningNumber = 3;
        } else if (daysUntilDeadline <= warningConfig.secondWarningDays && contractStatus.warningsSent < 2) {
            shouldWarn = true;
            warningNumber = 2;
        } else if (daysUntilDeadline <= warningConfig.firstWarningDays && contractStatus.warningsSent < 1) {
            shouldWarn = true;
            warningNumber = 1;
        }
        
        if (shouldWarn && contractStatus.warningsSent < WARNING_THRESHOLD) {
            contractStatus.warningsSent = warningNumber;
            
            emit WarningIssued(
                propertyTokenId,
                contractStatus.tenant,
                warningNumber,
                daysUntilDeadline,
                currentTime
            );
        }
    }

    /**
     * @dev Internal function to escalate contract to P2P marketplace
     * @param propertyTokenId Property NFT token ID
     */
    function _escalateToMarketplace(uint256 propertyTokenId) internal {
        ContractStatus storage contractStatus = contractStatuses[propertyTokenId];
        
        // Mark deposit as defaulted in DepositPool
        depositPool.handleDefault(propertyTokenId);
        
        // Update PropertyNFT status to overdue
        // Note: This would require a function in PropertyNFT to be called by authorized contracts
        
        // Create debt claim in marketplace
        // Note: This would require the marketplace to accept calls from this contract
        
        _updateSettlementStatus(propertyTokenId, SettlementStatus.DEFAULTED);
        totalActiveContracts--;
        totalDefaultedContracts++;

        emit ContractDefaulted(propertyTokenId, contractStatus.tenant, block.timestamp, true);
    }

    /**
     * @dev Internal function to update settlement status with event emission
     * @param propertyTokenId Property NFT token ID
     * @param newStatus New settlement status
     */
    function _updateSettlementStatus(uint256 propertyTokenId, SettlementStatus newStatus) internal {
        ContractStatus storage contractStatus = contractStatuses[propertyTokenId];
        SettlementStatus oldStatus = contractStatus.status;
        contractStatus.status = newStatus;
        
        emit SettlementStatusUpdated(propertyTokenId, oldStatus, newStatus, block.timestamp);
    }

    /**
     * @dev Update warning configuration
     * @param newConfig New warning configuration
     */
    function updateWarningConfig(WarningConfig calldata newConfig) external onlyRole(SETTLEMENT_MANAGER_ROLE) {
        require(newConfig.gracePeriodDays <= 90, "SettlementManager: Grace period too long");
        require(newConfig.firstWarningDays > newConfig.secondWarningDays, "SettlementManager: Invalid warning sequence");
        require(newConfig.secondWarningDays > newConfig.finalWarningDays, "SettlementManager: Invalid warning sequence");
        
        warningConfig = newConfig;
    }

    /**
     * @dev Get contract status information
     * @param propertyTokenId Property NFT token ID
     * @return ContractStatus struct
     */
    function getContractStatus(uint256 propertyTokenId) external view returns (ContractStatus memory) {
        return contractStatuses[propertyTokenId];
    }

    /**
     * @dev Get contracts for a tenant
     * @param tenant Tenant address
     * @return Array of property token IDs
     */
    function getTenantContracts(address tenant) external view returns (uint256[] memory) {
        return tenantContracts[tenant];
    }

    /**
     * @dev Get contracts for a landlord
     * @param landlord Landlord address
     * @return Array of property token IDs
     */
    function getLandlordContracts(address landlord) external view returns (uint256[] memory) {
        return landlordContracts[landlord];
    }

    /**
     * @dev Get current warning configuration
     * @return WarningConfig struct
     */
    function getWarningConfig() external view returns (WarningConfig memory) {
        return warningConfig;
    }

    /**
     * @dev Get settlement statistics
     * @return active Total active contracts
     * @return settled Total settled contracts
     * @return defaulted Total defaulted contracts
     */
    function getSettlementStats() external view returns (
        uint256 active,
        uint256 settled,
        uint256 defaulted
    ) {
        return (totalActiveContracts, totalSettledContracts, totalDefaultedContracts);
    }

    /**
     * @dev Check if a contract needs attention
     * @param propertyTokenId Property NFT token ID
     * @return needsAttention Whether the contract needs attention
     * @return daysRemaining Days remaining until deadline
     * @return currentStatus Current settlement status
     */
    function checkContractHealth(uint256 propertyTokenId) external view returns (
        bool needsAttention,
        uint256 daysRemaining,
        SettlementStatus currentStatus
    ) {
        if (!registeredContracts[propertyTokenId]) {
            return (false, 0, SettlementStatus.ACTIVE);
        }

        ContractStatus memory contractStatus = contractStatuses[propertyTokenId];
        currentStatus = contractStatus.status;
        
        uint256 timeRemaining = contractStatus.settlementDeadline > block.timestamp ? 
            contractStatus.settlementDeadline - block.timestamp : 0;
        daysRemaining = timeRemaining / SECONDS_PER_DAY;
        
        needsAttention = (currentStatus == SettlementStatus.GRACE_PERIOD) || 
                        (currentStatus == SettlementStatus.OVERDUE) ||
                        (daysRemaining <= warningConfig.firstWarningDays && currentStatus == SettlementStatus.PENDING);
                        
        return (needsAttention, daysRemaining, currentStatus);
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
}