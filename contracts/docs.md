# Re-Lease Smart Contract 시스템 문서

## 개요

**Re-Lease**는 한국의 전세 계약을 위한 Kaia 블록체인 기반 스마트 계약 플랫폼입니다. KRWC 스테이블코인을 활용하여 전세 보증금을 관리하고, ERC-4626 Vault를 통한 수익 생성, 프론트엔드 기반 P2P 채권 거래를 통한 디폴트 처리를 제공합니다.

### 핵심 특징

- **KRWC 스테이블코인 통합**: 변동성 위험을 제거한 KRWC 스테이블코인 사용
- **토큰화 구조**: KRWC를 수익 창출 가능한 yKRW로 변환하는 ERC-4626 Vault
- **프론트엔드 기반 P2P 거래**: 스마트 계약 데이터를 활용한 프론트엔드 채권 거래 시스템

## 시스템 아키텍처

### 핵심 컨트랙트

1. **PropertyNFT**: ERC-721 기반 부동산 NFT 및 전세 계약 관리
2. **DepositPool**: ERC-4626 Vault 기반 보증금 풀 및 수익 관리

### 주요 참여자

- **임차인 (Tenant)**: 전세 계약자, KRWC 보증금 예치
- **임대인 (Landlord)**: 부동산 소유자, yKRW 토큰 수령 (KRWC로 변환 선택 가능)
- **채권양수인 (Assignee)**: 디폴트 채권 구매자, 프론트엔드를 통한 P2P 거래
- **검증자 (Verifier)**: 부동산 검증 및 계약 승인 권한

## PropertyNFT Contract

### 기능 개요

PropertyNFT는 Re-Lease 플랫폼의 핵심 컨트랙트로, 부동산을 ERC-721 NFT로 토큰화하고 전세 계약의 전체 생명주기를 관리합니다.

### 주요 상태 및 구조

```solidity
enum PropertyStatus {
    PROPOSED,          // 임대인이 제안한 상태, 검증 대기 중
    PENDING,           // 등록 대기 중
    ACTIVE,            // 검증 완료, 임대 가능
    CONTRACT_PENDING,  // 계약 생성, 검증 대기
    CONTRACT_VERIFIED, // 계약 검증 완료, 보증금 대기
    RENTED,            // 임대 중
    SETTLEMENT,        // 정산 진행 중
    OVERDUE,           // 정산 기한 초과
    COMPLETED,         // 정산 완료
    DISPUTED,          // 분쟁 중
    SUSPENDED          // 일시 정지
}

struct Property {
    address landlord;                    // 임대인 주소
    PropertyStatus status;               // 현재 상태 (PROPOSED, ACTIVE, RENTED, EXPIRED, DEFAULTED 등)
    bool landOwnershipAuthority;        // 땅의 소유권한
    bool landTrustAuthority;            // 땅의 신탁권한
    uint256 ltv;                        // LTV 비율
    bytes32 registrationAddress;         // 등기 주소(해시)
    bytes32 propertyDescription;         // 매물 설명(해시)
    uint256 proposalTime;               // 제안 시간 (생성 시간)
    uint256 verificationDeadline;       // 검증 마감일 (14일)
    bool isVerified;                    // 검증 상태
    bool isProcessed;                   // 처리 상태 (승인/거부됨)
}

enum RentalContractStatus {
    PENDING,     // 계약 대기 중
    ACTIVE,      // 계약 활성 상태
    EXPIRED,     // 계약 만료 (유예기간 진행 중)
    DEFAULTED,   // 디폴트 확정 (listDebtProperty 호출됨)
    LISTED       // P2P 시장에서 거래 가능한 상태
}

struct RentalContract {
    uint256 propertyId;                 // 연관된 부동산 NFT ID
    address tenant;                     // 임차인 주소 (원래 채권자)
    address currentCreditor;            // 현재 채권자 (채권양수인 또는 임차인)
    uint256 originPrincipal;            // 계약 보증금 (KRWC) - 원금
    uint256 remainingPrincipal;         // 현재 미상환 원금 잔액
    uint256 contractStartTime;          // 계약 시작 시간
    uint256 contractEndTime;            // 계약 종료 시간
    uint256 createdAt;                  // 계약 생성 시간
    uint256 debtInterestRate;           // 미상환 시 연간 이자율 (basis points, 예: 500 = 5%)
    RentalContractStatus status;        // 계약 상태
    uint256 debtTransferTime;           // 채권 양도 시간 (0이면 양도되지 않음)
    uint256 debtPurchasePrice;          // 채권 구매 가격 (0이면 양도되지 않음)
    uint256 totalInterestClaimed;       // 이미 클레임된 총 이자 금액
    uint256 totalRepaidAmount;          // 총 상환 금액 (원금 + 이자 포함)
    uint256 lastRepaymentTime;          // 마지막 상환 시간
}
```

