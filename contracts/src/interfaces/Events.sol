// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title Events
 * @dev Collection of all events used across Re-Lease platform contracts
 * Updated to match docs.md specifications exactly
 */

import "./Structs.sol";

/**
 * @title IPropertyNFTEvents
 * @dev Events from PropertyNFT contract - matches docs.md specification
 */
interface IPropertyNFTEvents {
    /**
     * @dev Emitted when a property is proposed by landlord
     * Used in: PropertyNFT.registerProperty()
     */
    event PropertyProposed(
        uint256 indexed propertyId,
        address indexed landlord,
        uint256 ltv,
        bytes32 registrationAddress
    );

    /**
     * @dev Emitted when a property is approved by verifier
     * Used in: PropertyNFT.approveProperty()
     */
    event PropertyApproved(
        uint256 indexed propertyId,
        address indexed verifier
    );

    /**
     * @dev Emitted when a property is rejected by verifier
     * Used in: PropertyNFT.rejectProperty()
     */
    event PropertyRejected(
        uint256 indexed propertyId,
        address indexed verifier,
        string reason
    );

    /**
     * @dev Emitted when property status is updated
     * Used in: PropertyNFT.sol internal status updates
     */
    event PropertyStatusUpdated(
        uint256 indexed propertyId,
        PropertyStatus oldStatus,
        PropertyStatus newStatus
    );

    /**
     * @dev Emitted when a rental contract is created by landlord
     * Used in: PropertyNFT.createRentalContract()
     */
    event RentalContractCreated(
        uint256 indexed nftId,
        address indexed tenant,
        uint256 principal,
        uint256 contractStartDate,
        uint256 contractEndDate,
        uint256 debtInterestRate
    );

    /**
     * @dev Emitted when debt property is listed for P2P trading
     * Used in: PropertyNFT.listDebtProperty()
     */
    event DebtPropertyListed(
        uint256 indexed nftId,
        uint256 principal,
        uint256 debtInterestRate
    );

    /**
     * @dev Emitted when debt claim is transferred to assignee (P2P purchase)
     * Used in: DepositPool.purchaseDebt()
     */
    event DebtClaimTransferred(
        uint256 indexed nftId,
        address indexed previousCreditor,
        address indexed newCreditor,
        uint256 purchasePrice
    );

    /**
     * @dev Emitted when interest is claimed by creditor
     * Used in: DepositPool.collectDebtRepayment()
     */
    event InterestClaimed(
        uint256 indexed nftId,
        address indexed creditor,
        uint256 interestAmount
    );

    /**
     * @dev Emitted when debt is repaid by landlord (partial or full)
     * Used in: DepositPool.repayDebt()
     */
    event DebtRepaid(
        uint256 indexed nftId,
        address indexed creditor,
        uint256 repayAmount,
        uint256 interestPayment,
        uint256 principalPayment,
        uint256 remainingPrincipal
    );

    /**
     * @dev Emitted when debt is fully repaid - contract completed
     * Used in: DepositPool.repayDebt() when fully paid
     */
    event DebtFullyRepaid(
        uint256 indexed nftId,
        address indexed creditor,
        uint256 finalPayment
    );
}

/**
 * @title IDepositPoolEvents
 * @dev Events from DepositPool contract - matches docs.md specification
 */
interface IDepositPoolEvents {
    /**
     * @dev Emitted when a deposit is submitted
     * Used in: DepositPool.submitPrincipal()
     */
    event DepositSubmitted(
        uint256 indexed nftId,
        address indexed tenant,
        address indexed landlord,
        uint256 krwcAmount
    );

    /**
     * @dev Emitted when deposit is distributed (conversion of KRWC to yKRWC)
     * Used in: DepositPool.submitPrincipal()
     */
    event DepositDistributed(
        uint256 indexed nftId,
        address indexed landlord,
        uint256 yKrwcAmount
    );

    /**
     * @dev Emitted when yield is calculated for a deposit
     * Used in: DepositPool internal yield calculations
     */
    event YieldCalculated(
        uint256 indexed nftId,
        uint256 yieldAmount,
        uint256 totalAccumulated
    );

    /**
     * @dev Emitted when tenant recovers their deposit
     * Used in: DepositPool.recoverPrincipal()
     */
    event DepositRecovered(
        uint256 indexed nftId,
        address indexed tenant,
        uint256 krwcAmount
    );

    /**
     * @dev Emitted when debt is transferred to assignee (P2P purchase)
     * Used in: DepositPool.purchaseDebt()
     */
    event DebtTransferred(
        uint256 indexed nftId,
        address indexed previousCreditor,
        address indexed newCreditor,
        uint256 purchasePrice
    );

    /**
     * @dev Emitted when interest is claimed by creditor
     * Used in: DepositPool.collectDebtRepayment()
     */
    event InterestClaimed(
        uint256 indexed nftId,
        address indexed creditor,
        uint256 interestAmount
    );

    /**
     * @dev Emitted when debt is repaid by landlord (partial or full)
     * Used in: DepositPool.repayDebt()
     */
    event DebtRepaid(
        uint256 indexed nftId,
        address indexed creditor,
        uint256 repayAmount,
        uint256 interestPayment,
        uint256 principalPayment,
        uint256 remainingPrincipal
    );

    /**
     * @dev Emitted when debt is fully repaid - contract completed
     * Used in: DepositPool.repayDebt() when fully paid
     */
    event DebtFullyRepaid(
        uint256 indexed nftId,
        address indexed creditor,
        uint256 finalPayment
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