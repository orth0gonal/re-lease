// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title Structs
 * @dev Collection of all structs used across Re-Lease platform contracts
 */

// ═══════════════════════════════════════════════════════════════════
// PropertyNFT Contract Structs
// ═══════════════════════════════════════════════════════════════════

/**
 * @dev Property status enumeration
 * Used in: PropertyNFT.sol
 */
enum PropertyStatus {
    PROPOSED,          // Property proposed by landlord, awaiting verification
    PENDING,           // Property listed but not verified
    ACTIVE,            // Property verified and available for rental
    CONTRACT_PENDING,  // Rental contract created by landlord, awaiting verification
    CONTRACT_VERIFIED, // Contract verified by admin, awaiting tenant deposit
    RENTED,            // Property currently rented with deposit
    SETTLEMENT,        // In settlement period
    OVERDUE,           // Settlement overdue, needs P2P marketplace
    COMPLETED,         // Settlement completed successfully
    DISPUTED,          // In dispute resolution
    SUSPENDED          // Property suspended/delisted
}

/**
 * @dev Landlord distribution choice for deposits
 * Used in: PropertyNFT.sol, DepositPool.sol
 */
enum DistributionChoice {
    DIRECT,       // Direct KRW distribution to landlord
    POOL          // Hold in cKRW pool for yield optimization
}

/**
 * @dev Property proposal structure for landlord submissions
 * Used in: PropertyNFT.sol
 */
struct PropertyProposal {
    address landlord;                    // Property owner address
    DistributionChoice distributionChoice; // Landlord's preferred distribution method
    uint256 depositAmount;              // Required deposit amount in KRW
    bool landOwnershipAuthority;        // 땅의 소유권한
    bool landTrustAuthority;            // 땅의 신탁권한  
    uint256 ltv;                        // LTV (Loan-to-Value ratio)
    string registrationAddress;         // 등기 주소
    string propertyDescription;         // 매물 설명
    uint256 proposalTime;               // 제안 시간
    uint256 verificationDeadline;       // 검증 마감일
    bool isProcessed;                   // 처리 상태 (승인/거부됨)
}

/**
 * @dev Property information structure
 * Used in: PropertyNFT.sol
 */
struct Property {
    address landlord;                    // Property owner address
    PropertyStatus status;               // Current property status
    DistributionChoice distributionChoice; // Landlord's preferred distribution method
    uint256 depositAmount;              // Required deposit amount in KRW
    uint256 contractStartTime;          // Rental contract start timestamp
    uint256 contractEndTime;            // Rental contract end timestamp
    uint256 settlementDeadline;         // Settlement deadline timestamp
    address currentTenant;              // Current tenant address
    address proposedTenant;             // Proposed tenant during contract creation
    uint256 proposedDepositAmount;      // Proposed deposit amount during contract creation
    bool isVerified;                    // Property verification status
    uint256 createdAt;                  // Property creation timestamp
    uint256 proposalId;                 // Original proposal ID (0 if not from proposal)
    bool landOwnershipAuthority;        // 땅의 소유권한
    bool landTrustAuthority;            // 땅의 신탁권한  
    uint256 ltv;                        // LTV (Loan-to-Value ratio)
    string registrationAddress;         // 등기 주소
}

// ═══════════════════════════════════════════════════════════════════
// DepositPool Contract Structs
// ═══════════════════════════════════════════════════════════════════

/**
 * @dev Deposit status enumeration
 * Used in: DepositPool.sol
 */
enum DepositStatus {
    PENDING,      // Deposit submitted, waiting for confirmation
    ACTIVE,       // Deposit confirmed and active
    SETTLEMENT,   // In settlement process
    COMPLETED,    // Settlement completed successfully
    DEFAULTED,    // Default occurred, moved to P2P marketplace
    RECOVERED     // Tenant recovered deposit
}

/**
 * @dev Deposit information structure
 * Used in: DepositPool.sol
 */