### 핵심 함수

#### proposeProperty()
```solidity
function proposeProperty(
    bool landOwnershipAuthority,
    bool landTrustAuthority,
    uint256 ltv,
    string calldata registrationAddress,
    string calldata propertyDescription
) external returns (uint256)
```

임대인이 매물을 제안합니다. Property 구조체가 PROPOSED 상태로 생성되며 14일의 검증 기간이 주어집니다.

#### approveProperty()
```solidity
function approveProperty(uint256 propertyId) external onlyRole(PROPERTY_VERIFIER_ROLE)
```

검증자가 매물을 승인합니다. Property.status가 ACTIVE로 변경되고 임대 가능한 상태가 됩니다.

#### rejectProperty()
```solidity
function rejectProperty(uint256 propertyId, string calldata reason) external onlyRole(PROPERTY_VERIFIER_ROLE)
```

검증자가 매물을 거부합니다. Property.isProcessed가 true로 설정되고 거부 사유가 기록됩니다.

#### createRentalContract()
```solidity
function createRentalContract(
    uint256 propertyId,
    address tenant,
    uint256 depositAmount,
    uint256 contractStartTime,
    uint256 contractEndTime,
    uint256 debtInterestRate
) external
```

임대인이 특정 부동산에 대한 전세 계약을 생성합니다. 계약 생성 시:
- RentalContract.originPrincipal = depositAmount (원금 설정)
- RentalContract.remainingPrincipal = depositAmount (초기에는 전액 미상환)
- RentalContract.currentCreditor = tenant (초기 채권자는 임차인)
- RentalContract.debtInterestRate = debtInterestRate (미상환 시 이자율 설정)
- 상환 관련 필드들 모두 0으로 초기화
- 임대인은 보증금을 yKRW 형태로 받게 됩니다

#### listDebtProperty()
```solidity
function listDebtProperty(uint256 propertyId) external
```

계약 만료 후 1일 유예기간이 지난 매물에 대해 **누구나** 호출할 수 있는 함수입니다. 호출되면:
- Property.status가 DEFAULTED로 변경
- RentalContract.status가 LISTED로 변경  
- 프론트엔드 P2P 마켓플레이스에서 거래 가능한 상태가 됨
- 이자는 이 함수 호출과 무관하게 유예기간 종료 시점부터 자동으로 누적

### 권한 관리

- `PROPERTY_VERIFIER_ROLE`: 부동산 검증 및 계약 승인
- `PAUSER_ROLE`: 긴급 일시 정지

## DepositPool Contract

### 기능 개요

DepositPool은 ERC-4626 Vault 표준을 구현하여 KRWC 보증금을 yKRW로 변환하고 수익을 생성합니다.

### 주요 상태

```solidity
enum DepositStatus {
    PENDING,      // 제출 대기
    ACTIVE,       // 활성화됨
    SETTLEMENT,   // 정산 중
    COMPLETED,    // 정산 완료
    DEFAULTED,    // 디폴트 발생
    RECOVERED     // 회수 완료
}
```

### DepositInfo 구조체

```solidity
struct DepositInfo {
    uint256 propertyTokenId;         // 연관된 부동산 NFT ID
    address tenant;                  // 임차인 주소
    address landlord;                // 임대인 주소 (채무자)
    uint256 krwcAmount;             // 원래 KRWC 보증금 금액
    uint256 yKRWShares;             // yKRW 볼트 지분
    uint256 yieldEarned;            // 추가 수익
    DepositStatus status;           // 현재 상태
    uint256 submissionTime;         // 제출 시간
    uint256 expectedReturnTime;     // 예상 반환 시간
    uint256 lastYieldCalculation;   // 마지막 수익 계산 시간
}
```

