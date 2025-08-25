# Re-Lease Smart Contract 시스템 문서

## 개요

**Re-Lease**는 한국의 전세 계약을 위한 Kaia 블록체인 기반 스마트 계약 플랫폼입니다. KRW 스테이블코인을 활용하여 전세 보증금을 관리하고, ERC-4626 Vault를 통한 수익 생성, P2P 채권 거래 시장을 통한 디폴트 처리를 제공합니다.

### 핵심 특징

- **KRW 스테이블코인 통합**: 변동성 위험을 제거한 KRW-C 스테이블코인 사용
- **토큰화 구조**: KRW-C를 수익 창출 가능한 cKRW로 변환하는 ERC-4626 Vault
- **자동화된 채권 회수**: 임대인 미반환 시 P2P 채권 시장을 통한 자동 처리

## 시스템 아키텍처

### 핵심 컨트랙트

1. **PropertyNFT**: ERC-721 기반 부동산 NFT 및 상태 관리
2. **DepositPool**: ERC-4626 Vault 기반 보증금 풀 및 수익 관리
3. **P2PDebtMarketplace**: 채권 거래 마켓플레이스
4. **SettlementManager**: 계약 정산 및 모니터링 관리

### 주요 참여자

- **임차인 (Tenant)**: 전세 계약자, KRW-C 보증금 예치
- **임대인 (Landlord)**: 부동산 소유자, cKRW 토큰 수령
- **채권양수인 (Assignee)**: 디폴트 채권 구매자, 이자 수익 창출
- **검증자 (Verifier)**: 부동산 검증 및 계약 승인 권한

## PropertyNFT Contract

### 기능 개요

PropertyNFT는 Re-Lease 플랫폼의 핵심 컨트랙트로, 부동산을 ERC-721 NFT로 토큰화하고 전세 계약의 전체 생명주기를 관리합니다.

### 주요 상태

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

