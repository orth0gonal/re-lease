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
    PENDING,           // 등록 대기 중
    REGISTERED,        // 검증 완료, 임대 가능
    SUSPENDED          // 해당 매물 계약 등록 불가
}

struct Property {
    address landlord;                    // 임대인 이더리움 주소
    PropertyStatus status;               // 현재 상태 [PENDING, REGISTERED, SUSPENDED]
    address trustAuthority;            // 신탁사 이더리움 주소(없으면 zero address)
    bytes32 registrationAddress;         // 등기 도로명 주소(해시)
    uint256 ltv;                        // LTV 비율
}

enum RentalContractStatus {
    PENDING,     // 계약 대기 중
    ACTIVE,      // 계약 활성 상태
    COMPLETED,   // 계약 만료 or 채무 이행
    OUTSTANDING  // 채무 불이행 상태
}

struct RentalContract {
    uint256 nftId;                      // 연관된 부동산 NFT ID
    address tenantOrAssignee;           // 임차인 또는 채권양수인(자금 수령인)
    uint256 principal;                  // 계약 보증금 (KRWC) - 원금
    uint256 startDate;                  // 계약 시작 시간
    uint256 endDate;                    // 계약 만료 시간
    RentalContractStatus status;        // 계약 상태 [PENDING, ACTIVE, COMPLETED, OUTSTANDING]
    