### 핵심 함수

#### submitDeposit()
```solidity
function submitDeposit(
    uint256 propertyTokenId,
    uint256 krwcAmount
) external nonReentrant whenNotPaused
```

검증된 임차 계약에 대한 보증금을 제출합니다. 모든 보증금은 yKRW Vault에 예치되어 임대인이 yKRW를 받게 됩니다. 임대인은 나중에 yKRW를 KRWC로 변환하거나 그대로 보유할 수 있습니다.

#### calculateYield()
```solidity
function calculateYield(uint256 propertyTokenId) public returns (uint256 yieldAmount)
```

풀 보증금에 대한 수익을 계산하고 업데이트합니다.

#### recoverDeposit()
```solidity
function recoverDeposit(uint256 propertyTokenId) external nonReentrant
```

정산 완료 후 임차인이 원금 보증금을 회수합니다. yKRW 수익은 임대인에게 귀속됩니다.

#### returnDeposit()
```solidity
function returnDeposit(
    uint256 propertyTokenId,
    bool returnAsKRWC
) external nonReentrant
```

임대인이 보증금을 반환합니다. `returnAsKRWC` 파라미터에 따라:
- **true**: 현재 비율로 yKRW를 KRWC로 변환하여 임차인에게 반환
- **false**: yKRW 그대로 반환 (임차인이 yKRW를 받음)

#### withdrawYield()
```solidity
function withdrawYield(uint256 propertyTokenId) external nonReentrant returns (uint256)
```

임대인이 활성 상태인 풀 보증금에서 발생한 수익을 인출합니다.

#### convertToKRWC()
```solidity
function convertToKRWC(uint256 yKRWAmount) external nonReentrant returns (uint256)
```

임대인이 보유한 yKRW를 현재 비율로 KRWC로 변환합니다.

#### transferDebtClaim()
```solidity
function transferDebtClaim(
    uint256 propertyId,
    address newCreditor,
    uint256 purchasePrice
) external nonReentrant
```

채권양수인이 디폴트된 채권을 구매합니다. 호출되면:
- RentalContract.currentCreditor가 newCreditor로 변경
- RentalContract.debtTransferTime이 현재 시간으로 설정
- RentalContract.debtPurchasePrice가 구매 가격으로 설정
- 구매 비용이 기존 채권자(임차인)에게 즉시 전송

#### claimInterest()
```solidity
function claimInterest(uint256 propertyId) external nonReentrant returns (uint256)
```

현재 채권자(임차인 또는 채권양수인)가 누적된 이자를 클레임합니다. 호출되면:
- 유예기간 종료부터 현재까지의 이자를 계산
- 이미 클레임된 이자(totalInterestClaimed)를 제외한 신규 이자만 지급
- RentalContract.totalInterestClaimed에 클레임된 이자 금액 누적
- 클레임된 이자를 현재 채권자에게 전송 (임대인이 미리 예치한 자금에서)

#### repayDebt()
```solidity
function repayDebt(uint256 propertyId, uint256 repayAmount) external nonReentrant
```

임대인이 채무를 상환합니다. 호출되면:
- 현재까지의 총 누적 이자를 계산
- 상환 금액을 현재 채권자에게 전송
- RentalContract.totalRepaidAmount += repayAmount (총 상환 금액 누적)
- RentalContract.lastRepaymentTime = 현재 시간으로 업데이트
- **상환 로직**:
  - 이자 우선 상환: 상환 금액으로 미클레임 이자를 먼저 상환
  - 원금 상환: 이자 상환 후 남은 금액으로 원금 상환
  - RentalContract.remainingPrincipal -= 원금 상환 분
- 완전 상환 시 (remainingPrincipal = 0): 계약 완료 처리

### 수익 생성 메커니즘

1. **Vault 감가상승**: ERC-4626 Vault를 통한 기본 수익 (임대인 귀속)
2. **추가 연수익률**: 설정된 연간 수익률 적용 (임대인 귀속)
3. **복합 이자**: 시간 경과에 따른 자동 복리 계산 (임대인 귀속)

모든 yKRW 수익은 임대인에게 귀속되며, 임차인은 원금만 회수합니다.

