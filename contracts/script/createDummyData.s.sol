// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "../src/KRWToken.sol";
import "../src/PropertyNFT.sol";
import "../src/DepositPool.sol";

/**
 * @title CreateDummyData
 * @dev Script to create dummy data for testing Re-Lease platform
 */
contract CreateDummyData is Script {
    KRWToken public krwToken;
    PropertyNFT public propertyNFT;
    DepositPool public depositPool;
    
    // Test addresses from environment
    address public landlord;
    address public tenant;
    address public assignee;
    
    // Contract parameters
    uint256 public constant PRINCIPAL_1YEAR = 100_000 * 1e18; // 100,000 KRW
    uint256 public constant PRINCIPAL_1SEC = 50_000 * 1e18;   // 50,000 KRW
    uint256 public constant DEBT_INTEREST_RATE = 500; // 5% annual rate
    
    function run() external {
        // Get addresses from environment
        address deployerAddress = vm.envAddress("DEPLOYER_ADDRESS");
        string memory privateKeyString = vm.envString("DEPLOYER_PRIVATE_KEY");
        string memory privateKeyWithPrefix = string(abi.encodePacked("0x", privateKeyString));
        uint256 deployerPrivateKey = vm.parseUint(privateKeyWithPrefix);
        
        // Load deployed contract addresses
        _loadContractAddresses();
        
        // Load test addresses from environment
        _loadTestAddresses();
        
        console.log("=== Creating Dummy Data for Re-Lease ===");
        console.log("Deployer address:", deployerAddress);
        console.log("");
        
        vm.startBroadcast(deployerPrivateKey);
        
        // // Step 1: Setup test accounts with KRW tokens
        // _setupTestAccounts();
        
        // // Step 2: Register 3 properties
        // _registerProperties();
        
        // vm.stopBroadcast();
        
        // // Step 3: Create rental contracts for 2 properties (as landlord)
        // _createRentalContracts();
        
        // // Step 4: Submit deposits for both contracts (as tenant)
        // _submitDeposits();

        /////////////////////////////////////////////////////////////////////
        
        // Step 5: Create outstanding property (as anyone)
        
        // Wait for 1-second contract to expire and create outstanding property
        console.log("5. Creating outstanding property...");
        console.log("   Waiting for 1-second contract to expire...");
        
        // Call outstandingProperty for the 1-second contract (NFT ID 2)
        propertyNFT.outstandingProperty(2);
        console.log("   Outstanding property created for NFT ID 2");
        
        vm.stopBroadcast();
        
        // Step 6: Verify final state
        _verifyFinalState();
        
        console.log("");
        console.log("SUCCESS: Dummy data created successfully!");
    }
    
    function _loadContractAddresses() internal {
        // Load contract addresses from deployment file
        string memory deploymentFile = vm.readFile("./deployments/kaia_testnet.json");
        
        // Parse JSON to extract contract addresses
        address krwTokenAddress = vm.parseJsonAddress(deploymentFile, ".contracts.KRWToken");
        address propertyNFTAddress = vm.parseJsonAddress(deploymentFile, ".contracts.PropertyNFT");
        address depositPoolAddress = vm.parseJsonAddress(deploymentFile, ".contracts.DepositPool");
        
        krwToken = KRWToken(krwTokenAddress);
        propertyNFT = PropertyNFT(propertyNFTAddress);
        depositPool = DepositPool(depositPoolAddress);
        
        console.log("Loaded contract addresses from deployments/kaia_testnet.json:");
        console.log("  KRW Token:", address(krwToken));
        console.log("  PropertyNFT:", address(propertyNFT));
        console.log("  DepositPool:", address(depositPool));
        console.log("");
    }
    
    function _loadTestAddresses() internal {
        // Load test addresses from environment variables
        landlord = vm.envAddress("LANDLORD_ADDRESS");
        tenant = vm.envAddress("TENANT_ADDRESS");
        assignee = vm.envAddress("ASSIGNEE_ADDRESS");
        
        console.log("Loaded test addresses from environment:");
        console.log("  Landlord:", landlord);
        console.log("  Tenant:", tenant);
        console.log("  Assignee:", assignee);
        console.log("");
    }
    
    function _setupTestAccounts() internal {
        console.log("1. Setting up test accounts with KRW tokens...");
        
        // Transfer KRW tokens to test accounts
        uint256 testAmount = 1_000_000 * 1e18; // 1M KRW each
        
        krwToken.transfer(landlord, testAmount);
        krwToken.transfer(tenant, testAmount);
        krwToken.transfer(assignee, testAmount);
        
        console.log("   Transferred", testAmount / 1e18, "KRW to landlord, tenant, and assignee");
        console.log("");
    }
    
    function _registerProperties() internal {
        console.log("2. Registering 3 properties...");
        
        // Register property 1 (for 1-year contract)
        uint256 propertyId1 = propertyNFT.registerProperty(
            landlord,
            address(0), // no trust authority
            7000, // 70% LTV
            keccak256("Seoul Gangnam District Property 1")
        );
        console.log("   Property", propertyId1, "registered for landlord");
        
        // Register property 2 (for 1-second contract)
        uint256 propertyId2 = propertyNFT.registerProperty(
            landlord,
            address(0), // no trust authority
            8000, // 80% LTV
            keccak256("Seoul Seocho District Property 2")
        );
        console.log("   Property", propertyId2, "registered for landlord");
        
        // Register property 3 (no contract)
        uint256 propertyId3 = propertyNFT.registerProperty(
            landlord,
            address(0), // no trust authority
            6500, // 65% LTV
            keccak256("Seoul Yongsan District Property 3")
        );
        console.log("   Property", propertyId3, "registered for landlord");
        
        // Approve all properties
        propertyNFT.approveProperty(propertyId1);
        propertyNFT.approveProperty(propertyId2);
        propertyNFT.approveProperty(propertyId3);
        
        console.log("   All properties approved and NFTs minted");
        console.log("");
    }
    
    function _createRentalContracts() internal {
        console.log("3. Creating rental contracts...");
        
        uint256 currentTime = block.timestamp;
        
        // Get landlord private key
        string memory landlordPrivateKey = vm.envString("LANDLORD_PRIVATE_KEY");
        string memory landlordKeyWithPrefix = string(abi.encodePacked("0x", landlordPrivateKey));
        uint256 landlordKey = vm.parseUint(landlordKeyWithPrefix);
        
        vm.startBroadcast(landlordKey);
        
        // Create 1-year contract (NFT ID 1)
        propertyNFT.createRentalContract(
            1, // NFT ID 1
            tenant,
            currentTime, // start date
            currentTime + 365 days, // end date (1 year)
            PRINCIPAL_1YEAR,
            DEBT_INTEREST_RATE
        );
        console.log("   1-year rental contract created for NFT ID 1");
        console.log("   - Principal:", PRINCIPAL_1YEAR / 1e18, "KRW");
        console.log("   - Duration: 365 days");
        
        // Create 1-second contract (NFT ID 2)
        propertyNFT.createRentalContract(
            2, // NFT ID 2
            tenant,
            currentTime, // start date
            currentTime + 1, // end date (1 second)
            PRINCIPAL_1SEC,
            DEBT_INTEREST_RATE
        );
        console.log("   1-second rental contract created for NFT ID 2");
        console.log("   - Principal:", PRINCIPAL_1SEC / 1e18, "KRW");
        console.log("   - Duration: 1 second");
        console.log("");
        
        vm.stopBroadcast();
    }
    
    function _submitDeposits() internal {
        console.log("4. Submitting deposits...");
        
        // Get tenant private key
        string memory tenantPrivateKey = vm.envString("TENANT_PRIVATE_KEY");
        string memory tenantKeyWithPrefix = string(abi.encodePacked("0x", tenantPrivateKey));
        uint256 tenantKey = vm.parseUint(tenantKeyWithPrefix);
        
        vm.startBroadcast(tenantKey);
        
        // Submit deposit for 1-year contract
        krwToken.approve(address(depositPool), PRINCIPAL_1YEAR);
        depositPool.submitPrincipal(1, PRINCIPAL_1YEAR);
        console.log("   Deposit submitted for NFT ID 1 (1-year contract)");
        
        // Submit deposit for 1-second contract
        krwToken.approve(address(depositPool), PRINCIPAL_1SEC);
        depositPool.submitPrincipal(2, PRINCIPAL_1SEC);
        console.log("   Deposit submitted for NFT ID 2 (1-second contract)");
        console.log("");
        
        vm.stopBroadcast();
    }
    
    function _verifyFinalState() internal view {
        console.log("6. Verifying final state...");
        
        // Check rental contract statuses
        (,,,,,RentalContractStatus status1,,,,) = propertyNFT.rentalContracts(1);
        (,,,,,RentalContractStatus status2,,,,) = propertyNFT.rentalContracts(2);
        
        console.log("   NFT ID 1 rental contract status:", uint256(status1)); // Should be ACTIVE (1)
        console.log("   NFT ID 2 rental contract status:", uint256(status2)); // Should be OUTSTANDING (3)
        
        // Check property statuses
        (, PropertyStatus propStatus1,,,) = propertyNFT.properties(1);
        (, PropertyStatus propStatus2,,,) = propertyNFT.properties(2);
        (, PropertyStatus propStatus3,,,) = propertyNFT.properties(3);
        
        console.log("   Property 1 status:", uint256(propStatus1)); // Should be REGISTERED (1)
        console.log("   Property 2 status:", uint256(propStatus2)); // Should be SUSPENDED (2)
        console.log("   Property 3 status:", uint256(propStatus3)); // Should be REGISTERED (1)
        
        // Check yKRWC balances
        uint256 landlordYBalance = depositPool.balanceOf(landlord);
        
        console.log("   Landlord yKRWC balance:", landlordYBalance / 1e18);
        console.log("");
    }
}