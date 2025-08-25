// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../../src/PropertyNFT.sol";
import "../../src/interfaces/Structs.sol";

contract PropertyNFTUnitTest is Test {
    PropertyNFT public propertyNFT;
    
    // Test accounts with specific roles
    address public admin = makeAddr("admin");
    address public verifier = makeAddr("verifier");
    address public landlord1 = makeAddr("landlord1");
    address public landlord2 = makeAddr("landlord2");
    address public tenant1 = makeAddr("tenant1");
    address public tenant2 = makeAddr("tenant2");
    address public unauthorized = makeAddr("unauthorized");
    
    // Test data
    uint256 public constant TEST_DEPOSIT_AMOUNT = 100_000_000 * 1e18; // 100M KRW
    uint256 public constant TEST_LTV = 7000; // 70%
    bytes32 public constant TEST_ADDRESS = keccak256("Seoul, Gangnam-gu");
    bytes32 public constant TEST_DESCRIPTION = keccak256("3-bedroom apartment");
    
    function setUp() public {
        vm.startPrank(admin);
        propertyNFT = new PropertyNFT();
        
        // Grant verifier role
        propertyNFT.grantRole(propertyNFT.PROPERTY_VERIFIER_ROLE(), verifier);
        vm.stopPrank();
    }
    
    // ═══════════════════════════════════════════════════════════════════
    // Property Proposal Tests
    // ═══════════════════════════════════════════════════════════════════
    
    function testProposeProperty() public {
        // CALLER: landlord1 (property owner)
        vm.startPrank(landlord1);
        
        uint256 proposalId = propertyNFT.proposeProperty(
            DistributionChoice.POOL,
            TEST_DEPOSIT_AMOUNT,
            true,  // landOwnershipAuthority
            false, // landTrustAuthority
            TEST_LTV,
            TEST_ADDRESS,
            TEST_DESCRIPTION
        );
        
        vm.stopPrank();
        
        // Verify proposal was created
        PropertyProposal memory proposal = propertyNFT.getPropertyProposal(proposalId);
        assertEq(proposal.landlord, landlord1);
        assertEq(uint(proposal.distributionChoice), uint(DistributionChoice.POOL));
        assertEq(proposal.depositAmount, TEST_DEPOSIT_AMOUNT);
        assertTrue(proposal.landOwnershipAuthority);
        assertFalse(proposal.landTrustAuthority);
        assertEq(proposal.ltv, TEST_LTV);
        assertEq(proposal.registrationAddress, TEST_ADDRESS);
        assertEq(proposal.propertyDescription, TEST_DESCRIPTION);
        assertFalse(proposal.isProcessed);
        
        // Verify deadline is set correctly (14 days from now)
        assertEq(proposal.verificationDeadline, block.timestamp + 14 days);
    }
    
    function testProposePropertyInvalidParams() public {
        // CALLER: landlord1 (property owner)
        vm.startPrank(landlord1);
        
        // Test invalid deposit amount (too low)
        vm.expectRevert("PropertyNFT: Invalid deposit amount");
        propertyNFT.proposeProperty(
            DistributionChoice.POOL,
            1000 * 1e18, // Below minimum
            true, false, TEST_LTV, TEST_ADDRESS, TEST_DESCRIPTION
        );
        
        // Test invalid LTV (too high)
        vm.expectRevert("PropertyNFT: Invalid LTV ratio");
        propertyNFT.proposeProperty(
            DistributionChoice.POOL,
            TEST_DEPOSIT_AMOUNT,
            true, false, 10001, // Above 100%
            TEST_ADDRESS, TEST_DESCRIPTION
        );
        
        vm.stopPrank();
    }
    
    function testApprovePropertyProposal() public {
        // CALLER: landlord1 creates proposal
        vm.prank(landlord1);
        uint256 proposalId = propertyNFT.proposeProperty(
            DistributionChoice.DIRECT,
            TEST_DEPOSIT_AMOUNT,
            true, true, TEST_LTV, TEST_ADDRESS, TEST_DESCRIPTION
        );
        
        // CALLER: verifier (has PROPERTY_VERIFIER_ROLE)
        vm.startPrank(verifier);
        uint256 tokenId = propertyNFT.approvePropertyProposal(proposalId);
        vm.stopPrank();
        
        // Verify NFT was minted
        assertEq(propertyNFT.ownerOf(tokenId), landlord1);
        
        // Verify property data
        Property memory property = propertyNFT.getProperty(tokenId);
        assertEq(property.landlord, landlord1);
        assertEq(uint(property.status), uint(PropertyStatus.PENDING));
        assertEq(uint(property.distributionChoice), uint(DistributionChoice.DIRECT));
        assertEq(property.depositAmount, TEST_DEPOSIT_AMOUNT);
        assertEq(property.proposalId, proposalId);
        
        // Verify proposal is marked as processed
        PropertyProposal memory proposal = propertyNFT.getPropertyProposal(proposalId);
        assertTrue(proposal.isProcessed);
    }
    
    function testApprovePropertyProposalUnauthorized() public {
        // CALLER: landlord1 creates proposal
        vm.prank(landlord1);
        uint256 proposalId = propertyNFT.proposeProperty(
            DistributionChoice.DIRECT,
            TEST_DEPOSIT_AMOUNT,
            true, true, TEST_LTV, TEST_ADDRESS, TEST_DESCRIPTION
        );
        
        // CALLER: unauthorized user (no PROPERTY_VERIFIER_ROLE)
        vm.startPrank(unauthorized);
        bytes32 requiredRole = propertyNFT.PROPERTY_VERIFIER_ROLE();
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                unauthorized,
                requiredRole
            )
        );
        propertyNFT.approvePropertyProposal(proposalId);
        vm.stopPrank();
    }
    
    function testRejectPropertyProposal() public {
        // CALLER: landlord1 creates proposal
        vm.prank(landlord1);
        uint256 proposalId = propertyNFT.proposeProperty(
            DistributionChoice.POOL,
            TEST_DEPOSIT_AMOUNT,
            true, false, TEST_LTV, TEST_ADDRESS, TEST_DESCRIPTION
        );
        
        // CALLER: verifier (has PROPERTY_VERIFIER_ROLE)
        vm.startPrank(verifier);
        string memory reason = "Insufficient documentation";
        propertyNFT.rejectPropertyProposal(proposalId, reason);
        vm.stopPrank();
        
        // Verify proposal is marked as processed
        PropertyProposal memory proposal = propertyNFT.getPropertyProposal(proposalId);
        assertTrue(proposal.isProcessed);
    }
    
    // ═══════════════════════════════════════════════════════════════════
    // Property Verification Tests  
    // ═══════════════════════════════════════════════════════════════════
    
    function testVerifyProperty() public {
        // Setup: Create and approve a proposal
        vm.prank(landlord1);
        uint256 proposalId = propertyNFT.proposeProperty(
            DistributionChoice.POOL,
            TEST_DEPOSIT_AMOUNT,
            true, true, TEST_LTV, TEST_ADDRESS, TEST_DESCRIPTION
        );
        
        vm.prank(verifier);
        uint256 tokenId = propertyNFT.approvePropertyProposal(proposalId);
        
        // CALLER: verifier (has PROPERTY_VERIFIER_ROLE)
        vm.startPrank(verifier);
        propertyNFT.verifyProperty(tokenId);
        vm.stopPrank();
        
        // Verify property status changed to ACTIVE
        Property memory property = propertyNFT.getProperty(tokenId);
        assertEq(uint(property.status), uint(PropertyStatus.ACTIVE));
        assertTrue(property.isVerified);
    }
    
    function testVerifyPropertyUnauthorized() public {
        // Setup: Create and approve a proposal
        vm.prank(landlord1);
        uint256 proposalId = propertyNFT.proposeProperty(
            DistributionChoice.POOL,
            TEST_DEPOSIT_AMOUNT,
            true, true, TEST_LTV, TEST_ADDRESS, TEST_DESCRIPTION
        );
        
        vm.prank(verifier);
        uint256 tokenId = propertyNFT.approvePropertyProposal(proposalId);
        
        // CALLER: unauthorized user (no PROPERTY_VERIFIER_ROLE)
        vm.startPrank(unauthorized);
        bytes32 requiredRole = propertyNFT.PROPERTY_VERIFIER_ROLE();
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                unauthorized,
                requiredRole
            )
        );
        propertyNFT.verifyProperty(tokenId);
        vm.stopPrank();
    }
    
    // ═══════════════════════════════════════════════════════════════════
    // Rental Contract Tests
    // ═══════════════════════════════════════════════════════════════════
    
    function testCreateRentalContract() public {
        // Setup: Create, approve and verify a property
        vm.prank(landlord1);
        uint256 proposalId = propertyNFT.proposeProperty(
            DistributionChoice.DIRECT,
            TEST_DEPOSIT_AMOUNT,
            true, false, TEST_LTV, TEST_ADDRESS, TEST_DESCRIPTION
        );
        
        vm.startPrank(verifier);
        uint256 tokenId = propertyNFT.approvePropertyProposal(proposalId);
        propertyNFT.verifyProperty(tokenId);
        vm.stopPrank();
        
        // CALLER: landlord1 (property owner)
        vm.startPrank(landlord1);
        uint256 startTime = block.timestamp + 1 days;
        uint256 endTime = startTime + 365 days; // 1 year contract
        uint256 proposedDeposit = TEST_DEPOSIT_AMOUNT + 10_000_000 * 1e18; // Higher deposit
        
        propertyNFT.createRentalContract(
            tokenId,
            tenant1,
            startTime,
            endTime,
            proposedDeposit
        );
        vm.stopPrank();
        
        // Verify contract data
        Property memory property = propertyNFT.getProperty(tokenId);
        assertEq(uint(property.status), uint(PropertyStatus.CONTRACT_PENDING));
        assertEq(property.proposedTenant, tenant1);
        assertEq(property.contractStartTime, startTime);
        assertEq(property.contractEndTime, endTime);
        assertEq(property.proposedDepositAmount, proposedDeposit);
    }
    
    function testCreateRentalContractUnauthorized() public {
        // Setup: Create, approve and verify a property
        vm.prank(landlord1);
        uint256 proposalId = propertyNFT.proposeProperty(
            DistributionChoice.DIRECT,
            TEST_DEPOSIT_AMOUNT,
            true, false, TEST_LTV, TEST_ADDRESS, TEST_DESCRIPTION
        );
        
        vm.startPrank(verifier);
        uint256 tokenId = propertyNFT.approvePropertyProposal(proposalId);
        propertyNFT.verifyProperty(tokenId);
        vm.stopPrank();
        
        // CALLER: unauthorized user (not property owner)
        vm.startPrank(unauthorized);
        uint256 startTime = block.timestamp + 1 days;
        uint256 endTime = startTime + 365 days;
        
        vm.expectRevert("PropertyNFT: Only landlord can create contract");
        propertyNFT.createRentalContract(
            tokenId,
            tenant1,
            startTime,
            endTime,
            TEST_DEPOSIT_AMOUNT
        );
        vm.stopPrank();
    }
    
    function testVerifyRentalContract() public {
        // Setup: Create property and rental contract
        vm.prank(landlord1);
        uint256 proposalId = propertyNFT.proposeProperty(
            DistributionChoice.POOL,
            TEST_DEPOSIT_AMOUNT,
            true, true, TEST_LTV, TEST_ADDRESS, TEST_DESCRIPTION
        );
        
        vm.startPrank(verifier);
        uint256 tokenId = propertyNFT.approvePropertyProposal(proposalId);
        propertyNFT.verifyProperty(tokenId);
        vm.stopPrank();
        
        vm.prank(landlord1);
        propertyNFT.createRentalContract(
            tokenId,
            tenant1,
            block.timestamp + 1 days,
            block.timestamp + 366 days,
            TEST_DEPOSIT_AMOUNT
        );
        
        // CALLER: verifier (has PROPERTY_VERIFIER_ROLE)
        vm.startPrank(verifier);
        propertyNFT.verifyRentalContract(tokenId);
        vm.stopPrank();
        
        // Verify contract status changed
        Property memory property = propertyNFT.getProperty(tokenId);
        assertEq(uint(property.status), uint(PropertyStatus.CONTRACT_VERIFIED));
    }
    
    // ═══════════════════════════════════════════════════════════════════
    // Property Status Management Tests
    // ═══════════════════════════════════════════════════════════════════
    
    function testUpdatePropertyStatus() public {
        // Setup: Create property
        vm.prank(landlord1);
        uint256 proposalId = propertyNFT.proposeProperty(
            DistributionChoice.DIRECT,
            TEST_DEPOSIT_AMOUNT,
            true, false, TEST_LTV, TEST_ADDRESS, TEST_DESCRIPTION
        );
        
        vm.prank(verifier);
        uint256 tokenId = propertyNFT.approvePropertyProposal(proposalId);
        
        // CALLER: verifier (has PROPERTY_VERIFIER_ROLE) - verify the property
        vm.startPrank(verifier);
        propertyNFT.verifyProperty(tokenId);
        vm.stopPrank();
        
        // Verify status change
        Property memory property = propertyNFT.getProperty(tokenId);
        assertEq(uint(property.status), uint(PropertyStatus.ACTIVE));
    }
    
    function testUpdatePropertyStatusUnauthorized() public {
        // Setup: Create property
        vm.prank(landlord1);
        uint256 proposalId = propertyNFT.proposeProperty(
            DistributionChoice.DIRECT,
            TEST_DEPOSIT_AMOUNT,
            true, false, TEST_LTV, TEST_ADDRESS, TEST_DESCRIPTION
        );
        
        vm.prank(verifier);
        uint256 tokenId = propertyNFT.approvePropertyProposal(proposalId);
        
        // CALLER: unauthorized user (no PROPERTY_VERIFIER_ROLE)
        vm.startPrank(unauthorized);
        bytes32 requiredRole = propertyNFT.PROPERTY_VERIFIER_ROLE();
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                unauthorized,
                requiredRole
            )
        );
        propertyNFT.verifyProperty(tokenId);
        vm.stopPrank();
    }
    
    // ═══════════════════════════════════════════════════════════════════
    // Access Control Tests
    // ═══════════════════════════════════════════════════════════════════
    
    function testRoleManagement() public {
        // CALLER: admin (has DEFAULT_ADMIN_ROLE)
        vm.startPrank(admin);
        
        // Grant role
        address newVerifier = makeAddr("newVerifier");
        propertyNFT.grantRole(propertyNFT.PROPERTY_VERIFIER_ROLE(), newVerifier);
        assertTrue(propertyNFT.hasRole(propertyNFT.PROPERTY_VERIFIER_ROLE(), newVerifier));
        
        // Revoke role
        propertyNFT.revokeRole(propertyNFT.PROPERTY_VERIFIER_ROLE(), newVerifier);
        assertFalse(propertyNFT.hasRole(propertyNFT.PROPERTY_VERIFIER_ROLE(), newVerifier));
        
        vm.stopPrank();
    }
    
    function testUnauthorizedRoleManagement() public {
        // CALLER: unauthorized user (no admin role)
        vm.startPrank(unauthorized);
        
        address newVerifier = makeAddr("newVerifier");
        bytes32 adminRole = propertyNFT.DEFAULT_ADMIN_ROLE();
        
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                unauthorized,
                adminRole
            )
        );
        propertyNFT.grantRole(propertyNFT.PROPERTY_VERIFIER_ROLE(), newVerifier);
        
        vm.stopPrank();
    }
    
    // ═══════════════════════════════════════════════════════════════════
    // Emergency Pause Tests
    // ═══════════════════════════════════════════════════════════════════
    
    function testPauseUnpause() public {
        // CALLER: admin (has PAUSER_ROLE by default)
        vm.startPrank(admin);
        
        // Pause contract
        propertyNFT.pause();
        assertTrue(propertyNFT.paused());
        
        // Unpause contract
        propertyNFT.unpause();
        assertFalse(propertyNFT.paused());
        
        vm.stopPrank();
    }
    
    function testUnauthorizedPause() public {
        // CALLER: unauthorized user (no PAUSER_ROLE)
        vm.startPrank(unauthorized);
        
        bytes32 pauserRole = propertyNFT.PAUSER_ROLE();
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                unauthorized,
                pauserRole
            )
        );
        propertyNFT.pause();
        
        vm.stopPrank();
    }
    
    function testFunctionsWhenPaused() public {
        // Pause contract
        vm.prank(admin);
        propertyNFT.pause();
        
        // CALLER: landlord1 - should fail when paused
        vm.startPrank(landlord1);
        vm.expectRevert(abi.encodeWithSelector(Pausable.EnforcedPause.selector));
        propertyNFT.proposeProperty(
            DistributionChoice.DIRECT,
            TEST_DEPOSIT_AMOUNT,
            true, false, TEST_LTV, TEST_ADDRESS, TEST_DESCRIPTION
        );
        vm.stopPrank();
    }
}