### 보증금 반환 방식

임대인은 계약 만료 시 다음 두 가지 방식으로 보증금을 반환할 수 있습니다:

1. **KRWC 반환**: yKRW를 현재 환율로 KRWC로 변환하여 반환
2. **yKRW 반환**: yKRW를 그대로 임차인에게 전송 (임차인이 yKRW 보유)

임대인은 언제든 `convertToKRWC()` 함수를 통해 보유한 yKRW를 KRWC로 변환할 수 있습니다.

## P2P 채권 거래 시스템 (프론트엔드)

### 기능 개요

임대인이 보증금 반환에 실패할 경우, 프론트엔드에서 PropertyNFT와 DepositPool 컨트랙트의 데이터를 조회하여 채권을 P2P 시장에서 거래할 수 있게 하는 시스템입니다.

### 데이터 조회 구조

프론트엔드는 다음 스마트 계약 데이터를 활용하여 채권 정보를 구성합니다:

#### Property 및 RentalContract 구조체 조회
```solidity
// PropertyNFT.getProperty() 및 PropertyNFT.getRentalContract() 호출
struct Property {
    address landlord;                    // 임대인 주소 (채무자)
    PropertyStatus status;               // 현재 상태 (DEFAULTED)
    string propertyDescription;         // 매물 설명
    // ... 기타 필드
}

struct RentalContract {
    uint256 propertyId;                 // 연관된 부동산 NFT ID
    address tenant;                     // 임차인 주소 (원래 채권자)
    address currentCreditor;            // 현재 채권자 (채권양수인 또는 임차인)
    uint256 originPrincipal;            // 계약 보증금 (KRWC) - 원금
    uint256 remainingPrincipal;         // 현재 미상환 원금 잔액
    uint256 contractEndTime;            // 계약 종료 시간
    uint256 debtInterestRate;               // 미상환 시 연간 이자율 (basis points)
    RentalContractStatus status;        // 계약 상태 (LISTED)
    uint256 debtTransferTime;           // 채권 양도 시간 (0이면 양도되지 않음)
    uint256 debtPurchasePrice;          // 채권 구매 가격 (0이면 양돀되지 않음)
    uint256 totalInterestClaimed;       // 이미 클레임된 총 이자 금액
    uint256 totalRepaidAmount;          // 총 상환 금액 (원금 + 이자 포함)
    uint256 lastRepaymentTime;          // 마지막 상환 시간
    // ... 기타 필드
}
```

#### DepositInfo 구조체 조회
```solidity
// DepositPool.getDeposit() 호출
struct DepositInfo {
    uint256 propertyTokenId;         // 연관된 부동산 NFT ID
    address tenant;                  // 임차인 주소
    address landlord;                // 임대인 주소 (채무자)
    uint256 krwcAmount;             // 원금 금액
    DepositStatus status;           // DEFAULTED 상태
    uint256 expectedReturnTime;     // 계약 만료 시간
    // ... 기타 필드 (yKRW 관련)
}
```

### 프론트엔드 P2P 거래 로직

#### 1. 디폴트 채권 식별 및 리스팅
```typescript
// 유예기간(1일) 경과한 만료 계약 조회
const expiredContracts = await identifyDefaultedContracts();

// 조건 1: 유예기간 경과 확인
// - RentalContract.status === EXPIRED
// - block.timestamp > contractEndTime + 1 day
// - DepositInfo.status === DEFAULTED

// 조건 2: listDebtProperty() 호출로 거래 가능 상태로 전환
// - PropertyNFT.listDebtProperty(propertyId) 호출 (누구나 가능)
// - Property.status => DEFAULTED로 변경
// - RentalContract.status => LISTED로 변경
// - 프론트엔드에서 거래 가능한 상태로 표시
```