enum DistributionChoice {
    DIRECT,    // 임대인에게 직접 전송
    POOL       // cKRW 풀에서 수익 생성
}
```

### PropertyProposal 구조체

```solidity
struct PropertyProposal {
    address landlord;                    // 임대인 주소
    DistributionChoice distributionChoice; // 분배 방식 선택
    uint256 depositAmount;              // 보증금 금액 (KRW)
    bool landOwnershipAuthority;        // 땅의 소유권한
    bool landTrustAuthority;            // 땅의 신탁권한
    uint256 ltv;                        // LTV 비율
    string registrationAddress;         // 등기 주소
    string propertyDescription;         // 매물 설명
    uint256 proposalTime;               // 제안 시간
    uint256 verificationDeadline;       // 검증 마감일 (14일)
    bool isProcessed;                   // 처리 상태
}
```

### Property 구조체

```solidity
struct Property {
    address landlord;                    // 임대인 주소
    PropertyStatus status;               // 현재 상태
    DistributionChoice distributionChoice; // 분배 방식 선택
    uint256 depositAmount;              // 보증금 금액 (KRW)
    uint256 contractStartTime;          // 계약 시작 시간
    uint256 contractEndTime;            // 계약 종료 시간
    uint256 settlementDeadline;         // 정산 마감일
    address currentTenant;              // 현재 임차인
    address proposedTenant;             // 제안된 임차인
    uint256 proposedDepositAmount;      // 제안된 보증금
    bool isVerified;                    // 검증 상태
    uint256 createdAt;                  // 생성 시간
    uint256 proposalId;                 // 원본 제안 ID (직접 발행시 0)
    bool landOwnershipAuthority;        // 땅의 소유권한
    bool landTrustAuthority;            // 땅의 신탁권한
    uint256 ltv;                        // LTV 비율
    string registrationAddress;         // 등기 주소
}
```

### 핵심 함수

#### proposeProperty()
```solidity
function proposeProperty(
    DistributionChoice distributionChoice,
    uint256 depositAmount,
    bool landOwnershipAuthority,
    bool landTrustAuthority,
    uint256 ltv,
    string calldata registrationAddress,
    string calldata propertyDescription
) external returns (uint256)
```

임대인이 매물을 제안합니다. 14일의 검증 기간이 주어집니다.

#### approvePropertyProposal()
```solidity
function approvePropertyProposal(uint256 proposalId) external onlyRole(PROPERTY_VERIFIER_ROLE) returns (uint256)
```

검증자가 매물 제안을 승인하고 NFT를 발행합니다.

#### rejectPropertyProposal()
```solidity
function rejectPropertyProposal(uint256 proposalId, string calldata reason) external onlyRole(PROPERTY_VERIFIER_ROLE)
```

검증자가 매물 제안을 거부합니다.

#### _mintProperty()
```solidity
function _mintProperty(
    address landlord,
    DistributionChoice distributionChoice,
    uint256 depositAmount,
    bool landOwnershipAuthority,
    bool landTrustAuthority,
    uint256 ltv,
    string calldata registrationAddress
) internal returns (uint256)
```

내부적으로 사용되는 NFT 발행 함수입니다. `approvePropertyProposal()` 승인 시 자동 호출됩니다.

#### createRentalContract()
```solidity
function createRentalContract(
    uint256 tokenId,
    address tenant,
    uint256 contractStartTime,
    uint256 contractEndTime,
    uint256 proposedDepositAmount
) external
```

임대인이 임차 계약 제안을 생성합니다.

#### verifyRentalContract()
```solidity
function verifyRentalContract(uint256 tokenId) external onlyRole(PROPERTY_VERIFIER_ROLE)
```

검증자가 임차 계약을 승인합니다.

### 권한 관리

- `PROPERTY_VERIFIER_ROLE`: 부동산 검증 및 계약 승인
- `PAUSER_ROLE`: 긴급 일시 정지

## DepositPool Contract

### 기능 개요

DepositPool은 ERC-4626 Vault 표준을 구현하여 KRW 보증금을 cKRW로 변환하고 수익을 생성합니다.

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
    address landlord;                // 임대인 주소
    uint256 krwAmount;              // 원래 KRW 보증금 금액
    uint256 cKRWShares;             // cKRW 볼트 지분
    uint256 yieldEarned;            // 추가 수익
    DepositStatus status;           // 현재 상태
    DistributionChoice distributionChoice; // 분배 방식
    uint256 submissionTime;         // 제출 시간
    uint256 expectedReturnTime;     // 예상 반환 시간
    bool isInPool;                  // 풀에서 수익 생성 여부
    uint256 lastYieldCalculation;   // 마지막 수익 계산 시간
}
```

### 핵심 함수

#### submitDeposit()
```solidity
function submitDeposit(
    uint256 propertyTokenId,
    uint256 krwAmount
) external nonReentrant whenNotPaused
```

검증된 임차 계약에 대한 보증금을 제출합니다. 임대인의 분배 방식 선택에 따라:
- **DIRECT**: KRW를 임대인에게 직접 전송
- **POOL**: KRW를 cKRW Vault에 예치하여 수익 생성

#### calculateYield()
```solidity
function calculateYield(uint256 propertyTokenId) public returns (uint256 yieldAmount)
```

풀 보증금에 대한 수익을 계산하고 업데이트합니다.

#### recoverDeposit()
```solidity
function recoverDeposit(uint256 propertyTokenId) external nonReentrant
```

정산 완료 후 임차인이 원금 보증금을 회수합니다. cKRW 수익은 임대인에게 귀속됩니다.

#### withdrawYield()
```solidity
function withdrawYield(uint256 propertyTokenId) external nonReentrant returns (uint256)
```

임대인이 활성 상태인 풀 보증금에서 발생한 수익을 인출합니다.

### 수익 생성 메커니즘

