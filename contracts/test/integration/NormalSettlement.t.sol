// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../../src/PropertyNFT.sol";
import "../../src/DepositPool.sol";
import "../../src/KRWToken.sol";
import "../../src/interfaces/Structs.sol";

/**
 * @title NormalSettlementTest
 * @dev Integration tests for normal settlement process (정상 정산 경로)
 * Tests the complete flow from contract creation to normal settlement
 */
contract NormalSettlementTest is Test {
    PropertyNFT public propertyNFT;
    DepositPool public depositPool;
    KRWToken public krwToken;
    
    // Test accounts - using consistent addresses from deployment scripts
    address public deployer = address(0x1);
    address public verifier = address(0x2);
    address public landlord = address(0x3);
    address public tenant = address(0x4);
    address public assignee = address(0x5);
    
    // Test constants
    uint256 public constant INITIAL_SUPPLY = 1_000_000_000 * 1e18; // 1B KRWC
    uint256 public constant TEST_PRINCIPAL = 100_000_000 * 1e18; // 100M KRWC
    uint256 public constant TEST_LTV = 8000; // 80%
    bytes32 public constant TEST_ADDRESS = keccak256("123 Test Street, Seoul");
    uint256 public constant TEST_INTEREST_RATE = 500; // 5%
    
    // Time constants
    uint256 public constant CONTRACT_DURATION = 365 days;
    uint256 public constant GRACE_PERIOD = 1 days;
    
    // Events to verify
    event RentalContractCreated(uint256 indexed nftId, address indexed tenant, uint256 principal, uint256 contractStartDate, uint256 contractEndDate, uint256 debtInterestRate);
    event DepositSubmitted(uint256 indexed nftId, address indexed tenant, address indexed landlord, uint256 krwcAmount);
    event DepositDistributed(uint256 indexed nftId, address indexed landlord, uint256 yKrwcAmount);
    event DepositRecovered(uint256 indexed nftId, address indexed tenant, uint256 principal);
    
    function setUp() public {
        vm.startPrank(deployer);
        
        // Deploy contracts in correct order
        krwToken = new KRWToken(INITIAL_SUPPLY);
        propertyNFT = new PropertyNFT();
        depositPool = new DepositPool(address(propertyNFT), address(krwToken));
        
        // Setup roles
        propertyNFT.grantRole(propertyNFT.PROPERTY_VERIFIER_ROLE(), verifier);
        
        // Distribute tokens
        krwToken.transfer(landlord, TEST_PRINCIPAL * 3); // 300M KRWC
        krwToken.transfer(tenant, TEST_PRINCIPAL * 3);   // 300M KRWC
        krwToken.transfer(assignee, TEST_PRINCIPAL * 3); // 300M KRWC
        
        vm.stopPrank();
    }
    
    /**
     * @dev Helper to create approved property and rental contract
     * @return nftId The approved property NFT ID
     * @return propertyId The property registration ID
     * @return startDate Contract start timestamp
     * @return endDate Contract end timestamp
     */
    function _createRentalContract() internal returns (uint256 nftId, uint256 propertyId, uint256 startDate, uint256 endDate) {
        // 1. Register property
        vm.prank(landlord);
        propertyId = propertyNFT.registerProperty(
            landlord,
            address(0), // No trust authority
            TEST_LTV,
            TEST_ADDRESS
        );
        
        // 2. Approve property
        vm.prank(verifier);
        nftId = propertyNFT.approveProperty(propertyId);
        
        // 3. Create rental contract
        startDate = block.timestamp;
        endDate = startDate + CONTRACT_DURATION;
        
        vm.expectEmit(true, true, false, true);
        emit RentalContractCreated(nftId, tenant, TEST_PRINCIPAL, startDate, endDate, TEST_INTEREST_RATE);
        
        vm.prank(landlord);
        propertyNFT.createRentalContract(
            nftId,
            tenant,
            startDate,
            endDate,
            TEST_PRINCIPAL,
            TEST_INTEREST_RATE
        );
        
        return (nftId, propertyId, startDate, endDate);
    }
    
    /**
     * @dev Test complete normal settlement flow with KRWC return
     * Tests: 임대인이 KRWC로 보증금 반환하는 정상 정산
     */
    function test_NormalSettlement_WithKRWC() public {
        // Setup: Create rental contract
        (uint256 nftId, uint256 propertyId, uint256 startDate, uint256 endDate) = _createRentalContract();
        
        // Verify initial state
        RentalContract memory rentalContract = propertyNFT.getRentalContract(nftId);
        assertEq(uint256(rentalContract.status), uint256(RentalContractStatus.PENDING));
        
        // Step 1: Tenant submits deposit (보증금 제출)
        uint256 tenantInitialBalance = krwToken.balanceOf(tenant);
        uint256 landlordInitialShares = depositPool.balanceOf(landlord);
        
        vm.prank(tenant);
        krwToken.approve(address(depositPool), TEST_PRINCIPAL);
        
        vm.expectEmit(true, true, true, true);
        emit DepositSubmitted(nftId, tenant, landlord, TEST_PRINCIPAL);
        
        vm.expectEmit(true, true, false, true);
        emit DepositDistributed(nftId, landlord, TEST_PRINCIPAL);
        
        vm.prank(tenant);
        depositPool.submitPrincipal(nftId, TEST_PRINCIPAL);
        
        // Verify deposit submission
        assertEq(krwToken.balanceOf(tenant), tenantInitialBalance - TEST_PRINCIPAL);
        assertGt(depositPool.balanceOf(landlord), landlordInitialShares);
        
        rentalContract = propertyNFT.getRentalContract(nftId);
        assertEq(uint256(rentalContract.status), uint256(RentalContractStatus.ACTIVE));
        
        // Step 2: Fast forward to near contract end (계약 만료 임박)
        vm.warp(endDate - 1 hours);
        
        // Step 3: Landlord returns deposit with KRWC within grace period
        uint256 landlordInitialBalance = krwToken.balanceOf(landlord);
        uint256 poolInitialBalance = krwToken.balanceOf(address(depositPool));
        
        vm.prank(landlord);
        krwToken.approve(address(depositPool), TEST_PRINCIPAL);
        
        vm.prank(landlord);
        depositPool.returnPrincipal(nftId, true); // Return with KRWC
        
        // Verify landlord paid KRWC
        assertEq(krwToken.balanceOf(landlord), landlordInitialBalance - TEST_PRINCIPAL);
        assertEq(krwToken.balanceOf(address(depositPool)), poolInitialBalance + TEST_PRINCIPAL);
        
        // Step 4: Tenant recovers deposit
        tenantInitialBalance = krwToken.balanceOf(tenant);
        
        vm.expectEmit(true, true, false, true);
        emit DepositRecovered(nftId, tenant, TEST_PRINCIPAL);
        
        vm.prank(tenant);
        depositPool.recoverPrincipal(nftId);
        
        // Verify tenant received deposit back
        assertEq(krwToken.balanceOf(tenant), tenantInitialBalance + TEST_PRINCIPAL);
        
        // Verify contract completed
        rentalContract = propertyNFT.getRentalContract(nftId);
        assertEq(uint256(rentalContract.status), uint256(RentalContractStatus.COMPLETED));
        
        // Verify property remains available for future contracts
        Property memory property = propertyNFT.getProperty(propertyId);
        assertEq(uint256(property.status), uint256(PropertyStatus.REGISTERED));
    }
    
    /**
     * @dev Test normal settlement with yKRWC shares return
     * Tests: 임대인이 yKRWC 토큰으로 보증금 반환하는 정상 정산
     */
    function test_NormalSettlement_WithyKRWC() public {
        // Setup: Create rental contract
        (uint256 nftId,, uint256 startDate, uint256 endDate) = _createRentalContract();
        
        // Step 1: Submit deposit
        vm.prank(tenant);
        krwToken.approve(address(depositPool), TEST_PRINCIPAL);
        vm.prank(tenant);
        depositPool.submitPrincipal(nftId, TEST_PRINCIPAL);
        
        uint256 landlordShares = depositPool.balanceOf(landlord);
        assertGt(landlordShares, 0);
        
        // Step 2: Simulate some yield generation by adding assets to pool
        // (In real scenario, this would come from yield-generating strategies)
        uint256 yieldAmount = TEST_PRINCIPAL / 20; // 5% yield
        vm.prank(deployer);
        krwToken.transfer(address(depositPool), yieldAmount);
        
        // Step 3: Fast forward to contract end
        vm.warp(endDate - 1 hours);
        
        // Step 4: Landlord returns with yKRWC shares
        uint256 landlordInitialShares = depositPool.balanceOf(landlord);
        
        // Calculate required shares (should be approximately original principal worth)
        uint256 requiredShares = depositPool.convertToShares(TEST_PRINCIPAL);
        
        vm.prank(landlord);
        depositPool.approve(address(depositPool), requiredShares);
        
        vm.prank(landlord);
        depositPool.returnPrincipal(nftId, false); // Return with yKRWC
        
        // Verify landlord's shares reduced but may retain some yield
        assertLt(depositPool.balanceOf(landlord), landlordInitialShares);
        
        // Step 5: Tenant recovers deposit
        uint256 tenantInitialBalance = krwToken.balanceOf(tenant);
        
        vm.prank(tenant);
        depositPool.recoverPrincipal(nftId);
        
        // Verify tenant received original deposit
        assertEq(krwToken.balanceOf(tenant), tenantInitialBalance + TEST_PRINCIPAL);
        
        // Verify contract completed
        RentalContract memory rentalContract = propertyNFT.getRentalContract(nftId);
        assertEq(uint256(rentalContract.status), uint256(RentalContractStatus.COMPLETED));
    }
    
    /**
     * @dev Test settlement within grace period boundary
     * Tests: 유예기간 내 정산 처리
     */
    function test_NormalSettlement_GracePeriodBoundary() public {
        // Setup
        (uint256 nftId,, uint256 startDate, uint256 endDate) = _createRentalContract();
        
        // Submit deposit
        vm.prank(tenant);
        krwToken.approve(address(depositPool), TEST_PRINCIPAL);
        vm.prank(tenant);
        depositPool.submitPrincipal(nftId, TEST_PRINCIPAL);
        
        // Fast forward to exactly at contract end
        vm.warp(endDate);
        
        // Should still be able to return within grace period
        vm.prank(landlord);
        krwToken.approve(address(depositPool), TEST_PRINCIPAL);
        vm.prank(landlord);
        depositPool.returnPrincipal(nftId, true);
        
        // Fast forward to just before grace period ends
        vm.warp(endDate + GRACE_PERIOD - 1 seconds);
        
        // Tenant should still be able to recover
        vm.prank(tenant);
        depositPool.recoverPrincipal(nftId);
        
        // Verify successful completion
        RentalContract memory rentalContract = propertyNFT.getRentalContract(nftId);
        assertEq(uint256(rentalContract.status), uint256(RentalContractStatus.COMPLETED));
    }
    
    /**
     * @dev Test multiple contract cycles on same property
     * Tests: 동일 부동산에서 연속 계약 처리
     */
    function test_NormalSettlement_MultipleContracts() public {
        // First contract cycle
        (uint256 nftId1, uint256 propertyId,, uint256 endDate1) = _createRentalContract();
        
        vm.prank(tenant);
        krwToken.approve(address(depositPool), TEST_PRINCIPAL);
        vm.prank(tenant);
        depositPool.submitPrincipal(nftId1, TEST_PRINCIPAL);
        
        vm.warp(endDate1 - 1 hours);
        
        vm.prank(landlord);
        krwToken.approve(address(depositPool), TEST_PRINCIPAL);
        vm.prank(landlord);
        depositPool.returnPrincipal(nftId1, true);
        
        vm.prank(tenant);
        depositPool.recoverPrincipal(nftId1);
        
        // Verify first contract completed
        RentalContract memory rentalContract1 = propertyNFT.getRentalContract(nftId1);
        assertEq(uint256(rentalContract1.status), uint256(RentalContractStatus.COMPLETED));
        
        // Property should still be REGISTERED for new contracts
        Property memory property = propertyNFT.getProperty(propertyId);
        assertEq(uint256(property.status), uint256(PropertyStatus.REGISTERED));
        
        // Fast forward and create second contract on same property
        vm.warp(endDate1 + 30 days);
        
        address newTenant = address(0x999);
        vm.prank(deployer);
        krwToken.transfer(newTenant, TEST_PRINCIPAL * 2);
        
        uint256 startDate2 = block.timestamp;
        uint256 endDate2 = startDate2 + CONTRACT_DURATION;
        
        vm.prank(landlord);
        propertyNFT.createRentalContract(
            nftId1, // Same NFT ID
            newTenant,
            startDate2,
            endDate2,
            TEST_PRINCIPAL,
            TEST_INTEREST_RATE
        );
        
        // Submit second deposit
        vm.prank(newTenant);
        krwToken.approve(address(depositPool), TEST_PRINCIPAL);
        vm.prank(newTenant);
        depositPool.submitPrincipal(nftId1, TEST_PRINCIPAL);
        
        // Verify second contract is active
        RentalContract memory rentalContract2 = propertyNFT.getRentalContract(nftId1);
        assertEq(uint256(rentalContract2.status), uint256(RentalContractStatus.ACTIVE));
        assertEq(rentalContract2.tenantOrAssignee, newTenant);
    }
    
    /**
     * @dev Test edge case: Return exactly at grace period end
     * Tests: 유예기간 마지막 순간 정산
     */
    function test_NormalSettlement_GracePeriodEdge() public {
        // Setup
        (uint256 nftId,, uint256 startDate, uint256 endDate) = _createRentalContract();
        
        vm.prank(tenant);
        krwToken.approve(address(depositPool), TEST_PRINCIPAL);
        vm.prank(tenant);
        depositPool.submitPrincipal(nftId, TEST_PRINCIPAL);
        
        // Fast forward to exactly grace period end
        vm.warp(endDate + GRACE_PERIOD);
        
        // Should still be able to return at exact grace period end
        vm.prank(landlord);
        krwToken.approve(address(depositPool), TEST_PRINCIPAL);
        vm.prank(landlord);
        depositPool.returnPrincipal(nftId, true);
        
        vm.prank(tenant);
        depositPool.recoverPrincipal(nftId);
        
        // Verify completed
        RentalContract memory rentalContract = propertyNFT.getRentalContract(nftId);
        assertEq(uint256(rentalContract.status), uint256(RentalContractStatus.COMPLETED));
    }
    
    /**
     * @dev Test failed settlement - insufficient landlord balance
     * Tests: 임대인 잔액 부족으로 인한 정산 실패
     */
    function test_NormalSettlement_InsufficientLandlordBalance() public {
        // Setup
        (uint256 nftId,, uint256 startDate, uint256 endDate) = _createRentalContract();
        
        vm.prank(tenant);
        krwToken.approve(address(depositPool), TEST_PRINCIPAL);
        vm.prank(tenant);
        depositPool.submitPrincipal(nftId, TEST_PRINCIPAL);
        
        // Landlord loses most of their balance
        vm.prank(landlord);
        krwToken.transfer(deployer, krwToken.balanceOf(landlord) - 1000 * 1e18);
        
        vm.warp(endDate - 1 hours);
        
        // Should fail due to insufficient balance
        vm.prank(landlord);
        krwToken.approve(address(depositPool), TEST_PRINCIPAL);
        vm.prank(landlord);
        vm.expectRevert("DepositPool: Insufficient KRWC balance");
        depositPool.returnPrincipal(nftId, true);
        
        // Verify contract still active (not completed)
        RentalContract memory rentalContract = propertyNFT.getRentalContract(nftId);
        assertEq(uint256(rentalContract.status), uint256(RentalContractStatus.ACTIVE));
    }
    
    /**
     * @dev Test multiple settlement attempts (should fail after first)
     * Tests: 중복 정산 시도 방지
     */
    function test_NormalSettlement_DoubleSettlementPrevention() public {
        // Setup and complete normal settlement
        (uint256 nftId,, uint256 startDate, uint256 endDate) = _createRentalContract();
        
        vm.prank(tenant);
        krwToken.approve(address(depositPool), TEST_PRINCIPAL);
        vm.prank(tenant);
        depositPool.submitPrincipal(nftId, TEST_PRINCIPAL);
        
        vm.warp(endDate - 1 hours);
        
        vm.prank(landlord);
        krwToken.approve(address(depositPool), TEST_PRINCIPAL * 2); // Give extra for double attempt
        vm.prank(landlord);
        depositPool.returnPrincipal(nftId, true);
        
        vm.prank(tenant);
        depositPool.recoverPrincipal(nftId);
        
        // Try to settle again (should fail)
        vm.prank(landlord);
        vm.expectRevert("DepositPool: Contract not active");
        depositPool.returnPrincipal(nftId, true);
        
        // Try to recover again (should fail)
        vm.prank(tenant);
        vm.expectRevert("DepositPool: Only original tenant can recover principal");
        depositPool.recoverPrincipal(nftId);
    }
}