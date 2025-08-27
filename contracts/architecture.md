# Re-Lease Smart Contract Architecture

## System Overview

**Re-Lease**는 한국의 전세 계약을 위한 Kaia 블록체인 기반 스마트 계약 플랫폼입니다. KRWC 스테이블코인을 활용하여 전세 보증금을 관리하고, ERC-4626 Vault를 통한 수익 생성, 프론트엔드 기반 P2P 채권 거래를 통한 디폴트 처리를 제공합니다.

### 핵심 특징

- **KRWC 스테이블코인 통합**: 변동성 위험을 제거한 KRWC 스테이블코인 사용
- **토큰화 구조**: KRWC를 수익 창출 가능한 yKRW로 변환하는 ERC-4626 Vault
- **프론트엔드 기반 P2P 거래**: 스마트 계약 데이터를 활용한 프론트엔드 채권 거래 시스템

## Core Contracts Architecture

### PropertyNFT Contract (ERC-721)
부동산 NFT 및 전세 계약 관리의 핵심 컨트랙트

#### 주요 상태 구조

```solidity
enum PropertyStatus {
    PENDING,           // 등록 대기 중
    REGISTERED,        // 검증 완료, 임대 가능
    SUSPENDED          // 해당 매물 계약 등록 불가
}

struct Property {
    address landlord;                    // 임대인 이더리움 주소
    PropertyStatus status;               // 현재 상태
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
    RentalContractStatus status;        // 계약 상태
    
    uint256 debtInterestRate;           // 미상환 시 연간 이자율 (basis points)
    uint256 totalRepaidAmount;          // 총 상환 금액 (원금 + 이자 포함)
    uint256 lastRepaymentTime;          // 마지막 상환 시간 (이자 계산을 위해 필요)
}
```

#### 핵심 함수

**Property Management Functions**

- `registerProperty(landlord, trustAuthority, ltv, registrationAddress)` - 매물 등록 (PENDING 상태)
- `approveProperty(propertyId)` - 검증자가 매물 승인 (REGISTERED 상태로 변경)
- `rejectProperty(propertyId)` - 검증자가 매물 거부

**Rental Contract Functions**

- `createRentalContract(nftId, tenant, contractStartDate, contractEndDate, principal, debtInterestRate)` - 전세 계약 생성
- `listDebtProperty(nftId)` - 유예기간 경과 후 P2P 거래 활성화 (누구나 호출 가능)

### DepositPool Contract (ERC-4626)
KRWC 보증금을 yKRWC로 변환하고 수익을 생성하는 Vault 컨트랙트

#### 핵심 기능
- **Asset Token**: KRWC (Korean Won Coin)
- **Shares Token**: yKRWC (yield-bearing KRWC)
- **자동 수익 생성**: ERC-4626 Vault 표준을 통한 수익률 제공
- **보증금 관리**: 전세 계약의 보증금 예치 및 반환 처리

#### 주요 함수

**Deposit Management Functions**

- `submitPrincipal(nftId, principal)` - 임차인이 보증금 제출, yKRWC로 변환 후 임대인에게 전송
- `returnPrincipal(nftId, isKRWC)` - 임대인이 보증금 반환 (KRWC 또는 yKRWC 선택)
- `recoverPrincipal(nftId)` - 정산 완료 후 임차인이 원금 회수

**Debt Management Functions**

- `purchaseDebt(nftId, principal)` - 채권양수인이 디폴트된 채권 구매
- `collectDebtRepayment(nftId)` - 현재 채권자가 누적된 이자 클레임
- `repayDebt(nftId, repayAmount)` - 임대인이 채무 상환 (부분/완전)

## Key Participants

### 주요 참여자

- **임차인 (Tenant)**: 전세 계약자, KRWC 보증금 예치
- **임대인 (Landlord)**: 부동산 소유자, yKRW 토큰 수령 (KRWC로 변환 선택 가능)
- **채권양수인 (Assignee)**: 디폴트 채권 구매자, 프론트엔드를 통한 P2P 거래
- **검증자 (Verifier)**: 부동산 검증 및 계약 승인 권한

## Process Flow Architecture

### 1. Property Registration Flow

```
1. [임대인] PropertyNFT.registerProperty(landlord, trustAuthority, ltv, registrationAddress)
   └─ 결과: Property 구조체 생성 (status = PENDING), 14일 검증 기간 시작

2. [검증자] PropertyNFT.approveProperty(propertyId) 또는 rejectProperty(propertyId)
   ├─ 승인시: Property.status = PENDING → REGISTERED, NFT 토큰 발행
   └─ 거부시: Property 삭제, NFT 토큰 발행되지 않음
```

### 2. Rental Contract Creation & Activation

```
1. [임대인] PropertyNFT.createRentalContract(nftId, tenant, principal, contractStartTime, contractEndTime, debtInterestRate)
   └─ 결과: RentalContract 생성 (status = PENDING)

2. [임차인] DepositPool.submitPrincipal(nftId, krwcAmount)
   ├─ KRWC → yKRWC 변환 후 임대인에게 전송
   └─ 결과: RentalContract.status = PENDING → ACTIVE
```

### 3. Contract Settlement Process

#### 3-A. Normal Settlement Path

```
1. [임대인] DepositPool.returnPrincipal(nftId, isKRWC)
   ├─ isKRWC = true: 보증금만큼의 KRWC 토큰을 DepositPool에 전송
   ├─ isKRWC = false: 전세계약 당시 보증금의 가치에 해당하는 yKRWC 토큰 전송
   └─ 결과: RentalContract.status = ACTIVE → COMPLETED

2. [임차인] DepositPool.recoverPrincipal(nftId)
   └─ 결과: 임차인이 보증금을 KRWC로 회수
```

