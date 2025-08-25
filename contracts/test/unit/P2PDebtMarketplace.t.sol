// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../../src/P2PDebtMarketplace.sol";
import "../../src/PropertyNFT.sol";
import "../../src/DepositPool.sol";
import "../../src/KRWToken.sol";
import "../../src/interfaces/Structs.sol";
contract P2PDebtMarketplaceUnitTest is Test {
    P2PDebtMarketplace public marketplace;
    PropertyNFT public propertyNFT;
    DepositPool public depositPool;
    KRWToken public krwToken;
    // Test accounts with specific roles
    address public admin = makeAddr("admin");
    address public marketplaceAdmin = makeAddr("marketplaceAdmin");
    address public feeManager = makeAddr("feeManager");
    address public verifier = makeAddr("verifier");
    address public landlord1 = makeAddr("landlord1"); // will become debtor
    address public tenant1 = makeAddr("tenant1");
    address public assignee1 = makeAddr("assignee1"); // debt claim purchaser
    address public assignee2 = makeAddr("assignee2");
    address public unauthorized = makeAddr("unauthorized");
    // Test data
    uint256 public constant TEST_DEPOSIT_AMOUNT = 100_000_000 * 1e18; // 100M KRW
    uint256 public constant LISTING_PRICE = 95_000_000 * 1e18; // 95M KRW (5% discount)
    uint256 public constant INTEREST_RATE = 500; // 5% annual interest in basis points
    uint256 public constant PLATFORM_FEE_RATE = 100; // 1% in basis points
    uint256 public constant TEST_LTV = 7000; // 70%
    bytes32 public constant TEST_ADDRESS = keccak256("Seoul, Gangnam-gu");
    bytes32 public constant TEST_DESCRIPTION = keccak256("3-bedroom apartment");
    function setUp() public {
        vm.startPrank(admin);
        // Deploy contracts
        krwToken = new KRWToken(2_000_000_000 * 1e18); // 2B KRW initial supply
        propertyNFT = new PropertyNFT();
        depositPool = new DepositPool(address(propertyNFT), address(krwToken), 500);
        marketplace = new P2PDebtMarketplace(
            address(propertyNFT),
            address(depositPool),
            address(krwToken)
        );
        // Setup roles
        propertyNFT.grantRole(propertyNFT.PROPERTY_VERIFIER_ROLE(), verifier);
        marketplace.grantRole(marketplace.MARKETPLACE_ADMIN_ROLE(), marketplaceAdmin);
        marketplace.grantRole(marketplace.FEE_MANAGER_ROLE(), feeManager);
        // Update marketplace config (platformFee, interestRate, liquidationPeriod)
        marketplace.updateConfig(PLATFORM_FEE_RATE, 1500, 30 days); // 1% fee, 15% interest, 30d liquidation
        // Distribute KRW tokens
        krwToken.transfer(assignee1, 500_000_000 * 1e18); // 500M KRW to assignee1
        krwToken.transfer(assignee2, 300_000_000 * 1e18); // 300M KRW to assignee2
        krwToken.transfer(landlord1, 200_000_000 * 1e18); // 200M KRW to landlord1
        vm.stopPrank();
    }
    // Helper function to create a property in overdue status (ready for marketplace)
    function _createOverdueProperty() internal returns (uint256 tokenId) {
        // Create and verify property
        vm.prank(landlord1);
        uint256 proposalId = propertyNFT.proposeProperty(
            DistributionChoice.POOL,
            TEST_DEPOSIT_AMOUNT,
            true, false, TEST_LTV, TEST_ADDRESS, TEST_DESCRIPTION
        );
        vm.startPrank(verifier);
        tokenId = propertyNFT.approvePropertyProposal(proposalId);
        propertyNFT.verifyProperty(tokenId);
        vm.stopPrank();
        // Create rental contract
        vm.prank(landlord1);
        propertyNFT.createRentalContract(
            tokenId,
            tenant1,
            block.timestamp,
            block.timestamp + 365 days,
            TEST_DEPOSIT_AMOUNT
        );
        vm.prank(verifier);
        propertyNFT.verifyRentalContract(tokenId);
        // Mark as overdue (simulating failed settlement)
        vm.prank(landlord1);
        propertyNFT.checkSettlementOverdue(tokenId);
    }
    // ═══════════════════════════════════════════════════════════════════
    // Debt Claim Listing Tests
    // ═══════════════════════════════════════════════════════════════════
    function testListDebtClaim() public {
        uint256 tokenId = _createOverdueProperty();
        // CALLER: marketplaceAdmin (has MARKETPLACE_ADMIN_ROLE)
        vm.startPrank(marketplaceAdmin);
        uint256 claimId = marketplace.listDebtClaim(
            tokenId,
            TEST_DEPOSIT_AMOUNT, // principal amount
            LISTING_PRICE,
            INTEREST_RATE
        );
        vm.stopPrank();
        // Verify debt claim was created
        (DebtClaim memory claim,) = marketplace.getDebtClaim(claimId);
        assertEq(claim.claimId, claimId);
        assertEq(claim.propertyTokenId, tokenId);
        assertEq(claim.originalCreditor, tenant1); // tenant is the creditor
        assertEq(claim.currentOwner, address(0)); // not sold yet
        assertEq(claim.debtor, landlord1);
        assertEq(claim.principalAmount, TEST_DEPOSIT_AMOUNT);
        assertEq(claim.currentAmount, TEST_DEPOSIT_AMOUNT); // no interest accrued yet
        assertEq(uint(claim.status), uint(ClaimStatus.LISTED));
        // Verify metadata
        ClaimMetadata memory metadata = marketplace.getDebtClaimMetadata(claimId);
        assertEq(metadata.interestRate, INTEREST_RATE);
        assertEq(metadata.listingPrice, LISTING_PRICE);
        assertFalse(metadata.isSecondaryMarket);
    }
    function testListDebtClaimUnauthorized() public {
        uint256 tokenId = _createOverdueProperty();
        // CALLER: unauthorized user (no MARKETPLACE_ADMIN_ROLE)
        vm.startPrank(unauthorized);
        bytes32 requiredRole = marketplace.MARKETPLACE_ADMIN_ROLE();
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                unauthorized,
                requiredRole
            )
        );
        marketplace.listDebtClaim(
            tokenId,
            TEST_DEPOSIT_AMOUNT,
            LISTING_PRICE,
            INTEREST_RATE
        );
        vm.stopPrank();
    }
    function testListDebtClaimInvalidProperty() public {
        // Create property but don't mark as overdue
        vm.prank(landlord1);
        uint256 proposalId = propertyNFT.proposeProperty(
            DistributionChoice.POOL,
            TEST_DEPOSIT_AMOUNT,
            true, false, TEST_LTV, TEST_ADDRESS, TEST_DESCRIPTION
        );
        vm.startPrank(verifier);
        uint256 tokenId = propertyNFT.approvePropertyProposal(proposalId);
        propertyNFT.verifyProperty(tokenId);
        vm.stopPrank();
        // CALLER: marketplaceAdmin
        vm.startPrank(marketplaceAdmin);
        vm.expectRevert("P2PDebtMarketplace: Property not in overdue status");
        marketplace.listDebtClaim(
            tokenId,
            TEST_DEPOSIT_AMOUNT,
            LISTING_PRICE,
            INTEREST_RATE
        );
        vm.stopPrank();
    }
    // ═══════════════════════════════════════════════════════════════════
    // Debt Claim Purchase Tests
    // ═══════════════════════════════════════════════════════════════════
    function testPurchaseDebtClaim() public {
        // Setup: Create and list debt claim
        uint256 tokenId = _createOverdueProperty();
        vm.prank(marketplaceAdmin);
        uint256 claimId = marketplace.listDebtClaim(
            tokenId,
            TEST_DEPOSIT_AMOUNT,
            LISTING_PRICE,
            INTEREST_RATE
        );
        // CALLER: assignee1 (debt claim purchaser)
        vm.startPrank(assignee1);
        krwToken.approve(address(marketplace), LISTING_PRICE);
        uint256 assigneeBalanceBefore = krwToken.balanceOf(assignee1);
        uint256 tenantBalanceBefore = krwToken.balanceOf(tenant1);
        uint256 platformBalanceBefore = krwToken.balanceOf(admin);
        marketplace.purchaseDebtClaim(claimId);
        uint256 assigneeBalanceAfter = krwToken.balanceOf(assignee1);
        uint256 tenantBalanceAfter = krwToken.balanceOf(tenant1);
        uint256 platformBalanceAfter = krwToken.balanceOf(admin);
        vm.stopPrank();
        // Calculate expected amounts
        uint256 platformFee = (LISTING_PRICE * PLATFORM_FEE_RATE) / 10000;
        uint256 tenantPayment = LISTING_PRICE - platformFee;
        // Verify payments
        assertEq(assigneeBalanceBefore - assigneeBalanceAfter, LISTING_PRICE);
        assertEq(tenantBalanceAfter - tenantBalanceBefore, tenantPayment);
        assertEq(platformBalanceAfter - platformBalanceBefore, platformFee);
        // Verify claim ownership transferred
        (DebtClaim memory claim,) = marketplace.getDebtClaim(claimId);
        assertEq(claim.currentOwner, assignee1);
        assertEq(uint(claim.status), uint(ClaimStatus.SOLD));
    }
    function testPurchaseDebtClaimInsufficientApproval() public {
        // Setup: Create and list debt claim
        uint256 tokenId = _createOverdueProperty();
        vm.prank(marketplaceAdmin);
        uint256 claimId = marketplace.listDebtClaim(
            tokenId,
            TEST_DEPOSIT_AMOUNT,
            LISTING_PRICE,
            INTEREST_RATE
        );
        // CALLER: assignee1 with insufficient approval
        vm.startPrank(assignee1);
        krwToken.approve(address(marketplace), LISTING_PRICE - 1);
        vm.expectRevert("ERC20: insufficient allowance");
        marketplace.purchaseDebtClaim(claimId);
        vm.stopPrank();
    }
    function testPurchaseDebtClaimAlreadySold() public {
        // Setup: Create, list and sell debt claim
        uint256 tokenId = _createOverdueProperty();
        vm.prank(marketplaceAdmin);
        uint256 claimId = marketplace.listDebtClaim(
            tokenId,
            TEST_DEPOSIT_AMOUNT,
            LISTING_PRICE,
            INTEREST_RATE
        );
        // First purchase by assignee1
        vm.startPrank(assignee1);
        krwToken.approve(address(marketplace), LISTING_PRICE);
        marketplace.purchaseDebtClaim(claimId);
        vm.stopPrank();
        // CALLER: assignee2 trying to purchase already sold claim
        vm.startPrank(assignee2);
        krwToken.approve(address(marketplace), LISTING_PRICE);
        vm.expectRevert("P2PDebtMarketplace: Claim not available for purchase");
        marketplace.purchaseDebtClaim(claimId);
        vm.stopPrank();
    }
    // ═══════════════════════════════════════════════════════════════════
    // Interest Calculation Tests
    // ═══════════════════════════════════════════════════════════════════
    function testCalculateInterest() public {
        // Setup: Create and sell debt claim
        uint256 tokenId = _createOverdueProperty();
        vm.prank(marketplaceAdmin);
        uint256 claimId = marketplace.listDebtClaim(
            tokenId,
            TEST_DEPOSIT_AMOUNT,
            LISTING_PRICE,
            INTEREST_RATE
        );
        vm.startPrank(assignee1);
        krwToken.approve(address(marketplace), LISTING_PRICE);
        marketplace.purchaseDebtClaim(claimId);
        vm.stopPrank();
        // Fast forward 1 year
        vm.warp(block.timestamp + 365 days);
        // CALLER: anyone can call updateInterest
        marketplace.updateInterest(claimId);
        
        // Get accrued interest from metadata
        ClaimMetadata memory metadata = marketplace.getDebtClaimMetadata(claimId);
        uint256 interestAccrued = metadata.totalInterestAccrued;
        // Verify interest was calculated (should be approximately 5% of principal)
        uint256 expectedInterest = (TEST_DEPOSIT_AMOUNT * INTEREST_RATE) / 10000;
        assertApproxEqRel(interestAccrued, expectedInterest, 1e16); // 1% tolerance
        // Verify claim was updated
        (DebtClaim memory claim,) = marketplace.getDebtClaim(claimId);
        assertEq(claim.currentAmount, TEST_DEPOSIT_AMOUNT + interestAccrued);
    }
    function testCalculateInterestNotSold() public {
        // Setup: Create debt claim but don't sell
        uint256 tokenId = _createOverdueProperty();
        vm.prank(marketplaceAdmin);
        uint256 claimId = marketplace.listDebtClaim(
            tokenId,
            TEST_DEPOSIT_AMOUNT,
            LISTING_PRICE,
            INTEREST_RATE
        );
        vm.warp(block.timestamp + 365 days);
        // Interest should not accrue for unsold claims
        marketplace.updateInterest(claimId);
        ClaimMetadata memory metadata = marketplace.getDebtClaimMetadata(claimId);
        assertEq(metadata.totalInterestAccrued, 0);
    }
    // ═══════════════════════════════════════════════════════════════════
    // Debt Repayment Tests
    // ═══════════════════════════════════════════════════════════════════
    function testRepayDebt() public {
        // Setup: Create, sell debt claim and accrue some interest
        uint256 tokenId = _createOverdueProperty();
        vm.prank(marketplaceAdmin);
        uint256 claimId = marketplace.listDebtClaim(
            tokenId,
            TEST_DEPOSIT_AMOUNT,
            LISTING_PRICE,
            INTEREST_RATE
        );
        vm.startPrank(assignee1);
        krwToken.approve(address(marketplace), LISTING_PRICE);
        marketplace.purchaseDebtClaim(claimId);
        vm.stopPrank();
        // Fast forward and calculate interest
        vm.warp(block.timestamp + 180 days); // 6 months
        marketplace.updateInterest(claimId);
        (DebtClaim memory claimBefore,) = marketplace.getDebtClaim(claimId);
        uint256 totalOwed = claimBefore.currentAmount;
        // CALLER: landlord1 (debtor)
        vm.startPrank(landlord1);
        krwToken.approve(address(marketplace), totalOwed);
        uint256 landlordBalanceBefore = krwToken.balanceOf(landlord1);
        uint256 assigneeBalanceBefore = krwToken.balanceOf(assignee1);
        marketplace.repayDebt(claimId);
        uint256 landlordBalanceAfter = krwToken.balanceOf(landlord1);
        uint256 assigneeBalanceAfter = krwToken.balanceOf(assignee1);
        vm.stopPrank();
        // Verify payments
        assertEq(landlordBalanceBefore - landlordBalanceAfter, totalOwed);
        assertEq(assigneeBalanceAfter - assigneeBalanceBefore, totalOwed);
        // Verify claim status
        (DebtClaim memory claimAfter,) = marketplace.getDebtClaim(claimId);
        assertEq(uint(claimAfter.status), uint(ClaimStatus.REPAID));
    }
    function testRepayDebtUnauthorized() public {
        // Setup: Create and sell debt claim
        uint256 tokenId = _createOverdueProperty();
        vm.prank(marketplaceAdmin);
        uint256 claimId = marketplace.listDebtClaim(
            tokenId,
            TEST_DEPOSIT_AMOUNT,
            LISTING_PRICE,
            INTEREST_RATE
        );
        vm.startPrank(assignee1);
        krwToken.approve(address(marketplace), LISTING_PRICE);
        marketplace.purchaseDebtClaim(claimId);
        vm.stopPrank();
        // CALLER: unauthorized user (not the debtor)
        vm.startPrank(unauthorized);
        krwToken.approve(address(marketplace), TEST_DEPOSIT_AMOUNT);
        vm.expectRevert("P2PDebtMarketplace: Only debtor can repay");
        marketplace.repayDebt(claimId);
        vm.stopPrank();
    }
    function testRepayDebtInvalidStatus() public {
        // Setup: Create debt claim but don't sell
        uint256 tokenId = _createOverdueProperty();
        vm.prank(marketplaceAdmin);
        uint256 claimId = marketplace.listDebtClaim(
            tokenId,
            TEST_DEPOSIT_AMOUNT,
            LISTING_PRICE,
            INTEREST_RATE
        );
        // CALLER: landlord1 trying to repay unsold claim
        vm.startPrank(landlord1);
        krwToken.approve(address(marketplace), TEST_DEPOSIT_AMOUNT);
        vm.expectRevert("P2PDebtMarketplace: Claim not in repayable state");
        marketplace.repayDebt(claimId);
        vm.stopPrank();
    }
    // ═══════════════════════════════════════════════════════════════════
    // Platform Configuration Tests
    // ═══════════════════════════════════════════════════════════════════
    function testUpdateConfig() public {
        // CALLER: feeManager (has FEE_MANAGER_ROLE)
        vm.startPrank(feeManager);
        uint256 newFeeRate = 150; // 1.5%
        uint256 newInterestRate = 1200; // 12%  
        uint256 newLiquidationPeriod = 60 days;
        marketplace.updateConfig(newFeeRate, newInterestRate, newLiquidationPeriod);
        (uint256 platformFeeRate, uint256 defaultInterestRate,,,,) = marketplace.config();
        assertEq(platformFeeRate, newFeeRate);
        assertEq(defaultInterestRate, newInterestRate);
        vm.stopPrank();
    }
    function testUpdateConfigUnauthorized() public {
        // CALLER: unauthorized user (no FEE_MANAGER_ROLE)
        vm.startPrank(unauthorized);
        bytes32 requiredRole = marketplace.FEE_MANAGER_ROLE();
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                unauthorized,
                requiredRole
            )
        );
        marketplace.updateConfig(150, 1200, 60 days);
        vm.stopPrank();
    }
    function testUpdateConfigInvalid() public {
        // CALLER: feeManager
        vm.startPrank(feeManager);
        // Test fee rate too high (over 10%)
        vm.expectRevert("P2PDebtMarketplace: Fee rate too high");
        marketplace.updateConfig(1001, 1200, 60 days);
        vm.stopPrank();
    }
    // ═══════════════════════════════════════════════════════════════════
    // Secondary Market Tests  
    // ═══════════════════════════════════════════════════════════════════
    function testEnableSecondaryTrading() public {
        // CALLER: marketplaceAdmin (has MARKETPLACE_ADMIN_ROLE)
        vm.startPrank(marketplaceAdmin);
        marketplace.setSecondaryTradingEnabled(true);
        (,,,,, bool secondaryTradingEnabled) = marketplace.config();
        assertTrue(secondaryTradingEnabled);
        vm.stopPrank();
    }
    // ═══════════════════════════════════════════════════════════════════
    // Access Control Tests
    // ═══════════════════════════════════════════════════════════════════
    function testRoleManagement() public {
        // CALLER: admin (has DEFAULT_ADMIN_ROLE)
        vm.startPrank(admin);
        address newAdmin = makeAddr("newAdmin");
        // Grant role
        marketplace.grantRole(marketplace.MARKETPLACE_ADMIN_ROLE(), newAdmin);
        assertTrue(marketplace.hasRole(marketplace.MARKETPLACE_ADMIN_ROLE(), newAdmin));
        // Revoke role
        marketplace.revokeRole(marketplace.MARKETPLACE_ADMIN_ROLE(), newAdmin);
        assertFalse(marketplace.hasRole(marketplace.MARKETPLACE_ADMIN_ROLE(), newAdmin));
        vm.stopPrank();
    }
    // ═══════════════════════════════════════════════════════════════════
    // Emergency Pause Tests
    // ═══════════════════════════════════════════════════════════════════
    function testPauseUnpause() public {
        // CALLER: admin (has PAUSER_ROLE)
        vm.startPrank(admin);
        marketplace.pause();
        assertTrue(marketplace.paused());
        marketplace.unpause();
        assertFalse(marketplace.paused());
        vm.stopPrank();
    }
    function testFunctionsWhenPaused() public {
        uint256 tokenId = _createOverdueProperty();
        vm.prank(marketplaceAdmin);
        uint256 claimId = marketplace.listDebtClaim(
            tokenId,
            TEST_DEPOSIT_AMOUNT,
            LISTING_PRICE,
            INTEREST_RATE
        );
        // Pause contract
        vm.prank(admin);
        marketplace.pause();
        // CALLER: assignee1 - should fail when paused
        vm.startPrank(assignee1);
        krwToken.approve(address(marketplace), LISTING_PRICE);
        vm.expectRevert(abi.encodeWithSelector(Pausable.EnforcedPause.selector));
        marketplace.purchaseDebtClaim(claimId);
        vm.stopPrank();
    }
    // ═══════════════════════════════════════════════════════════════════
    // Edge Cases and Error Tests
    // ═══════════════════════════════════════════════════════════════════
    function testListDebtClaimZeroAmount() public {
        uint256 tokenId = _createOverdueProperty();
        // CALLER: marketplaceAdmin
        vm.startPrank(marketplaceAdmin);
        vm.expectRevert("P2PDebtMarketplace: Invalid principal amount");
        marketplace.listDebtClaim(
            tokenId,
            0, // zero principal
            LISTING_PRICE,
            INTEREST_RATE
        );
        vm.stopPrank();
    }
    function testListDebtClaimInvalidInterestRate() public {
        uint256 tokenId = _createOverdueProperty();
        // CALLER: marketplaceAdmin
        vm.startPrank(marketplaceAdmin);
        vm.expectRevert("P2PDebtMarketplace: Interest rate too high");
        marketplace.listDebtClaim(
            tokenId,
            TEST_DEPOSIT_AMOUNT,
            LISTING_PRICE,
            5001 // over 50%
        );
        vm.stopPrank();
    }
    function testGetNonexistentClaim() public {
        vm.expectRevert("P2PDebtMarketplace: Claim does not exist");
        marketplace.getDebtClaim(999);
    }
    function testCalculateInterestNonexistentClaim() public {
        vm.expectRevert("P2PDebtMarketplace: Claim does not exist");
        marketplace.updateInterest(999);
    }
}