struct DepositInfo {
    uint256 propertyTokenId;         // Associated property NFT token ID
    address tenant;                  // Tenant who submitted deposit
    address landlord;                // Property landlord
    uint256 krwAmount;              // Original KRW deposit amount
    uint256 cKRWShares;             // cKRW vault shares for this deposit
    uint256 yieldEarned;            // Additional yield earned
    DepositStatus status;           // Current deposit status
    DistributionChoice distributionChoice; // Landlord's choice
    uint256 submissionTime;         // Deposit submission timestamp
    uint256 expectedReturnTime;     // Expected contract end time
    bool isInPool;                  // Whether deposit is retained in pool for yield
    uint256 lastYieldCalculation;   // Last yield calculation timestamp
}

// ═══════════════════════════════════════════════════════════════════
// P2PDebtMarketplace Contract Structs
// ═══════════════════════════════════════════════════════════════════

/**
 * @dev Debt claim status enumeration
 * Used in: P2PDebtMarketplace.sol
 */
enum ClaimStatus {
    LISTED,       // Debt claim listed for sale
    SOLD,         // Debt claim sold to investor
    REPAID,       // Debt repaid by tenant
    LIQUIDATED,   // Debt liquidated due to extended default
    CANCELLED     // Debt claim cancelled
}

/**
 * @dev Debt claim structure - optimized to avoid stack too deep
 * Used in: P2PDebtMarketplace.sol
 */
struct DebtClaim {
    uint256 claimId;                // Unique claim identifier
    uint256 propertyTokenId;        // Associated property NFT token ID
    address originalCreditor;       // Original landlord/creditor
    address currentOwner;           // Current debt claim owner
    address debtor;                 // Landlord/debtor (failed to return deposit)
    uint256 principalAmount;        // Original debt amount
    uint256 currentAmount;          // Current debt amount (principal + interest)
    uint256 creationTime;           // Debt claim creation timestamp
    uint256 repaymentDeadline;      // Final repayment deadline
    ClaimStatus status;             // Current claim status
}

/**
 * @dev Additional claim data structure
 * Used in: P2PDebtMarketplace.sol
 */
struct ClaimMetadata {
    uint256 interestRate;           // Annual interest rate (scaled by 1e18)
    uint256 listingPrice;           // Price at which debt is listed
    uint256 lastInterestUpdate;     // Last interest calculation timestamp
    uint256 totalInterestAccrued;   // Total interest accrued to date
    bool isSecondaryMarket;         // Whether it's a secondary market listing
}

/**
 * @dev Marketplace configuration
 * Used in: P2PDebtMarketplace.sol
 */
struct MarketplaceConfig {
    uint256 platformFeeRate;        // Platform fee rate (scaled by 1e18)
    uint256 defaultInterestRate;    // Default interest rate for new claims
    uint256 maxInterestRate;        // Maximum allowed interest rate
    uint256 liquidationPeriod;      // Period after which claims can be liquidated
    uint256 minListingPrice;        // Minimum listing price
    bool secondaryTradingEnabled;   // Whether secondary trading is allowed
}

// ═══════════════════════════════════════════════════════════════════
// SettlementManager Contract Structs
// ═══════════════════════════════════════════════════════════════════

/**
 * @dev Settlement status enumeration
 * Used in: SettlementManager.sol
 */
enum SettlementStatus {
    ACTIVE,           // Contract is active, no settlement needed
    PENDING,          // Settlement period started
    GRACE_PERIOD,     // In grace period, warning issued
    OVERDUE,          // Grace period expired, escalation needed
    SETTLED,          // Successfully settled
    DEFAULTED         // Settlement failed, moved to marketplace
}

/**
 * @dev Contract monitoring structure
 * Used in: SettlementManager.sol
 */
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
    bool autoProcessingEnabled;     // Whether automatic processing is enabled
    string notes;                   // Additional notes for the settlement
}

/**
 * @dev Warning configuration
 * Used in: SettlementManager.sol
 */
struct WarningConfig {
    uint256 firstWarningDays;       // Days before deadline for first warning
    uint256 secondWarningDays;      // Days before deadline for second warning
    uint256 finalWarningDays;       // Days before deadline for final warning
    uint256 gracePeriodDays;        // Grace period duration in days
    bool autoEscalationEnabled;     // Whether to auto-escalate to marketplace
}