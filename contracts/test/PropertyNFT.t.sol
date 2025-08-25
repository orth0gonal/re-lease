// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.20;

// import "forge-std/Test.sol";
// import "../src/PropertyNFT.sol";
// import "../src/interfaces/Structs.sol";

// contract PropertyNFTTest is Test {
//     PropertyNFT public propertyNFT;
//     address public admin = address(0x1);
//     address public verifier = address(0x2);
//     address public landlord = address(0x3);
//     address public tenant = address(0x4);

//     function setUp() public {
//         vm.startPrank(admin);
//         propertyNFT = new PropertyNFT();
//         propertyNFT.grantRole(propertyNFT.PROPERTY_VERIFIER_ROLE(), verifier);
//         vm.stopPrank();
//     }

//     function testMintPropertyGasUsage() public {
//         vm.startPrank(verifier);
        
//         uint256 gasStart = gasleft();
//         uint256 tokenId = propertyNFT.approvePropertyProposal(
//             landlord,
//             DistributionChoice.DIRECT,
//             1000000, // 1M KRW deposit
//             true,    // land ownership authority
//             false,   // land trust authority
//             7500,    // 75% LTV
//             keccak256(bytes("Seoul, Gangnam-gu, Teheran-ro 123"))
//         );
//         uint256 gasUsed = gasStart - gasleft();
        
//         vm.stopPrank();
        
//         // Check gas usage is under 150,000
//         console.log("Gas used for minting:", gasUsed);
//         assertLt(gasUsed, 150000, "Minting gas usage exceeds target");
        
//         // Verify the property was created correctly
//         assertEq(tokenId, 1);
//         assertEq(propertyNFT.ownerOf(tokenId), landlord);
        
//         Property memory property = propertyNFT.getProperty(tokenId);
//         assertEq(property.landlord, landlord);
//         assertEq(uint(property.status), uint(PropertyStatus.PENDING));
//         assertEq(uint(property.distributionChoice), uint(DistributionChoice.DIRECT));
//         assertEq(property.depositAmount, 1000000);
//         assertEq(property.ltv, 7500);
//     }
// }