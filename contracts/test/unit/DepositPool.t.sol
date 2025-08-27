// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../../src/DepositPool.sol";
import "../../src/PropertyNFT.sol";
import "../../src/KRWToken.sol";
import "../../src/interfaces/Structs.sol";

/**
 * @title DepositPoolTest
 * @dev Comprehensive unit tests for DepositPool (ERC-4626 Vault) contract
 */
contract DepositPoolTest is Test {
    DepositPool public depositPool;
    PropertyNFT public propertyNFT;
    KRWToken public krwToken;
    
    // Test accounts
    address public admin = address(0x1);
    address public verifier = admin;
    address public landlord = address(0x3);
    address public tenant = address(0x4);
    address public assignee = address(0x5);
    address public poolManager = admin;
    
    // Test data
    uint256 public constant INITIAL_SUPPLY = 1_000_000_000 * 1e18; // 1B KRWC
    uint256 public constant TEST_PRINCIPAL = 100_000_000 * 1e18; // 100M KRWC
    uint256 public constant TEST_LTV = 8000; // 80%
    bytes32 public constant TEST_ADDRESS = keccak256("123 Test Street, Seoul");
    uint256 public constant TEST_INTEREST_RATE = 500; // 5%
    
    // Events to test
    event DepositSubmitted(uint256 indexed nftId, address indexed tenant, address indexed landlord, uint256 principal);
    event DepositDistributed(uint256 indexed nftId, address indexed landlord, uint256 shares);
    event DepositRecovered(uint256 indexed nftId, address indexed tenant, uint256 principal);
    event DebtTransferred(uint256 indexed nftId, address indexed oldCreditor, address indexed newCreditor, uint256 purchasePrice);
    event InterestClaimed(uint256 indexed nftId, address indexed creditor, uint256 amount);
    event DebtRepaid(uint256 indexed nftId, address indexed creditor, uint256 amount, uint256 remainingPrincipal, uint256 remainingInterest, uint256 totalRemaining);
    event DebtFullyRepaid(uint256 indexed nftId, address indexed creditor, uint256 finalAmount);
    
    function setUp() public {
        vm.startPrank(admin);
        
        // Deploy contracts
        krwToken = new KRWToken(INITIAL_SUPPLY);
        propertyNFT = new PropertyNFT();
        depositPool = new DepositPool(address(propertyNFT), address(krwToken));
        
        // Setup roles
        propertyNFT.grantRole(propertyNFT.PROPERTY_VERIFIER_ROLE(), verifier);
        depositPool.grantRole(depositPool.POOL_MANAGER_ROLE(), poolManager);
        
        vm.stopPrank();
        
        // Distribute tokens
        vm.prank(admin);
        krwToken.transfer(tenant, TEST_PRINCIPAL * 10); // Give tenant enough KRWC
        
        vm.prank(admin);
        krwToken.transfer(landlord, TEST_PRINCIPAL * 5); // Give landlord some KRWC
        
        vm.prank(admin);
        krwToken.transfer(assignee, TEST_PRINCIPAL * 5); // Give assignee some KRWC
    }
    
    // ═══════════════════════════════════════════════════════════════════
    // Helper Functions
    // ═══════════════════════════════════════════════════════════════════
    
    function setupActiveRentalContract() internal returns (uint256 nftId, uint256 propertyId) {
        // Register and approve property
        vm.prank(landlord);
        propertyId = propertyNFT.registerProperty(
            landlord,
            address(0),
            TEST_LTV,
            TEST_ADDRESS
        );
        
        vm.prank(verifier);
        nftId = propertyNFT.approveProperty(propertyId);
        
        // Create rental contract
        uint256 startDate = block.timestamp;
        uint256 endDate = startDate + 365 days;
        
        vm.prank(landlord);
        propertyNFT.createRentalContract(
            nftId,
            tenant,
            startDate,
            endDate,
            TEST_PRINCIPAL,
            TEST_INTEREST_RATE
        );
        
        return (nftId, propertyId);
    }
    
    function setupOutstandingContract() internal returns (uint256 nftId, uint256 propertyId) {
        (nftId, propertyId) = setupActiveRentalContract();
        
        // Submit deposit to activate
        vm.prank(tenant);
        krwToken.approve(address(depositPool), TEST_PRINCIPAL);
        vm.prank(tenant);
        depositPool.submitPrincipal(nftId, TEST_PRINCIPAL);
        
        // Fast forward past contract end + grace period
        RentalContract memory rentalContract = propertyNFT.getRentalContract(nftId);
        vm.warp(rentalContract.endDate + 1 days + 1 seconds);
        
        // Mark as outstanding
        propertyNFT.outstandingProperty(nftId);
        
        return (nftId, propertyId);
    }
    
    // ═══════════════════════════════════════════════════════════════════
    // Constructor Tests
    // ═══════════════════════════════════════════════════════════════════
    
    function test_constructor_Success() public {
        DepositPool newPool = new DepositPool(address(propertyNFT), address(krwToken));
        
        assertEq(address(newPool.propertyNFT()), address(propertyNFT));
        assertEq(address(newPool.asset()), address(krwToken));
        assertEq(newPool.name(), "yKRWC Vault Token");
        assertEq(newPool.symbol(), "yKRWC");
        assertEq(newPool.decimals(), 18);
    }
    
    function test_constructor_InvalidAddresses() public {
        vm.expectRevert("DepositPool: Invalid PropertyNFT address");
        new DepositPool(address(0), address(krwToken));
        
        vm.expectRevert("DepositPool: Invalid KRWC token address");
        new DepositPool(address(propertyNFT), address(0));
    }
    
    // ═══════════════════════════════════════════════════════════════════
    // Submit Principal Tests
    // ═══════════════════════════════════════════════════════════════════
    
    function test_submitPrincipal_Success() public {
        (uint256 nftId,) = setupActiveRentalContract();
        
        uint256 initialLandlordBalance = depositPool.balanceOf(landlord);
        uint256 initialTenantBalance = krwToken.balanceOf(tenant);
        
        vm.prank(tenant);
        krwToken.approve(address(depositPool), TEST_PRINCIPAL);
        
        vm.expectEmit(true, true, true, true);
        emit DepositSubmitted(nftId, tenant, landlord, TEST_PRINCIPAL);
        
        vm.expectEmit(true, true, false, true);
        emit DepositDistributed(nftId, landlord, TEST_PRINCIPAL); // 1:1 conversion initially
        
        vm.prank(tenant);
        depositPool.submitPrincipal(nftId, TEST_PRINCIPAL);
        
        // Check balances
        assertEq(krwToken.balanceOf(tenant), initialTenantBalance - TEST_PRINCIPAL);
        assertGt(depositPool.balanceOf(landlord), initialLandlordBalance);
        
        // Check contract is now active
        RentalContract memory rentalContract = propertyNFT.getRentalContract(nftId);
        assertEq(uint256(rentalContract.status), uint256(RentalContractStatus.ACTIVE));
    }
    
    function test_submitPrincipal_ZeroPrincipal() public {
        (uint256 nftId,) = setupActiveRentalContract();
        
        vm.prank(tenant);
        vm.expectRevert("DepositPool: Principal must be positive");
        depositPool.submitPrincipal(nftId, 0);
    }
    
    function test_submitPrincipal_ContractNotPending() public {
        (uint256 nftId,) = setupActiveRentalContract();
        
        // Submit once to activate
        vm.prank(tenant);
        krwToken.approve(address(depositPool), TEST_PRINCIPAL);
        vm.prank(tenant);
        depositPool.submitPrincipal(nftId, TEST_PRINCIPAL);
        
        // Try to submit again
        vm.prank(tenant);
        krwToken.approve(address(depositPool), TEST_PRINCIPAL);
        vm.prank(tenant);
        vm.expectRevert("DepositPool: Contract not pending");
        depositPool.submitPrincipal(nftId, TEST_PRINCIPAL);
    }
    
    function test_submitPrincipal_OnlyTenant() public {
        (uint256 nftId,) = setupActiveRentalContract();
        
        vm.prank(landlord);
        krwToken.approve(address(depositPool), TEST_PRINCIPAL);
        vm.prank(landlord);
        vm.expectRevert("DepositPool: Only contract tenant can submit deposit");
        depositPool.submitPrincipal(nftId, TEST_PRINCIPAL);
    }
    
    function test_submitPrincipal_IncorrectAmount() public {
        (uint256 nftId,) = setupActiveRentalContract();
        
        vm.prank(tenant);
        krwToken.approve(address(depositPool), TEST_PRINCIPAL + 1000);
        vm.prank(tenant);
        vm.expectRevert("DepositPool: Incorrect principal amount");
        depositPool.submitPrincipal(nftId, TEST_PRINCIPAL + 1000);
    }
    
    function test_submitPrincipal_InvalidTimeRange() public {
        // Create contract with start date too far in future
        vm.prank(landlord);
        uint256 propertyId = propertyNFT.registerProperty(
            landlord,
            address(0),
            TEST_LTV,
            TEST_ADDRESS
        );
        
        vm.prank(verifier);
        uint256 nftId = propertyNFT.approveProperty(propertyId);
        
        uint256 startDate = block.timestamp + 2 days;
        vm.prank(landlord);
        propertyNFT.createRentalContract(
            nftId,
            tenant,
            startDate,
            startDate + 365 days,
            TEST_PRINCIPAL,
            TEST_INTEREST_RATE
        );
        
        vm.prank(tenant);
        krwToken.approve(address(depositPool), TEST_PRINCIPAL);
        vm.prank(tenant);
        vm.expectRevert("DepositPool: Contract start date not within valid range");
        depositPool.submitPrincipal(nftId, TEST_PRINCIPAL);
    }
    
    function test_submitPrincipal_InsufficientBalance() public {
        (uint256 nftId,) = setupActiveRentalContract();
        
        // Create new tenant with no balance
        address poorTenant = address(0x999);
        
        // Update rental contract to use poor tenant
        vm.prank(landlord);
        propertyNFT.createRentalContract(
            nftId + 1, // This will fail, but let's test the balance check
            poorTenant,
            block.timestamp,
            block.timestamp + 365 days,
            TEST_PRINCIPAL,
            TEST_INTEREST_RATE
        );
        
        // The test should check insufficient balance, but since we can't easily 
        // modify existing contracts, let's create a new scenario
        
        // Transfer away most of tenant's balance
        vm.prank(tenant);
        krwToken.transfer(admin, krwToken.balanceOf(tenant) - 1000);
        
        vm.prank(tenant);
        krwToken.approve(address(depositPool), TEST_PRINCIPAL);
        vm.prank(tenant);
        vm.expectRevert("DepositPool: Insufficient KRWC balance");
        depositPool.submitPrincipal(nftId, TEST_PRINCIPAL);
    }
    
    // ═══════════════════════════════════════════════════════════════════
    // Return Principal Tests
    // ═══════════════════════════════════════════════════════════════════
    
    function test_returnPrincipal_WithKRWC() public {
        (uint256 nftId,) = setupActiveRentalContract();
        
        // Submit deposit first
        vm.prank(tenant);
        krwToken.approve(address(depositPool), TEST_PRINCIPAL);
        vm.prank(tenant);
        depositPool.submitPrincipal(nftId, TEST_PRINCIPAL);
        
        uint256 initialPoolBalance = krwToken.balanceOf(address(depositPool));
        uint256 initialLandlordBalance = krwToken.balanceOf(landlord);
        
        // Landlord returns KRWC
        vm.prank(landlord);
        krwToken.approve(address(depositPool), TEST_PRINCIPAL);
        vm.prank(landlord);
        depositPool.returnPrincipal(nftId, true);
        
        // Check balances
        assertEq(krwToken.balanceOf(address(depositPool)), initialPoolBalance + TEST_PRINCIPAL);
        assertEq(krwToken.balanceOf(landlord), initialLandlordBalance - TEST_PRINCIPAL);
    }
    
    function test_returnPrincipal_WithyKRWC() public {
        (uint256 nftId,) = setupActiveRentalContract();
        
        // Submit deposit first
        vm.prank(tenant);
        krwToken.approve(address(depositPool), TEST_PRINCIPAL);
        vm.prank(tenant);
        depositPool.submitPrincipal(nftId, TEST_PRINCIPAL);
        
        uint256 landlordShares = depositPool.balanceOf(landlord);
        assertTrue(landlordShares > 0);
        
        // Landlord returns yKRWC shares
        vm.prank(landlord);
        depositPool.approve(address(depositPool), landlordShares);
        vm.prank(landlord);
        depositPool.returnPrincipal(nftId, false);
        
        // Landlord should have fewer shares now
        assertLt(depositPool.balanceOf(landlord), landlordShares);
    }
    
    function test_returnPrincipal_ContractNotActive() public {
        (uint256 nftId,) = setupActiveRentalContract();
        
        // Don't submit deposit, so contract stays PENDING
        vm.prank(landlord);
        krwToken.approve(address(depositPool), TEST_PRINCIPAL);
        vm.prank(landlord);
        vm.expectRevert("DepositPool: Contract not active");
        depositPool.returnPrincipal(nftId, true);
    }
    
    function test_returnPrincipal_OnlyLandlord() public {
        (uint256 nftId,) = setupActiveRentalContract();
        
        // Submit deposit
        vm.prank(tenant);
        krwToken.approve(address(depositPool), TEST_PRINCIPAL);
        vm.prank(tenant);
        depositPool.submitPrincipal(nftId, TEST_PRINCIPAL);
        
        // Try to return as non-landlord
        vm.prank(tenant);
        krwToken.approve(address(depositPool), TEST_PRINCIPAL);
        vm.prank(tenant);
        vm.expectRevert("DepositPool: Only landlord can return principal");
        depositPool.returnPrincipal(nftId, true);
    }
    
    function test_returnPrincipal_InsufficientShares() public {
        (uint256 nftId,) = setupActiveRentalContract();
        
        // Submit deposit
        vm.prank(tenant);
        krwToken.approve(address(depositPool), TEST_PRINCIPAL);
        vm.prank(tenant);
        depositPool.submitPrincipal(nftId, TEST_PRINCIPAL);
        
        // Transfer away landlord's shares
        uint256 landlordShares = depositPool.balanceOf(landlord);
        vm.prank(landlord);
        depositPool.transfer(admin, landlordShares);
        
        // Try to return yKRWC without shares
        vm.prank(landlord);
        vm.expectRevert("DepositPool: Insufficient yKRWC balance");
        depositPool.returnPrincipal(nftId, false);
    }
    
    // ═══════════════════════════════════════════════════════════════════
    // Recover Principal Tests
    // ═══════════════════════════════════════════════════════════════════
    
    function test_recoverPrincipal_Success() public {
        (uint256 nftId,) = setupActiveRentalContract();
        
        // Submit and return deposit
        vm.prank(tenant);
        krwToken.approve(address(depositPool), TEST_PRINCIPAL);
        vm.prank(tenant);
        depositPool.submitPrincipal(nftId, TEST_PRINCIPAL);
        
        vm.prank(landlord);
        krwToken.approve(address(depositPool), TEST_PRINCIPAL);
        vm.prank(landlord);
        depositPool.returnPrincipal(nftId, true);
        
        uint256 initialTenantBalance = krwToken.balanceOf(tenant);
        
        vm.expectEmit(true, true, false, true);
        emit DepositRecovered(nftId, tenant, TEST_PRINCIPAL);
        
        // Tenant recovers principal
        vm.prank(tenant);
        depositPool.recoverPrincipal(nftId);
        
        // Check balance
        assertEq(krwToken.balanceOf(tenant), initialTenantBalance + TEST_PRINCIPAL);
        
        // Check contract is completed
        RentalContract memory rentalContract = propertyNFT.getRentalContract(nftId);
        assertEq(uint256(rentalContract.status), uint256(RentalContractStatus.COMPLETED));
    }
    
    function test_recoverPrincipal_ContractNotCompleted() public {
        (uint256 nftId,) = setupActiveRentalContract();
        
        // Submit deposit but don't return
        vm.prank(tenant);
        krwToken.approve(address(depositPool), TEST_PRINCIPAL);
        vm.prank(tenant);
        depositPool.submitPrincipal(nftId, TEST_PRINCIPAL);
        
        // Try to recover without landlord returning
        vm.prank(tenant);
        vm.expectRevert("DepositPool: Contract not completed");
        depositPool.recoverPrincipal(nftId);
    }
    
    function test_recoverPrincipal_OnlyTenant() public {
        (uint256 nftId,) = setupActiveRentalContract();
        
        // Submit and return deposit
        vm.prank(tenant);
        krwToken.approve(address(depositPool), TEST_PRINCIPAL);
        vm.prank(tenant);
        depositPool.submitPrincipal(nftId, TEST_PRINCIPAL);
        
        vm.prank(landlord);
        krwToken.approve(address(depositPool), TEST_PRINCIPAL);
        vm.prank(landlord);
        depositPool.returnPrincipal(nftId, true);
        
        // Try to recover as non-tenant
        vm.prank(landlord);
        vm.expectRevert("DepositPool: Only original tenant can recover principal");
        depositPool.recoverPrincipal(nftId);
    }
    
    // ═══════════════════════════════════════════════════════════════════
    // Purchase Debt Tests
    // ═══════════════════════════════════════════════════════════════════
    
    function test_purchaseDebt_Success() public {
        (uint256 nftId,) = setupOutstandingContract();
        
        uint256 purchasePrice = TEST_PRINCIPAL;
        uint256 initialTenantBalance = krwToken.balanceOf(tenant);
        uint256 initialAssigneeBalance = krwToken.balanceOf(assignee);
        
        vm.prank(assignee);
        krwToken.approve(address(depositPool), purchasePrice);
        
        vm.expectEmit(true, true, true, true);
        emit DebtTransferred(nftId, tenant, assignee, purchasePrice);
        
        vm.prank(assignee);
        depositPool.purchaseDebt(nftId, purchasePrice);
        
        // Check balances
        assertEq(krwToken.balanceOf(tenant), initialTenantBalance + purchasePrice);
        assertEq(krwToken.balanceOf(assignee), initialAssigneeBalance - purchasePrice);
        
        // Check debt ownership transferred
        RentalContract memory rentalContract = propertyNFT.getRentalContract(nftId);
        assertEq(rentalContract.tenantOrAssignee, assignee);
    }
    
    function test_purchaseDebt_ContractNotOutstanding() public {
        (uint256 nftId,) = setupActiveRentalContract();
        
        // Submit deposit but don't let contract expire
        vm.prank(tenant);
        krwToken.approve(address(depositPool), TEST_PRINCIPAL);
        vm.prank(tenant);
        depositPool.submitPrincipal(nftId, TEST_PRINCIPAL);
        
        vm.prank(assignee);
        krwToken.approve(address(depositPool), TEST_PRINCIPAL);
        vm.prank(assignee);
        vm.expectRevert("DepositPool: Contract not outstanding");
        depositPool.purchaseDebt(nftId, TEST_PRINCIPAL);
    }
    
    function test_purchaseDebt_CannotPurchaseFromSelf() public {
        (uint256 nftId,) = setupOutstandingContract();
        
        vm.prank(tenant);
        krwToken.approve(address(depositPool), TEST_PRINCIPAL);
        vm.prank(tenant);
        vm.expectRevert("DepositPool: Cannot purchase from self");
        depositPool.purchaseDebt(nftId, TEST_PRINCIPAL);
    }
    
    function test_purchaseDebt_InsufficientBalance() public {
        (uint256 nftId,) = setupOutstandingContract();
        
        // Create assignee with insufficient balance
        address poorAssignee = address(0x999);
        
        vm.prank(poorAssignee);
        vm.expectRevert("DepositPool: Insufficient KRWC balance");
        depositPool.purchaseDebt(nftId, TEST_PRINCIPAL);
    }
    
    // ═══════════════════════════════════════════════════════════════════
    // Debt Repayment Tests
    // ═══════════════════════════════════════════════════════════════════
    
    function test_repayDebt_Success() public {
        (uint256 nftId,) = setupOutstandingContract();
        
        uint256 repayAmount = 10_000_000 * 1e18; // 10M KRWC
        uint256 initialPoolBalance = krwToken.balanceOf(address(depositPool));
        uint256 initialLandlordBalance = krwToken.balanceOf(landlord);
        
        vm.prank(landlord);
        krwToken.approve(address(depositPool), repayAmount);
        
        vm.expectEmit(true, true, false, true);
        emit DebtRepaid(nftId, tenant, repayAmount, 0, 0, 0);
        
        vm.prank(landlord);
        depositPool.repayDebt(nftId, repayAmount);
        
        // Check balances
        assertEq(krwToken.balanceOf(address(depositPool)), initialPoolBalance + repayAmount);
        assertEq(krwToken.balanceOf(landlord), initialLandlordBalance - repayAmount);
    }
    
    function test_repayDebt_FullRepayment() public {
        (uint256 nftId,) = setupOutstandingContract();
        
        // Get total amount needed (should be equal to principal initially)
        RentalContract memory rentalContract = propertyNFT.getRentalContract(nftId);
        uint256 totalOwed = rentalContract.totalRepaidAmount - rentalContract.currentRepaidAmount;
        
        vm.prank(landlord);
        krwToken.approve(address(depositPool), totalOwed);
        
        vm.expectEmit(true, true, false, true);
        emit DebtFullyRepaid(nftId, tenant, totalOwed);
        
        vm.prank(landlord);
        depositPool.repayDebt(nftId, totalOwed);
        
        // Check contract is completed
        RentalContract memory updatedRentalContract = propertyNFT.getRentalContract(nftId);
        assertEq(uint256(updatedRentalContract.status), uint256(RentalContractStatus.COMPLETED));
    }
    
    function test_repayDebt_ZeroAmount() public {
        (uint256 nftId,) = setupOutstandingContract();
        
        vm.prank(landlord);
        vm.expectRevert("DepositPool: Repay amount must be positive");
        depositPool.repayDebt(nftId, 0);
    }
    
    function test_repayDebt_OnlyLandlord() public {
        (uint256 nftId,) = setupOutstandingContract();
        
        uint256 repayAmount = 10_000_000 * 1e18;
        
        vm.prank(tenant);
        krwToken.approve(address(depositPool), repayAmount);
        vm.prank(tenant);
        vm.expectRevert("DepositPool: Only landlord can repay debt");
        depositPool.repayDebt(nftId, repayAmount);
    }
    
    function test_repayDebt_ContractNotOutstanding() public {
        (uint256 nftId,) = setupActiveRentalContract();
        
        uint256 repayAmount = 10_000_000 * 1e18;
        
        vm.prank(landlord);
        krwToken.approve(address(depositPool), repayAmount);
        vm.prank(landlord);
        vm.expectRevert("DepositPool: Contract not outstanding");
        depositPool.repayDebt(nftId, repayAmount);
    }
    
    // ═══════════════════════════════════════════════════════════════════
    // Collect Debt Repayment Tests
    // ═══════════════════════════════════════════════════════════════════
    
    function test_collectDebtRepayment_Success() public {
        (uint256 nftId,) = setupOutstandingContract();
        
        // Make a repayment
        uint256 repayAmount = 10_000_000 * 1e18;
        vm.prank(landlord);
        krwToken.approve(address(depositPool), repayAmount);
        vm.prank(landlord);
        depositPool.repayDebt(nftId, repayAmount);
        
        uint256 initialTenantBalance = krwToken.balanceOf(tenant);
        
        vm.expectEmit(true, true, false, true);
        emit InterestClaimed(nftId, tenant, repayAmount);
        
        // Tenant collects repayment
        vm.prank(tenant);
        uint256 collected = depositPool.collectDebtRepayment(nftId);
        
        assertEq(collected, repayAmount);
        assertEq(krwToken.balanceOf(tenant), initialTenantBalance + repayAmount);
    }
    
    function test_collectDebtRepayment_OnlyCurrentCreditor() public {
        (uint256 nftId,) = setupOutstandingContract();
        
        // Make a repayment
        uint256 repayAmount = 10_000_000 * 1e18;
        vm.prank(landlord);
        krwToken.approve(address(depositPool), repayAmount);
        vm.prank(landlord);
        depositPool.repayDebt(nftId, repayAmount);
        
        // Try to collect as non-creditor
        vm.prank(landlord);
        vm.expectRevert("DepositPool: Only current creditor can collect repayment");
        depositPool.collectDebtRepayment(nftId);
    }
    
    function test_collectDebtRepayment_ContractNotOutstanding() public {
        (uint256 nftId,) = setupActiveRentalContract();
        
        // Submit deposit
        vm.prank(tenant);
        krwToken.approve(address(depositPool), TEST_PRINCIPAL);
        vm.prank(tenant);
        depositPool.submitPrincipal(nftId, TEST_PRINCIPAL);
        
        // Try to collect from active contract
        vm.prank(tenant);
        vm.expectRevert("DepositPool: Contract not outstanding");
        depositPool.collectDebtRepayment(nftId);
    }
    
    function test_collectDebtRepayment_NoUnclaimedAmount() public {
        (uint256 nftId,) = setupOutstandingContract();
        
        // Try to collect without any repayments
        vm.prank(tenant);
        vm.expectRevert("DepositPool: No unclaimed principal and interest");
        depositPool.collectDebtRepayment(nftId);
    }
    
    function test_collectDebtRepayment_AfterDebtTransfer() public {
        (uint256 nftId,) = setupOutstandingContract();
        
        // Transfer debt to assignee
        vm.prank(assignee);
        krwToken.approve(address(depositPool), TEST_PRINCIPAL);
        vm.prank(assignee);
        depositPool.purchaseDebt(nftId, TEST_PRINCIPAL);
        
        // Make a repayment
        uint256 repayAmount = 10_000_000 * 1e18;
        vm.prank(landlord);
        krwToken.approve(address(depositPool), repayAmount);
        vm.prank(landlord);
        depositPool.repayDebt(nftId, repayAmount);
        
        // Assignee should now be able to collect
        uint256 initialAssigneeBalance = krwToken.balanceOf(assignee);
        
        vm.prank(assignee);
        uint256 collected = depositPool.collectDebtRepayment(nftId);
        
        assertEq(collected, repayAmount);
        assertEq(krwToken.balanceOf(assignee), initialAssigneeBalance + repayAmount);
        
        // Original tenant should not be able to collect
        vm.prank(tenant);
        vm.expectRevert("DepositPool: Only current creditor can collect repayment");
        depositPool.collectDebtRepayment(nftId);
    }
    
    // ═══════════════════════════════════════════════════════════════════
    // ERC-4626 Vault Tests
    // ═══════════════════════════════════════════════════════════════════
    
    function test_deposit_Success() public {
        uint256 assets = 1000 * 1e18;
        
        vm.prank(admin);
        krwToken.approve(address(depositPool), assets);
        
        uint256 shares = depositPool.deposit(assets, admin);
        
        assertEq(depositPool.balanceOf(admin), shares);
        assertEq(krwToken.balanceOf(address(depositPool)), assets);
    }
    
    function test_redeem_Success() public {
        uint256 assets = 1000 * 1e18;
        
        // First deposit
        vm.prank(admin);
        krwToken.approve(address(depositPool), assets);
        uint256 shares = depositPool.deposit(assets, admin);
        
        // Then redeem
        uint256 initialBalance = krwToken.balanceOf(admin);
        
        vm.prank(admin);
        uint256 assetsRedeemed = depositPool.redeem(shares, admin, admin);
        
        assertEq(assetsRedeemed, assets);
        assertEq(krwToken.balanceOf(admin), initialBalance + assets);
        assertEq(depositPool.balanceOf(admin), 0);
    }
    
    function test_convertToShares() public {
        uint256 assets = 1000 * 1e18;
        uint256 shares = depositPool.convertToShares(assets);
        
        // Initially should be 1:1
        assertEq(shares, assets);
    }
    
    function test_convertToAssets() public {
        uint256 shares = 1000 * 1e18;
        uint256 assets = depositPool.convertToAssets(shares);
        
        // Initially should be 1:1
        assertEq(assets, shares);
    }
    
    // ═══════════════════════════════════════════════════════════════════
    // Access Control & Pausable Tests
    // ═══════════════════════════════════════════════════════════════════
    
    function test_pause_OnlyPauserRole() public {
        vm.prank(admin);
        depositPool.pause();
        assertTrue(depositPool.paused());
        
        vm.prank(admin);
        depositPool.unpause();
        assertFalse(depositPool.paused());
        
        // Non-pauser should fail
        vm.prank(tenant);
        vm.expectRevert();
        depositPool.pause();
    }
    
    function test_pausedFunctionality() public {
        vm.prank(admin);
        depositPool.pause();
        
        (uint256 nftId,) = setupActiveRentalContract();
        
        // Should revert when paused
        vm.prank(tenant);
        krwToken.approve(address(depositPool), TEST_PRINCIPAL);
        vm.prank(tenant);
        vm.expectRevert();
        depositPool.submitPrincipal(nftId, TEST_PRINCIPAL);
    }
    
    function test_nonReentrant() public {
        // This is a basic test - in practice, reentrancy testing requires more sophisticated setup
        (uint256 nftId,) = setupActiveRentalContract();
        
        vm.prank(tenant);
        krwToken.approve(address(depositPool), TEST_PRINCIPAL);
        vm.prank(tenant);
        depositPool.submitPrincipal(nftId, TEST_PRINCIPAL);
        
        // The function should complete successfully once
        RentalContract memory rentalContract = propertyNFT.getRentalContract(nftId);
        assertEq(uint256(rentalContract.status), uint256(RentalContractStatus.ACTIVE));
    }
    
    // ═══════════════════════════════════════════════════════════════════
    // Integration Tests
    // ═══════════════════════════════════════════════════════════════════
    
    function test_fullLifecycle_Normal() public {
        // 1. Setup rental contract
        (uint256 nftId,) = setupActiveRentalContract();
        
        // 2. Submit deposit
        vm.prank(tenant);
        krwToken.approve(address(depositPool), TEST_PRINCIPAL);
        vm.prank(tenant);
        depositPool.submitPrincipal(nftId, TEST_PRINCIPAL);
        
        // 3. Landlord returns deposit
        vm.prank(landlord);
        krwToken.approve(address(depositPool), TEST_PRINCIPAL);
        vm.prank(landlord);
        depositPool.returnPrincipal(nftId, true);
        
        // 4. Tenant recovers deposit
        vm.prank(tenant);
        depositPool.recoverPrincipal(nftId);
        
        // Verify final state
        RentalContract memory rentalContract = propertyNFT.getRentalContract(nftId);
        assertEq(uint256(rentalContract.status), uint256(RentalContractStatus.COMPLETED));
    }
    
    function test_fullLifecycle_WithDebtTransfer() public {
        // 1. Setup outstanding contract
        (uint256 nftId,) = setupOutstandingContract();
        
        // 2. Assignee purchases debt
        vm.prank(assignee);
        krwToken.approve(address(depositPool), TEST_PRINCIPAL);
        vm.prank(assignee);
        depositPool.purchaseDebt(nftId, TEST_PRINCIPAL);
        
        // 3. Landlord makes partial repayment
        uint256 repayAmount = 50_000_000 * 1e18;
        vm.prank(landlord);
        krwToken.approve(address(depositPool), repayAmount);
        vm.prank(landlord);
        depositPool.repayDebt(nftId, repayAmount);
        
        // 4. Assignee collects repayment
        vm.prank(assignee);
        depositPool.collectDebtRepayment(nftId);
        
        // Verify debt was transferred and collected
        RentalContract memory rentalContract = propertyNFT.getRentalContract(nftId);
        assertEq(rentalContract.tenantOrAssignee, assignee);
    }
}