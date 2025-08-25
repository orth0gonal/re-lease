// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title Events
 * @dev Collection of all events used across Re-Lease platform contracts
 */

import "./Structs.sol";

/**
 * @title IPropertyNFTEvents
 * @dev Events from PropertyNFT contract
 */
interface IPropertyNFTEvents {
    /**
     * @dev Emitted when a property is proposed by landlord
     * Used in: PropertyNFT.sol
     */
    event PropertyProposed(
        uint256 indexed proposalId,
        address indexed landlord,
        DistributionChoice distributionChoice,
        uint256 depositAmount,
        uint256 ltv,
        bytes32 registrationAddress,
        bytes32 propertyDescription
    );

    /**
     * @dev Emitted when a property proposal is approved
     * Used in: PropertyNFT.sol
     */
    event PropertyProposalApproved(
        uint256 indexed proposalId,
        uint256 indexed tokenId,
        address indexed verifier
    );

    /**
     * @dev Emitted when a property proposal is rejected
     * Used in: PropertyNFT.sol
     */
    event PropertyProposalRejected(
        uint256 indexed proposalId,
        address indexed verifier,
        string reason
    );

    /**
     * @dev Emitted when a new property NFT is minted
     * Used in: PropertyNFT.sol
     */
    event PropertyMinted(
        uint256 indexed tokenId,
        address indexed landlord,
        DistributionChoice distributionChoice,
        uint256 depositAmount,
        uint256 ltv,
        bytes32 registrationAddress
    );

    /**
     * @dev Emitted when property status is updated
     * Used in: PropertyNFT.sol
     */
    event PropertyStatusUpdated(
        uint256 indexed tokenId,
        PropertyStatus oldStatus,
        PropertyStatus newStatus
    );

    /**
     * @dev Emitted when a property is rented
     * Used in: PropertyNFT.sol
     */
    event PropertyRented(
        uint256 indexed tokenId,
        address indexed tenant,
        uint256 contractStartTime,
        uint256 contractEndTime
    );

    /**
     * @dev Emitted when settlement process is initiated
     * Used in: PropertyNFT.sol
     */
    event SettlementInitiated(
        uint256 indexed tokenId,
        uint256 settlementDeadline
    );

    /**
     * @dev Emitted when property becomes overdue
     * Used in: PropertyNFT.sol
     */
    event PropertyOverdue(
        uint256 indexed tokenId,
        uint256 overdueTimestamp
    );

    /**
     * @dev Emitted when landlord's distribution choice is updated
     * Used in: PropertyNFT.sol
     */
    event DistributionChoiceUpdated(
        uint256 indexed tokenId,
        DistributionChoice oldChoice,
        DistributionChoice newChoice
    );

    /**
     * @dev Emitted when a rental contract is created by landlord
     * Used in: PropertyNFT.sol
     */
    event RentalContractCreated(
        uint256 indexed tokenId,
        address indexed proposedTenant,
        uint256 contractStartTime,
        uint256 contractEndTime,
        uint256 proposedDepositAmount
    );

    /**
     * @dev Emitted when rental contract is verified by admin
     * Used in: PropertyNFT.sol
     */
    event RentalContractVerified(
        uint256 indexed tokenId,
        address indexed verifier
    );

    /**
     * @dev Emitted when rental contract is finalized after deposit
     * Used in: PropertyNFT.sol
     */
    event RentalContractFinalized(
        uint256 indexed tokenId,
        address indexed tenant
    );
}

/**
 * @title IDepositPoolEvents
 * @dev Events from DepositPool contract
 */
interface IDepositPoolEvents {
    /**
     * @dev Emitted when a deposit is submitted
     * Used in: DepositPool.sol
     */
    event DepositSubmitted(
        uint256 indexed propertyTokenId,
        address indexed tenant,
        address indexed landlord,
        uint256 krwAmount,
        uint256 cKRWShares,
        DistributionChoice distributionChoice
    );

    /**
     * @dev Emitted when a deposit is activated
     * Used in: DepositPool.sol
     */
    event DepositActivated(
        uint256 indexed propertyTokenId,
        address indexed tenant,
        uint256 expectedReturnTime
    );

    /**
     * @dev Emitted when deposit is distributed to landlord
     * Used in: DepositPool.sol
     */
    event DepositDistributed(
        uint256 indexed propertyTokenId,
        address indexed landlord,
        uint256 krwAmount,
        DistributionChoice distributionChoice
    );

    /**
     * @dev Emitted when deposit is retained in pool for yield
     * Used in: DepositPool.sol
     */
    event DepositRetainedInPool(
        uint256 indexed propertyTokenId,
        uint256 cKRWShares,
        uint256 expectedYield
    );

    /**
     * @dev Emitted when yield is calculated for a deposit
     * Used in: DepositPool.sol
     */
    event YieldCalculated(
        uint256 indexed propertyTokenId,
        uint256 yieldAmount,
        uint256 totalAccumulated
    );

