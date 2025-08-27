// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../../src/PropertyNFT.sol";
import "../../src/DepositPool.sol";
import "../../src/KRWToken.sol";
import "../../src/interfaces/Structs.sol";

/**
 * @title ContractExpirationTest
 * @dev Integration tests for contract expiration and transition mechanics
 * Tests the automatic conversion from rental relationship to creditor-debtor relationship
 */
contract ContractExpirationTest is Test {
    PropertyNFT public propertyNFT;
    DepositPool public depositPool;
    KRWToken public krwToken;
    
    // Test accounts
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
    uint256 public constant TEST_INTEREST_RATE = 500; // 5% annual
    
    // Time constants
    uint256 public constant CONTRACT_DURATION = 365 days;
    uint256 public constant GRACE_PERIOD = 1 days;
    
    // Events to verify
    event RentalContractCreated(uint256 indexed nftId, address indexed tenant, uint256 principal, uint256 startDate, uint256 endDate, uint256 debtInterestRate);
    event DepositSubmitted(uint256 indexed nftId, address indexed tenant, address indexed landlord, uint256 principal);
    event DebtPropertyListed(uint256 indexed nftId, uint256 principal, uint256 debtInterestRate);
    event PropertyStatusUpdated(uint256 indexed propertyId, PropertyStatus oldStatus, PropertyStatus newStatus);
    
    function setUp() public {
        vm.startPrank(deployer);
        
        // Deploy contracts
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
     * @dev Helper to create active rental contract
     */
    function _createActiveContract() internal returns (uint256 nftId, uint256 propertyId, uint256 startDate, uint256 endDate) {
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
        startDate = block.timestamp;
        endDate = startDate + CONTRACT_DURATION;
        
        vm.prank(landlord);
        propertyNFT.createRentalContract(
            nftId,
            tenant,
            startDate,
            endDate,
            TEST_PRINCIPAL,
            TEST_INTEREST_RATE
        );
        
        // Submit deposit to activate
        vm.prank(tenant);
        krwToken.approve(address(depositPool), TEST_PRINCIPAL);
        vm.prank(tenant);
        depositPool.submitPrincipal(nftId, TEST_PRINCIPAL);
        
        return (nftId, propertyId, startDate, endDate);
    }
    
    /**
     * @dev Test contract expiration timing
     * Tests: 계약 만료 시점 처리
     */
    function test_ContractExpiration_TimingBoundaries() public {
        (uint256 nftId, uint256 propertyId, uint256 startDate, uint256 endDate) = _createActiveContract();
        
        // Verify contract is active before expiration
        RentalContract memory rentalContract = propertyNFT.getRentalContract(nftId);
        assertEq(uint256(rentalContract.status), uint256(RentalContractStatus.ACTIVE));
        assertEq(rentalContract.startDate, startDate);
        assertEq(rentalContract.endDate, endDate);
        
        // Fast forward to exactly contract end time
        vm.warp(endDate);
        
        // Contract should still be active at exact end time
        rentalContract = propertyNFT.getRentalContract(nftId);
        assertEq(uint256(rentalContract.status), uint256(RentalContractStatus.ACTIVE));
        
        // Fast forward to within grace period
        vm.warp(endDate + GRACE_PERIOD / 2);
        
        // Should not be able to list as outstanding yet
        vm.prank(assignee);
        vm.expectRevert("PropertyNFT: Grace period not passed");
        propertyNFT.outstandingProperty(nftId);
        
        // Fast forward to exactly grace period end
        vm.warp(endDate + GRACE_PERIOD);
        
        // Should still not be able to list at exact grace period end
        vm.prank(assignee);
        vm.expectRevert("PropertyNFT: Grace period not passed");
        propertyNFT.outstandingProperty(nftId);
        
        // Fast forward past grace period
        vm.warp(endDate + GRACE_PERIOD + 1 seconds);
        
        // Now should be able to list as outstanding
        vm.prank(assignee);
        propertyNFT.outstandingProperty(nftId);
        
        rentalContract = propertyNFT.getRentalContract(nftId);
        assertEq(uint256(rentalContract.status), uint256(RentalContractStatus.OUTSTANDING));
    }
    
    /**
     * @dev Test transition from tenant-landlord to creditor-debtor relationship
     * Tests: 임차인-임대인 관계에서 채권자-채무자 관계로 전환
     */
    function test_RelationshipTransition_TenantToCreditor() public {
        (uint256 nftId, uint256 propertyId,, uint256 endDate) = _createActiveContract();
        
        // Verify initial tenant-landlord relationship
        RentalContract memory rentalContract = propertyNFT.getRentalContract(nftId);
        assertEq(rentalContract.tenantOrAssignee, tenant);
        assertEq(uint256(rentalContract.status), uint256(RentalContractStatus.ACTIVE));
        
        Property memory property = propertyNFT.getProperty(propertyId);
        assertEq(property.landlord, landlord);
        assertEq(uint256(property.status), uint256(PropertyStatus.REGISTERED));
        
        // Fast forward past grace period
        vm.warp(endDate + GRACE_PERIOD + 1 seconds);
        
        // Transition to outstanding (creditor-debtor relationship)
        vm.expectEmit(true, false, false, true);
        emit PropertyStatusUpdated(propertyId, PropertyStatus.REGISTERED, PropertyStatus.SUSPENDED);
        
        vm.expectEmit(true, false, false, true);
        emit DebtPropertyListed(nftId, TEST_PRINCIPAL, TEST_INTEREST_RATE);
        
        vm.prank(assignee);
        propertyNFT.outstandingProperty(nftId);
        
        // Verify relationship changed
        rentalContract = propertyNFT.getRentalContract(nftId);
        assertEq(rentalContract.tenantOrAssignee, tenant); // Tenant becomes creditor
        assertEq(uint256(rentalContract.status), uint256(RentalContractStatus.OUTSTANDING));
        
        property = propertyNFT.getProperty(propertyId);
        assertEq(property.landlord, landlord); // Landlord becomes debtor
        assertEq(uint256(property.status), uint256(PropertyStatus.SUSPENDED));
        
        // Verify debt terms initialized
        assertEq(rentalContract.principal, TEST_PRINCIPAL);
        assertEq(rentalContract.totalRepaidAmount, TEST_PRINCIPAL); // Initially equals principal
        assertEq(rentalContract.currentRepaidAmount, 0); // No repayments yet
        assertEq(rentalContract.debtInterestRate, TEST_INTEREST_RATE);
    }
    
    /**
     * @dev Test interest accumulation start timing
     * Tests: 이자 누적 시작 시점
     */
    function test_InterestAccumulation_StartTiming() public {
        (uint256 nftId,, uint256 startDate, uint256 endDate) = _createActiveContract();
        
        // Fast forward past grace period
        vm.warp(endDate + GRACE_PERIOD + 1 seconds);
        
        // List as outstanding
        vm.prank(assignee);
        propertyNFT.outstandingProperty(nftId);
        
        RentalContract memory rentalContract = propertyNFT.getRentalContract(nftId);
        
        // Interest should start accumulating from grace period end
        // (Verified by checking lastRepaymentTime is initially 0, meaning interest calculation starts from grace period end)
        assertEq(rentalContract.lastRepaymentTime, 0);
        
        // Fast forward and make a repayment to trigger interest calculation
        vm.warp(endDate + GRACE_PERIOD + 30 days);
        
        uint256 smallRepayment = 1_000_000 * 1e18; // 1M KRWC
        vm.prank(landlord);
        krwToken.approve(address(depositPool), smallRepayment);
        vm.prank(landlord);
        depositPool.repayDebt(nftId, smallRepayment);
        
        // Verify repayment recorded and timestamp updated
        rentalContract = propertyNFT.getRentalContract(nftId);
        assertEq(rentalContract.currentRepaidAmount, smallRepayment);
        assertEq(rentalContract.lastRepaymentTime, block.timestamp);
    }
    
    /**
     * @dev Test multiple expiration scenarios
     * Tests: 다양한 만료 시나리오
     */
    function test_ContractExpiration_MultipleScenarios() public {
        // Scenario 1: Short-term contract (3 months)
        vm.prank(landlord);
        uint256 propertyId1 = propertyNFT.registerProperty(
            landlord,
            address(0),
            TEST_LTV,
            keccak256("Property 1")
        );
        
        vm.prank(verifier);
        uint256 nftId1 = propertyNFT.approveProperty(propertyId1);
        
        uint256 shortTermEnd = block.timestamp + 90 days;
        vm.prank(landlord);
        propertyNFT.createRentalContract(
            nftId1,
            tenant,
            block.timestamp,
            shortTermEnd,
            TEST_PRINCIPAL / 2, // 50M KRWC
            TEST_INTEREST_RATE
        );
        
        vm.prank(tenant);
        krwToken.approve(address(depositPool), TEST_PRINCIPAL / 2);
        vm.prank(tenant);
        depositPool.submitPrincipal(nftId1, TEST_PRINCIPAL / 2);
        
        // Scenario 2: Long-term contract (2 years)
        vm.prank(landlord);
        uint256 propertyId2 = propertyNFT.registerProperty(
            landlord,
            address(0),
            TEST_LTV,
            keccak256("Property 2")
        );
        
        vm.prank(verifier);
        uint256 nftId2 = propertyNFT.approveProperty(propertyId2);
        
        uint256 longTermEnd = block.timestamp + 730 days;
        vm.prank(landlord);
        propertyNFT.createRentalContract(
            nftId2,
            address(0x999), // Different tenant
            block.timestamp,
            longTermEnd,
            TEST_PRINCIPAL * 2, // 200M KRWC
            TEST_INTEREST_RATE
        );
        
        // Give new tenant tokens
        vm.prank(deployer);
        krwToken.transfer(address(0x999), TEST_PRINCIPAL * 3);
        
        vm.prank(address(0x999));
        krwToken.approve(address(depositPool), TEST_PRINCIPAL * 2);
        vm.prank(address(0x999));
        depositPool.submitPrincipal(nftId2, TEST_PRINCIPAL * 2);
        
        // Test short-term expiration
        vm.warp(shortTermEnd + GRACE_PERIOD + 1 seconds);
        
        vm.prank(assignee);
        propertyNFT.outstandingProperty(nftId1);
        
        RentalContract memory contract1 = propertyNFT.getRentalContract(nftId1);
        assertEq(uint256(contract1.status), uint256(RentalContractStatus.OUTSTANDING));
        
        // Long-term contract should still be active
        RentalContract memory contract2 = propertyNFT.getRentalContract(nftId2);
        assertEq(uint256(contract2.status), uint256(RentalContractStatus.ACTIVE));
        
        // Test long-term expiration later
        vm.warp(longTermEnd + GRACE_PERIOD + 1 seconds);
        
        vm.prank(assignee);
        propertyNFT.outstandingProperty(nftId2);
        
        contract2 = propertyNFT.getRentalContract(nftId2);
        assertEq(uint256(contract2.status), uint256(RentalContractStatus.OUTSTANDING));
    }
    
    /**
     * @dev Test prevention of operations during grace period
     * Tests: 유예기간 중 작업 제한
     */
    function test_GracePeriod_OperationRestrictions() public {
        (uint256 nftId, uint256 propertyId,, uint256 endDate) = _createActiveContract();
        
        // Fast forward to within grace period
        vm.warp(endDate + GRACE_PERIOD / 2);
        
        // Should not be able to create new contracts during grace period on expired property
        // (This test verifies that the system properly tracks contract states)
        RentalContract memory rentalContract = propertyNFT.getRentalContract(nftId);
        assertEq(uint256(rentalContract.status), uint256(RentalContractStatus.ACTIVE));
        
        // Should not be able to list as outstanding
        vm.prank(assignee);
        vm.expectRevert("PropertyNFT: Grace period not passed");
        propertyNFT.outstandingProperty(nftId);
        
        // Should not be able to purchase non-existent debt
        vm.prank(assignee);
        krwToken.approve(address(depositPool), TEST_PRINCIPAL);
        vm.prank(assignee);
        vm.expectRevert("DepositPool: Contract not outstanding");
        depositPool.purchaseDebt(nftId, TEST_PRINCIPAL);
        
        // Landlord can still return deposit during grace period
        vm.prank(landlord);
        krwToken.approve(address(depositPool), TEST_PRINCIPAL);
        vm.prank(landlord);
        depositPool.returnPrincipal(nftId, true);
        
        // After landlord returns, tenant can recover
        vm.prank(tenant);
        depositPool.recoverPrincipal(nftId);
        
        // Contract should be completed, preventing outstanding listing
        rentalContract = propertyNFT.getRentalContract(nftId);
        assertEq(uint256(rentalContract.status), uint256(RentalContractStatus.COMPLETED));
        
        vm.warp(endDate + GRACE_PERIOD + 1 seconds);
        vm.prank(assignee);
        vm.expectRevert("PropertyNFT: Contract not active");
        propertyNFT.outstandingProperty(nftId);
    }
    
    /**
     * @dev Test automatic transition with different interest rates
     * Tests: 다양한 이자율로 자동 전환
     */
    function test_AutomaticTransition_DifferentInterestRates() public {
        // Create contracts with different interest rates
        uint256[] memory interestRates = new uint256[](3);
        interestRates[0] = 300; // 3%
        interestRates[1] = 500; // 5%
        interestRates[2] = 1000; // 10%
        
        uint256[] memory nftIds = new uint256[](3);
        uint256[] memory endDates = new uint256[](3);
        
        for (uint256 i = 0; i < 3; i++) {
            // Register property
            vm.prank(landlord);
            uint256 propertyId = propertyNFT.registerProperty(
                landlord,
                address(0),
                TEST_LTV,
                keccak256(abi.encodePacked("Property", i))
            );
            
            vm.prank(verifier);
            nftIds[i] = propertyNFT.approveProperty(propertyId);
            
            // Create contract
            uint256 startDate = block.timestamp;
            endDates[i] = startDate + CONTRACT_DURATION;
            
            vm.prank(landlord);
            propertyNFT.createRentalContract(
                nftIds[i],
                tenant,
                startDate,
                endDates[i],
                TEST_PRINCIPAL,
                interestRates[i]
            );
            
            // Submit deposit
            vm.prank(tenant);
            krwToken.approve(address(depositPool), TEST_PRINCIPAL);
            vm.prank(tenant);
            depositPool.submitPrincipal(nftIds[i], TEST_PRINCIPAL);
        }
        
        // Fast forward past all grace periods
        uint256 maxEndDate = endDates[0];
        for (uint256 i = 1; i < endDates.length; i++) {
            if (endDates[i] > maxEndDate) {
                maxEndDate = endDates[i];
            }
        }
        vm.warp(maxEndDate + GRACE_PERIOD + 1 seconds);
        
        // List all as outstanding and verify interest rates preserved
        for (uint256 i = 0; i < 3; i++) {
            vm.prank(assignee);
            propertyNFT.outstandingProperty(nftIds[i]);
            
            RentalContract memory rentalContract = propertyNFT.getRentalContract(nftIds[i]);
            assertEq(uint256(rentalContract.status), uint256(RentalContractStatus.OUTSTANDING));
            assertEq(rentalContract.debtInterestRate, interestRates[i]);
        }
    }
    
    /**
     * @dev Test batch expiration handling
     * Tests: 대량 만료 처리
     */
    function test_BatchExpiration_SystemLoad() public {
        uint256 contractCount = 5;
        uint256[] memory nftIds = new uint256[](contractCount);
        uint256 commonEndDate = block.timestamp + CONTRACT_DURATION;
        
        // Create multiple contracts with same end date
        for (uint256 i = 0; i < contractCount; i++) {
            address currentTenant = address(uint160(0x1000 + i));
            
            // Give tenant tokens
            vm.prank(deployer);
            krwToken.transfer(currentTenant, TEST_PRINCIPAL * 2);
            
            // Register property
            vm.prank(landlord);
            uint256 propertyId = propertyNFT.registerProperty(
                landlord,
                address(0),
                TEST_LTV,
                keccak256(abi.encodePacked("Batch Property", i))
            );
            
            vm.prank(verifier);
            nftIds[i] = propertyNFT.approveProperty(propertyId);
            
            // Create contract
            vm.prank(landlord);
            propertyNFT.createRentalContract(
                nftIds[i],
                currentTenant,
                block.timestamp,
                commonEndDate,
                TEST_PRINCIPAL,
                TEST_INTEREST_RATE
            );
            
            // Submit deposit
            vm.prank(currentTenant);
            krwToken.approve(address(depositPool), TEST_PRINCIPAL);
            vm.prank(currentTenant);
            depositPool.submitPrincipal(nftIds[i], TEST_PRINCIPAL);
        }
        
        // Fast forward past grace period
        vm.warp(commonEndDate + GRACE_PERIOD + 1 seconds);
        
        // List all as outstanding in batch
        for (uint256 i = 0; i < contractCount; i++) {
            vm.prank(assignee);
            propertyNFT.outstandingProperty(nftIds[i]);
            
            RentalContract memory rentalContract = propertyNFT.getRentalContract(nftIds[i]);
            assertEq(uint256(rentalContract.status), uint256(RentalContractStatus.OUTSTANDING));
        }
        
        // Verify all contracts properly transitioned
        uint256[] memory outstandingContracts = propertyNFT.getRentalContractsByStatus(RentalContractStatus.OUTSTANDING);
        assertEq(outstandingContracts.length, contractCount);
    }
}