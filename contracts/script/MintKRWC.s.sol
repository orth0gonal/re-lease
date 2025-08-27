// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "../src/KRWToken.sol";

/**
 * @title MintKRWC
 * @dev Script to mint 1,000,000 KRWC tokens to all addresses for testing
 */
contract MintKRWC is Script {
    // Deployed contract address from kaia_testnet.json
    address public constant KRW_TOKEN_ADDRESS = 0x7a625e7F7E2feFD32aC932f9898f18Cfa7775342;
    
    // Contract instance
    KRWToken public krwToken;

    address public deployer;
    uint256 public deployerPrivateKey;
    address public landlord;
    address public tenant;
    address public assignee;
    
    // Amount to mint to each address (1,000,000 KRWC)
    uint256 public constant MINT_AMOUNT = 1_000_000 * 1e18;
    
    function setUp() public {
        krwToken = KRWToken(KRW_TOKEN_ADDRESS);
        // Get deployer private key from environment
        string memory privateKeyString = vm.envString("DEPLOYER_PRIVATE_KEY");
        string memory privateKeyWithPrefix = string(abi.encodePacked("0x", privateKeyString));
        deployerPrivateKey = vm.parseUint(privateKeyWithPrefix);
        deployer = vm.envAddress("DEPLOYER_ADDRESS");
        landlord = vm.envAddress("LANDLORD_ADDRESS");
        tenant = vm.envAddress("TENANT_ADDRESS");
        assignee = vm.envAddress("ASSIGNEE_ADDRESS");
    }

    function run() external {
        console.log("=== KRWC Token Minting Script ===");
        console.log("KRW Token Address:", KRW_TOKEN_ADDRESS);
        console.log("Deployer Address:", vm.envAddress("DEPLOYER_ADDRESS"));
        console.log("Amount to mint per address:", MINT_AMOUNT);
        console.log("");
        
        // Get all addresses from environment
        address[] memory addresses = new address[](3);
        // addresses[0] = deployer; // Deployer
        addresses[0] = landlord;
        addresses[1] = tenant;
        addresses[2] = assignee;
        
        vm.startBroadcast(deployerPrivateKey);
        
        console.log("=== Starting Minting Process ===");
        
        // Mint to each address
        for (uint256 i = 0; i < addresses.length; i++) {
            address recipient = addresses[i];
            
            if (recipient == address(0)) {
                console.log("Skipping null address at index:", i);
                continue;
            }
            
            // Check current balance
            uint256 currentBalance = krwToken.balanceOf(recipient);
            console.log("Current balance for", recipient, ":", currentBalance);
            
            try krwToken.mint(recipient, MINT_AMOUNT) {
                uint256 newBalance = krwToken.balanceOf(recipient);
                console.log("Successfully minted", MINT_AMOUNT, "KRWC to:", recipient);
                console.log("New balance:", newBalance);
                console.log("");
            } catch Error(string memory reason) {
                console.log("Failed to mint to", recipient, "- Reason:", reason);
                console.log("");
            } catch {
                console.log("Failed to mint to", recipient, "- Unknown error");
                console.log("");
            }
        }
        
        vm.stopBroadcast();
        
        // Final summary
        console.log("=== Minting Summary ===");
        console.log("New Total Supply:", krwToken.totalSupply());
        console.log("Remaining Mintable Supply:", krwToken.remainingSupply());
        
        console.log("");
        console.log("=== Final Balances ===");
        for (uint256 i = 0; i < addresses.length; i++) {
            address recipient = addresses[i];
            if (recipient != address(0)) {
                uint256 finalBalance = krwToken.balanceOf(recipient);
                console.log("Address:", recipient);
                console.log("Balance:", finalBalance);
                console.log("");
            }
        }
        
        console.log("KRWC minting completed successfully!");
    }
    
    /**
     * @dev Helper function to mint to a specific address (for testing)
     * @param recipient Address to mint tokens to
     * @param amount Amount to mint
     */
    function mintToAddress(address recipient, uint256 amount) external {
        vm.startBroadcast(deployerPrivateKey);
        
        krwToken.mint(recipient, amount);
        console.log("Minted", amount, "KRWC to:", recipient);
        console.log("New balance:", krwToken.balanceOf(recipient));
        
        vm.stopBroadcast();
    }
}