1. **Vault 감가상승**: ERC-4626 Vault를 통한 기본 수익 (임대인 귀속)
2. **추가 연수익률**: 설정된 연간 수익률 적용 (임대인 귀속)
3. **복합 이자**: 시간 경과에 따른 자동 복리 계산 (임대인 귀속)

모든 cKRW 수익은 임대인에게 귀속되며, 임차인은 원금만 회수합니다.

## P2PDebtMarketplace Contract

### 기능 개요

임대인이 보증금 반환에 실패할 경우, 채권을 P2P 시장에서 거래할 수 있게 하는 마켓플레이스입니다.

### 주요 상태

```solidity
enum ClaimStatus {
    LISTED,       // 판매 중
    SOLD,         // 판매 완료
    REPAID,       // 상환 완료
    LIQUIDATED,   // 청산 완료
    CANCELLED     // 취소됨
}
```

### DebtClaim 구조체

```solidity
struct DebtClaim {
    uint256 claimId;                // 고유 채권 ID
    uint256 propertyTokenId;        // 연관된 부동산 NFT ID
    address originalCreditor;       // 원래 채권자 (임대인)
    address currentOwner;           // 현재 채권 소유자
    address debtor;                 // 채무자 (임대인 - 보증금 반납 실패)
    uint256 principalAmount;        // 원금
    uint256 currentAmount;          // 현재 금액 (원금 + 이자)
    uint256 creationTime;           // 생성 시간
    uint256 repaymentDeadline;      // 상환 마감일
    ClaimStatus status;             // 현재 상태
}
```

### 핵심 함수

#### listDebtClaim()
```solidity
function listDebtClaim(
    uint256 propertyTokenId,
    address debtor,
    uint256 principalAmount,
    uint256 listingPrice,
    uint256 interestRate
) external onlyRole(MARKETPLACE_ADMIN_ROLE) returns (uint256)
```

보증금 디폴트 시 채권을 마켓플레이스에 등록합니다.

#### purchaseDebtClaim()
```solidity
function purchaseDebtClaim(uint256 claimId) external nonReentrant whenNotPaused
```

채권양수인이 채권을 구매합니다. 플랫폼 수수료가 차감됩니다.

#### repayDebt()
```solidity
function repayDebt(uint256 claimId) external nonReentrant whenNotPaused
```

임대인(채무자)이 채권을 상환합니다. 보증금을 반납하지 못한 임대인이 채권양수인에게 원금 + 이자를 지불합니다.

### 이자 계산

이자는 다음 공식으로 계산됩니다:
```solidity
uint256 annualInterest = (currentAmount * interestRate) / INTEREST_RATE_PRECISION;
uint256 interestAccrued = (annualInterest * timeElapsed) / SECONDS_PER_YEAR;
```

## SettlementManager Contract

### 기능 개요

임차 계약의 정산 과정을 모니터링하고 자동화하는 컨트랙트입니다.

### 주요 상태

```solidity
enum SettlementStatus {
    ACTIVE,           // 계약 활성 상태
    PENDING,          // 정산 대기 중
    GRACE_PERIOD,     // 유예 기간 중
    OVERDUE,          // 기한 초과
    SETTLED,          // 정산 완료
    DEFAULTED         // 디폴트로 마켓플레이스 이관
}
```

### ContractStatus 구조체

```solidity
struct ContractStatus {
    uint256 propertyTokenId;        // 연관된 부동산 NFT ID
    address tenant;                 // 임차인 주소
    address landlord;               // 임대인 주소
    uint256 contractEndTime;        // 원래 계약 종료 시간
    uint256 settlementDeadline;     // 정산 마감일
    uint256 gracePeriodStart;       // 유예 기간 시작
    uint256 warningsSent;           // 발송된 경고 수
    uint256 lastStatusUpdate;       // 마지막 상태 업데이트
    SettlementStatus status;        // 현재 정산 상태
    bool autoProcessingEnabled;     // 자동 처리 활성화 여부
    string notes;                   // 추가 메모
}
```

