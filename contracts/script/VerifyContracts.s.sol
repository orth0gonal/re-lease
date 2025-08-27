// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "forge-std/console.sol";

/**
 * @title VerifyContracts
 * @dev Script to verify deployed Re-Lease contracts on Kaia testnet
 */
contract VerifyContracts is Script {
    // Deployed contract addresses from kaia_testnet.json
    address public constant KRW_TOKEN_ADDRESS = 0xfDb2145CEd8006f1311b0dE6FDeF89f3479DD6E1;
    address public constant PROPERTY_NFT_ADDRESS = 0x2b2f54b9178F5Fe084055184bB0FCEe828d9fC7B;
    address public constant DEPOSIT_POOL_ADDRESS = 0xD0e632DA0D3ffC36505a23F3294925be3fDc6436;
    
    // Constructor arguments
    uint256 public constant KRW_INITIAL_SUPPLY = 100_000_000 * 1e18; // 100M KRWC from deployment
    
    function run() external {
        console.log("=== Re-Lease Contract Verification Script ===");
        console.log("Network: Kaia Testnet");
        console.log("");
        
        console.log("Contract Addresses:");
        console.log("KRWToken:     ", KRW_TOKEN_ADDRESS);
        console.log("PropertyNFT:  ", PROPERTY_NFT_ADDRESS);
        console.log("DepositPool:  ", DEPOSIT_POOL_ADDRESS);
        console.log("");
        
        // Check if KAIASCAN_API_KEY is set
        try vm.envString("KAIASCAN_API_KEY") returns (string memory apiKey) {
            if (bytes(apiKey).length == 0) {
                console.log("ERROR: KAIASCAN_API_KEY is empty in .env file");
                return;
            }
            console.log("KAIASCAN_API_KEY found in environment");
        } catch {
            console.log("ERROR: KAIASCAN_API_KEY not found in .env file");
            console.log("Please add KAIASCAN_API_KEY to your .env file");
            return;
        }
        
        console.log("");
        console.log("=== Starting Contract Verification ===");
        console.log("");
        
        // Verify KRWToken
        _verifyKRWToken();
        
        // Verify PropertyNFT
        _verifyPropertyNFT();
        
        // Verify DepositPool
        _verifyDepositPool();
        
        console.log("=== Verification Process Complete ===");
        console.log("Check Kaiascan for verification status:");
        console.log("- KRWToken:    https://kaiascan.io/address/", KRW_TOKEN_ADDRESS);
        console.log("- PropertyNFT: https://kaiascan.io/address/", PROPERTY_NFT_ADDRESS);
        console.log("- DepositPool: https://kaiascan.io/address/", DEPOSIT_POOL_ADDRESS);
    }
    
    /**
     * @dev Verify KRWToken contract
     */
    function _verifyKRWToken() internal {
        console.log("1. Verifying KRWToken...");
        console.log("   Address:", KRW_TOKEN_ADDRESS);
        console.log("   Constructor args: initialSupply =", KRW_INITIAL_SUPPLY);
        
        // Encode constructor arguments
        string memory constructorArgs = vm.toString(abi.encode(KRW_INITIAL_SUPPLY));
        
        // Build verification command
        string[] memory verifyCmd = new string[](9);
        verifyCmd[0] = "forge";
        verifyCmd[1] = "verify-contract";
        verifyCmd[2] = "--chain";
        verifyCmd[3] = "kaia";
        verifyCmd[4] = "--etherscan-api-key";
        verifyCmd[5] = vm.envString("KAIASCAN_API_KEY");
        verifyCmd[6] = "--constructor-args";
        verifyCmd[7] = constructorArgs;
        verifyCmd[8] = vm.toString(KRW_TOKEN_ADDRESS);
        
        console.log("   Executing verification command...");
        
        try vm.ffi(verifyCmd) returns (bytes memory result) {
            console.log("   SUCCESS: KRWToken verification submitted");
            console.log("   Result:", string(result));
        } catch Error(string memory reason) {
            console.log("   FAILED: KRWToken verification failed");
            console.log("   Reason:", reason);
        } catch {
            console.log("   FAILED: KRWToken verification failed with unknown error");
        }
        
        console.log("");
    }
    
    /**
     * @dev Verify PropertyNFT contract
     */
    function _verifyPropertyNFT() internal {
        console.log("2. Verifying PropertyNFT...");
        console.log("   Address:", PROPERTY_NFT_ADDRESS);
        console.log("   Constructor args: none");
        
        // Build verification command (no constructor args)
        string[] memory verifyCmd = new string[](7);
        verifyCmd[0] = "forge";
        verifyCmd[1] = "verify-contract";
        verifyCmd[2] = "--chain";
        verifyCmd[3] = "kaia";
        verifyCmd[4] = "--etherscan-api-key";
        verifyCmd[5] = vm.envString("KAIASCAN_API_KEY");
        verifyCmd[6] = vm.toString(PROPERTY_NFT_ADDRESS);
        
        console.log("   Executing verification command...");
        
        try vm.ffi(verifyCmd) returns (bytes memory result) {
            console.log("   SUCCESS: PropertyNFT verification submitted");
            console.log("   Result:", string(result));
        } catch Error(string memory reason) {
            console.log("   FAILED: PropertyNFT verification failed");
            console.log("   Reason:", reason);
        } catch {
            console.log("   FAILED: PropertyNFT verification failed with unknown error");
        }
        
        console.log("");
    }
    
    /**
     * @dev Verify DepositPool contract
     */
    function _verifyDepositPool() internal {
        console.log("3. Verifying DepositPool...");
        console.log("   Address:", DEPOSIT_POOL_ADDRESS);
        console.log("   Constructor args:");
        console.log("     _propertyNFT =", PROPERTY_NFT_ADDRESS);
        console.log("     _krwcToken   =", KRW_TOKEN_ADDRESS);
        
        // Encode constructor arguments
        string memory constructorArgs = vm.toString(abi.encode(PROPERTY_NFT_ADDRESS, KRW_TOKEN_ADDRESS));
        
        // Build verification command
        string[] memory verifyCmd = new string[](9);
        verifyCmd[0] = "forge";
        verifyCmd[1] = "verify-contract";
        verifyCmd[2] = "--chain";
        verifyCmd[3] = "kaia";
        verifyCmd[4] = "--etherscan-api-key";
        verifyCmd[5] = vm.envString("KAIASCAN_API_KEY");
        verifyCmd[6] = "--constructor-args";
        verifyCmd[7] = constructorArgs;
        verifyCmd[8] = vm.toString(DEPOSIT_POOL_ADDRESS);
        
        console.log("   Executing verification command...");
        
        try vm.ffi(verifyCmd) returns (bytes memory result) {
            console.log("   SUCCESS: DepositPool verification submitted");
            console.log("   Result:", string(result));
        } catch Error(string memory reason) {
            console.log("   FAILED: DepositPool verification failed");
            console.log("   Reason:", reason);
        } catch {
            console.log("   FAILED: DepositPool verification failed with unknown error");
        }
        
        console.log("");
    }
    
    /**
     * @dev Manual verification commands (backup method)
     */
    function printManualCommands() external view {
        console.log("=== Manual Verification Commands ===");
        console.log("");
        
        console.log("1. KRWToken:");
        console.log("forge verify-contract --chain kaia --etherscan-api-key $KAIASCAN_API_KEY \\");
        console.log("  --constructor-args $(cast abi-encode \"constructor(uint256)\" 100000000000000000000000000) \\");
        console.log("  0x8F83a3f4bdc8D95B80495c7210F3e34c1Fb473d4 \\");
        console.log("  src/KRWToken.sol:KRWToken");
        console.log("");
        
        console.log("2. PropertyNFT:");
        console.log("forge verify-contract --chain kaia --etherscan-api-key $KAIASCAN_API_KEY \\");
        console.log("  0xF37D765250A25933D1f46C25Db1b5cEC68290E56 \\");
        console.log("  src/PropertyNFT.sol:PropertyNFT");
        console.log("");
        
        console.log("3. DepositPool:");
        console.log("forge verify-contract --chain kaia --etherscan-api-key $KAIASCAN_API_KEY \\");
        console.log("  --constructor-args $(cast abi-encode \"constructor(address,address)\" 0xF37D765250A25933D1f46C25Db1b5cEC68290E56 0x8F83a3f4bdc8D95B80495c7210F3e34c1Fb473d4) \\");
        console.log("  0x79ab091Af72eFd65184E3d964D181D22cFa4b055 \\");
        console.log("  src/DepositPool.sol:DepositPool");
        console.log("");
    }
    
    /**
     * @dev Check verification status by querying Kaiascan API
     */
    function checkVerificationStatus() external {
        console.log("=== Checking Verification Status ===");
        console.log("");
        
        string memory apiKey = vm.envString("KAIASCAN_API_KEY");
        
        // Check KRWToken
        console.log("1. KRWToken verification status:");
        _checkContractStatus(KRW_TOKEN_ADDRESS, apiKey);
        
        // Check PropertyNFT  
        console.log("2. PropertyNFT verification status:");
        _checkContractStatus(PROPERTY_NFT_ADDRESS, apiKey);
        
        // Check DepositPool
        console.log("3. DepositPool verification status:");
        _checkContractStatus(DEPOSIT_POOL_ADDRESS, apiKey);
    }
    
    /**
     * @dev Helper function to check individual contract verification status
     */
    function _checkContractStatus(address contractAddr, string memory apiKey) internal {
        console.log("   Address:", contractAddr);
        console.log("   Check manually at: https://kaiascan.io/address/", contractAddr);
        console.log("");
        
        // Note: Kaiascan API endpoints may differ from Etherscan
        // Users should check manually on the website
    }
}