#### 2. 채권 거래 정보 구성 (프론트엔드)
```typescript
interface DebtClaim {
    propertyTokenId: uint256;        // 부동산 NFT ID
    originalCreditor: address;       // 원래 채권자 (임차인)
    currentCreditor: address;        // 현재 채권자 (채권양수인 또는 임차인)
    debtor: address;                 // 채무자 (임대인)
    originalPrincipalAmount: uint256; // 원래 원금 금액
    remainingPrincipal: uint256;     // 현재 미상환 원금 잔액
    debtInterestRate: uint256;           // 연 이자율 (RentalContract.debtInterestRate 사용)
    gracePeriodEnd: uint256;         // 유예기간 종료 시점 (이자 시작점)
    listingTime: uint256;            // listDebtProperty() 호출 시점
    listingPrice: uint256;           // 채권 판매 가격
    status: 'LISTED' | 'SOLD' | 'REPAID'; // 거래 상태
    propertyDescription: string;     // 매물 설명 (Property에서 조회)
    debtTransferTime: uint256;       // 채권 양도 시간 (0이면 양도되지 않음)
    debtPurchasePrice: uint256;      // 채권 구매 가격 (0이면 양도되지 않음)
    totalInterestClaimed: uint256;   // 이미 클레임된 총 이자 금액
    totalRepaidAmount: uint256;      // 총 상환 금액 (원금 + 이자 포함)
    lastRepaymentTime: uint256;      // 마지막 상환 시간
    hasBeenTransferred: boolean;     // 채권 양도 여부
}
```

#### 3. 채권 구매 및 이자 관리 (프론트엔드 + 스마트 계약)
```typescript
// 1. 채권양수인이 구매 의사 표명 (프론트엔드)
// 2. PropertyNFT.transferDebtClaim() 호출
await propertyNFT.transferDebtClaim(propertyId, newCreditor, purchasePrice);

// 3. 채권양수인의 이자 클레임
await propertyNFT.claimInterest(propertyId); // 누적된 이자 클레임

// 4. 임대인의 부분 상환
await propertyNFT.repayDebt(propertyId, partialAmount); // 일부 상환

// 5. 미상환 잔액 추적 및 이자 누적
// - RentalContract.remainingPrincipal에서 실시간 잔액 확인
// - 잔액(remainingPrincipal)에 대해서만 이자 계속 발생
// - 상환 히스토리는 totalRepaidAmount, remainingPrincipal에서 확인
```

### 이자 계산 및 관리 시스템

이자는 **유예기간 종료 시점**부터 누적되며, `listDebtProperty()` 함수 호출과는 무관합니다. 이자율은 계약 생성 시 설정된 RentalContract.debtInterestRate 값을 사용합니다. 채권자는 언제든 누적된 이자를 클레임할 수 있고, 임대인은 부분 상환이 가능합니다:

```typescript
// 1. 기본 이자 계산 (미상환 잔액에 대한 누적 이자)
function calculateTotalAccruedInterest(
    remainingPrincipal: bigint, // RentalContract.remainingPrincipal 사용
    debtInterestRate: bigint, // 연 이자율 (RentalContract.debtInterestRate, basis points)
    gracePeriodEnd: bigint, // 유예기간 종료 시점 (이자 시작점)
    currentTime: bigint
): bigint {
    const timeElapsed = currentTime - gracePeriodEnd;
    
    if (timeElapsed <= 0n) return 0n; // 유예기간 내라면 이자 없음
    
    const annualInterest = (remainingPrincipal * debtInterestRate) / 10000n;
    const totalAccruedInterest = (annualInterest * timeElapsed) / (365n * 24n * 60n * 60n);
    return totalAccruedInterest;
}

// 2. 클레임 가능한 신규 이자 계산
function getClaimableInterest(
    remainingPrincipal: bigint, // RentalContract.remainingPrincipal
    debtInterestRate: bigint,
    gracePeriodEnd: bigint,
    totalInterestClaimed: bigint, // RentalContract.totalInterestClaimed
    currentTime: bigint
): bigint {
    const totalAccruedInterest = calculateTotalAccruedInterest(
        remainingPrincipal, debtInterestRate, gracePeriodEnd, currentTime
    );
    
    // 총 누적 이자에서 이미 클레임된 이자를 제외한 신규 이자
    return totalAccruedInterest > totalInterestClaimed 
        ? totalAccruedInterest - totalInterestClaimed 
        : 0n;
}

// 3. 전체 채무 금액 계산 (원금 + 미클레임 이자)
function getTotalDebtAmount(
    remainingPrincipal: bigint, // RentalContract.remainingPrincipal
    debtInterestRate: bigint,
    gracePeriodEnd: bigint,
    totalInterestClaimed: bigint, // RentalContract.totalInterestClaimed
    currentTime: bigint
): bigint {
    const claimableInterest = getClaimableInterest(
        remainingPrincipal, debtInterestRate, gracePeriodEnd, 
        totalInterestClaimed, currentTime
    );
    return remainingPrincipal + claimableInterest;
}

// 4. 상환 처리 로직 (repayDebt 함수에서 사용)
function processRepayment(
    repayAmount: bigint,
    remainingPrincipal: bigint, // RentalContract.remainingPrincipal
    totalInterestClaimed: bigint, // RentalContract.totalInterestClaimed
    claimableInterest: bigint // 현재 클레임 가능한 이자
): {
    interestPayment: bigint,
    principalPayment: bigint,
    newRemainingPrincipal: bigint,
    newTotalInterestClaimed: bigint
} {
    // 이자 우선 상환
    const interestPayment = repayAmount > claimableInterest ? claimableInterest : repayAmount;
    const principalPayment = repayAmount - interestPayment;
    
    return {
        interestPayment,
        principalPayment,
        newRemainingPrincipal: remainingPrincipal - principalPayment,
        newTotalInterestClaimed: totalInterestClaimed + interestPayment
    };
}
```