### 핵심 함수

#### registerContract()
```solidity
function registerContract(
    uint256 propertyTokenId,
    address tenant,
    uint256 contractEndTime,
    bool autoProcessing
) external onlyRole(SETTLEMENT_MANAGER_ROLE)
```

임차 계약을 모니터링에 등록합니다.

#### batchProcessSettlements()
```solidity
function batchProcessSettlements(uint256 maxContracts) 
    external onlyRole(MONITOR_ROLE) 
    returns (uint256 processed, uint256 warnings, uint256 escalations)
```

다수의 계약 상태를 일괄 처리합니다.

#### completeSettlement()
```solidity
function completeSettlement(uint256 propertyTokenId) external onlyRole(SETTLEMENT_MANAGER_ROLE)
```

계약 정산을 완료합니다.

### 경고 시스템

경고는 3단계로 발송됩니다:
1. **첫 번째 경고**: 마감일 14일 전
2. **두 번째 경고**: 마감일 7일 전  
3. **최종 경고**: 마감일 1일 전

## 전체 프로세스 플로우

### 1. 매물 등록 프로세스

```
1. [임대인] PropertyNFT.proposeProperty()
   ├─ 매개변수: 분배방식, 보증금, 소유권한, 신탁권한, LTV, 등기주소, 매물설명
   └─ 결과: PropertyProposal 생성, 14일 검증 기간 시작

2. [검증자] PropertyNFT.approvePropertyProposal() 또는 rejectPropertyProposal()
   ├─ 승인시: PropertyNFT 발행, 상태 = PENDING
   └─ 거부시: 제안 거부, 거부 사유 기록

3. [검증자] PropertyNFT.verifyProperty() (승인된 경우)
   └─ 매물 검증 완료, 상태 = ACTIVE
```

### 2. 전세 계약 체결 프로세스

```
1. [임대인] PropertyNFT.createRentalContract()
   └─ 계약 제안 생성, 상태 = CONTRACT_PENDING

2. [검증자] PropertyNFT.verifyRentalContract()
   └─ 계약 검증, 상태 = CONTRACT_VERIFIED

3. [임차인] DepositPool.submitDeposit()
   └─ 보증금 제출, 분배 방식에 따라 처리
   ├─ DIRECT: 임대인에게 직접 전송
   └─ POOL: cKRW Vault에 예치

4. [관리자] SettlementManager.registerContract()
   └─ 계약 모니터링 시작
```

### 3-1. 정상 정산 프로세스

```
1. [임차인/임대인] PropertyNFT.initiateSettlement()
   └─ 정산 개시, 30일 유예 기간 시작

2. [시스템] SettlementManager.checkSettlementStatus()
   └─ 자동 상태 업데이트 및 경고 발송

3. [관리자] SettlementManager.completeSettlement()
   └─ 정산 완료 처리

4. [임차인] DepositPool.recoverDeposit()
   └─ 원금 회수 (POOL 방식 수익은 임대인 귀속)
```

### 3-2. 디폴트 및 P2P 거래 프로세스

