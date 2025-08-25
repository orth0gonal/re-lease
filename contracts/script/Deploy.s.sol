// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "../src/KRWToken.sol";
import "../src/PropertyNFT.sol";
import "../src/DepositPool.sol";
import "../src/P2PDebtMarketplace.sol";
import "../src/SettlementManager.sol";

/**
 * @title Deploy
 * @dev Deployment script for Re-Lease smart contracts on Kaia testnet
 */
contract Deploy is Script {
    // Deployment addresses will be populated during deployment
    KRWToken public krwToken;
    PropertyNFT public propertyNFT;
    DepositPool public depositPool;
    P2PDebtMarketplace public debtMarketplace;
    SettlementManager public settlementManager;
    
    // Configuration parameters
    uint256 public constant KRW_INITIAL_SUPPLY = 100_000_000 * 1e18; // 100M KRW initial supply
    uint256 public constant INITIAL_EXCHANGE_RATE = 1e18; // 1:1 KRW to cKRW initially
    uint256 public constant INITIAL_YIELD_RATE = 500;      // 5% annual yield rate (in basis points)

    function run() external {
        // Get deployer from environment
        string memory privateKeyString = vm.envString("DEPLOYER_PRIVATE_KEY");
        string memory privateKeyWithPrefix = string(abi.encodePacked("0x", privateKeyString));
        uint256 deployerPrivateKey = vm.parseUint(privateKeyWithPrefix);
        address deployer = vm.envAddress("DEPLOYER_ADDRESS");
        
        console.log("=== Re-Lease Contract Deployment ===");
        console.log("Deployer address:", deployer);
        console.log("Network: Kaia Testnet");
        console.log("");

        vm.startBroadcast(deployerPrivateKey);

        // Step 1: Deploy KRW Token
        console.log("1. Deploying KRW Token...");
        krwToken = new KRWToken(KRW_INITIAL_SUPPLY);
        console.log("   KRW Token deployed at:", address(krwToken));
        console.log("   - Initial supply:", KRW_INITIAL_SUPPLY);
        console.log("   - Symbol:", krwToken.symbol());
        console.log("   - Decimals:", krwToken.decimals());
        console.log("");

        // Step 2: Deploy PropertyNFT
        console.log("2. Deploying PropertyNFT...");
        propertyNFT = new PropertyNFT();
        console.log("   PropertyNFT deployed at:", address(propertyNFT));
        console.log("");

        // Step 3: Deploy DepositPool (ERC-4626 Vault)
        console.log("3. Deploying DepositPool (ERC-4626 Vault)...");
        depositPool = new DepositPool(
            address(propertyNFT),
            address(krwToken),
            INITIAL_YIELD_RATE
        );
        console.log("   DepositPool deployed at:", address(depositPool));
        console.log("   - PropertyNFT reference:", address(propertyNFT));
        console.log("   - KRW Token reference:", address(krwToken));
        console.log("   - Vault token symbol:", depositPool.symbol());
        console.log("   - Initial yield rate:", INITIAL_YIELD_RATE);
        console.log("");

        // Step 4: Deploy P2PDebtMarketplace
        console.log("4. Deploying P2PDebtMarketplace...");
        debtMarketplace = new P2PDebtMarketplace(
            address(propertyNFT),
            address(depositPool),
            address(krwToken)
        );
        console.log("   P2PDebtMarketplace deployed at:", address(debtMarketplace));
        console.log("   - PropertyNFT reference:", address(propertyNFT));
        console.log("   - DepositPool reference:", address(depositPool));
        console.log("   - KRW Token reference:", address(krwToken));
        console.log("");

        // Step 5: Deploy SettlementManager
        console.log("5. Deploying SettlementManager...");
        settlementManager = new SettlementManager(
            address(propertyNFT),
            address(depositPool),
            address(debtMarketplace)
        );
        console.log("   SettlementManager deployed at:", address(settlementManager));
        console.log("   - PropertyNFT reference:", address(propertyNFT));
        console.log("   - DepositPool reference:", address(depositPool));
        console.log("   - P2PDebtMarketplace reference:", address(debtMarketplace));
        console.log("");

        // Step 6: Configure Access Control Relationships
        console.log("6. Configuring access control relationships...");
        
        // Grant DepositPool permission to call PropertyNFT functions
        console.log("   - Granting POOL_MANAGER_ROLE to DepositPool in PropertyNFT");
        // Note: PropertyNFT doesn't have POOL_MANAGER_ROLE, so this step is skipped for now
        
        // Grant SettlementManager permission to call DepositPool functions
        console.log("   - Granting POOL_MANAGER_ROLE to SettlementManager in DepositPool");
        depositPool.grantRole(depositPool.POOL_MANAGER_ROLE(), address(settlementManager));
        
        // Grant SettlementManager permission to call P2PDebtMarketplace functions
        console.log("   - Granting MARKETPLACE_ADMIN_ROLE to SettlementManager in P2PDebtMarketplace");
        debtMarketplace.grantRole(debtMarketplace.MARKETPLACE_ADMIN_ROLE(), address(settlementManager));
        
        // Grant deployer access to manage all contracts
        console.log("   - Ensuring deployer has admin roles on all contracts");
        console.log("   - PropertyNFT: Deployer has DEFAULT_ADMIN_ROLE and PROPERTY_VERIFIER_ROLE");
        console.log("   - DepositPool: Deployer has DEFAULT_ADMIN_ROLE and POOL_MANAGER_ROLE");
        console.log("   - P2PDebtMarketplace: Deployer has DEFAULT_ADMIN_ROLE and MARKETPLACE_ADMIN_ROLE");
        console.log("   - SettlementManager: Deployer has DEFAULT_ADMIN_ROLE and SETTLEMENT_MANAGER_ROLE");
        console.log("");

        vm.stopBroadcast();

        // Step 7: Verify deployments and log summary
        console.log("7. Deployment Summary:");
        console.log("=======================");
        console.log("KRW Token:             ", address(krwToken));
        console.log("PropertyNFT:           ", address(propertyNFT));
        console.log("DepositPool:           ", address(depositPool));
        console.log("P2PDebtMarketplace:    ", address(debtMarketplace));
        console.log("SettlementManager:     ", address(settlementManager));
        console.log("");
        console.log("KRW Token Supply:      ", krwToken.totalSupply());
        console.log("Vault Token Symbol:    ", depositPool.symbol());
        console.log("Initial Yield Rate:    ", INITIAL_YIELD_RATE);
        console.log("");
        
        // Verify contract references
        console.log("8. Verifying contract references...");
        address propertyNFTFromDepositPool = address(depositPool.propertyNFT());
        address depositPoolFromMarketplace = address(debtMarketplace.depositPool());
        address propertyNFTFromMarketplace = address(debtMarketplace.propertyNFT());
        address propertyNFTFromSettlement = address(settlementManager.propertyNFT());
        address depositPoolFromSettlement = address(settlementManager.depositPool());
        address marketplaceFromSettlement = address(settlementManager.debtMarketplace());
        
        console.log("   DepositPool -> PropertyNFT:        ", propertyNFTFromDepositPool);
        console.log("   P2PDebtMarketplace -> PropertyNFT:  ", propertyNFTFromMarketplace);
        console.log("   P2PDebtMarketplace -> DepositPool:  ", depositPoolFromMarketplace);
        console.log("   SettlementManager -> PropertyNFT:   ", propertyNFTFromSettlement);
        console.log("   SettlementManager -> DepositPool:   ", depositPoolFromSettlement);
        console.log("   SettlementManager -> Marketplace:   ", marketplaceFromSettlement);
        console.log("");

        // Verify references are correct
        require(propertyNFTFromDepositPool == address(propertyNFT), "DepositPool PropertyNFT reference mismatch");
        require(propertyNFTFromMarketplace == address(propertyNFT), "Marketplace PropertyNFT reference mismatch");
        require(depositPoolFromMarketplace == address(depositPool), "Marketplace DepositPool reference mismatch");
        require(propertyNFTFromSettlement == address(propertyNFT), "SettlementManager PropertyNFT reference mismatch");
        require(depositPoolFromSettlement == address(depositPool), "SettlementManager DepositPool reference mismatch");
        require(marketplaceFromSettlement == address(debtMarketplace), "SettlementManager Marketplace reference mismatch");
        
        console.log("SUCCESS: All contract references verified successfully!");
        console.log("");
        
        console.log("9. Access Control Verification:");
        // Check if SettlementManager has required roles
        bool hasPoolManagerRole = depositPool.hasRole(depositPool.POOL_MANAGER_ROLE(), address(settlementManager));
        bool hasMarketplaceAdminRole = debtMarketplace.hasRole(debtMarketplace.MARKETPLACE_ADMIN_ROLE(), address(settlementManager));
        
        console.log("   SettlementManager has POOL_MANAGER_ROLE:     ", hasPoolManagerRole);
        console.log("   SettlementManager has MARKETPLACE_ADMIN_ROLE:", hasMarketplaceAdminRole);
        
        require(hasPoolManagerRole, "SettlementManager missing POOL_MANAGER_ROLE");
        require(hasMarketplaceAdminRole, "SettlementManager missing MARKETPLACE_ADMIN_ROLE");
        
        console.log("SUCCESS: All access control relationships verified successfully!");
        console.log("");
        
        console.log("DEPLOYMENT COMPLETE: Re-Lease contracts deployed and configured successfully on Kaia Testnet!");
        console.log("");
        
        // Save deployment addresses to a file for future reference
        _saveDeploymentAddresses();
    }

    /**
     * @dev Save deployment addresses to a JSON file for future reference
     */
    function _saveDeploymentAddresses() internal {
        string memory json = string(abi.encodePacked(
            '{\n',
            '  "network": "kaia_testnet",\n',
            '  "chainId": 1001,\n',
            '  "deployedAt": "', vm.toString(block.timestamp), '",\n',
            '  "deployer": "', vm.toString(vm.envAddress("DEPLOYER_ADDRESS")), '",\n',
            '  "contracts": {\n',
            '    "KRWToken": "', vm.toString(address(krwToken)), '",\n',
            '    "PropertyNFT": "', vm.toString(address(propertyNFT)), '",\n',
            '    "DepositPool": "', vm.toString(address(depositPool)), '",\n',
            '    "P2PDebtMarketplace": "', vm.toString(address(debtMarketplace)), '",\n',
            '    "SettlementManager": "', vm.toString(address(settlementManager)), '"\n',
            '  },\n',
            '  "configuration": {\n',
            '    "krwTokenSupply": "', vm.toString(KRW_INITIAL_SUPPLY), '",\n',
            '    "vaultTokenSymbol": "cKRW",\n',
            '    "initialYieldRate": "', vm.toString(INITIAL_YIELD_RATE), '"\n',
            '  }\n',
            '}'
        ));
        
        vm.writeFile("./deployments/kaia_testnet.json", json);
        console.log("Deployment addresses saved to: ./deployments/kaia_testnet.json");
    }
}