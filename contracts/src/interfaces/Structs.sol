// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title Structs
 * @dev Collection of all structs used across Re-Lease platform contracts
 * Updated to match docs.md specifications exactly
 */

// ═══════════════════════════════════════════════════════════════════
// PropertyNFT Contract Structs
// ═══════════════════════════════════════════════════════════════════

/**
 * @dev Property status enumeration - matches docs.md specification
 * Used in: PropertyNFT.sol
 */
enum PropertyStatus {
    PENDING,           // 등록 대기 중
    REGISTERED,        // 검증 완료, 임대 가능  
    SUSPENDED          // 해당 매물 계약 등록 불가
}

/**
 * @dev Rental contract status enumeration - matches docs.md specification
 * Used in: PropertyNFT.sol
 */
enum RentalContractStatus {
    PENDING,     // 계약 대기 중
    ACTIVE,      // 계약 활성 상태
    COMPLETED,   // 계약 만료 or 채무 이행
    OUTSTANDING  // 채무 불이행 상태
}

/**
 * @dev Property information structure - matches docs.md specification
 * Used in: PropertyNFT.sol
 */
struct Property {
    address landlord;                    // 임대인 이더리움 주소
    PropertyStatus status;               // 현재 상태 [PENDING, REGISTERED, SUSPENDED]
    address trustAuthority;            // 신탁사 이더리움 주소(없으면 zero address)
    bytes32 registrationAddress;         // 등기 도로명 주소(해시)
    uint256 ltv;                        // LTV 비율
}

/**
 * @dev Rental contract structure - matches docs.md specification
 * Used in: PropertyNFT.sol
 */
struct RentalContract {
    uint256 nftId;                      // 연관된 부동산 NFT ID
    address tenantOrAssignee;           // 임차인 또는 채권양수인(자금 수령인)
    uint256 principal;                  // 계약 보증금 (KRWC) - 원금
    uint256 startDate;                  // 계약 시작 시간
    uint256 endDate;                    // 계약 만료 시간
    RentalContractStatus status;        // 계약 상태 [PENDING, ACTIVE, COMPLETED, OUTSTANDING]
    
    uint256 debtInterestRate;           // 미상환 시 연간 이자율 (basis points, 예: 500 = 5%)
    uint256 totalRepaidAmount;          // 총 상환 금액 (원금 + 이자 포함)
    uint256 currentRepaidAmount;        // 현재 상환 금액 (원금 + 이자 포함)
    uint256 lastRepaymentTime;          // 마지막 상환 시간 (이자 계산을 위해 필요)
}