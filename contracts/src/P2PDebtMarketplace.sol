// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./PropertyNFT.sol";
import "./DepositPool.sol";
import "./interfaces/Events.sol";
import "./interfaces/Structs.sol";

/**
 * @title P2PDebtMarketplace
 * @dev Peer-to-peer marketplace for trading rental deposit debt claims
 */
contract P2PDebtMarketplace is AccessControl, Pausable, ReentrancyGuard, IP2PDebtMarketplaceEvents {
    using SafeERC20 for IERC20;

    // Role definitions
    bytes32 public constant MARKETPLACE_ADMIN_ROLE = keccak256("MARKETPLACE_ADMIN_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant FEE_MANAGER_ROLE = keccak256("FEE_MANAGER_ROLE");


    // State variables
    PropertyNFT public immutable propertyNFT;
    DepositPool public immutable depositPool;
    IERC20 public immutable krwToken;

    mapping(uint256 => DebtClaim) public debtClaims;           // claimId => DebtClaim
    mapping(uint256 => ClaimMetadata) public claimMetadata;   // claimId => ClaimMetadata
    mapping(uint256 => uint256) public propertyToClaim;       // propertyTokenId => claimId
    mapping(address => uint256[]) public creditorClaims;      // creditor => claimIds[]
    mapping(address => uint256[]) public debtorClaims;        // debtor => claimIds[]

    MarketplaceConfig public config;
    uint256 private _claimIdCounter;
    uint256 public totalActiveClaims;
    uint256 public totalTradingVolume;
    uint256 public totalPlatformFees;

    // Constants
    uint256 public constant INTEREST_RATE_PRECISION = 1e18;
    uint256 public constant FEE_RATE_PRECISION = 1e18;
    uint256 public constant SECONDS_PER_YEAR = 365 days;
    uint256 public constant MAX_INTEREST_RATE = 50e18; // 50% max interest rate


    /**
     * @dev Constructor initializes the marketplace with required dependencies
     * @param _propertyNFT PropertyNFT contract address
     * @param _depositPool DepositPool contract address
     * @param _krwToken KRW stablecoin contract address
     */
    constructor(
        address _propertyNFT,
        address _depositPool,
        address _krwToken
    ) {
        require(_propertyNFT != address(0), "P2PMarketplace: Invalid PropertyNFT address");
        require(_depositPool != address(0), "P2PMarketplace: Invalid DepositPool address");
        require(_krwToken != address(0), "P2PMarketplace: Invalid KRW token address");

        propertyNFT = PropertyNFT(_propertyNFT);
        depositPool = DepositPool(_depositPool);
        krwToken = IERC20(_krwToken);

        // Initialize marketplace configuration
        config = MarketplaceConfig({
            platformFeeRate: 2e16,          // 2% platform fee
            defaultInterestRate: 15e16,     // 15% annual interest rate
            maxInterestRate: MAX_INTEREST_RATE,
            liquidationPeriod: 90 days,     // 90 days liquidation period
            minListingPrice: 10000,         // 10K KRW minimum listing
            secondaryTradingEnabled: true
        });

        _claimIdCounter = 1;

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MARKETPLACE_ADMIN_ROLE, msg.sender);
        _grantRole(PAUSER_ROLE, msg.sender);
        _grantRole(FEE_MANAGER_ROLE, msg.sender);
    }

    /**
     * @dev List a debt claim for sale (called when deposit defaults)
     * @param propertyTokenId Property NFT token ID
     * @param principalAmount Original debt amount
     * @param listingPrice Price at which to list the debt
     * @param interestRate Custom interest rate (0 for default rate)
     * @return claimId The newly created claim ID
     * @notice The landlord automatically becomes the debtor as they failed to return the deposit
     */
    function listDebtClaim(
        uint256 propertyTokenId,
        uint256 principalAmount,
        uint256 listingPrice,
        uint256 interestRate
    ) external onlyRole(MARKETPLACE_ADMIN_ROLE) whenNotPaused returns (uint256) {
        require(principalAmount > 0, "P2PMarketplace: Invalid principal amount");
        require(listingPrice >= config.minListingPrice, "P2PMarketplace: Listing price too low");
        require(propertyToClaim[propertyTokenId] == 0, "P2PMarketplace: Claim already exists");

        // Use default interest rate if not specified
        uint256 finalInterestRate = interestRate == 0 ? config.defaultInterestRate : interestRate;
        require(finalInterestRate <= config.maxInterestRate, "P2PMarketplace: Interest rate too high");

        // Get property information
        Property memory property = propertyNFT.getProperty(propertyTokenId);
        require(property.status == PropertyStatus.OVERDUE, "P2PMarketplace: Property not overdue");

        uint256 claimId = _claimIdCounter++;

        // Create debt claim - landlord is the debtor who failed to return deposit
        debtClaims[claimId] = DebtClaim({
            claimId: claimId,
            propertyTokenId: propertyTokenId,
            originalCreditor: property.landlord,
            currentOwner: property.landlord,
            debtor: property.landlord, // Landlord is the debtor who failed to return deposit
            principalAmount: principalAmount,
            currentAmount: principalAmount,
            creationTime: block.timestamp,
            repaymentDeadline: block.timestamp + config.liquidationPeriod,
            status: ClaimStatus.LISTED
        });

        // Create claim metadata
        claimMetadata[claimId] = ClaimMetadata({
            interestRate: finalInterestRate,
            listingPrice: listingPrice,
            lastInterestUpdate: block.timestamp,
            totalInterestAccrued: 0,
            isSecondaryMarket: false
        });

        // Update mappings
        propertyToClaim[propertyTokenId] = claimId;
        creditorClaims[property.landlord].push(claimId);
        debtorClaims[property.landlord].push(claimId); // Landlord is the debtor
        totalActiveClaims++;

        emit DebtClaimListed(
            claimId,
            propertyTokenId,
            property.landlord,
            property.landlord, // Landlord is the debtor who failed to return deposit
            principalAmount,
            listingPrice,
            finalInterestRate
        );

        return claimId;
    }

    /**
     * @dev Purchase a debt claim from the marketplace
     * @param claimId Debt claim ID to purchase
     */
    function purchaseDebtClaim(uint256 claimId) external nonReentrant whenNotPaused {
        DebtClaim storage claim = debtClaims[claimId];
        require(claim.status == ClaimStatus.LISTED, "P2PMarketplace: Claim not available");
        require(claim.currentOwner != msg.sender, "P2PMarketplace: Cannot buy own claim");
        require(block.timestamp < claim.repaymentDeadline, "P2PMarketplace: Claim expired");

        // Calculate accrued interest
        _updateInterest(claimId);

        uint256 purchasePrice = claimMetadata[claimId].listingPrice;
        uint256 platformFee = (purchasePrice * config.platformFeeRate) / FEE_RATE_PRECISION;
        uint256 sellerAmount = purchasePrice - platformFee;

        // Transfer payment from buyer
        krwToken.safeTransferFrom(msg.sender, address(this), purchasePrice);

        // Transfer to seller
        krwToken.safeTransfer(claim.currentOwner, sellerAmount);

        // Update claim ownership
        address previousOwner = claim.currentOwner;
        claim.currentOwner = msg.sender;
        claim.status = ClaimStatus.SOLD;

        // Update creditor mappings
        creditorClaims[msg.sender].push(claimId);

        // Update platform metrics
        totalTradingVolume += purchasePrice;
        totalPlatformFees += platformFee;

        emit DebtClaimPurchased(claimId, msg.sender, previousOwner, purchasePrice, platformFee);
    }

    /**
     * @dev Repay debt to settle the claim (called by landlord as debtor)
     * @param claimId Debt claim ID to repay
     * @notice Only the landlord (debtor) can call this function to repay the debt
     */
    function repayDebt(uint256 claimId) external nonReentrant whenNotPaused {
        DebtClaim storage claim = debtClaims[claimId];
        require(claim.debtor == msg.sender, "P2PMarketplace: Only debtor can repay");
        require(
            claim.status == ClaimStatus.LISTED || claim.status == ClaimStatus.SOLD,
            "P2PMarketplace: Invalid claim status"
        );
        require(block.timestamp < claim.repaymentDeadline, "P2PMarketplace: Repayment deadline passed");

        // Calculate final amount with accrued interest
        _updateInterest(claimId);
        uint256 repaymentAmount = claim.currentAmount;

        // Transfer repayment from debtor to current owner
        krwToken.safeTransferFrom(msg.sender, claim.currentOwner, repaymentAmount);

        // Update claim status
        claim.status = ClaimStatus.REPAID;
        totalActiveClaims--;

        emit DebtRepaid(claimId, msg.sender, repaymentAmount, claimMetadata[claimId].totalInterestAccrued);
    }

    /**
     * @dev List debt claim for secondary market trading
     * @param claimId Debt claim ID to list
     * @param newListingPrice New listing price
     */
    function listForSecondaryTrading(
        uint256 claimId,
        uint256 newListingPrice
    ) external whenNotPaused {
        require(config.secondaryTradingEnabled, "P2PMarketplace: Secondary trading disabled");
        
        DebtClaim storage claim = debtClaims[claimId];
        require(claim.currentOwner == msg.sender, "P2PMarketplace: Only owner can list");
        require(claim.status == ClaimStatus.SOLD, "P2PMarketplace: Invalid status for secondary listing");
        require(newListingPrice >= config.minListingPrice, "P2PMarketplace: Listing price too low");
        require(block.timestamp < claim.repaymentDeadline, "P2PMarketplace: Claim expired");

        // Update interest before listing
        _updateInterest(claimId);

        claimMetadata[claimId].listingPrice = newListingPrice;
        claim.status = ClaimStatus.LISTED;
        claimMetadata[claimId].isSecondaryMarket = true;
    }

    /**
     * @dev Liquidate an expired debt claim
     * @param claimId Debt claim ID to liquidate
     */
    function liquidateDebtClaim(uint256 claimId) external whenNotPaused {
        DebtClaim storage claim = debtClaims[claimId];
        require(
            claim.status == ClaimStatus.LISTED || claim.status == ClaimStatus.SOLD,
            "P2PMarketplace: Invalid status for liquidation"
        );
        require(block.timestamp >= claim.repaymentDeadline, "P2PMarketplace: Liquidation period not reached");

        // Update final interest
        _updateInterest(claimId);

        uint256 recoveredAmount = 0; // In real implementation, this would involve property liquidation
        
        claim.status = ClaimStatus.LIQUIDATED;
        totalActiveClaims--;

        emit DebtLiquidated(claimId, msg.sender, recoveredAmount);
    }

    /**
     * @dev Cancel a debt claim listing
     * @param claimId Debt claim ID to cancel
     */
    function cancelListing(uint256 claimId) external {
        DebtClaim storage claim = debtClaims[claimId];
        require(claim.currentOwner == msg.sender, "P2PMarketplace: Only owner can cancel");
        require(claim.status == ClaimStatus.LISTED, "P2PMarketplace: Claim not listed");

        claim.status = ClaimStatus.CANCELLED;
        totalActiveClaims--;
    }

    /**
     * @dev Update accrued interest for a debt claim
     * @param claimId Debt claim ID
     */
    function updateInterest(uint256 claimId) external {
        require(debtClaims[claimId].claimId != 0, "P2PMarketplace: Claim does not exist");
        _updateInterest(claimId);
    }

    /**
     * @dev Internal function to calculate and update accrued interest
     * @param claimId Debt claim ID
     */
    function _updateInterest(uint256 claimId) internal {
        DebtClaim storage claim = debtClaims[claimId];
        ClaimMetadata storage metadata = claimMetadata[claimId];
        
        if (claim.status == ClaimStatus.REPAID || claim.status == ClaimStatus.LIQUIDATED) {
            return;
        }

        uint256 timeElapsed = block.timestamp - metadata.lastInterestUpdate;
        if (timeElapsed == 0) return;

        uint256 annualInterest = (claim.currentAmount * metadata.interestRate) / INTEREST_RATE_PRECISION;
        uint256 interestAccrued = (annualInterest * timeElapsed) / SECONDS_PER_YEAR;

        claim.currentAmount += interestAccrued;
        metadata.totalInterestAccrued += interestAccrued;
        metadata.lastInterestUpdate = block.timestamp;

        emit InterestAccrued(claimId, interestAccrued, claim.currentAmount);
    }

    /**
     * @dev Update marketplace configuration
     * @param newPlatformFeeRate New platform fee rate
     * @param newDefaultInterestRate New default interest rate
     * @param newLiquidationPeriod New liquidation period
     */
    function updateConfig(
        uint256 newPlatformFeeRate,
        uint256 newDefaultInterestRate,
        uint256 newLiquidationPeriod
    ) external onlyRole(FEE_MANAGER_ROLE) {
        require(newPlatformFeeRate <= 10e16, "P2PMarketplace: Fee rate too high"); // Max 10%
        require(newDefaultInterestRate <= config.maxInterestRate, "P2PMarketplace: Interest rate too high");
        require(newLiquidationPeriod >= 30 days, "P2PMarketplace: Liquidation period too short");

        config.platformFeeRate = newPlatformFeeRate;
        config.defaultInterestRate = newDefaultInterestRate;
        config.liquidationPeriod = newLiquidationPeriod;

        emit ConfigUpdated(newPlatformFeeRate, newDefaultInterestRate, newLiquidationPeriod);
    }

    /**
     * @dev Toggle secondary market trading
     * @param enabled Whether to enable secondary trading
     */
    function setSecondaryTradingEnabled(bool enabled) external onlyRole(MARKETPLACE_ADMIN_ROLE) {
        config.secondaryTradingEnabled = enabled;
    }

    /**
     * @dev Get debt claim information
     * @param claimId Debt claim ID
     * @return claim DebtClaim struct
     * @return metadata ClaimMetadata struct
     */
    function getDebtClaim(uint256 claimId) external view returns (DebtClaim memory claim, ClaimMetadata memory metadata) {
        return (debtClaims[claimId], claimMetadata[claimId]);
    }

    /**
     * @dev Get basic debt claim information
     * @param claimId Debt claim ID
     * @return DebtClaim struct
     */
    function getDebtClaimBasic(uint256 claimId) external view returns (DebtClaim memory) {
        return debtClaims[claimId];
    }

    /**
     * @dev Get debt claim metadata
     * @param claimId Debt claim ID
     * @return ClaimMetadata struct
     */
    function getDebtClaimMetadata(uint256 claimId) external view returns (ClaimMetadata memory) {
        return claimMetadata[claimId];
    }

    /**
     * @dev Get claims owned by an address
     * @param owner Owner address
     * @return Array of claim IDs
     */
    function getCreditorClaims(address owner) external view returns (uint256[] memory) {
        return creditorClaims[owner];
    }

    /**
     * @dev Get claims for a debtor
     * @param debtor Debtor address
     * @return Array of claim IDs
     */
    function getDebtorClaims(address debtor) external view returns (uint256[] memory) {
        return debtorClaims[debtor];
    }

    /**
     * @dev Get marketplace statistics
     * @return activeClaims Total active claims
     * @return tradingVolume Total trading volume
     * @return platformFees Total platform fees collected
     * @return nextClaimId Next claim ID to be assigned
     */
    function getMarketplaceStats() external view returns (
        uint256 activeClaims,
        uint256 tradingVolume,
        uint256 platformFees,
        uint256 nextClaimId
    ) {
        return (totalActiveClaims, totalTradingVolume, totalPlatformFees, _claimIdCounter);
    }

    /**
     * @dev Withdraw accumulated platform fees
     * @param amount Amount to withdraw
     * @param to Recipient address
     */
    function withdrawPlatformFees(
        uint256 amount,
        address to
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(to != address(0), "P2PMarketplace: Invalid recipient");
        require(amount <= totalPlatformFees, "P2PMarketplace: Insufficient fees");
        
        totalPlatformFees -= amount;
        krwToken.safeTransfer(to, amount);
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
     * @dev Emergency withdrawal function
     * @param token Token address to withdraw
     * @param amount Amount to withdraw
     * @param to Recipient address
     */
    function emergencyWithdraw(
        address token,
        uint256 amount,
        address to
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(to != address(0), "P2PMarketplace: Invalid recipient");
        IERC20(token).safeTransfer(to, amount);
    }
}