```
1. [시스템] SettlementManager.checkSettlementOverdue()
   └─ 유예 기간 초과 시 자동 연체 처리

2. [시스템] SettlementManager._escalateToMarketplace()
   └─ P2P 마켓플레이스로 에스컬레이션

3. [관리자] P2PDebtMarketplace.listDebtClaim()
   └─ 채권 시장 등록

4. [채권양수인] P2PDebtMarketplace.purchaseDebtClaim()
   └─ 채권 구매, 임차인에게 즉시 보증금 지급

5. [임대인] P2PDebtMarketplace.repayDebt() (선택사항)
   └─ 임대인이 채권양수인에게 원금 + 이자 상환, 또는 청산 절차 진행
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

#### P2PDebtMarketplace
- `MARKETPLACE_ADMIN_ROLE`: 채권 등록 관리
- `FEE_MANAGER_ROLE`: 수수료 설정
- `PAUSER_ROLE`: 긴급 일시 정지

#### SettlementManager
- `SETTLEMENT_MANAGER_ROLE`: 정산 관리
- `MONITOR_ROLE`: 계약 모니터링
- `PAUSER_ROLE`: 긴급 일시 정지

### 보안 메커니즘

1. **ReentrancyGuard**: 모든 외부 호출에서 재진입 공격 방지
2. **Pausable**: 긴급 상황 시 계약 기능 일시 정지
3. **SafeERC20**: 안전한 토큰 전송을 위한 라이브러리 사용
4. **Input Validation**: 모든 함수에서 철저한 입력값 검증
5. **Access Control**: 세분화된 권한 관리 시스템

## 가스 최적화

### 목표 가스 사용량

- **Property NFT 발행**: <150,000 gas
- **보증금 제출**: <200,000 gas  
- **채권 구매**: <180,000 gas
- **정산 처리**: <120,000 gas

### 최적화 전략

1. **구조체 패킹**: 스토리지 슬롯 최적화
2. **배치 처리**: 다중 계약 상태 일괄 업데이트
3. **이벤트 기반 로깅**: 스토리지 비용 절감
4. **View 함수 최적화**: 오프체인 쿼리 성능 향상

## 배포 및 초기화

### 배포 순서

1. KRW 스테이블코인 (또는 기존 토큰 사용)
2. PropertyNFT 배포
3. DepositPool 배포 (PropertyNFT, KRW 토큰 주소 필요)
4. P2PDebtMarketplace 배포 (PropertyNFT, DepositPool 주소 필요)
5. SettlementManager 배포 (모든 컨트랙트 주소 필요)
6. 컨트랙트 간 참조 설정 및 권한 부여

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
- `PropertyProposalApproved`: 매물 제안 승인
- `PropertyProposalRejected`: 매물 제안 거부
- `PropertyMinted`: 부동산 NFT 발행
- `PropertyStatusUpdated`: 상태 변경
- `RentalContractCreated`: 임차 계약 생성
- `SettlementInitiated`: 정산 시작

#### DepositPool
- `DepositSubmitted`: 보증금 제출
- `DepositDistributed`: 보증금 분배
- `YieldCalculated`: 수익 계산
- `DepositRecovered`: 보증금 회수

#### P2PDebtMarketplace
- `DebtClaimListed`: 채권 등록
- `DebtClaimPurchased`: 채권 구매
- `DebtRepaid`: 채무 상환
- `InterestAccrued`: 이자 발생

#### SettlementManager
- `ContractRegistered`: 계약 등록
- `WarningIssued`: 경고 발송
- `SettlementCompleted`: 정산 완료
- `ContractDefaulted`: 계약 디폴트

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
        // 2. 계약 생성 및 검증
        // 3. 보증금 제출
        // 4. 정산 과정
        // 5. P2P 거래 (디폴트 시나리오)
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

Re-Lease 스마트 계약 시스템은 한국의 전세 제도를 블록체인 기술로 현대화한 혁신적인 솔루션입니다. ERC-4626 Vault를 통한 수익 생성, P2P 채권 거래를 통한 리스크 관리, 그리고 자동화된 정산 시스템을 통해 전통적인 전세 계약의 문제점들을 해결합니다.

주요 이점:
- **투명성**: 모든 거래가 블록체인에 기록
- **자동화**: 스마트 계약을 통한 프로세스 자동화
- **수익 생성**: ERC-4626 Vault를 통한 보증금 수익 창출
- **리스크 관리**: P2P 채권 거래를 통한 디폴트 리스크 분산
- **효율성**: 중개자 없는 직접 거래로 비용 절감

이 시스템은 Kaia 블록체인의 빠른 트랜잭션 처리와 낮은 수수료를 활용하여 실제 부동산 시장에서 사용 가능한 실용적인 솔루션을 제공합니다.