## 전체 프로세스 플로우

### 1. 매물 등록 프로세스

```
1. [임대인] PropertyNFT.proposeProperty(landOwnershipAuthority, landTrustAuthority, ltv, registrationAddress, propertyDescription)
   └─ 결과: Property 구조체 생성 (status = PROPOSED), 14일 검증 기간 시작

2. [검증자] PropertyNFT.approveProperty(propertyId) 또는 rejectProperty(propertyId, reason)
   ├─ 승인시: Property.status = ACTIVE, 임대 가능한 상태
   └─ 거부시: Property.isProcessed = true, 거부 사유 기록
```

### 2. 전세 계약 체결 프로세스

```
1. [임대인] PropertyNFT.createRentalContract(propertyId, tenant, depositAmount, contractStartTime, contractEndTime, debtInterestRate)
   └─ 결과: RentalContract 생성, 계약 조건 확정

2. [임차인] DepositPool.submitDeposit(propertyTokenId, krwcAmount)
   └─ 보증금을 KRWC로 제출하여 yKRW Vault에 예치
   ├─ KRWC → yKRW 변환 후 임대인에게 yKRW 전송
   ├─ 임대인은 yKRW를 보유하거나 KRWC로 변환 선택 가능
   └─ 계약 상태 = ACTIVE로 변경
```

### 3. 계약 만료 및 정산 프로세스

