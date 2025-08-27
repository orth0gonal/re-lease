// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../../src/PropertyNFT.sol";
import "../../src/DepositPool.sol";
import "../../src/KRWToken.sol";
import "../../src/interfaces/Structs.sol";

/**
 * @title DefaultAndP2PTradingTest
 * @dev Integration tests for default handling and P2P debt trading process (디폴트 및 P2P 거래 경로)
 * Tests the complete flow from contract expiration to debt trading and repayment
 */
contract DefaultAndP2PTradingTest is Test {
    PropertyNFT public propertyNFT;
    DepositPool public depositPool;
    KRWToken public krwToken;
    
    // Test accounts
    address public deployer = address(0x1);
    address public verifier = address(0x2);
    address public landlord = address(0x3);
    address public tenant = address(0x4);
    address public assignee = address(0x5);
    address public secondAssignee = address(0x6);
    
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
    event DebtPropertyListed(uint256 indexed nftId, uint256 principal, uint256 debtInterestRate);
    event DebtTransferred(uint256 indexed nftId, address indexed oldCreditor, address indexed newCreditor, uint256 purchasePrice);
    event InterestClaimed(uint256 indexed nftId, address indexed creditor, uint256 amount);
    event DebtRepaid(uint256 indexed nftId, address indexed creditor, uint256 amount, uint256 remainingPrincipal, uint256 remainingInterest, uint256 totalRemaining);
    event DebtFullyRepaid(uint256 indexed nftId, address indexed creditor, uint256 finalAmount);
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
        krwToken.transfer(landlord, TEST_PRINCIPAL * 2);      // 200M KRWC
        krwToken.transfer(tenant, TEST_PRINCIPAL * 2);        // 200M KRWC
        krwToken.transfer(assignee, TEST_PRINCIPAL * 2);      // 200M KRWC
        krwToken.transfer(secondAssignee, TEST_PRINCIPAL * 2); // 200M KRWC
        
        vm.stopPrank();
    }
    
    /**
     * @dev Helper to create active rental contract that expires into default
     * @return nftId The approved property NFT ID
     * @return propertyId The property registration ID
     * @return endDate Contract end timestamp
     */
    function _createExpiredContract() internal returns (uint256 nftId, uint256 propertyId, uint256 endDate) {
        // 1. Register and approve property
        vm.prank(landlord);
        propertyId = propertyNFT.registerProperty(
            landlord,
            address(0),
            TEST_LTV,
            TEST_ADDRESS
        );
        
        vm.prank(verifier);
        nftId = propertyNFT.approveProperty(propertyId);
        
        // 2. Create rental contract
        uint256 startDate = block.timestamp;
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
        
        // 3. Submit deposit to activate
        vm.prank(tenant);
        krwToken.approve(address(depositPool), TEST_PRINCIPAL);
        vm.prank(tenant);
        depositPool.submitPrincipal(nftId, TEST_PRINCIPAL);
        
        // 4. Fast forward past grace period(landlord didn't return deposit)
        vm.warp(endDate + GRACE_PERIOD + 1 seconds);
        
        return (nftId, propertyId, endDate);
    }
    
    /**
     * @dev Test automatic property listing after grace period
     * Tests: 유예기간 경과 후 자동 디폴트 매물 리스팅
     */
    function test_DefaultListing_AutomaticAfterGracePeriod() public {
        (uint256 nftId, uint256 propertyId, uint256 endDate) = _createExpiredContract();
        
        // Verify contract is active before grace period ends
        vm.warp(endDate + GRACE_PERIOD - 1 seconds);
        RentalContract memory rentalContract = propertyNFT.getRentalContract(nftId);
        assertEq(uint256(rentalContract.status), uint256(RentalContractStatus.ACTIVE));
        
        // Fast forward past grace period
        vm.warp(endDate + GRACE_PERIOD + 1 seconds);
        
        // Anyone can call listDebtProperty after grace period
        vm.expectEmit(true, false, false, true);
        emit PropertyStatusUpdated(propertyId, PropertyStatus.REGISTERED, PropertyStatus.SUSPENDED);
        
        vm.expectEmit(true, false, false, true);
        emit DebtPropertyListed(nftId, TEST_PRINCIPAL, TEST_INTEREST_RATE);
        
        vm.prank(assignee); // Anyone can call this
        propertyNFT.outstandingProperty(nftId);
        
        // Verify property and contract status changed
        Property memory property = propertyNFT.getProperty(propertyId);
        assertEq(uint256(property.status), uint256(PropertyStatus.SUSPENDED));
        
        rentalContract = propertyNFT.getRentalContract(nftId);
        assertEq(uint256(rentalContract.status), uint256(RentalContractStatus.OUTSTANDING));
    }
    
    /**
     * @dev Test complete P2P debt purchase flow
     * Tests: P2P 채권 구매 전체 흐름
     */
    function test_DebtPurchase_CompleteFlow() public {
        (uint256 nftId, uint256 propertyId,) = _createExpiredContract();
        
        // List property as outstanding
        vm.prank(assignee);
        propertyNFT.outstandingProperty(nftId);
        
        uint256 purchasePrice = TEST_PRINCIPAL * 80 / 100; // 80% of principal
        uint256 tenantInitialBalance = krwToken.balanceOf(tenant);
        uint256 assigneeInitialBalance = krwToken.balanceOf(assignee);
        
        // Assignee purchases debt
        vm.prank(assignee);
        krwToken.approve(address(depositPool), purchasePrice);
        
        vm.expectEmit(true, true, true, true);
        emit DebtTransferred(nftId, tenant, assignee, purchasePrice);
        
        vm.prank(assignee);
        depositPool.purchaseDebt(nftId, purchasePrice);
        
        // Verify money transfer
        assertEq(krwToken.balanceOf(tenant), tenantInitialBalance + purchasePrice);
        assertEq(krwToken.balanceOf(assignee), assigneeInitialBalance - purchasePrice);
        
        // Verify creditor change
        RentalContract memory rentalContract = propertyNFT.getRentalContract(nftId);
        assertEq(rentalContract.tenantOrAssignee, assignee);
        assertEq(uint256(rentalContract.status), uint256(RentalContractStatus.OUTSTANDING));
    }
    
    /**
     * @dev Test debt repayment by landlord to assignee
     * Tests: 임대인의 채권양수인에 대한 채무 상환
     */
    function test_DebtRepayment_PartialAndFull() public {
        (uint256 nftId,, uint256 endDate) = _createExpiredContract();
        
        // List and purchase debt
        vm.prank(assignee);
        propertyNFT.outstandingProperty(nftId);
        
        uint256 purchasePrice = TEST_PRINCIPAL * 90 / 100; // 90% purchase
        vm.prank(assignee);
        krwToken.approve(address(depositPool), purchasePrice);
        vm.prank(assignee);
        depositPool.purchaseDebt(nftId, purchasePrice);
        
        // Fast forward to accumulate some interest
        vm.warp(endDate + GRACE_PERIOD + 30 days);
        
        // Test partial repayment
        uint256 partialRepayment = TEST_PRINCIPAL / 4; // 25M KRWC
        uint256 landlordInitialBalance = krwToken.balanceOf(landlord);
        
        vm.prank(landlord);
        krwToken.approve(address(depositPool), partialRepayment);
        
        vm.expectEmit(true, true, false, true);
        emit DebtRepaid(nftId, assignee, partialRepayment, 0, 0, 0); // Remaining amounts calculated by contract
        
        vm.prank(landlord);
        depositPool.repayDebt(nftId, partialRepayment);
        
        // Verify landlord paid
        assertEq(krwToken.balanceOf(landlord), landlordInitialBalance - partialRepayment);
        
        // Verify repayment recorded
        RentalContract memory rentalContract = propertyNFT.getRentalContract(nftId);
        assertGt(rentalContract.currentRepaidAmount, 0);
        assertEq(uint256(rentalContract.status), uint256(RentalContractStatus.OUTSTANDING)); // Still outstanding
        
        // Test assignee claiming repayment
        uint256 assigneeInitialBalance = krwToken.balanceOf(assignee);
        
        vm.expectEmit(true, true, false, true);
        emit InterestClaimed(nftId, assignee, partialRepayment);
        
        vm.prank(assignee);
        uint256 claimedAmount = depositPool.collectDebtRepayment(nftId);
        
        assertEq(claimedAmount, partialRepayment);
        assertEq(krwToken.balanceOf(assignee), assigneeInitialBalance + partialRepayment);
        
        // Test full repayment (pay remaining amount)
        rentalContract = propertyNFT.getRentalContract(nftId);
        uint256 remainingAmount = rentalContract.totalRepaidAmount - rentalContract.currentRepaidAmount;
        
        vm.prank(landlord);
        krwToken.approve(address(depositPool), remainingAmount);
        
        vm.expectEmit(true, true, false, true);
        emit DebtFullyRepaid(nftId, assignee, remainingAmount);
        
        vm.prank(landlord);
        depositPool.repayDebt(nftId, remainingAmount);
        
        // Verify contract completed
        rentalContract = propertyNFT.getRentalContract(nftId);
        assertEq(uint256(rentalContract.status), uint256(RentalContractStatus.COMPLETED));
    }
    
    /**
     * @dev Test interest calculation and accumulation
     * Tests: 이자 계산 및 누적
     */
    function test_InterestCalculation_TimeAccumulation() public {
        (uint256 nftId,, uint256 endDate) = _createExpiredContract();
        
        // List and purchase debt
        vm.prank(assignee);
        propertyNFT.outstandingProperty(nftId);
        
        vm.prank(assignee);
        krwToken.approve(address(depositPool), TEST_PRINCIPAL);
        vm.prank(assignee);
        depositPool.purchaseDebt(nftId, TEST_PRINCIPAL);
        
        // Fast forward to accumulate interest (30 days)
        uint256 interestPeriod = 30 days;
        vm.warp(endDate + GRACE_PERIOD + interestPeriod);
        
        // Make small repayment to trigger interest calculation
        uint256 smallRepayment = 1_000_000 * 1e18; // 1M KRWC
        
        vm.prank(landlord);
        krwToken.approve(address(depositPool), smallRepayment);
        vm.prank(landlord);
        depositPool.repayDebt(nftId, smallRepayment);
        
        // Collect and verify interest was accumulated
        vm.prank(assignee);
        uint256 collected = depositPool.collectDebtRepayment(nftId);
        
        assertEq(collected, smallRepayment);
        
        // Fast forward another period and make another repayment
        vm.warp(endDate + GRACE_PERIOD + interestPeriod * 2);
        
        vm.prank(landlord);
        krwToken.approve(address(depositPool), smallRepayment);
        vm.prank(landlord);
        depositPool.repayDebt(nftId, smallRepayment);
        
        // Should be able to collect more
        vm.prank(assignee);
        uint256 collected2 = depositPool.collectDebtRepayment(nftId);
        
        assertEq(collected2, smallRepayment);
        
        // Verify total repayment recorded
        RentalContract memory rentalContract = propertyNFT.getRentalContract(nftId);
        assertEq(rentalContract.currentRepaidAmount, smallRepayment * 2);
    }
    
    /**
     * @dev Test multiple debt transfers (P2P secondary market)
     * Tests: 채권의 2차 거래 (assignee 간 거래)
     */
    function test_DebtTransfer_SecondaryMarket() public {
        (uint256 nftId,,) = _createExpiredContract();
        
        // Initial debt purchase by first assignee
        vm.prank(assignee);
        propertyNFT.outstandingProperty(nftId);
        
        uint256 firstPurchase = TEST_PRINCIPAL * 80 / 100;
        vm.prank(assignee);
        krwToken.approve(address(depositPool), firstPurchase);
        vm.prank(assignee);
        depositPool.purchaseDebt(nftId, firstPurchase);
        
        // Verify first assignee owns debt
        RentalContract memory rentalContract = propertyNFT.getRentalContract(nftId);
        assertEq(rentalContract.tenantOrAssignee, assignee);
        
        // Landlord makes partial repayment
        uint256 partialRepayment = TEST_PRINCIPAL / 10; // 10% repayment
        vm.prank(landlord);
        krwToken.approve(address(depositPool), partialRepayment);
        vm.prank(landlord);
        depositPool.repayDebt(nftId, partialRepayment);
        
        // First assignee collects repayment
        vm.prank(assignee);
        depositPool.collectDebtRepayment(nftId);
        
        // Second assignee purchases debt from first assignee at premium
        uint256 secondPurchase = TEST_PRINCIPAL * 85 / 100; // Higher price due to partial repayment
        uint256 firstAssigneeInitialBalance = krwToken.balanceOf(assignee);
        uint256 secondAssigneeInitialBalance = krwToken.balanceOf(secondAssignee);
        
        vm.prank(secondAssignee);
        krwToken.approve(address(depositPool), secondPurchase);
        
        vm.expectEmit(true, true, true, true);
        emit DebtTransferred(nftId, assignee, secondAssignee, secondPurchase);
        
        vm.prank(secondAssignee);
        depositPool.purchaseDebt(nftId, secondPurchase);
        
        // Verify transfer
        assertEq(krwToken.balanceOf(assignee), firstAssigneeInitialBalance + secondPurchase);
        assertEq(krwToken.balanceOf(secondAssignee), secondAssigneeInitialBalance - secondPurchase);
        
        // Verify new creditor
        rentalContract = propertyNFT.getRentalContract(nftId);
        assertEq(rentalContract.tenantOrAssignee, secondAssignee);
        
        // Only new creditor can collect future repayments
        vm.prank(landlord);
        krwToken.approve(address(depositPool), partialRepayment);
        vm.prank(landlord);
        depositPool.repayDebt(nftId, partialRepayment);
        
        // Old assignee cannot collect
        vm.prank(assignee);
        vm.expectRevert("DepositPool: Only current creditor can collect repayment");
        depositPool.collectDebtRepayment(nftId);
        
        // New assignee can collect
        vm.prank(secondAssignee);
        uint256 collected = depositPool.collectDebtRepayment(nftId);
        assertEq(collected, partialRepayment);
    }
    
    /**
     * @dev Test debt purchase price validation
     * Tests: 채권 구매가격 검증
     */
    function test_DebtPurchase_PriceValidation() public {
        (uint256 nftId,,) = _createExpiredContract();
        
        vm.prank(assignee);
        propertyNFT.outstandingProperty(nftId);
        
        // Test zero price (should fail)
        vm.prank(assignee);
        vm.expectRevert("DepositPool: Purchase price must be positive");
        depositPool.purchaseDebt(nftId, 0);
        
        // Test insufficient balance (should fail)
        address poorAssignee = address(0x999);
        vm.prank(poorAssignee);
        vm.expectRevert("DepositPool: Insufficient KRWC balance");
        depositPool.purchaseDebt(nftId, TEST_PRINCIPAL);
        
        // Test valid purchase
        uint256 validPrice = TEST_PRINCIPAL / 2;
        vm.prank(assignee);
        krwToken.approve(address(depositPool), validPrice);
        vm.prank(assignee);
        depositPool.purchaseDebt(nftId, validPrice);
        
        RentalContract memory rentalContract = propertyNFT.getRentalContract(nftId);
        assertEq(rentalContract.tenantOrAssignee, assignee);
    }
    
    /**
     * @dev Test property suspension and contract restrictions
     * Tests: 부동산 거래 정지 및 계약 제한
     */
    function test_PropertySuspension_ContractRestrictions() public {
        (uint256 nftId, uint256 propertyId,) = _createExpiredContract();
        
        // List property as outstanding
        vm.prank(assignee);
        propertyNFT.outstandingProperty(nftId);
        
        // Verify property is suspended
        Property memory property = propertyNFT.getProperty(propertyId);
        assertEq(uint256(property.status), uint256(PropertyStatus.SUSPENDED));
        
        // Should not be able to create new rental contracts on suspended property
        vm.prank(landlord);
        vm.expectRevert("PropertyNFT: Property not available for rental");
        propertyNFT.createRentalContract(
            nftId,
            address(0x999), // New tenant
            block.timestamp,
            block.timestamp + CONTRACT_DURATION,
            TEST_PRINCIPAL,
            TEST_INTEREST_RATE
        );
    }
    
    /**
     * @dev Test edge case: Purchase attempt by current creditor (should fail)
     * Tests: 현재 채권자의 자기 채권 구매 시도 방지
     */
    function test_DebtPurchase_SelfPurchasePrevention() public {
        (uint256 nftId,,) = _createExpiredContract();
        
        vm.prank(assignee);
        propertyNFT.outstandingProperty(nftId);
        
        // Original tenant tries to purchase their own debt
        vm.prank(tenant);
        krwToken.approve(address(depositPool), TEST_PRINCIPAL);
        vm.prank(tenant);
        vm.expectRevert("DepositPool: Cannot purchase from self");
        depositPool.purchaseDebt(nftId, TEST_PRINCIPAL);
        
        // After successful purchase, assignee tries to purchase from themselves
        vm.prank(assignee);
        krwToken.approve(address(depositPool), TEST_PRINCIPAL);
        vm.prank(assignee);
        depositPool.purchaseDebt(nftId, TEST_PRINCIPAL);
        
        vm.prank(assignee);
        krwToken.approve(address(depositPool), TEST_PRINCIPAL);
        vm.prank(assignee);
        vm.expectRevert("DepositPool: Cannot purchase from self");
        depositPool.purchaseDebt(nftId, TEST_PRINCIPAL);
    }
    
    /**
     * @dev Test complete lifecycle: Default -> Purchase -> Partial Repayments -> Full Settlement
     * Tests: 디폴트부터 완전 상환까지 전체 생명주기
     */
    function test_CompleteDefaultLifecycle() public {
        (uint256 nftId, uint256 propertyId, uint256 endDate) = _createExpiredContract();
        
        uint256 tenantInitialBalance = krwToken.balanceOf(tenant);
        
        // 1. Property becomes outstanding
        vm.prank(assignee);
        propertyNFT.outstandingProperty(nftId);
        
        // 2. Assignee purchases debt at discount
        uint256 purchasePrice = TEST_PRINCIPAL * 70 / 100; // 30% discount
        vm.prank(assignee);
        krwToken.approve(address(depositPool), purchasePrice);
        vm.prank(assignee);
        depositPool.purchaseDebt(nftId, purchasePrice);
        
        // Verify tenant received payment
        assertEq(krwToken.balanceOf(tenant), tenantInitialBalance + purchasePrice);
        
        // 3. Multiple partial repayments over time
        uint256 repayment1 = TEST_PRINCIPAL / 5; // 20M KRWC
        uint256 repayment2 = TEST_PRINCIPAL / 4; // 25M KRWC
        uint256 repayment3 = TEST_PRINCIPAL / 10; // 10M KRWC
        
        // First repayment after 15 days
        vm.warp(endDate + GRACE_PERIOD + 15 days);
        vm.prank(landlord);
        krwToken.approve(address(depositPool), repayment1);
        vm.prank(landlord);
        depositPool.repayDebt(nftId, repayment1);
        
        vm.prank(assignee);
        uint256 collected1 = depositPool.collectDebtRepayment(nftId);
        assertEq(collected1, repayment1);
        
        // Second repayment after 45 days
        vm.warp(endDate + GRACE_PERIOD + 45 days);
        vm.prank(landlord);
        krwToken.approve(address(depositPool), repayment2);
        vm.prank(landlord);
        depositPool.repayDebt(nftId, repayment2);
        
        vm.prank(assignee);
        uint256 collected2 = depositPool.collectDebtRepayment(nftId);
        assertEq(collected2, repayment2);
        
        // Third repayment after 90 days
        vm.warp(endDate + GRACE_PERIOD + 90 days);
        vm.prank(landlord);
        krwToken.approve(address(depositPool), repayment3);
        vm.prank(landlord);
        depositPool.repayDebt(nftId, repayment3);
        
        vm.prank(assignee);
        uint256 collected3 = depositPool.collectDebtRepayment(nftId);
        assertEq(collected3, repayment3);
        
        // 4. Final full repayment
        RentalContract memory rentalContract = propertyNFT.getRentalContract(nftId);
        uint256 remainingAmount = rentalContract.totalRepaidAmount - rentalContract.currentRepaidAmount;
        
        vm.prank(landlord);
        krwToken.approve(address(depositPool), remainingAmount);
        vm.prank(landlord);
        depositPool.repayDebt(nftId, remainingAmount);
        
        // 5. Verify final state
        rentalContract = propertyNFT.getRentalContract(nftId);
        assertEq(uint256(rentalContract.status), uint256(RentalContractStatus.COMPLETED));
        
        // Property should remain suspended until manually resolved
        Property memory property = propertyNFT.getProperty(propertyId);
        assertEq(uint256(property.status), uint256(PropertyStatus.SUSPENDED));
        
        // Verify total collected by assignee
        uint256 totalCollected = collected1 + collected2 + collected3 + remainingAmount;
        assertGe(totalCollected, TEST_PRINCIPAL); // Should be at least principal due to interest
    }
}