    uint256 debtInterestRate;           // 미상환 시 연간 이자율 (basis points, 예: 500 = 5%)
    uint256 totalRepaidAmount;          // 총 상환 금액 (원금 + 이자 포함)
    uint256 lastRepaymentTime;          // 마지막 상환 시간 (이자 계산을 위해 필요)
}
```

### 핵심 함수

#### PropertyNFT.registerProperty()
```solidity
function registerProperty(
    address landlord,
    address trustAuthority,
    uint256 ltv,
    string calldata registrationAddress
) external returns (uint256 propertyId)
```

임대인이 매물을 제안합니다. Property.status가 PENDING 상태로 Property 구조체가 생성되며 14일의 검증 기간이 주어집니다.

#### PropertyNFT.approveProperty()
```solidity
function approveProperty(uint256 propertyId) external onlyRole(PROPERTY_VERIFIER_ROLE) returns (uint256 nftId)
```

검증자가 매물을 승인합니다. Property.status가 REGISTERED 상태로 변경되고 임대 가능한 상태가 됩니다.

#### PropertyNFT.rejectProperty()
```solidity
function rejectProperty(uint256 propertyId) external onlyRole(PROPERTY_VERIFIER_ROLE)
```

검증자가 매물을 거부합니다. nft가 생성되지 않습니다.

#### PropertyNFT.createRentalContract()
```solidity
function createRentalContract(
    uint256 nftId,
    address tenant,
    uint256 contractStartDate,
    uint256 contractEndDate,
    uint256 principal,
    uint256 debtInterestRate
) external
```

임대인이 특정 부동산에 대한 전세 계약을 생성합니다. 계약 생성 시:
- RentalContract.status가 PENDING 상태로 생성됩니다.

#### PropertyNFT.listDebtProperty()
```solidity
function listDebtProperty(uint256 nftId) external
```

계약 만료 후 1일 유예기간이 지난 매물에 대해 **누구나** 호출할 수 있는 함수입니다. 호출되면:
- Property.status가 SUSPENDED 변경
- RentalContract.status가 OUTSTANDING로 변경  
- 프론트엔드 P2P 마켓플레이스에서 거래 가능한 상태가 됨
- 이자는 이 함수 호출과 무관하게 유예기간 종료 시점부터 자동으로 누적
- 해당 함수는 nftId 관련 함수를 호출할 때 맨 앞에 호출되는 _update() 함수 내부에서 호출되므로, 따로 누군가 호출할 필요가 없습니다.

### 권한 관리

- `PROPERTY_VERIFIER_ROLE`: 부동산 검증 및 계약 승인
- `PAUSER_ROLE`: 긴급 일시 정지

## DepositPool Contract

### 기능 개요

DepositPool은 ERC-4626 Vault 표준을 구현하여 KRWC 보증금을 yKRWC로 변환하고 수익을 생성합니다.
asset 토큰은 KRWC 토큰이며, shares 토큰은 yKRWC 토큰입니다.

### 핵심 함수

#### DepositPool.submitPrincipal()
```solidity
function submitPrincipal(
    uint256 nftId,
    uint256 principal
) external nonReentrant whenNotPaused
```

전세 계약 실행 시 임차인이 검증된 임차 계약에 대한 보증금을 제출합니다. KRWC 형태로 제출되며, 이는 vault에 의해 yKRWC로 변환된 후 임대인에게 전송됩니다.
해당 nftId의 RentalContract.startDate가 현재 시간 전후 1일 이내에 있으면 호출 가능합니다.
호출되면 해당 nftId의 RentalContract.status가 ACTIVE 상태로 바뀝니다.

#### DepositPool.returnPrincipal()
```solidity
function returnPrincipal(
    uint256 nftId,
    bool isKRWC
) external nonReentrant
```

임대인이 보증금을 반환합니다. `isKRWC` 파라미터에 따라:
- **true**: 보증금만큼의 KRWC 토큰을 DepositPool에 전송
- **false**: 전세계약 당시 보증금의 가치에 해당하는 yKRWC 토큰을 DepositPool에 전송
수량이 부족할 시 revert가 발생합니다.
호출이 성공하면, 해당 nftId의 RentalContract.status가 COMPLETED 상태로 바뀝니다.
계약 만료 후 유예기간(1일) 이내에 해당 함수 호출이 성공하지 않으면, 해당 nftId의 RentalContract.status가 OUTSTANDING 상태로 바뀝니다.

#### DepositPool.recoverPrincipal()
```solidity
function recoverPrincipal(uint256 nftId) external nonReentrant
```

정산 완료 후 임차인이 원금 보증금을 회수합니다. 임대인의 DepositPool.returnPrincipal() 호출이 선행되어야 합니다.

#### DepositPool.purchaseDebt()
```solidity
function purchaseDebt(
    uint256 nftId,
    uint256 principal
) external nonReentrant
```

채권양수인이 디폴트된 채권을 구매합니다. nftId가 묶여있는 계약 만기일로부터 유예기간 1일이 지난 이후부터 호출할 수 있으며, 호출되면:
- RentalContract.tenantOrAssignee가 method caller의 주소로 변경
- 구매 비용(principal)이 기존 채권자(임차인)에게 즉시 전송

#### DepositPool.collectDebtRepayment()
```solidity
function collectDebtRepayment(uint256 nftId) external nonReentrant returns (uint256)
```

현재 채권자(임차인 또는 채권양수인)가 호출하며, 임대인(대출자)이 지금까지 상환한 원리금을 클레임합니다. 호출되면:
- 유예기간 종료 이후 최근 이자상환 시점부터 현재까지의 이자를 계산 후 채권자에게 전송
- 이자 계산은 RentalContract.principal, RentalContract.debtInterestRate를 고려하여 계산
- 지급된 이자는 RentalContract.totalRepaidAmount에 누적됨
- 이미 클레임된 이자를 제외한 신규 이자만 지급

#### DepositPool.repayDebt()
```solidity
function repayDebt(uint256 nftId, uint256 repayAmount) external nonReentrant
```

임대인이 채무를 상환합니다. 호출되면:
- collectDebtRepayment() 호출하여 이자 한번 업데이트
- RentalContract.lastRepaymentTime = 현재 시간으로 업데이트
- RentalContract.totalRepaidAmount += repayAmount (총 상환 금액 누적)
- 만일 RentalContract.totalRepaidAmount + repayAmount >= RentalContract.principal + 총 이자 금액이면, RentalContract.status가 COMPLETED 상태로 바뀌며 대출 계약이 종료됩니다.

## 전체 프로세스 플로우

### 1. 매물 등록 프로세스

```
1. [임대인] PropertyNFT.registerProperty(landlord, trustAuthority, ltv, registrationAddress)
   └─ 결과: Property 구조체 생성 (status = PENDING), 14일 검증 기간 시작

2. [검증자] PropertyNFT.approveProperty(propertyId) 또는 rejectProperty(propertyId, reason)
   ├─ 승인시: Property.status = PENDING → REGISTERED, NFT 토큰 발행
   └─ 거부시: Property.status = PENDING → SUSPENDED, NFT 토큰 발행되지 않음
