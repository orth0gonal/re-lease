// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "../src/KRWToken.sol";
import "../src/PropertyNFT.sol";
import "../src/DepositPool.sol";

/**
 * @title Deploy
 * @dev Deployment script for Re-Lease smart contracts on Kaia testnet
 */
contract Deploy is Script {
    // Deployment addresses will be populated during deployment
    KRWToken public krwToken;
    PropertyNFT public propertyNFT;
    DepositPool public depositPool;
    
    // Configuration parameters
    uint256 public constant KRW_INITIAL_SUPPLY = 100_000_000 * 1e18; // 100M KRW initial supply
    
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
            address(krwToken)
        );
        console.log("   DepositPool deployed at:", address(depositPool));
        console.log("   - PropertyNFT reference:", address(propertyNFT));
        console.log("   - KRW Token reference:", address(krwToken));
        console.log("   - Vault token symbol:", depositPool.symbol());
        console.log("");

        vm.stopBroadcast();

        // Step 4: Verify deployments and log summary
        console.log("4. Deployment Summary:");
        console.log("=======================");
        console.log("KRW Token:             ", address(krwToken));
        console.log("PropertyNFT:           ", address(propertyNFT));
        console.log("DepositPool:           ", address(depositPool));
        console.log("");
        console.log("KRW Token Supply:      ", krwToken.totalSupply());
        console.log("Vault Token Symbol:    ", depositPool.symbol());
        console.log("");
        
        // Verify contract references
        console.log("5. Verifying contract references...");
        address propertyNFTFromDepositPool = address(depositPool.propertyNFT());
        address assetFromDepositPool = address(depositPool.asset());
        
        console.log("   DepositPool -> PropertyNFT:        ", propertyNFTFromDepositPool);
        console.log("   DepositPool -> KRW Token (asset):  ", assetFromDepositPool);
        console.log("");

        // Verify references are correct
        require(propertyNFTFromDepositPool == address(propertyNFT), "DepositPool PropertyNFT reference mismatch");
        require(assetFromDepositPool == address(krwToken), "DepositPool KRW Token reference mismatch");
        
        console.log("SUCCESS: All contract references verified successfully!");
        console.log("");
        
        console.log("6. Access Control Verification:");
        // Verify deployer has required roles
        bool hasKRWTokenAdmin = krwToken.hasRole(krwToken.DEFAULT_ADMIN_ROLE(), deployer);
        bool hasPropertyNFTAdmin = propertyNFT.hasRole(propertyNFT.DEFAULT_ADMIN_ROLE(), deployer);
        bool hasDepositPoolAdmin = depositPool.hasRole(depositPool.DEFAULT_ADMIN_ROLE(), deployer);
        
        console.log("   Deployer has KRW Token admin role:    ", hasKRWTokenAdmin);
        console.log("   Deployer has PropertyNFT admin role:  ", hasPropertyNFTAdmin);
        console.log("   Deployer has DepositPool admin role:  ", hasDepositPoolAdmin);
        
        require(hasKRWTokenAdmin, "Deployer missing KRW Token admin role");
        require(hasPropertyNFTAdmin, "Deployer missing PropertyNFT admin role");
        require(hasDepositPoolAdmin, "Deployer missing DepositPool admin role");
        
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
            '    "DepositPool": "', vm.toString(address(depositPool)), '"\n',
            '  },\n',
            '  "configuration": {\n',
            '    "krwTokenSupply": "', vm.toString(KRW_INITIAL_SUPPLY), '",\n',
            '    "vaultTokenSymbol": "yKRWC",\n',
            '    "vaultTokenName": "yKRWC Vault Token"\n',
            '  }\n',
            '}'
        ));
        
        // Try to save deployment addresses, but don't fail if we can't write the file
        try vm.writeFile("./deployments/kaia_testnet.json", json) {
            console.log("Deployment addresses saved to: ./deployments/kaia_testnet.json");
        } catch {
            console.log("WARNING: Could not save deployment addresses to file");
            console.log("Deployment addresses:");
            console.log("KRW Token: ", address(krwToken));
            console.log("PropertyNFT: ", address(propertyNFT));
            console.log("DepositPool: ", address(depositPool));
        }
    }
}