```
1. [계약 만료] 전세 계약 기간 종료
   └─ 계약 상태 = EXPIRED로 자동 변경
   └─ 임차인-임대인 관계가 채권자-채무자 관계로 전환
   └─ 1일 유예 기간 시작

2-A. [정상 정산 경로] 유예기간 내 보증금 반환
   ├─ [임대인] DepositPool.returnDeposit(propertyId, returnAsKRWC) 호출
   │   ├─ returnAsKRWC = true: yKRW를 KRWC로 변환하여 임차인에게 반환
   │   └─ returnAsKRWC = false: yKRW를 그대로 임차인에게 반환
   ├─ 계약 당시에 해당하는 가치의 yKRW만큼이 임차인에게 돌아가고, 수익 증가분은 임대인에게 귀속
   └─ 계약 완료, 모든 권리관계 종료

2-B. [디폴트 및 P2P 거래 경로] 유예기간 경과 시 처리
   ├─ [유예기간 경과] contractEndTime + 1 day < 현재시간
   │   └─ 이자 누적 시작 (RentalContract.debtInterestRate 사용, listDebtProperty 호출과 무관)
   ├─ [누구나] PropertyNFT.listDebtProperty(propertyId) 호출
   │   ├─ Property.status = DEFAULTED로 변경
   │   ├─ RentalContract.status = LISTED로 변경
   │   └─ 프론트엔드 P2P 마켓플레이스에서 거래 가능한 상태로 표시
   ├─ [프론트엔드] 디폴트 채권 정보 구성 및 표시
   │   ├─ Property/RentalContract/DepositInfo 구조체 데이터 조합
   │   ├─ 실시간 이자 계산 (유예기간 종료부터 누적)
   │   └─ DebtClaim 인터페이스로 채권 정보 구성
   ├─ [채권양수인] 프론트엔드를 통한 채권 구매
   │   ├─ PropertyNFT.transferDebtClaim(propertyId, newCreditor, purchasePrice) 호출
   │   ├─ RentalContract.currentCreditor가 채권양수인으로 변경
   │   └─ 임대인에 대한 원금 + 이자 수취권 획득
   ├─ [채권자] 이자 클레임 관리
   │   ├─ PropertyNFT.claimInterest(propertyId) 호출로 누적된 이자 클레임
   │   ├─ RentalContract.totalInterestClaimed에 클레임된 이자 누적 기록
   │   └─ 미클레임 이자는 계속 누적 (미상환 원금에 대해)
   └─ [임대인] 부분 또는 완전 상환
       ├─ PropertyNFT.repayDebt(propertyId, repayAmount) 호출
       ├─ 상환 금액을 현재 채권자에게 전송
       ├─ 상환 처리 로직:
       │   ├─ 이자 우선 상환: 미클레임 이자를 먼저 상환
       │   ├─ 원금 상환: 이자 상환 후 잔액으로 원금 상환
       │   ├─ RentalContract.totalRepaidAmount += 상환금액
       │   ├─ RentalContract.remainingPrincipal -= 원금상환분
       │   └─ RentalContract.lastRepaymentTime = 현재시간
       ├─ 부분 상환 시: remainingPrincipal > 0, 잔액에 대해 이자 계속 발생
       └─ 완전 상환 시: remainingPrincipal = 0, 모든 권리관계 종료
```

## 보안 및 권한 관리

### Role-Based Access Control (RBAC)

각 컨트랙트는 OpenZeppelin AccessControl을 사용한 역할 기반 접근 제어를 구현합니다:

#### PropertyNFT
- `PROPERTY_VERIFIER_ROLE`: 부동산 검증, 계약 승인
- `PAUSER_ROLE`: 긴급 일시 정지

#### DepositPool  
- `POOL_MANAGER_ROLE`: 보증금 관리, 정산 처리
- `YIELD_MANAGER_ROLE`: 수익률 설정
- `PAUSER_ROLE`: 긴급 일시 정지


### 보안 메커니즘

1. **ReentrancyGuard**: 모든 외부 호출에서 재진입 공격 방지
2. **Pausable**: 긴급 상황 시 계약 기능 일시 정지
3. **SafeERC20**: 안전한 토큰 전송을 위한 라이브러리 사용
4. **Input Validation**: 모든 함수에서 철저한 입력값 검증
5. **Access Control**: 세분화된 권한 관리 시스템


## 배포 및 초기화

### 배포 순서

1. KRWC 스테이블코인 (또는 기존 토큰 사용)
2. PropertyNFT 배포
3. DepositPool 배포 (PropertyNFT, KRWC 토큰 주소 필요)
4. 컨트랙트 간 참조 설정 및 권한 부여
5. 프론트엔드 P2P 채권 거래 시스템 구축

### Kaia 네트워크 설정

```toml
# foundry.toml
[profile.kaia]
src = "src"
out = "out"
libs = ["lib"]
remappings = [
    "@openzeppelin/=lib/openzeppelin-contracts/"
]

[rpc_endpoints]
kaia_mainnet = "https://klaytn-mainnet-rpc.allthatnode.com:8551"
kaia_testnet = "https://klaytn-baobab-rpc.allthatnode.com:8551"
```

## 모니터링 및 이벤트

### 주요 이벤트

#### PropertyNFT
- `PropertyProposed`: 임대인 매물 제안
- `PropertyApproved`: 매물 승인
- `PropertyRejected`: 매물 거부
- `PropertyStatusUpdated`: 상태 변경
- `RentalContractCreated`: 임차 계약 생성
- `DebtPropertyListed`: 디폴트 매물 P2P 거래 가능 상태로 리스팅
- `DebtClaimTransferred`: 채권 양도 완료 (채권양수인, 구매가격 포함)
- `InterestClaimed`: 이자 클레임 완료 (클레임 금액, 채권자 포함)
- `DebtRepaid`: 채무 상환 (상환금액, 이자분, 원금분, 잔여원금 포함)
- `DebtFullyRepaid`: 완전 상환 완료 (계약 종료)

