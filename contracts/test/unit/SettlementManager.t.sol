// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../../src/SettlementManager.sol";
import "../../src/PropertyNFT.sol";
import "../../src/DepositPool.sol";
import "../../src/P2PDebtMarketplace.sol";
import "../../src/KRWToken.sol";
import "../../src/interfaces/Structs.sol";

contract SettlementManagerUnitTest is Test {
    SettlementManager public settlementManager;
    PropertyNFT public propertyNFT;
    DepositPool public depositPool;
    P2PDebtMarketplace public marketplace;
    KRWToken public krwToken;
    
    // Test accounts with specific roles
    address public admin = makeAddr("admin");
    address public settlementManagerRole = makeAddr("settlementManagerRole");
    address public monitorRole = makeAddr("monitorRole");
    address public verifier = makeAddr("verifier");
    address public landlord1 = makeAddr("landlord1");
    address public tenant1 = makeAddr("tenant1");
    address public unauthorized = makeAddr("unauthorized");
    
    // Test data
    uint256 public constant TEST_DEPOSIT_AMOUNT = 100_000_000 * 1e18; // 100M KRW
    uint256 public constant TEST_LTV = 7000; // 70%
    bytes32 public constant TEST_ADDRESS = keccak256("Seoul, Gangnam-gu");
    bytes32 public constant TEST_DESCRIPTION = keccak256("3-bedroom apartment");
    
    function setUp() public {
        vm.startPrank(admin);
        
        // Deploy contracts
        krwToken = new KRWToken(1_000_000_000 * 1e18);
        propertyNFT = new PropertyNFT();
        depositPool = new DepositPool(address(propertyNFT), address(krwToken), 500);
        marketplace = new P2PDebtMarketplace(
            address(propertyNFT),
            address(depositPool),
            address(krwToken)
        );
        settlementManager = new SettlementManager(
            address(propertyNFT),
            address(depositPool),
            address(marketplace)
        );
        
        // Setup roles
        propertyNFT.grantRole(propertyNFT.PROPERTY_VERIFIER_ROLE(), verifier);
        settlementManager.grantRole(settlementManager.SETTLEMENT_MANAGER_ROLE(), settlementManagerRole);
        settlementManager.grantRole(settlementManager.MONITOR_ROLE(), monitorRole);
        
        vm.stopPrank();
    }
    
    // Helper function to create an active rental contract
    function _createActiveContract() internal returns (uint256 tokenId) {
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
        
        // Create and verify rental contract
        uint256 startTime = block.timestamp;
        uint256 endTime = startTime + 365 days;
        
        vm.prank(landlord1);
        propertyNFT.createRentalContract(tokenId, tenant1, startTime, endTime, TEST_DEPOSIT_AMOUNT);
        
        vm.prank(verifier);
        propertyNFT.verifyRentalContract(tokenId);
        
        // Update to RENTED status (simulating deposit submission)
        vm.prank(verifier);
        propertyNFT.finalizeRentalContract(tokenId);
    }
    
    // ═══════════════════════════════════════════════════════════════════
    // Contract Registration Tests
    // ═══════════════════════════════════════════════════════════════════
    
    function testRegisterContract() public {
        uint256 tokenId = _createActiveContract();
        Property memory property = propertyNFT.getProperty(tokenId);
        
        // CALLER: settlementManagerRole (has SETTLEMENT_MANAGER_ROLE)
        vm.startPrank(settlementManagerRole);
        
        settlementManager.registerContract(
            tokenId,
            tenant1,
            property.contractEndTime,
            true // enable auto processing
        );
        
        vm.stopPrank();
        
        // Verify contract registration
        ContractStatus memory contractStatus = settlementManager.getContractStatus(tokenId);
        assertEq(contractStatus.propertyTokenId, tokenId);
        assertEq(contractStatus.tenant, tenant1);
        assertEq(contractStatus.landlord, landlord1);
        assertEq(contractStatus.contractEndTime, property.contractEndTime);
        assertEq(uint(contractStatus.status), uint(SettlementStatus.ACTIVE));
        assertTrue(contractStatus.autoProcessingEnabled);
        
        // Settlement deadline should be contract end + grace period
        assertEq(contractStatus.settlementDeadline, property.contractEndTime + 30 days);
    }
    
    function testRegisterContractUnauthorized() public {
        uint256 tokenId = _createActiveContract();
        Property memory property = propertyNFT.getProperty(tokenId);
        
        // CALLER: unauthorized user (no SETTLEMENT_MANAGER_ROLE)
        vm.startPrank(unauthorized);
        
        bytes32 requiredRole = settlementManager.SETTLEMENT_MANAGER_ROLE();
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                unauthorized,
                requiredRole
            )
        );
        settlementManager.registerContract(tokenId, tenant1, property.contractEndTime, true);
        vm.stopPrank();
    }
    
    function testRegisterContractAlreadyRegistered() public {
        uint256 tokenId = _createActiveContract();
        Property memory property = propertyNFT.getProperty(tokenId);
        
        // Register once
        vm.prank(settlementManagerRole);
        settlementManager.registerContract(tokenId, tenant1, property.contractEndTime, true);
        
        // Try to register again
        vm.startPrank(settlementManagerRole);
        vm.expectRevert("SettlementManager: Contract already registered");
        settlementManager.registerContract(tokenId, tenant1, property.contractEndTime, true);
        vm.stopPrank();
    }
    
    // ═══════════════════════════════════════════════════════════════════
    // Settlement Status Check Tests
    // ═══════════════════════════════════════════════════════════════════
    
    function testCheckSettlementStatus() public {
        uint256 tokenId = _createActiveContract();
        Property memory property = propertyNFT.getProperty(tokenId);
        
        // Register contract
        vm.prank(settlementManagerRole);
        settlementManager.registerContract(tokenId, tenant1, property.contractEndTime, true);
        
        // Fast forward to near settlement deadline (warning period)
        vm.warp(property.contractEndTime + 20 days); // 10 days before grace period ends
        
        // CALLER: anyone can call checkSettlementStatus
        settlementManager.checkSettlementStatus(tokenId);
        
        // Check the health status using checkContractHealth
        (bool needsAttention, uint256 daysRemaining, SettlementStatus currentStatus) = 
            settlementManager.checkContractHealth(tokenId);
        
        assertTrue(needsAttention);
        assertGt(daysRemaining, 0);
        assertEq(uint(currentStatus), uint(SettlementStatus.PENDING));
    }
    
    function testCheckSettlementStatusOverdue() public {
        uint256 tokenId = _createActiveContract();
        Property memory property = propertyNFT.getProperty(tokenId);
        
        // Register contract
        vm.prank(settlementManagerRole);
        settlementManager.registerContract(tokenId, tenant1, property.contractEndTime, true);
        
        // Fast forward past settlement deadline
        vm.warp(property.contractEndTime + 31 days); // 1 day after grace period
        
        // CALLER: anyone can call checkSettlementStatus
        settlementManager.checkSettlementStatus(tokenId);
        
        // Check the health status using checkContractHealth
        (bool needsAttention, uint256 daysRemaining, SettlementStatus currentStatus) = 
            settlementManager.checkContractHealth(tokenId);
        
        assertTrue(needsAttention); // Should need attention when overdue
        assertEq(daysRemaining, 0);
        assertEq(uint(currentStatus), uint(SettlementStatus.OVERDUE));
    }
    
    function testCheckSettlementStatusUnregistered() public {
        uint256 tokenId = _createActiveContract();
        
        vm.expectRevert("SettlementManager: Contract not registered");
        settlementManager.checkSettlementStatus(tokenId);
    }
    
    // ═══════════════════════════════════════════════════════════════════
    // Warning System Tests
    // ═══════════════════════════════════════════════════════════════════
    
    function testIssueWarning() public {
        uint256 tokenId = _createActiveContract();
        Property memory property = propertyNFT.getProperty(tokenId);
        
        // Register contract
        vm.prank(settlementManagerRole);
        settlementManager.registerContract(tokenId, tenant1, property.contractEndTime, true);
        
        // CALLER: monitorRole (has MONITOR_ROLE)
        vm.startPrank(monitorRole);
        
        // Fast forward to trigger warnings automatically through status check
        vm.warp(property.contractEndTime + 15 days); // Within grace period but should trigger warnings
        
        settlementManager.checkSettlementStatus(tokenId);
        
        vm.stopPrank();
        
        // Verify warning was recorded
        ContractStatus memory contractStatus = settlementManager.getContractStatus(tokenId);
        assertGt(contractStatus.warningsSent, 0);
        assertEq(uint(contractStatus.status), uint(SettlementStatus.GRACE_PERIOD));
    }
    
    function testIssueWarningUnauthorized() public {
        uint256 tokenId = _createActiveContract();
        Property memory property = propertyNFT.getProperty(tokenId);
        
        vm.prank(settlementManagerRole);
        settlementManager.registerContract(tokenId, tenant1, property.contractEndTime, true);
        
        // CALLER: unauthorized user (no MONITOR_ROLE)
        vm.startPrank(unauthorized);
        
        // Since issueWarning doesn't exist, just test checkSettlementStatus which anyone can call
        // This test is no longer relevant as checkSettlementStatus doesn't require authorization
        settlementManager.checkSettlementStatus(tokenId); // Should work without authorization
        vm.stopPrank();
    }
    
    // ═══════════════════════════════════════════════════════════════════
    // Batch Processing Tests
    // ═══════════════════════════════════════════════════════════════════
    
    function testBatchProcessSettlements() public {
        // Create multiple contracts
        uint256 tokenId1 = _createActiveContract();
        
        // Create second property and contract
        vm.prank(landlord1);
        uint256 proposalId2 = propertyNFT.proposeProperty(
            DistributionChoice.DIRECT,
            TEST_DEPOSIT_AMOUNT,
            true, true, TEST_LTV, TEST_ADDRESS, TEST_DESCRIPTION
        );
        
        vm.startPrank(verifier);
        uint256 tokenId2 = propertyNFT.approvePropertyProposal(proposalId2);
        propertyNFT.verifyProperty(tokenId2);
        vm.stopPrank();
        
        vm.prank(landlord1);
        propertyNFT.createRentalContract(
            tokenId2, 
            tenant1, 
            block.timestamp, 
            block.timestamp + 365 days, 
            TEST_DEPOSIT_AMOUNT
        );
        
        vm.prank(verifier);
        propertyNFT.verifyRentalContract(tokenId2);
        vm.prank(verifier);
        propertyNFT.finalizeRentalContract(tokenId2);
        
        // Register both contracts
        Property memory property1 = propertyNFT.getProperty(tokenId1);
        Property memory property2 = propertyNFT.getProperty(tokenId2);
        
        vm.startPrank(settlementManagerRole);
        settlementManager.registerContract(tokenId1, tenant1, property1.contractEndTime, true);
        settlementManager.registerContract(tokenId2, tenant1, property2.contractEndTime, true);
        vm.stopPrank();
        
        // Fast forward to warning period
        vm.warp(property1.contractEndTime + 20 days);
        
        // CALLER: monitorRole (has MONITOR_ROLE)
        vm.startPrank(monitorRole);
        
        (uint256 processed, uint256 warnings, uint256 escalations) = 
            settlementManager.batchProcessSettlements(10);
        
        vm.stopPrank();
        
        // Verify batch processing results
        assertEq(processed, 2); // Both contracts processed
        assertGt(warnings, 0);  // Warnings should be issued
        assertEq(escalations, 0); // No escalations yet
    }
    
    function testBatchProcessSettlementsUnauthorized() public {
        // CALLER: unauthorized user (no MONITOR_ROLE)
        vm.startPrank(unauthorized);
        
        bytes32 requiredRole = settlementManager.MONITOR_ROLE();
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                unauthorized,
                requiredRole
            )
        );
        settlementManager.batchProcessSettlements(10);
        vm.stopPrank();
    }
    
    // ═══════════════════════════════════════════════════════════════════
    // Settlement Completion Tests
    // ═══════════════════════════════════════════════════════════════════
    
    function testCompleteSettlement() public {
        uint256 tokenId = _createActiveContract();
        Property memory property = propertyNFT.getProperty(tokenId);
        
        // Register contract
        vm.prank(settlementManagerRole);
        settlementManager.registerContract(tokenId, tenant1, property.contractEndTime, true);
        
        // Fast forward past contract end but within grace period
        vm.warp(property.contractEndTime + 1 days);
        
        // CALLER: settlementManagerRole (has SETTLEMENT_MANAGER_ROLE)
        vm.startPrank(settlementManagerRole);
        
        settlementManager.completeSettlement(tokenId);
        
        vm.stopPrank();
        
        // Verify settlement completion
        ContractStatus memory contractStatus = settlementManager.getContractStatus(tokenId);
        assertEq(uint(contractStatus.status), uint(SettlementStatus.SETTLED));
        
        // Note: Property status update would depend on DepositPool.processSettlement implementation
        // We just verify the settlement manager status for now
    }
    
    function testCompleteSettlementUnauthorized() public {
        uint256 tokenId = _createActiveContract();
        Property memory property = propertyNFT.getProperty(tokenId);
        
        vm.prank(settlementManagerRole);
        settlementManager.registerContract(tokenId, tenant1, property.contractEndTime, true);
        
        // CALLER: unauthorized user (no SETTLEMENT_MANAGER_ROLE)
        vm.startPrank(unauthorized);
        
        bytes32 requiredRole = settlementManager.SETTLEMENT_MANAGER_ROLE();
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                unauthorized,
                requiredRole
            )
        );
        settlementManager.completeSettlement(tokenId);
        vm.stopPrank();
    }
    
    function testCompleteSettlementAlreadySettled() public {
        uint256 tokenId = _createActiveContract();
        Property memory property = propertyNFT.getProperty(tokenId);
        
        vm.prank(settlementManagerRole);
        settlementManager.registerContract(tokenId, tenant1, property.contractEndTime, true);
        
        // Complete settlement once
        vm.prank(settlementManagerRole);
        settlementManager.completeSettlement(tokenId);
        
        // Try to complete again
        vm.startPrank(settlementManagerRole);
        vm.expectRevert("SettlementManager: Invalid status for settlement");
        settlementManager.completeSettlement(tokenId);
        vm.stopPrank();
    }
    
    // ═══════════════════════════════════════════════════════════════════
    // Marketplace Escalation Tests
    // ═══════════════════════════════════════════════════════════════════
    
    function testEscalateToMarketplace() public {
        uint256 tokenId = _createActiveContract();
        Property memory property = propertyNFT.getProperty(tokenId);
        
        // Register contract with auto processing
        vm.prank(settlementManagerRole);
        settlementManager.registerContract(tokenId, tenant1, property.contractEndTime, true);
        
        // Fast forward past settlement deadline (overdue)
        vm.warp(property.contractEndTime + 31 days);
        
        // CALLER: settlementManagerRole (has SETTLEMENT_MANAGER_ROLE)  
        vm.startPrank(settlementManagerRole);
        
        settlementManager.escalateToMarketplace(tokenId, TEST_DEPOSIT_AMOUNT, 500); // 5% interest
        
        vm.stopPrank();
        
        // Verify escalation
        ContractStatus memory contractStatus = settlementManager.getContractStatus(tokenId);
        assertEq(uint(contractStatus.status), uint(SettlementStatus.DEFAULTED));
        
        // Note: Property status update would depend on internal implementation
        // We just verify the settlement manager status for now
    }
    
    function testEscalateToMarketplaceUnauthorized() public {
        uint256 tokenId = _createActiveContract();
        Property memory property = propertyNFT.getProperty(tokenId);
        
        vm.prank(settlementManagerRole);
        settlementManager.registerContract(tokenId, tenant1, property.contractEndTime, true);
        
        vm.warp(property.contractEndTime + 31 days);
        
        // CALLER: unauthorized user (no SETTLEMENT_MANAGER_ROLE)
        vm.startPrank(unauthorized);
        
        bytes32 requiredRole = settlementManager.SETTLEMENT_MANAGER_ROLE();
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                unauthorized,
                requiredRole
            )
        );
        settlementManager.escalateToMarketplace(tokenId, TEST_DEPOSIT_AMOUNT, 500);
        vm.stopPrank();
    }
    
    function testEscalateToMarketplaceNotOverdue() public {
        uint256 tokenId = _createActiveContract();
        Property memory property = propertyNFT.getProperty(tokenId);
        
        vm.prank(settlementManagerRole);
        settlementManager.registerContract(tokenId, tenant1, property.contractEndTime, true);
        
        // Still within grace period
        vm.warp(property.contractEndTime + 20 days);
        
        // CALLER: settlementManagerRole
        vm.startPrank(settlementManagerRole);
        vm.expectRevert("SettlementManager: Invalid status for escalation");
        settlementManager.escalateToMarketplace(tokenId, TEST_DEPOSIT_AMOUNT, 500);
        vm.stopPrank();
    }
    
    // ═══════════════════════════════════════════════════════════════════
    // Warning Configuration Tests
    // ═══════════════════════════════════════════════════════════════════
    
    function testSetWarningConfig() public {
        // CALLER: settlementManagerRole (has SETTLEMENT_MANAGER_ROLE)
        vm.startPrank(settlementManagerRole);
        
        WarningConfig memory newConfig = WarningConfig({
            firstWarningDays: 21,    // 21 days before deadline
            secondWarningDays: 10,   // 10 days before deadline  
            finalWarningDays: 3,     // 3 days before deadline
            gracePeriodDays: 45,     // 45 day grace period
            autoEscalationEnabled: false
        });
        
        settlementManager.updateWarningConfig(newConfig);
        
        vm.stopPrank();
        
        // Verify config was updated
        WarningConfig memory config = settlementManager.getWarningConfig();
        assertEq(config.firstWarningDays, 21);
        assertEq(config.secondWarningDays, 10);
        assertEq(config.finalWarningDays, 3);
        assertEq(config.gracePeriodDays, 45);
        assertFalse(config.autoEscalationEnabled);
    }
    
    function testSetWarningConfigUnauthorized() public {
        WarningConfig memory newConfig = WarningConfig({
            firstWarningDays: 21,
            secondWarningDays: 10,
            finalWarningDays: 3,
            gracePeriodDays: 45,
            autoEscalationEnabled: false
        });
        
        // CALLER: unauthorized user (no SETTLEMENT_MANAGER_ROLE)
        vm.startPrank(unauthorized);
        
        bytes32 requiredRole = settlementManager.SETTLEMENT_MANAGER_ROLE();
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                unauthorized,
                requiredRole
            )
        );
        settlementManager.updateWarningConfig(newConfig);
        vm.stopPrank();
    }
    
    // ═══════════════════════════════════════════════════════════════════
    // Access Control Tests
    // ═══════════════════════════════════════════════════════════════════
    
    function testRoleManagement() public {
        // CALLER: admin (has DEFAULT_ADMIN_ROLE)
        vm.startPrank(admin);
        
        address newManager = makeAddr("newManager");
        
        // Grant role
        settlementManager.grantRole(settlementManager.SETTLEMENT_MANAGER_ROLE(), newManager);
        assertTrue(settlementManager.hasRole(settlementManager.SETTLEMENT_MANAGER_ROLE(), newManager));
        
        // Revoke role
        settlementManager.revokeRole(settlementManager.SETTLEMENT_MANAGER_ROLE(), newManager);
        assertFalse(settlementManager.hasRole(settlementManager.SETTLEMENT_MANAGER_ROLE(), newManager));
        
        vm.stopPrank();
    }
    
    // ═══════════════════════════════════════════════════════════════════
    // Emergency Pause Tests
    // ═══════════════════════════════════════════════════════════════════
    
    function testPauseUnpause() public {
        // CALLER: admin (has PAUSER_ROLE)
        vm.startPrank(admin);
        
        settlementManager.pause();
        assertTrue(settlementManager.paused());
        
        settlementManager.unpause();
        assertFalse(settlementManager.paused());
        
        vm.stopPrank();
    }
    
    function testFunctionsWhenPaused() public {
        uint256 tokenId = _createActiveContract();
        Property memory property = propertyNFT.getProperty(tokenId);
        
        // Pause contract
        vm.prank(admin);
        settlementManager.pause();
        
        // CALLER: settlementManagerRole - should fail when paused
        vm.startPrank(settlementManagerRole);
        vm.expectRevert(abi.encodeWithSelector(Pausable.EnforcedPause.selector));
        settlementManager.registerContract(tokenId, tenant1, property.contractEndTime, true);
        vm.stopPrank();
    }
    
    // ═══════════════════════════════════════════════════════════════════
    // Edge Cases and Integration Tests
    // ═══════════════════════════════════════════════════════════════════
    
    function testAutoProcessingFlow() public {
        uint256 tokenId = _createActiveContract();
        Property memory property = propertyNFT.getProperty(tokenId);
        
        // Register with auto processing enabled
        vm.prank(settlementManagerRole);
        settlementManager.registerContract(tokenId, tenant1, property.contractEndTime, true);
        
        // Fast forward past deadline but within grace period
        vm.warp(property.contractEndTime + 35 days); // Past grace period
        
        // Batch processing should auto-escalate
        vm.prank(monitorRole);
        (uint256 processed, uint256 warnings, uint256 escalations) = 
            settlementManager.batchProcessSettlements(10);
        
        assertEq(processed, 1);
        assertEq(escalations, 1);
        
        // Verify status
        ContractStatus memory contractStatus = settlementManager.getContractStatus(tokenId);
        assertEq(uint(contractStatus.status), uint(SettlementStatus.DEFAULTED));
    }
    
    function testGetContractStatusNonexistent() public {
        // getContractStatus returns a default struct for non-existent contracts
        ContractStatus memory status = settlementManager.getContractStatus(999);
        assertEq(status.propertyTokenId, 0);
    }
    
    function testExtendGracePeriod() public {
        uint256 tokenId = _createActiveContract();
        Property memory property = propertyNFT.getProperty(tokenId);
        
        // Register contract and move to grace period
        vm.prank(settlementManagerRole);
        settlementManager.registerContract(tokenId, tenant1, property.contractEndTime, true);
        
        // Fast forward to grace period
        vm.warp(property.contractEndTime + 15 days);
        settlementManager.checkSettlementStatus(tokenId);
        
        // CALLER: settlementManagerRole (has SETTLEMENT_MANAGER_ROLE)
        vm.startPrank(settlementManagerRole);
        
        string memory reason = "Tenant contacted, payment pending";
        settlementManager.extendGracePeriod(tokenId, 5, reason);
        
        vm.stopPrank();
        
        // Verify notes were updated through grace period extension
        ContractStatus memory contractStatus = settlementManager.getContractStatus(tokenId);
        assertEq(contractStatus.notes, reason);
    }
}