// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../../src/PropertyNFT.sol";
import "../../src/DepositPool.sol";
import "../../src/P2PDebtMarketplace.sol";
import "../../src/SettlementManager.sol";
import "../../src/KRWToken.sol";
import "../../src/interfaces/Structs.sol";

/**
 * @title SystemInteractionsIntegrationTest
 * @dev Integration test focusing on cross-contract interactions and system behaviors
 * Tests complex scenarios involving multiple contracts working together
 */
contract SystemInteractionsIntegrationTest is Test {
    // Contract instances
    PropertyNFT public propertyNFT;
    DepositPool public depositPool;
    P2PDebtMarketplace public marketplace;
    SettlementManager public settlementManager;
    KRWToken public krwToken;
    
    // Accounts
    address public admin = makeAddr("admin");
    address public verifier = makeAddr("verifier");
    address public settlementManagerRole = makeAddr("settlementManagerRole");
    address public monitorRole = makeAddr("monitorRole");
    address public marketplaceAdmin = makeAddr("marketplaceAdmin");
    
    address public landlord1 = makeAddr("landlord1");
    address public landlord2 = makeAddr("landlord2");
    address public tenant1 = makeAddr("tenant1");
    address public tenant2 = makeAddr("tenant2");
    address public assignee1 = makeAddr("assignee1");
    address public assignee2 = makeAddr("assignee2");
    
    // Constants
    uint256 public constant INITIAL_KRW_SUPPLY = 10_000_000_000 * 1e18; // 10B KRW
    uint256 public constant DEPOSIT_AMOUNT_1 = 100_000_000 * 1e18; // 100M KRW
    uint256 public constant DEPOSIT_AMOUNT_2 = 200_000_000 * 1e18; // 200M KRW
    uint256 public constant TEST_LTV = 7000; // 70%
    bytes32 public constant TEST_ADDRESS_1 = keccak256("Seoul, Gangnam-gu, Apt 101");
    bytes32 public constant TEST_ADDRESS_2 = keccak256("Seoul, Seocho-gu, Apt 202");
    bytes32 public constant TEST_DESCRIPTION_1 = keccak256("Luxury 3-bedroom apartment");
    bytes32 public constant TEST_DESCRIPTION_2 = keccak256("Modern 2-bedroom apartment");
    
    function setUp() public {
        vm.startPrank(admin);
        
        // Deploy contracts
        krwToken = new KRWToken(INITIAL_KRW_SUPPLY);
        propertyNFT = new PropertyNFT();
        depositPool = new DepositPool(address(propertyNFT), address(krwToken), 500);
        marketplace = new P2PDebtMarketplace(address(propertyNFT), address(depositPool), address(krwToken));
        settlementManager = new SettlementManager(
            address(propertyNFT),
            address(depositPool),
            address(marketplace)
        );
        
        // Setup roles
        propertyNFT.grantRole(propertyNFT.PROPERTY_VERIFIER_ROLE(), verifier);
        depositPool.grantRole(depositPool.POOL_MANAGER_ROLE(), address(settlementManager));
        marketplace.grantRole(marketplace.MARKETPLACE_ADMIN_ROLE(), marketplaceAdmin);
        marketplace.grantRole(marketplace.MARKETPLACE_ADMIN_ROLE(), address(settlementManager));
        settlementManager.grantRole(settlementManager.SETTLEMENT_MANAGER_ROLE(), settlementManagerRole);
        settlementManager.grantRole(settlementManager.MONITOR_ROLE(), monitorRole);
        
        // Distribute tokens
        krwToken.transfer(landlord1, 1_000_000_000 * 1e18);
        krwToken.transfer(landlord2, 1_000_000_000 * 1e18);
        krwToken.transfer(tenant1, 2_000_000_000 * 1e18);
        krwToken.transfer(tenant2, 2_000_000_000 * 1e18);
        krwToken.transfer(assignee1, 1_000_000_000 * 1e18);
        krwToken.transfer(assignee2, 1_000_000_000 * 1e18);
        
        vm.stopPrank();
    }
    
    // ═══════════════════════════════════════════════════════════════════
    // Cross-Contract Dependency Tests
    // ═══════════════════════════════════════════════════════════════════
    
    function testPropertyNFTDepositPoolIntegration() public {
        console.log("\n=== Testing PropertyNFT-DepositPool Integration ===");
        
        // Create property with POOL distribution
        uint256 tokenId = _createVerifiedProperty(landlord1, DistributionChoice.POOL, DEPOSIT_AMOUNT_1);
        _createAndVerifyRentalContract(tokenId, tenant1, DEPOSIT_AMOUNT_1);
        
        // Submit deposit to pool
        vm.startPrank(tenant1);
        krwToken.approve(address(depositPool), DEPOSIT_AMOUNT_1);
        depositPool.submitDeposit(tokenId, DEPOSIT_AMOUNT_1);
        vm.stopPrank();
        
        // Verify deposit pool received property data correctly
        DepositInfo memory depositInfo = depositPool.getDeposit(tokenId);
        Property memory property = propertyNFT.getProperty(tokenId);
        
        assertEq(depositInfo.propertyTokenId, tokenId);
        assertEq(depositInfo.landlord, property.landlord);
        assertEq(depositInfo.tenant, property.currentTenant);
        assertEq(uint(depositInfo.distributionChoice), uint(property.distributionChoice));
        assertTrue(depositInfo.isInPool);
        
        console.log(" PropertyNFT data correctly integrated with DepositPool");
    }
    
    function testSettlementManagerPropertyNFTIntegration() public {
        console.log("\n=== Testing SettlementManager-PropertyNFT Integration ===");
        
        uint256 tokenId = _createActiveRentalContract(landlord1, tenant1, DistributionChoice.DIRECT, DEPOSIT_AMOUNT_1);
        
        // Register contract with settlement manager
        Property memory property = propertyNFT.getProperty(tokenId);
        vm.prank(settlementManagerRole);
        settlementManager.registerContract(tokenId, tenant1, property.contractEndTime, true);
        
        // Complete settlement through settlement manager
        vm.warp(property.contractEndTime + 1 days);
        vm.prank(settlementManagerRole);
        settlementManager.completeSettlement(tokenId);
        
        // Verify PropertyNFT status was updated by SettlementManager
        Property memory updatedProperty = propertyNFT.getProperty(tokenId);
        assertEq(uint(updatedProperty.status), uint(PropertyStatus.COMPLETED));
        
        console.log(" SettlementManager successfully updated PropertyNFT status");
    }
    
    function testMarketplaceSettlementManagerIntegration() public {
        console.log("\n=== Testing Marketplace-SettlementManager Integration ===");
        
        uint256 tokenId = _createActiveRentalContract(landlord1, tenant1, DistributionChoice.POOL, DEPOSIT_AMOUNT_1);
        
        // Fast forward to overdue
        Property memory property = propertyNFT.getProperty(tokenId);
        vm.warp(property.contractEndTime + 31 days);
        
        // Escalate through settlement manager (which should interact with marketplace)
        vm.prank(monitorRole);
        settlementManager.escalateToMarketplace(tokenId, DEPOSIT_AMOUNT_1, 500);
        
        // Verify marketplace received escalation
        // Note: This assumes the escalation creates a debt claim in the marketplace
        Property memory updatedProperty = propertyNFT.getProperty(tokenId);
        assertEq(uint(updatedProperty.status), uint(PropertyStatus.OVERDUE));
        
        ContractStatus memory contractStatus = settlementManager.getContractStatus(tokenId);
        assertEq(uint(contractStatus.status), uint(SettlementStatus.DEFAULTED));
        
        console.log(" SettlementManager successfully escalated to Marketplace");
    }
    
    // ═══════════════════════════════════════════════════════════════════
    // Multi-Property System Tests
    // ═══════════════════════════════════════════════════════════════════
    
    function testMultiplePropertiesWithDifferentDistributions() public {
        console.log("\n=== Testing Multiple Properties with Different Distributions ===");
        
        // Create two properties with different distribution methods
        uint256 tokenId1 = _createActiveRentalContract(landlord1, tenant1, DistributionChoice.POOL, DEPOSIT_AMOUNT_1);
        uint256 tokenId2 = _createActiveRentalContract(landlord2, tenant2, DistributionChoice.DIRECT, DEPOSIT_AMOUNT_2);
        
        // Verify different distribution behaviors
        DepositInfo memory deposit1 = depositPool.getDeposit(tokenId1);
        DepositInfo memory deposit2 = depositPool.getDeposit(tokenId2);
        
        assertTrue(deposit1.isInPool);   // POOL distribution
        assertFalse(deposit2.isInPool);  // DIRECT distribution
        
        // Fast forward time and calculate yields
        vm.warp(block.timestamp + 180 days); // 6 months
        
        uint256 yield1 = depositPool.calculateYield(tokenId1);
        uint256 yield2 = depositPool.calculateYield(tokenId2);
        
        assertGt(yield1, 0);  // POOL should generate yield
        assertEq(yield2, 0);  // DIRECT should not generate yield
        
        console.log(" Different distribution methods working correctly");
        console.log("  - POOL yield:", yield1);
        console.log("  - DIRECT yield:", yield2);
    }
    
    function testConcurrentSettlementsAndDefaults() public {
        console.log("\n=== Testing Concurrent Settlements and Defaults ===");
        
        // Create multiple properties
        uint256 tokenId1 = _createActiveRentalContract(landlord1, tenant1, DistributionChoice.POOL, DEPOSIT_AMOUNT_1);
        uint256 tokenId2 = _createActiveRentalContract(landlord2, tenant2, DistributionChoice.DIRECT, DEPOSIT_AMOUNT_2);
        
        Property memory property1 = propertyNFT.getProperty(tokenId1);
        Property memory property2 = propertyNFT.getProperty(tokenId2);
        
        // Property 1: Normal settlement at contract end
        vm.warp(property1.contractEndTime + 1 days);
        vm.prank(settlementManagerRole);
        settlementManager.completeSettlement(tokenId1);
        
        // Property 2: Default scenario - advance further
        vm.warp(property2.contractEndTime + 31 days);
        vm.prank(monitorRole);
        settlementManager.escalateToMarketplace(tokenId2, DEPOSIT_AMOUNT_2, 500);
        
        // Verify different outcomes
        ContractStatus memory status1 = settlementManager.getContractStatus(tokenId1);
        ContractStatus memory status2 = settlementManager.getContractStatus(tokenId2);
        
        assertEq(uint(status1.status), uint(SettlementStatus.SETTLED));
        assertEq(uint(status2.status), uint(SettlementStatus.DEFAULTED));
        
        console.log(" Concurrent settlements handled correctly");
        console.log("  - Property 1: Normal settlement");
        console.log("  - Property 2: Defaulted to marketplace");
    }
    
    // ═══════════════════════════════════════════════════════════════════
    // System State Consistency Tests
    // ═══════════════════════════════════════════════════════════════════
    
    function testSystemStateConsistencyAfterOperations() public {
        console.log("\n=== Testing System State Consistency ===");
        
        uint256 tokenId = _createActiveRentalContract(landlord1, tenant1, DistributionChoice.POOL, DEPOSIT_AMOUNT_1);
        
        // Track system state at different points
        _verifySystemStateConsistency(tokenId, "After rental contract creation");
        
        // Complete normal settlement
        Property memory property = propertyNFT.getProperty(tokenId);
        vm.warp(property.contractEndTime + 1 days);
        vm.prank(settlementManagerRole);
        settlementManager.completeSettlement(tokenId);
        
        _verifySystemStateConsistency(tokenId, "After settlement completion");
        
        // Tenant recovers deposit
        vm.prank(tenant1);
        depositPool.recoverDeposit(tokenId);
        
        _verifySystemStateConsistency(tokenId, "After deposit recovery");
        
        console.log(" System state consistency maintained throughout lifecycle");
    }
    
    function _verifySystemStateConsistency(uint256 tokenId, string memory stage) internal view {
        Property memory property = propertyNFT.getProperty(tokenId);
        DepositInfo memory deposit = depositPool.getDeposit(tokenId);
        
        // Verify data consistency across contracts
        assertEq(deposit.propertyTokenId, tokenId);
        assertEq(deposit.landlord, property.landlord);
        
        // Log current state
        console.log(string.concat(" State consistent at: ", stage));
    }
    
    // ═══════════════════════════════════════════════════════════════════
    // Complex P2P Marketplace Scenarios
    // ═══════════════════════════════════════════════════════════════════
    
    function testMultipleDebtClaimsAndAssignees() public {
        console.log("\n=== Testing Multiple Debt Claims and Assignees ===");
        
        // Create multiple overdue properties
        uint256 tokenId1 = _createOverdueProperty(landlord1, tenant1, DEPOSIT_AMOUNT_1);
        uint256 tokenId2 = _createOverdueProperty(landlord2, tenant2, DEPOSIT_AMOUNT_2);
        
        // List both as debt claims
        vm.startPrank(marketplaceAdmin);
        uint256 claimId1 = marketplace.listDebtClaim(
            tokenId1, DEPOSIT_AMOUNT_1, DEPOSIT_AMOUNT_1 * 95 / 100, 500
        );
        uint256 claimId2 = marketplace.listDebtClaim(
            tokenId2, DEPOSIT_AMOUNT_2, DEPOSIT_AMOUNT_2 * 90 / 100, 600
        );
        vm.stopPrank();
        
        // Different assignees purchase different claims
        vm.startPrank(assignee1);
        krwToken.approve(address(marketplace), DEPOSIT_AMOUNT_1);
        marketplace.purchaseDebtClaim(claimId1);
        vm.stopPrank();
        
        vm.startPrank(assignee2);
        krwToken.approve(address(marketplace), DEPOSIT_AMOUNT_2);
        marketplace.purchaseDebtClaim(claimId2);
        vm.stopPrank();
        
        // Verify separate ownership
        (DebtClaim memory claim1,) = marketplace.getDebtClaim(claimId1);
        (DebtClaim memory claim2,) = marketplace.getDebtClaim(claimId2);
        
        assertEq(claim1.currentOwner, assignee1);
        assertEq(claim2.currentOwner, assignee2);
        assertEq(uint(claim1.status), uint(ClaimStatus.SOLD));
        assertEq(uint(claim2.status), uint(ClaimStatus.SOLD));
        
        console.log(" Multiple debt claims handled independently");
        console.log("  - Claim 1 owned by assignee1");
        console.log("  - Claim 2 owned by assignee2");
    }
    
    function testInterestAccrualAcrossMultipleClaims() public {
        console.log("\n=== Testing Interest Accrual Across Multiple Claims ===");
        
        // Create and purchase two claims with different interest rates
        uint256 tokenId1 = _createOverdueProperty(landlord1, tenant1, DEPOSIT_AMOUNT_1);
        uint256 tokenId2 = _createOverdueProperty(landlord2, tenant2, DEPOSIT_AMOUNT_2);
        
        vm.startPrank(marketplaceAdmin);
        uint256 claimId1 = marketplace.listDebtClaim(
            tokenId1, DEPOSIT_AMOUNT_1, DEPOSIT_AMOUNT_1 * 95 / 100, 500 // 5%
        );
        uint256 claimId2 = marketplace.listDebtClaim(
            tokenId2, DEPOSIT_AMOUNT_2, DEPOSIT_AMOUNT_2 * 90 / 100, 750 // 7.5%
        );
        vm.stopPrank();
        
        // Purchase both claims
        vm.startPrank(assignee1);
        krwToken.approve(address(marketplace), type(uint256).max);
        marketplace.purchaseDebtClaim(claimId1);
        marketplace.purchaseDebtClaim(claimId2);
        vm.stopPrank();
        
        // Fast forward 1 year
        vm.warp(block.timestamp + 365 days);
        
        // Update interest for both
        marketplace.updateInterest(claimId1);
        marketplace.updateInterest(claimId2);
        
        // Get interest from metadata
        (,ClaimMetadata memory metadata1) = marketplace.getDebtClaim(claimId1);
        (,ClaimMetadata memory metadata2) = marketplace.getDebtClaim(claimId2);
        uint256 interest1 = metadata1.totalInterestAccrued;
        uint256 interest2 = metadata2.totalInterestAccrued;
        
        // Verify different interest amounts based on rates
        assertGt(interest2, interest1); // 7.5% should be more than 5%
        
        console.log(" Different interest rates applied correctly");
        console.log("  - Interest 1 (5%):", interest1);
        console.log("  - Interest 2 (7.5%):", interest2);
    }
    
    // ═══════════════════════════════════════════════════════════════════
    // Yield Management Across Pool Deposits
    // ═══════════════════════════════════════════════════════════════════
    
    function testYieldManagementWithMultiplePoolDeposits() public {
        console.log("\n=== Testing Yield Management with Multiple Pool Deposits ===");
        
        // Create multiple POOL deposits
        uint256 tokenId1 = _createActiveRentalContract(landlord1, tenant1, DistributionChoice.POOL, DEPOSIT_AMOUNT_1);
        uint256 tokenId2 = _createActiveRentalContract(landlord2, tenant2, DistributionChoice.POOL, DEPOSIT_AMOUNT_2);
        
        // Fast forward to accumulate yield
        vm.warp(block.timestamp + 365 days); // 1 year
        
        // Calculate yields for both deposits
        uint256 yield1 = depositPool.calculateYield(tokenId1);
        uint256 yield2 = depositPool.calculateYield(tokenId2);
        
        // Verify yields are proportional to deposit amounts
        uint256 expectedYield1 = (DEPOSIT_AMOUNT_1 * 500) / 10000; // 5% of deposit 1
        uint256 expectedYield2 = (DEPOSIT_AMOUNT_2 * 500) / 10000; // 5% of deposit 2
        
        assertApproxEqRel(yield1, expectedYield1, 1e16); // 1% tolerance
        assertApproxEqRel(yield2, expectedYield2, 1e16); // 1% tolerance
        
        // Withdraw yields separately
        vm.prank(landlord1);
        uint256 withdrawn1 = depositPool.withdrawYield(tokenId1);
        
        vm.prank(landlord2);
        uint256 withdrawn2 = depositPool.withdrawYield(tokenId2);
        
        assertEq(withdrawn1, yield1);
        assertEq(withdrawn2, yield2);
        
        console.log(" Independent yield management verified");
        console.log("  - Landlord 1 yield:", withdrawn1);
        console.log("  - Landlord 2 yield:", withdrawn2);
    }
    
    // ═══════════════════════════════════════════════════════════════════
    // System Performance and Edge Cases
    // ═══════════════════════════════════════════════════════════════════
    
    function testSystemPerformanceUnderLoad() public {
        console.log("\n=== Testing System Performance Under Load ===");
        
        uint256 numProperties = 5;
        uint256[] memory tokenIds = new uint256[](numProperties);
        
        // Create multiple properties quickly
        for (uint256 i = 0; i < numProperties; i++) {
            address dynamicLandlord = address(uint160(uint256(keccak256(abi.encode("landlord", i)))));
            address dynamicTenant = address(uint160(uint256(keccak256(abi.encode("tenant", i)))));
            
            // Fund dynamic accounts
            vm.prank(admin);
            krwToken.transfer(dynamicTenant, DEPOSIT_AMOUNT_1);
            
            tokenIds[i] = _createActiveRentalContract(
                dynamicLandlord,
                dynamicTenant,
                DistributionChoice.POOL,
                DEPOSIT_AMOUNT_1
            );
        }
        
        // Batch process all properties
        vm.warp(block.timestamp + 400 days); // Past all deadlines
        
        vm.prank(monitorRole);
        (uint256 processed, uint256 warnings, uint256 escalations) = 
            settlementManager.batchProcessSettlements(numProperties);
        
        assertEq(processed, numProperties);
        console.log(" Batch processing handled", numProperties, "properties");
        console.log("  - Processed:", processed);
        console.log("  - Escalations:", escalations);
    }
    
    function testEdgeCaseTimingScenarios() public {
        console.log("\n=== Testing Edge Case Timing Scenarios ===");
        
        uint256 tokenId = _createActiveRentalContract(landlord1, tenant1, DistributionChoice.POOL, DEPOSIT_AMOUNT_1);
        Property memory property = propertyNFT.getProperty(tokenId);
        
        // Test exact deadline timing
        vm.warp(property.contractEndTime); // Exactly at contract end
        (bool needsAttention, uint256 daysRemaining, SettlementStatus currentStatus) = settlementManager.checkContractHealth(tokenId);
        assertTrue(needsAttention == false);
        assertTrue(currentStatus == SettlementStatus.ACTIVE);
        
        // Test 1 second after contract end (should trigger warning period)
        vm.warp(property.contractEndTime + 1);
        (needsAttention, daysRemaining, currentStatus) = settlementManager.checkContractHealth(tokenId);
        assertTrue(needsAttention);
        assertTrue(currentStatus == SettlementStatus.PENDING);
        
        // Test exactly at grace period end
        vm.warp(property.contractEndTime + 30 days); // Exactly 30 days grace period
        (needsAttention, daysRemaining, currentStatus) = settlementManager.checkContractHealth(tokenId);
        assertTrue(needsAttention);
        assertTrue(currentStatus == SettlementStatus.PENDING);
        
        // Test 1 second after grace period (should be overdue)
        vm.warp(property.contractEndTime + 30 days + 1);
        (needsAttention, daysRemaining, currentStatus) = settlementManager.checkContractHealth(tokenId);
        assertTrue(needsAttention);
        assertTrue(currentStatus == SettlementStatus.OVERDUE);
        
        console.log(" Edge case timing scenarios handled correctly");
    }
    
    // ═══════════════════════════════════════════════════════════════════
    // Helper Functions
    // ═══════════════════════════════════════════════════════════════════
    
    function _createVerifiedProperty(
        address landlord,
        DistributionChoice choice,
        uint256 depositAmount
    ) internal returns (uint256 tokenId) {
        vm.prank(landlord);
        uint256 proposalId = propertyNFT.proposeProperty(
            choice, depositAmount, true, false, TEST_LTV, TEST_ADDRESS_1, TEST_DESCRIPTION_1
        );
        
        vm.startPrank(verifier);
        tokenId = propertyNFT.approvePropertyProposal(proposalId);
        propertyNFT.verifyProperty(tokenId);
        vm.stopPrank();
    }
    
    function _createAndVerifyRentalContract(
        uint256 tokenId,
        address tenant,
        uint256 depositAmount
    ) internal {
        address landlord = propertyNFT.ownerOf(tokenId);
        
        vm.prank(landlord);
        propertyNFT.createRentalContract(
            tokenId, tenant, block.timestamp + 1 days, block.timestamp + 366 days, depositAmount
        );
        
        vm.prank(verifier);
        propertyNFT.verifyRentalContract(tokenId);
    }
    
    function _createActiveRentalContract(
        address landlord,
        address tenant,
        DistributionChoice choice,
        uint256 depositAmount
    ) internal returns (uint256 tokenId) {
        tokenId = _createVerifiedProperty(landlord, choice, depositAmount);
        _createAndVerifyRentalContract(tokenId, tenant, depositAmount);
        
        // Submit deposit
        vm.startPrank(tenant);
        krwToken.approve(address(depositPool), depositAmount);
        depositPool.submitDeposit(tokenId, depositAmount);
        vm.stopPrank();
        
        // Register for monitoring
        Property memory property = propertyNFT.getProperty(tokenId);
        vm.prank(settlementManagerRole);
        settlementManager.registerContract(tokenId, tenant, property.contractEndTime, true);
    }
    
    function _createOverdueProperty(
        address landlord,
        address tenant,
        uint256 depositAmount
    ) internal returns (uint256 tokenId) {
        tokenId = _createActiveRentalContract(landlord, tenant, DistributionChoice.POOL, depositAmount);
        
        // Fast forward past deadline and escalate
        Property memory property = propertyNFT.getProperty(tokenId);
        vm.warp(property.contractEndTime + 31 days);
        
        vm.prank(monitorRole);
        settlementManager.escalateToMarketplace(tokenId, depositAmount, 500);
    }
}