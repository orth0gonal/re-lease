// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../../src/PropertyNFT.sol";
import "../../src/interfaces/Structs.sol";

/**
 * @title PropertyNFTTest
 * @dev Comprehensive unit tests for PropertyNFT contract
 */
contract PropertyNFTTest is Test {
    PropertyNFT public propertyNFT;
    
    // Test accounts
    address public admin = address(0x1);
    address public verifier = address(0x2);
    address public landlord = address(0x3);
    address public tenant = address(0x4);
    address public trustAuthority = address(0x5);
    address public assignee = address(0x6);
    
    // Test data
    uint256 public constant TEST_LTV = 8000; // 80%
    bytes32 public constant TEST_ADDRESS = keccak256("123 Test Street, Seoul");
    uint256 public constant TEST_PRINCIPAL = 100_000_000; // 100M KRWC
    uint256 public constant TEST_INTEREST_RATE = 500; // 5%
    
    // Events to test
    event PropertyProposed(uint256 indexed propertyId, address indexed landlord, uint256 ltv, bytes32 registrationAddress);
    event PropertyApproved(uint256 indexed propertyId, address indexed verifier);
    event PropertyRejected(uint256 indexed propertyId, address indexed verifier, string reason);
    event PropertyStatusUpdated(uint256 indexed propertyId, PropertyStatus oldStatus, PropertyStatus newStatus);
    event RentalContractCreated(uint256 indexed nftId, address indexed tenant, uint256 principal, uint256 startDate, uint256 endDate, uint256 debtInterestRate);
    event DebtPropertyListed(uint256 indexed nftId, uint256 principal, uint256 debtInterestRate);
    event DebtFullyRepaid(uint256 indexed nftId, address indexed creditor, uint256 finalAmount);
    
    function setUp() public {
        vm.startPrank(admin);
        
        // Deploy PropertyNFT
        propertyNFT = new PropertyNFT();
        
        // Grant verifier role
        propertyNFT.grantRole(propertyNFT.PROPERTY_VERIFIER_ROLE(), verifier);
        
        vm.stopPrank();
    }
    
    // ═══════════════════════════════════════════════════════════════════
    // Property Registration Tests
    // ═══════════════════════════════════════════════════════════════════
    
    function test_registerProperty_Success() public {
        vm.prank(landlord);
        
        vm.expectEmit(true, true, false, true);
        emit PropertyProposed(1, landlord, TEST_LTV, TEST_ADDRESS);
        
        uint256 propertyId = propertyNFT.registerProperty(
            landlord,
            trustAuthority,
            TEST_LTV,
            TEST_ADDRESS
        );
        
        assertEq(propertyId, 1);
        
        Property memory prop = propertyNFT.getProperty(propertyId);
        assertEq(prop.landlord, landlord);
        assertEq(uint256(prop.status), uint256(PropertyStatus.PENDING));
        assertEq(prop.trustAuthority, trustAuthority);
        assertEq(prop.registrationAddress, TEST_ADDRESS);
        assertEq(prop.ltv, TEST_LTV);
    }
    
    function test_registerProperty_InvalidLandlord() public {
        vm.prank(landlord);
        
        vm.expectRevert("PropertyNFT: Invalid landlord address");
        propertyNFT.registerProperty(
            address(0),
            trustAuthority,
            TEST_LTV,
            TEST_ADDRESS
        );
    }
    
    function test_registerProperty_EmptyAddress() public {
        vm.prank(landlord);
        
        vm.expectRevert("PropertyNFT: Registration address cannot be empty");
        propertyNFT.registerProperty(
            landlord,
            trustAuthority,
            TEST_LTV,
            bytes32(0)
        );
    }
    
    function test_registerProperty_ExcessiveLTV() public {
        vm.prank(landlord);
        
        vm.expectRevert("PropertyNFT: LTV cannot exceed 100% (10000 basis points)");
        propertyNFT.registerProperty(
            landlord,
            trustAuthority,
            10001, // > 100%
            TEST_ADDRESS
        );
    }
    
    // ═══════════════════════════════════════════════════════════════════
    // Property Approval/Rejection Tests
    // ═══════════════════════════════════════════════════════════════════
    
    function test_approveProperty_Success() public {
        // First register property
        vm.prank(landlord);
        uint256 propertyId = propertyNFT.registerProperty(
            landlord,
            trustAuthority,
            TEST_LTV,
            TEST_ADDRESS
        );
        
        // Then approve it
        vm.prank(verifier);
        
        vm.expectEmit(true, true, false, true);
        emit PropertyApproved(propertyId, verifier);
        
        vm.expectEmit(true, false, false, true);
        emit PropertyStatusUpdated(propertyId, PropertyStatus.PENDING, PropertyStatus.REGISTERED);
        
        uint256 nftId = propertyNFT.approveProperty(propertyId);
        
        assertEq(nftId, 1);
        assertEq(propertyNFT.ownerOf(nftId), landlord);
        
        Property memory prop = propertyNFT.getProperty(propertyId);
        assertEq(uint256(prop.status), uint256(PropertyStatus.REGISTERED));
    }
    
    function test_approveProperty_NonExistentProperty() public {
        vm.prank(verifier);
        
        vm.expectRevert("PropertyNFT: Property does not exist");
        propertyNFT.approveProperty(999);
    }
    
    function test_approveProperty_NotPending() public {
        // Register and approve property
        vm.prank(landlord);
        uint256 propertyId = propertyNFT.registerProperty(
            landlord,
            trustAuthority,
            TEST_LTV,
            TEST_ADDRESS
        );
        
        vm.prank(verifier);
        propertyNFT.approveProperty(propertyId);
        
        // Try to approve again
        vm.prank(verifier);
        vm.expectRevert("PropertyNFT: Property not in pending status");
        propertyNFT.approveProperty(propertyId);
    }
    
    function test_approveProperty_OnlyVerifier() public {
        vm.prank(landlord);
        uint256 propertyId = propertyNFT.registerProperty(
            landlord,
            trustAuthority,
            TEST_LTV,
            TEST_ADDRESS
        );
        
        vm.prank(landlord); // Not verifier
        vm.expectRevert();
        propertyNFT.approveProperty(propertyId);
    }
    
    function test_rejectProperty_Success() public {
        // Register property
        vm.prank(landlord);
        uint256 propertyId = propertyNFT.registerProperty(
            landlord,
            trustAuthority,
            TEST_LTV,
            TEST_ADDRESS
        );
        
        // Reject it
        vm.prank(verifier);
        
        vm.expectEmit(true, true, false, true);
        emit PropertyRejected(propertyId, verifier, "Property rejected by verifier");
        
        vm.expectEmit(true, false, false, true);
        emit PropertyStatusUpdated(propertyId, PropertyStatus.PENDING, PropertyStatus.SUSPENDED);
        
        propertyNFT.rejectProperty(propertyId);
        
        Property memory prop = propertyNFT.getProperty(propertyId);
        assertEq(uint256(prop.status), uint256(PropertyStatus.SUSPENDED));
    }
    
    // ═══════════════════════════════════════════════════════════════════
    // Rental Contract Tests
    // ═══════════════════════════════════════════════════════════════════
    
    function test_createRentalContract_Success() public {
        // Setup: Register and approve property
        vm.prank(landlord);
        uint256 propertyId = propertyNFT.registerProperty(
            landlord,
            trustAuthority,
            TEST_LTV,
            TEST_ADDRESS
        );
        
        vm.prank(verifier);
        uint256 nftId = propertyNFT.approveProperty(propertyId);
        
        // Create rental contract
        uint256 startDate = block.timestamp + 1 days;
        uint256 endDate = startDate + 365 days;
        
        vm.prank(landlord);
        
        vm.expectEmit(true, true, false, true);
        emit RentalContractCreated(nftId, tenant, TEST_PRINCIPAL, startDate, endDate, TEST_INTEREST_RATE);
        
        propertyNFT.createRentalContract(
            nftId,
            tenant,
            startDate,
            endDate,
            TEST_PRINCIPAL,
            TEST_INTEREST_RATE
        );
        
        RentalContract memory rentalContract = propertyNFT.getRentalContract(nftId);
        assertEq(rentalContract.nftId, nftId);
        assertEq(rentalContract.tenantOrAssignee, tenant);
        assertEq(rentalContract.principal, TEST_PRINCIPAL);
        assertEq(rentalContract.startDate, startDate);
        assertEq(rentalContract.endDate, endDate);
        assertEq(uint256(rentalContract.status), uint256(RentalContractStatus.PENDING));
        assertEq(rentalContract.debtInterestRate, TEST_INTEREST_RATE);
        assertEq(rentalContract.totalRepaidAmount, TEST_PRINCIPAL);
        assertEq(rentalContract.currentRepaidAmount, 0);
        assertEq(rentalContract.lastRepaymentTime, 0);
    }
    
    function test_createRentalContract_OnlyNFTOwner() public {
        // Setup
        vm.prank(landlord);
        uint256 propertyId = propertyNFT.registerProperty(
            landlord,
            trustAuthority,
            TEST_LTV,
            TEST_ADDRESS
        );
        
        vm.prank(verifier);
        uint256 nftId = propertyNFT.approveProperty(propertyId);
        
        // Try to create contract as non-owner
        vm.prank(tenant);
        vm.expectRevert("PropertyNFT: Only NFT owner can create rental contract");
        propertyNFT.createRentalContract(
            nftId,
            tenant,
            block.timestamp + 1 days,
            block.timestamp + 366 days,
            TEST_PRINCIPAL,
            TEST_INTEREST_RATE
        );
    }
    
    function test_createRentalContract_InvalidParameters() public {
        // Setup
        vm.prank(landlord);
        uint256 propertyId = propertyNFT.registerProperty(
            landlord,
            trustAuthority,
            TEST_LTV,
            TEST_ADDRESS
        );
        
        vm.prank(verifier);
        uint256 nftId = propertyNFT.approveProperty(propertyId);
        
        vm.startPrank(landlord);
        
        // Invalid tenant
        vm.expectRevert("PropertyNFT: Invalid tenant address");
        propertyNFT.createRentalContract(
            nftId,
            address(0),
            block.timestamp + 1 days,
            block.timestamp + 366 days,
            TEST_PRINCIPAL,
            TEST_INTEREST_RATE
        );
        
        // Zero principal
        vm.expectRevert("PropertyNFT: Principal must be positive");
        propertyNFT.createRentalContract(
            nftId,
            tenant,
            block.timestamp + 1 days,
            block.timestamp + 366 days,
            0,
            TEST_INTEREST_RATE
        );
        
        // Invalid contract period
        vm.expectRevert("PropertyNFT: Invalid contract period");
        propertyNFT.createRentalContract(
            nftId,
            tenant,
            block.timestamp + 366 days,
            block.timestamp + 1 days,
            TEST_PRINCIPAL,
            TEST_INTEREST_RATE
        );
        
        // Excessive interest rate
        vm.expectRevert("PropertyNFT: Interest rate too high");
        propertyNFT.createRentalContract(
            nftId,
            tenant,
            block.timestamp + 1 days,
            block.timestamp + 366 days,
            TEST_PRINCIPAL,
            10001 // > 100%
        );
        
        vm.stopPrank();
    }
    
    function test_createRentalContract_ContractAlreadyExists() public {
        // Setup
        vm.prank(landlord);
        uint256 propertyId = propertyNFT.registerProperty(
            landlord,
            trustAuthority,
            TEST_LTV,
            TEST_ADDRESS
        );
        
        vm.prank(verifier);
        uint256 nftId = propertyNFT.approveProperty(propertyId);
        
        // Create first contract
        vm.prank(landlord);
        propertyNFT.createRentalContract(
            nftId,
            tenant,
            block.timestamp + 1 days,
            block.timestamp + 366 days,
            TEST_PRINCIPAL,
            TEST_INTEREST_RATE
        );
        
        // Try to create second contract for same NFT
        vm.prank(landlord);
        vm.expectRevert("PropertyNFT: Rental contract already exists for this NFT");
        propertyNFT.createRentalContract(
            nftId,
            tenant,
            block.timestamp + 1 days,
            block.timestamp + 366 days,
            TEST_PRINCIPAL,
            TEST_INTEREST_RATE
        );
    }
    
    // ═══════════════════════════════════════════════════════════════════
    // Contract Status Management Tests
    // ═══════════════════════════════════════════════════════════════════
    
    function test_activeRentalContractStatus_Success() public {
        // Setup
        vm.prank(landlord);
        uint256 propertyId = propertyNFT.registerProperty(
            landlord,
            trustAuthority,
            TEST_LTV,
            TEST_ADDRESS
        );
        
        vm.prank(verifier);
        uint256 nftId = propertyNFT.approveProperty(propertyId);
        
        uint256 startDate = block.timestamp;
        vm.prank(landlord);
        propertyNFT.createRentalContract(
            nftId,
            tenant,
            startDate,
            startDate + 365 days,
            TEST_PRINCIPAL,
            TEST_INTEREST_RATE
        );
        
        // Activate contract (normally called by DepositPool)
        propertyNFT.activeRentalContractStatus(nftId);
        
        RentalContract memory rentalContract = propertyNFT.getRentalContract(nftId);
        assertEq(uint256(rentalContract.status), uint256(RentalContractStatus.ACTIVE));
    }
    
    function test_outstandingProperty_Success() public {
        // Setup complete rental contract
        vm.prank(landlord);
        uint256 propertyId = propertyNFT.registerProperty(
            landlord,
            trustAuthority,
            TEST_LTV,
            TEST_ADDRESS
        );
        
        vm.prank(verifier);
        uint256 nftId = propertyNFT.approveProperty(propertyId);
        
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
        
        propertyNFT.activeRentalContractStatus(nftId);
        
        // Fast forward past contract end + grace period
        vm.warp(endDate + 1 days + 1 seconds);
        
        vm.expectEmit(true, false, false, true);
        emit PropertyStatusUpdated(propertyId, PropertyStatus.REGISTERED, PropertyStatus.SUSPENDED);
        
        vm.expectEmit(true, false, false, true);
        emit DebtPropertyListed(nftId, TEST_PRINCIPAL, TEST_INTEREST_RATE);
        
        propertyNFT.outstandingProperty(nftId);
        
        RentalContract memory rentalContract = propertyNFT.getRentalContract(nftId);
        assertEq(uint256(rentalContract.status), uint256(RentalContractStatus.OUTSTANDING));
        
        Property memory prop = propertyNFT.getProperty(propertyId);
        assertEq(uint256(prop.status), uint256(PropertyStatus.SUSPENDED));
    }
    
    function test_outstandingProperty_GracePeriodNotPassed() public {
        // Setup
        vm.prank(landlord);
        uint256 propertyId = propertyNFT.registerProperty(
            landlord,
            trustAuthority,
            TEST_LTV,
            TEST_ADDRESS
        );
        
        vm.prank(verifier);
        uint256 nftId = propertyNFT.approveProperty(propertyId);
        
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
        
        propertyNFT.activeRentalContractStatus(nftId);
        
        // Fast forward to just after contract end but within grace period
        vm.warp(endDate + 12 hours);
        
        vm.expectRevert("PropertyNFT: Grace period not passed");
        propertyNFT.outstandingProperty(nftId);
    }
    
    // ═══════════════════════════════════════════════════════════════════
    // Debt Transfer Tests
    // ═══════════════════════════════════════════════════════════════════
    
    function test_transferDebt_Success() public {
        // Setup outstanding contract
        vm.prank(landlord);
        uint256 propertyId = propertyNFT.registerProperty(
            landlord,
            trustAuthority,
            TEST_LTV,
            TEST_ADDRESS
        );
        
        vm.prank(verifier);
        uint256 nftId = propertyNFT.approveProperty(propertyId);
        
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
        
        propertyNFT.activeRentalContractStatus(nftId);
        vm.warp(endDate + 1 days + 1 seconds);
        propertyNFT.outstandingProperty(nftId);
        
        // Transfer debt
        propertyNFT.transferDebt(nftId, assignee);
        
        RentalContract memory rentalContract = propertyNFT.getRentalContract(nftId);
        assertEq(rentalContract.tenantOrAssignee, assignee);
    }
    
    function test_transferDebt_InvalidAssignee() public {
        // Setup outstanding contract
        vm.prank(landlord);
        uint256 propertyId = propertyNFT.registerProperty(
            landlord,
            trustAuthority,
            TEST_LTV,
            TEST_ADDRESS
        );
        
        vm.prank(verifier);
        uint256 nftId = propertyNFT.approveProperty(propertyId);
        
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
        
        propertyNFT.activeRentalContractStatus(nftId);
        vm.warp(endDate + 1 days + 1 seconds);
        propertyNFT.outstandingProperty(nftId);
        
        vm.expectRevert("PropertyNFT: Invalid assignee address");
        propertyNFT.transferDebt(nftId, address(0));
    }
    
    // ═══════════════════════════════════════════════════════════════════
    // View Function Tests
    // ═══════════════════════════════════════════════════════════════════
    
    function test_getLandlordProperties() public {
        // Register multiple properties
        vm.startPrank(landlord);
        
        uint256 propertyId1 = propertyNFT.registerProperty(
            landlord,
            trustAuthority,
            TEST_LTV,
            TEST_ADDRESS
        );
        
        uint256 propertyId2 = propertyNFT.registerProperty(
            landlord,
            address(0),
            7000,
            keccak256("456 Another Street")
        );
        
        vm.stopPrank();
        
        uint256[] memory properties = propertyNFT.getLandlordProperties(landlord);
        assertEq(properties.length, 2);
        assertEq(properties[0], propertyId1);
        assertEq(properties[1], propertyId2);
    }
    
    function test_getRentalContractsByStatus() public {
        // Setup multiple contracts
        vm.prank(landlord);
        uint256 propertyId1 = propertyNFT.registerProperty(
            landlord,
            trustAuthority,
            TEST_LTV,
            TEST_ADDRESS
        );
        
        vm.prank(landlord);
        uint256 propertyId2 = propertyNFT.registerProperty(
            landlord,
            address(0),
            7000,
            keccak256("456 Another Street")
        );
        
        vm.prank(verifier);
        uint256 nftId1 = propertyNFT.approveProperty(propertyId1);
        
        vm.prank(verifier);
        uint256 nftId2 = propertyNFT.approveProperty(propertyId2);
        
        // Create contracts
        vm.startPrank(landlord);
        propertyNFT.createRentalContract(
            nftId1,
            tenant,
            block.timestamp,
            block.timestamp + 365 days,
            TEST_PRINCIPAL,
            TEST_INTEREST_RATE
        );
        
        propertyNFT.createRentalContract(
            nftId2,
            tenant,
            block.timestamp,
            block.timestamp + 365 days,
            TEST_PRINCIPAL,
            TEST_INTEREST_RATE
        );
        vm.stopPrank();
        
        // Both should be PENDING
        uint256[] memory pendingContracts = propertyNFT.getRentalContractsByStatus(RentalContractStatus.PENDING);
        assertEq(pendingContracts.length, 2);
        assertEq(pendingContracts[0], nftId1);
        assertEq(pendingContracts[1], nftId2);
        
        // Activate one contract
        propertyNFT.activeRentalContractStatus(nftId1);
        
        // Check status filtering
        uint256[] memory activeContracts = propertyNFT.getRentalContractsByStatus(RentalContractStatus.ACTIVE);
        assertEq(activeContracts.length, 1);
        assertEq(activeContracts[0], nftId1);
        
        uint256[] memory stillPendingContracts = propertyNFT.getRentalContractsByStatus(RentalContractStatus.PENDING);
        assertEq(stillPendingContracts.length, 1);
        assertEq(stillPendingContracts[0], nftId2);
    }
    
    // ═══════════════════════════════════════════════════════════════════
    // Access Control & Pausable Tests
    // ═══════════════════════════════════════════════════════════════════
    
    function test_pause_OnlyPauserRole() public {
        vm.prank(admin);
        propertyNFT.pause();
        assertTrue(propertyNFT.paused());
        
        vm.prank(admin);
        propertyNFT.unpause();
        assertFalse(propertyNFT.paused());
        
        // Non-pauser should fail
        vm.prank(landlord);
        vm.expectRevert();
        propertyNFT.pause();
    }
    
    function test_pausedFunctionality() public {
        vm.prank(admin);
        propertyNFT.pause();
        
        // Should revert when paused
        vm.prank(landlord);
        vm.expectRevert();
        propertyNFT.registerProperty(
            landlord,
            trustAuthority,
            TEST_LTV,
            TEST_ADDRESS
        );
    }
    
    // ═══════════════════════════════════════════════════════════════════
    // Repayment Function Tests
    // ═══════════════════════════════════════════════════════════════════
    
    function test_incrementTotalRepaidAmount() public {
        // Setup
        vm.prank(landlord);
        uint256 propertyId = propertyNFT.registerProperty(
            landlord,
            trustAuthority,
            TEST_LTV,
            TEST_ADDRESS
        );
        
        vm.prank(verifier);
        uint256 nftId = propertyNFT.approveProperty(propertyId);
        
        vm.prank(landlord);
        propertyNFT.createRentalContract(
            nftId,
            tenant,
            block.timestamp,
            block.timestamp + 365 days,
            TEST_PRINCIPAL,
            TEST_INTEREST_RATE
        );
        
        // Test increment
        uint256 increment = 50_000_000;
        propertyNFT.incrementTotalRepaidAmount(nftId, increment);
        
        RentalContract memory rentalContract = propertyNFT.getRentalContract(nftId);
        assertEq(rentalContract.totalRepaidAmount, TEST_PRINCIPAL + increment);
    }
    
    function test_incrementCurrentRepaidAmount() public {
        // Setup
        vm.prank(landlord);
        uint256 propertyId = propertyNFT.registerProperty(
            landlord,
            trustAuthority,
            TEST_LTV,
            TEST_ADDRESS
        );
        
        vm.prank(verifier);
        uint256 nftId = propertyNFT.approveProperty(propertyId);
        
        vm.prank(landlord);
        propertyNFT.createRentalContract(
            nftId,
            tenant,
            block.timestamp,
            block.timestamp + 365 days,
            TEST_PRINCIPAL,
            TEST_INTEREST_RATE
        );
        
        // Test increment
        uint256 increment = 25_000_000;
        propertyNFT.incrementCurrentRepaidAmount(nftId, increment);
        
        RentalContract memory rentalContract = propertyNFT.getRentalContract(nftId);
        assertEq(rentalContract.currentRepaidAmount, increment);
    }
    
    function test_updateLastRepaymentTime() public {
        // Setup
        vm.prank(landlord);
        uint256 propertyId = propertyNFT.registerProperty(
            landlord,
            trustAuthority,
            TEST_LTV,
            TEST_ADDRESS
        );
        
        vm.prank(verifier);
        uint256 nftId = propertyNFT.approveProperty(propertyId);
        
        vm.prank(landlord);
        propertyNFT.createRentalContract(
            nftId,
            tenant,
            block.timestamp,
            block.timestamp + 365 days,
            TEST_PRINCIPAL,
            TEST_INTEREST_RATE
        );
        
        // Test update
        uint256 newTime = block.timestamp + 30 days;
        vm.warp(newTime);
        propertyNFT.updateLastRepaymentTime(nftId, newTime);
        
        RentalContract memory rentalContract = propertyNFT.getRentalContract(nftId);
        assertEq(rentalContract.lastRepaymentTime, newTime);
    }
    
    function test_updateLastRepaymentTime_InvalidTime() public {
        // Setup
        vm.prank(landlord);
        uint256 propertyId = propertyNFT.registerProperty(
            landlord,
            trustAuthority,
            TEST_LTV,
            TEST_ADDRESS
        );
        
        vm.prank(verifier);
        uint256 nftId = propertyNFT.approveProperty(propertyId);
        
        vm.prank(landlord);
        propertyNFT.createRentalContract(
            nftId,
            tenant,
            block.timestamp,
            block.timestamp + 365 days,
            TEST_PRINCIPAL,
            TEST_INTEREST_RATE
        );
        
        // Set initial time
        uint256 initialTime = block.timestamp + 30 days;
        vm.warp(initialTime);
        propertyNFT.updateLastRepaymentTime(nftId, initialTime);
        
        // Try to set earlier time (should fail)
        vm.expectRevert("PropertyNFT: Invalid time");
        propertyNFT.updateLastRepaymentTime(nftId, initialTime - 1 days);
    }
}