#### 3-B. Default & P2P Trading Path

```
1. [유예기간 경과] contractEndTime + 1 day < 현재시간
   └─ 이자 누적 시작 (RentalContract.debtInterestRate 사용)

2. [누구나] PropertyNFT.listDebtProperty(nftId) 호출
   ├─ Property.status = REGISTERED → SUSPENDED
   ├─ RentalContract.status = ACTIVE → OUTSTANDING
   └─ 프론트엔드 P2P 마켓플레이스에서 거래 가능한 상태

3. [채권양수인] DepositPool.purchaseDebt(nftId, principal) 호출
   ├─ RentalContract.tenantOrAssignee가 채권양수인으로 변경
   └─ 구매 비용이 기존 채권자(임차인)에게 즉시 전송

4. [채권자] DepositPool.collectDebtRepayment(nftId) 호출
   └─ 유예기간 종료 이후 누적된 이자 클레임

5. [임대인] DepositPool.repayDebt(nftId, repayAmount) 호출
   ├─ 상환 처리: 이자 우선, 남은 금액으로 원금 상환
   └─ 완전 상환 시: RentalContract.status = OUTSTANDING → COMPLETED
```

## Interest Calculation System

### Interest Accrual Logic
- **시작점**: 유예기간 종료 시점 (contractEndTime + 1 day)
- **이자율**: RentalContract.debtInterestRate (basis points, 예: 500 = 5%)
- **계산 대상**: RentalContract.principal (미상환 원금)
- **클레임**: collectDebtRepayment() 호출 시 누적된 이자 지급

### Repayment Logic
1. **이자 우선**: 미클레임 이자를 먼저 상환
2. **원금 상환**: 이자 상환 후 남은 금액으로 원금 상환
3. **잔액 추적**: totalRepaidAmount 실시간 업데이트
4. **완전 상환**: totalRepaidAmount >= principal + 총 이자 → 계약 완료

## Security & Access Control

### Role-Based Access Control (RBAC)

**PropertyNFT Roles:**
- `PROPERTY_VERIFIER_ROLE`: 부동산 검증 및 계약 승인
- `PAUSER_ROLE`: 긴급 일시 정지

**DepositPool Roles:**
- `POOL_MANAGER_ROLE`: 보증금 관리, 정산 처리
- `YIELD_MANAGER_ROLE`: 수익률 설정
- `PAUSER_ROLE`: 긴급 일시 정지

### Security Mechanisms
1. **ReentrancyGuard**: 모든 외부 호출에서 재진입 공격 방지
2. **Pausable**: 긴급 상황 시 계약 기능 일시 정지
3. **SafeERC20**: 안전한 토큰 전송을 위한 라이브러리 사용
4. **Input Validation**: 모든 함수에서 철저한 입력값 검증
5. **Access Control**: 세분화된 권한 관리 시스템

## Token Economics

### KRWC Stablecoin
- **역할**: 기본 결제 수단 및 보증금
- **특징**: KRW 페깅된 스테이블코인

### yKRWC Token (ERC-4626)
- **역할**: 수익 창출 가능한 보증금 토큰
- **특징**:
  - KRWC의 Vault 표현
  - 자동 수익 생성
  - KRWC로 언제든 변환 가능
  - 임대인에게 수익 귀속

## Deployment Architecture

### Contract Dependencies
1. **KRWC Stablecoin** (기존 토큰 또는 새로 배포)
2. **PropertyNFT** 배포
3. **DepositPool** 배포 (PropertyNFT, KRWC 토큰 주소 필요)
4. **컨트랙트 간 참조 설정** 및 권한 부여
5. **프론트엔드 P2P 시스템** 구축

### Kaia Network Configuration
- **Mainnet**: `https://klaytn-mainnet-rpc.allthatnode.com:8551`
- **Testnet**: `https://klaytn-baobab-rpc.allthatnode.com:8551`
- **Framework**: Foundry 기반 개발 환경
- **Standards**: ERC-721, ERC-4626, OpenZeppelin AccessControl

## Key Events

### PropertyNFT Events
- `PropertyProposed`: 임대인 매물 제안
- `PropertyApproved`: 매물 승인
- `PropertyRejected`: 매물 거부
- `PropertyStatusUpdated`: 상태 변경
- `RentalContractCreated`: 임차 계약 생성
- `DebtPropertyListed`: 디폴트 매물 P2P 거래 가능 상태로 리스팅
- `DebtClaimTransferred`: 채권 양도 완료
- `InterestClaimed`: 이자 클레임 완료
- `DebtRepaid`: 채무 상환
- `DebtFullyRepaid`: 완전 상환 완료

### DepositPool Events
- `DepositSubmitted`: 보증금 제출
- `DepositDistributed`: 보증금 분배
- `YieldCalculated`: 수익 계산
- `DepositRecovered`: 보증금 회수

### Frontend P2P System
- `DebtClaimIdentified`: 디폴트 채권 식별 (프론트엔드 이벤트)
- `DebtClaimListed`: 채권 리스팅 (프론트엔드 이벤트)
- `DebtClaimPurchased`: 채권 구매 완료 (프론트엔드 이벤트)

## System Benefits

### 주요 이점
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

이 아키텍처는 Kaia 블록체인의 빠른 트랜잭션 처리와 낮은 수수료를 활용하며, 프론트엔드와 스마트 계약의 역할을 명확히 분리하여 유지보수와 확장이 용이한 실용적인 솔루션을 제공합니다.