```

### 2. 전세 계약 체결 프로세스

```
1. [임대인] PropertyNFT.createRentalContract(propertyId, tenant, principal, contractStartTime, contractEndTime, debtInterestRate)
   └─ 결과: RentalContract 생성, 계약 조건 확정

2. [임차인] DepositPool.submitPrincipal(propertyTokenId, krwcAmount)
   └─ 보증금을 KRWC로 전송하여 yKRWC Vault에 예치
   ├─ KRWC → yKRWC 변환 후 임대인에게 전세금에 상응하는 yKRWC 전송
   └─ 결과: RentalContract.status = PENDING → ACTIVE
```

### 3. 계약 만료 및 정산 프로세스

```
1. [계약 만료] 전세 계약 기간 종료
   └─ 결과: RentalContract.status = PENDING → COMPLETED
   └─ 임차인-임대인 관계가 채권자-채무자 관계로 전환
   └─ 1일 유예 기간 시작
   └─ 유예기간 종료 시 자동으로 PropertyNFT.listDebtProperty(propertyId) 호출되어 디폴트 채권 매물 리스팅됨

2-A. [정상 정산 경로] 유예기간 내 보증금 반환
   ├─ [임대인] DepositPool.returnPrincipal(propertyId, isKRWC) 호출
   │   ├─ isKRWC = true: 보증금만큼의 KRWC 토큰을 DepositPool에 전송
   │   └─ isKRWC = false: 전세계약 당시 보증금의 가치에 해당하는 yKRWC 토큰을 DepositPool에 전송
   ├─ 계약 당시에 해당하는 가치의 yKRWC만큼이 DepositPool에게 돌아가고, 이는 임차인이 클레임할 수 있는 권한을 가짐. 수익 증가분은 임대인에게 귀속
   └─ 결과: RentalContract.status = COMPLETED, 모든 권리관계 종료
   ├─ [임대인] DepositPool.recoverPrincipal(propertyId) 호출
   │   └─ 결과: 임차인이 보증금을 KRWC로 회수
   └─ 결과: 임차인이 보증금을 회수할 수 있음

2-B. [디폴트 및 P2P 거래 경로] 유예기간 경과 시 처리
   ├─ [유예기간 경과] contractEndTime + 1 day < 현재시간
   │   └─ 이자 누적 시작 (RentalContract.debtInterestRate 사용, listDebtProperty 호출과 무관)
   ├─ [누구나] PropertyNFT.listDebtProperty(propertyId) 호출
   │   ├─ Property.status = REGISTERED → SUSPENDED
   │   ├─ RentalContract.status = ACTIVE → OUTSTANDING
   │   ├─ 전세계약이 채권-채무 관계를 가진 대출계약으로 전환됨
   │   └─ 프론트엔드 P2P 마켓플레이스에서 거래 가능한 상태로 표시
   ├─ [채권양수인] 프론트엔드를 통한 채권 구매
   │   ├─ DepositPool.purchaseDebt(propertyId, principal) 호출
   │   ├─ RentalContract.tenantOrAssignee가 채권양수인으로 변경
   │   └─ 임대인에 대한 원금 + 이자 수취권 획득
   ├─ [채권자] 이자 클레임 관리
   │   ├─ DepositPool.collectDebtRepayment(propertyId) 호출로 채무자(임대인)이 부분 혹은 완전히 입금한 미수취금 클레임
   │   ├─ RentalContract.totalRepaidAmount에 클레임된 원리금 누적 기록
   │   └─ 미상환 원리금에 대한 이자는 계속 누적
   └─ [임대인] 부분 또는 완전 상환
       ├─ DepositPool.repayDebt(propertyId, repayAmount) 호출
       ├─ 상환 금액을 DepositPool에 전송
       ├─ 상환 처리 로직:
       │   ├─ RentalContract.totalRepaidAmount += 상환금액
       │   └─ RentalContract.lastRepaymentTime = 현재시간
       ├─ 부분 상환 시: RentalContract.totalRepaidAmount < RentalContract.principal + 총 이자 금액, 잔액에 대해 이자 계속 발생
       └─ 완전 상환 시: RentalContract.totalRepaidAmount >= RentalContract.principal + 총 이자 금액, 모든 권리관계 종료
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