#### DepositPool
- `DepositSubmitted`: 보증금 제출
- `DepositDistributed`: 보증금 분배
- `YieldCalculated`: 수익 계산
- `DepositRecovered`: 보증금 회수

#### 프론트엔드 P2P 시스템
- `DebtClaimIdentified`: 디폴트 채권 식별 (프론트엔드 이벤트)
- `DebtClaimListed`: 채권 리스팅 (프론트엔드 이벤트)
- `DebtClaimPurchased`: 채권 구매 완료 (프론트엔드 이벤트)
- `DebtRepaid`: 채무 상환 완료 (스마트 계약 + 프론트엔드)


## 테스팅 전략

### 단위 테스트

```solidity
contract PropertyNFTTest is Test {
    function testMintProperty() public {
        // 부동산 NFT 발행 테스트
    }
    
    function testCreateRentalContract() public {
        // 임차 계약 생성 테스트
    }
}
```

### 통합 테스트

```solidity
contract IntegrationTest is Test {
    function testFullRentalFlow() public {
        // 1. PropertyNFT 생성
        // 2. 계약 생성
        // 3. 보증금 제출
        // 4. 정상 정산 과정
        // 5. 디폴트 시나리오 (프론트엔드 시뮬레이션)
    }
}
```

### 퍼징 테스트

```solidity
function testFuzzDeposit(uint256 amount) public {
    vm.assume(amount > MIN_DEPOSIT_AMOUNT && amount <= MAX_DEPOSIT_AMOUNT);
    // 랜덤 값으로 테스트
}
```

## 규정 준수 및 KYC

### KYC 통합 구조

```solidity
contract KYCManager is AccessControl {
    enum KYCStatus { Pending, Approved, Rejected, Suspended }
    
    mapping(address => KYCInfo) public kycStatus;
    
    modifier onlyKYCApproved() {
        require(kycStatus[msg.sender].status == KYCStatus.Approved, "KYC required");
        _;
    }
}
```

## 업그레이드 패턴

### UUPS 프록시 패턴

```solidity
contract PropertyNFTUpgradeable is PropertyNFT, UUPSUpgradeable {
    function _authorizeUpgrade(address newImplementation) 
        internal 
        override 
        onlyRole(DEFAULT_ADMIN_ROLE) 
    {}
}
```

## 결론

Re-Lease 스마트 계약 시스템은 한국의 전세 제도를 블록체인 기술로 현대화한 혁신적인 솔루션입니다. ERC-4626 Vault를 통한 수익 생성, 프론트엔드 기반 P2P 채권 거래를 통한 리스크 관리, 그리고 간소화된 정산 시스템을 통해 전통적인 전세 계약의 문제점들을 해결합니다.

주요 이점:
- **투명성**: 모든 거래가 블록체인에 기록되며 프론트엔드에서 실시간 조회
- **간소화**: 핵심 스마트 계약만으로 구성된 효율적인 시스템 구조
- **수익 생성**: ERC-4626 Vault를 통한 보증금 수익 창출 (yKRW 시스템)
- **선택권 보장**: 임대인은 yKRW 보유 또는 KRWC 변환 선택 가능
- **유연한 반환**: 보증금 반환 시 KRWC 또는 yKRW 중 선택 가능
- **리스크 관리**: 프론트엔드 P2P 채권 거래를 통한 디폴트 리스크 분산
- **상환 추적**: 부분 상환 지원 및 실시간 잔액 추적으로 유연한 채무 관리
- **이자 관리**: 클레임 기반 이자 시스템으로 투명하고 효율적인 수익 분배
- **유연성**: 스마트 계약 데이터 기반 프론트엔드 로직으로 확장성 확보
- **효율성**: 중개 컨트랙트 없는 직접 거래로 가스비 절감

이 시스템은 Kaia 블록체인의 빠른 트랜잭션 처리와 낮은 수수료를 활용하며, 프론트엔드와 스마트 계약의 역할을 명확히 분리하여 유지보수와 확장이 용이한 실용적인 솔루션을 제공합니다.