    /**
     * @dev Emitted when tenant recovers their deposit
     * Used in: DepositPool.sol
     */
    event DepositRecovered(
        uint256 indexed propertyTokenId,
        address indexed tenant,
        uint256 krwAmount,
        uint256 yieldAmount
    );

    /**
     * @dev Emitted when yield rate is updated
     * Used in: DepositPool.sol
     */
    event YieldRateUpdated(
        uint256 oldRate,
        uint256 newRate
    );

    /**
     * @dev Emitted when deposit default is handled
     * Used in: DepositPool.sol
     */
    event DepositDefaultHandled(
        uint256 indexed propertyTokenId,
        address indexed tenant,
        uint256 krwAmount
    );
}

/**
 * @title IP2PDebtMarketplaceEvents
 * @dev Events from P2PDebtMarketplace contract
 */
interface IP2PDebtMarketplaceEvents {
    /**
     * @dev Emitted when a debt claim is listed for sale
     * Used in: P2PDebtMarketplace.sol
     */
    event DebtClaimListed(
        uint256 indexed claimId,
        uint256 indexed propertyTokenId,
        address indexed creditor,
        address debtor,
        uint256 principalAmount,
        uint256 listingPrice,
        uint256 interestRate
    );

    /**
     * @dev Emitted when a debt claim is purchased
     * Used in: P2PDebtMarketplace.sol
     */
    event DebtClaimPurchased(
        uint256 indexed claimId,
        address indexed buyer,
        address indexed seller,
        uint256 purchasePrice,
        uint256 platformFee
    );

    /**
     * @dev Emitted when debt is repaid
     * Used in: P2PDebtMarketplace.sol
     */
    event DebtRepaid(
        uint256 indexed claimId,
        address indexed debtor,
        uint256 repaidAmount,
        uint256 interestPaid
    );

    /**
     * @dev Emitted when debt claim is liquidated
     * Used in: P2PDebtMarketplace.sol
     */
    event DebtLiquidated(
        uint256 indexed claimId,
        address indexed liquidator,
        uint256 recoveredAmount
    );

    /**
     * @dev Emitted when interest accrues on a debt claim
     * Used in: P2PDebtMarketplace.sol
     */
    event InterestAccrued(
        uint256 indexed claimId,
        uint256 interestAmount,
        uint256 newTotalAmount
    );

    /**
     * @dev Emitted when marketplace configuration is updated
     * Used in: P2PDebtMarketplace.sol
     */
    event ConfigUpdated(
        uint256 newPlatformFeeRate,
        uint256 newDefaultInterestRate,
        uint256 newLiquidationPeriod
    );
}

/**
 * @title ISettlementManagerEvents
 * @dev Events from SettlementManager contract
 */
interface ISettlementManagerEvents {
    /**
     * @dev Emitted when a contract is registered for monitoring
     * Used in: SettlementManager.sol
     */
    event ContractRegistered(
        uint256 indexed propertyTokenId,
        address indexed tenant,
        address indexed landlord,
        uint256 contractEndTime,
        uint256 settlementDeadline
    );

    /**
     * @dev Emitted when settlement status is updated
     * Used in: SettlementManager.sol
     */
    event SettlementStatusUpdated(
        uint256 indexed propertyTokenId,
        SettlementStatus oldStatus,
        SettlementStatus newStatus,
        uint256 timestamp
    );

    /**
     * @dev Emitted when a warning is issued to tenant/landlord
     * Used in: SettlementManager.sol
     */
    event WarningIssued(
        uint256 indexed propertyTokenId,
        address indexed tenant,
        uint256 warningNumber,
        uint256 daysRemaining,
        uint256 timestamp
    );

    /**
     * @dev Emitted when settlement is completed successfully
     * Used in: SettlementManager.sol
     */
    event SettlementCompleted(
        uint256 indexed propertyTokenId,
        address indexed tenant,
        uint256 completionTime
    );

    /**
     * @dev Emitted when contract defaults and goes to marketplace
     * Used in: SettlementManager.sol
     */
    event ContractDefaulted(
        uint256 indexed propertyTokenId,
        address indexed tenant,
        uint256 defaultTime,
        bool escalatedToMarketplace
    );

    /**
     * @dev Emitted when batch processing is completed
     * Used in: SettlementManager.sol
     */
    event BatchProcessingCompleted(
        uint256 contractsProcessed,
        uint256 warningsIssued,
        uint256 escalations
    );

    /**
     * @dev Emitted when grace period is extended
     * Used in: SettlementManager.sol
     */
    event GracePeriodExtended(
        uint256 indexed propertyTokenId,
        uint256 newDeadline,
        string reason
    );
}

/**
 * @title IKRWTokenEvents
 * @dev Events from KRWToken contract
 */
interface IKRWTokenEvents {
    /**
     * @dev Emitted when tokens are minted
     * Used in: KRWToken.sol
     */
    event TokensMinted(address indexed to, uint256 amount);

    /**
     * @dev Emitted when tokens are burned
     * Used in: KRWToken.sol
     */
    event TokensBurned(address indexed from, uint256 amount);
}