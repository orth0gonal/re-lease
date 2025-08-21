# Re-Lease 스마트 컨트랙트 프로세스 플로우

## 개요

Re-Lease 시스템의 주요 프로세스별 컨트랙트 메소드 호출 순서를 정리합니다.

---

## 1. 매물 등록 프로세스

### 참여자
- **임대인 (Landlord)**: 매물 소유자
- **검증자 (Verifier)**: PROPERTY_VERIFIER_ROLE을 가진 주체 (플랫폼 관리자)

### 호출 순서

```
1. [검증자] PropertyNFT.mintProperty()
   ├─ 매개변수: landlord, distributionChoice, depositAmount, monthlyRent, 
   │           landOwnershipAuthority, landTrustAuthority, ltv, registrationAddress
   ├─ 권한: PROPERTY_VERIFIER_ROLE
   ├─ 새로운 필드:
   │   ├─ landOwnershipAuthority: 땅의 소유권한 (true/false)
   │   ├─ landTrustAuthority: 땅의 신탁권한 (true/false)  
   │   ├─ ltv: LTV 비율 (기본 단위, 10000 = 100%)
   │   └─ registrationAddress: 등기 주소
   └─ 결과: PropertyNFT 발행, 상태 = PENDING

2. [검증자] PropertyNFT.verifyProperty()
   ├─ 매개변수: tokenId
   ├─ 권한: PROPERTY_VERIFIER_ROLE
   └─ 결과: 매물 검증 완료, 상태 = ACTIVE
```

### 결과 상태
- PropertyNFT: `ACTIVE` 상태로 임차인 모집 가능
- 임대인 distribution choice (DIRECT/POOL) 설정 완료

---

## 2. 전세 계약 체결 프로세스

### 참여자
- **임차인 (Tenant)**: 전세 계약자
- **임대인 (Landlord)**: 매물 소유자  
- **관리자 (Manager)**: PROPERTY_VERIFIER_ROLE, POOL_MANAGER_ROLE, SETTLEMENT_MANAGER_ROLE을 가진 주체 (플랫폼 관리자)

### 호출 순서

```
1. [임대인] PropertyNFT.createRentalContract()
   ├─ 매개변수: tokenId, tenant, contractStartTime, contractEndTime, depositAmount
   ├─ 조건: 매물 상태 = ACTIVE, 매물 소유자만 호출 가능
   └─ 결과: 전세 계약 생성, 매물 상태 = CONTRACT_PENDING

2. [관리자] PropertyNFT.verifyRentalContract()
   ├─ 매개변수: tokenId
   ├─ 권한: PROPERTY_VERIFIER_ROLE
   ├─ 조건: 매물 상태 = CONTRACT_PENDING
   └─ 결과: 계약 검증 완료, 매물 상태 = CONTRACT_VERIFIED

3. [임차인] DepositPool.submitDeposit()
   ├─ 매개변수: propertyTokenId, krwAmount
   ├─ 조건: 매물 상태 = CONTRACT_VERIFIED, 정확한 보증금 액수
   └─ 결과: 
       ├─ DIRECT choice: 임대인에게 KRW 즉시 전송
       └─ POOL choice: KRW → ERC-4626 Vault 예치하여 cKRW 발행 + 수익 창출

4. [관리자] SettlementManager.activateRentalContract()
   ├─ 매개변수: propertyTokenId, tenant, contractEndTime, autoProcessing
   ├─ 권한: SETTLEMENT_MANAGER_ROLE
   └─ 결과: 계약 모니터링 시작, 상태 = ACTIVE
```

### 결과 상태
- PropertyNFT: `RENTED` 상태
- DepositPool: 보증금 `ACTIVE` 상태
- SettlementManager: 계약 `ACTIVE` 모니터링 중

---

## 3-1. 계약 정상 종료 프로세스

### 참여자
- **임차인/임대인**: 정산 개시자
- **관리자 (Manager)**: SETTLEMENT_MANAGER_ROLE, POOL_MANAGER_ROLE, PROPERTY_VERIFIER_ROLE을 가진 주체 (플랫폼 관리자)

### 호출 순서

```
1. [임차인 또는 임대인] PropertyNFT.initiateSettlement()
   ├─ 매개변수: tokenId
   ├─ 조건: 계약 종료 시점 도달
   └─ 결과: 매물 상태 = SETTLEMENT, 30일 grace period 시작

2. [시스템/관리자] SettlementManager.checkSettlementStatus()
   ├─ 매개변수: propertyTokenId
   └─ 결과: 정산 상태 자동 업데이트, 경고 발송

3. [관리자] SettlementManager.completeSettlement()
   ├─ 매개변수: propertyTokenId
   ├─ 권한: SETTLEMENT_MANAGER_ROLE
   └─ 결과: 
       ├─ SettlementManager 상태 = SETTLED
       └─ DepositPool.processSettlement() 자동 호출

4. [임차인] DepositPool.recoverDeposit()
   ├─ 매개변수: propertyTokenId
   ├─ 조건: 정산 완료 상태
   └─ 결과:
       ├─ 원금 + 수익 (POOL choice인 경우) 반환
       └─ 보증금 상태 = RECOVERED
```

### 결과 상태
- PropertyNFT: `COMPLETED` 상태
- DepositPool: `RECOVERED` 상태
- SettlementManager: `SETTLED` 상태

---

## 3-2. 임대인 보증금 미반환 프로세스 (P2P 거래)

### 참여자
- **시스템**: 자동 처리
- **관리자 (Manager)**: SETTLEMENT_MANAGER_ROLE, MARKETPLACE_ADMIN_ROLE, PROPERTY_VERIFIER_ROLE을 가진 주체 (플랫폼 관리자)
- **투자자 (Investor)**: 채권 구매자

### 호출 순서

#### A. 연체 처리 및 P2P 시장 등록

```
1. [시스템] SettlementManager.checkSettlementOverdue()
   ├─ 매개변수: propertyTokenId
   ├─ 조건: grace period (30일) 초과
   └─ 결과: 자동 연체 처리

2. [시스템] SettlementManager._escalateToMarketplace()
   ├─ 내부 함수 자동 호출
   └─ 결과:
       ├─ DepositPool.handleDefault() 호출
       ├─ PropertyNFT 상태 = OVERDUE
       └─ SettlementManager 상태 = DEFAULTED

3. [관리자] P2PDebtMarketplace.listDebtClaim()
   ├─ 매개변수: propertyTokenId, debtor, principalAmount, listingPrice, interestRate
   ├─ 권한: MARKETPLACE_ADMIN_ROLE
   └─ 결과: 채권 P2P 시장에 상장, 상태 = LISTED
```

#### B. 투자자 채권 구매

```
4. [투자자] KRWToken.approve()
   ├─ 매개변수: P2PDebtMarketplace address, purchasePrice
   └─ 결과: 마켓플레이스가 KRW 토큰 사용 승인

5. [투자자] P2PDebtMarketplace.purchaseDebtClaim()
   ├─ 매개변수: claimId
   └─ 결과:
       ├─ 투자자 → 임대인: KRW 지급 (수수료 제외)
       ├─ 플랫폼 수수료 징수
       └─ 채권 소유권 이전, 상태 = SOLD
```

#### C. 채권 정산 (정상 회수 시)

```
6-A. [임차인] P2PDebtMarketplace.repayDebt()
     ├─ 매개변수: claimId
     ├─ 조건: 상환 기한 내
     └─ 결과:
         ├─ 임차인 → 투자자: 원금 + 이자 지급
         └─ 채권 상태 = REPAID

6-B. [투자자 또는 시스템] P2PDebtMarketplace.liquidateDebtClaim()
     ├─ 매개변수: claimId
     ├─ 조건: 상환 기한 초과
     └─ 결과: 채권 상태 = LIQUIDATED
```

#### D. 2차 시장 거래 (선택사항)

```
7. [채권 소유자] P2PDebtMarketplace.listForSecondaryTrading()
   ├─ 매개변수: claimId, newListingPrice
   └─ 결과: 2차 시장 재상장, isSecondaryMarket = true

8. [새 투자자] P2PDebtMarketplace.purchaseDebtClaim()
   ├─ 매개변수: claimId
   └─ 결과: 채권 소유권 재이전
```

### 결과 상태
- PropertyNFT: `OVERDUE` 상태
- DepositPool: `DEFAULTED` 상태  
- SettlementManager: `DEFAULTED` 상태
- P2PDebtMarketplace: 채권 `SOLD/REPAID/LIQUIDATED` 상태

---

## 주요 권한 매트릭스

| 역할 | 컨트랙트 | 권한 |
|------|----------|------|
| 관리자 (플랫폼) | PropertyNFT | PROPERTY_VERIFIER_ROLE |
| 관리자 (플랫폼) | DepositPool | POOL_MANAGER_ROLE |
| 관리자 (플랫폼) | P2PDebtMarketplace | MARKETPLACE_ADMIN_ROLE |
| 관리자 (플랫폼) | SettlementManager | SETTLEMENT_MANAGER_ROLE |
| 관리자 (플랫폼) | KRWToken | MINTER_ROLE |

**참고**: 모든 역할은 동일한 플랫폼 관리자가 수행하여 운영 효율성을 높입니다.

### ERC-4626 Vault 통합
- **DepositPool**: ERC-4626 표준을 준수하는 KRW Vault
- **cKRW 토큰**: Vault shares 역할, KRW에 대한 청구권 표현
- **수익 생성**: Vault 운용 수익 + 추가 연 수익률
- **표준 호환**: 모든 ERC-4626 지원 서비스와 호환

## 자동화 프로세스

### SettlementManager 배치 처리
```
[시스템] SettlementManager.batchProcessSettlements()
├─ 매개변수: maxContracts
├─ 권한: MONITOR_ROLE
└─ 결과: 다수 계약 상태 일괄 업데이트
```

### 수익 계산 (POOL 방식 - ERC-4626 Vault)
```
[시스템/사용자] DepositPool.calculateYield()
├─ 매개변수: propertyTokenId
└─ 결과: 
    ├─ Vault 가치 상승 (cKRW 주가 상승)
    ├─ 추가 연 수익률 적용
    └─ 시간 비례 수익 자동 계산

[임차인] DepositPool.recoverDeposit()
├─ 매개변수: propertyTokenId
├─ 조건: 정산 완료 상태
└─ 결과:
    ├─ cKRW shares → KRW 환전 (ERC-4626 redeem)
    ├─ 원금 + Vault 수익 + 추가 수익 반환
    └─ 보증금 상태 = RECOVERED
```

### 이자 누적 (P2P 채권)
```
[시스템/사용자] P2PDebtMarketplace.updateInterest()
├─ 매개변수: claimId
└─ 결과: 시간 경과에 따른 이자 자동 계산
```

---

## 매물 정보 업데이트 프로세스

### 매물 기본 정보 업데이트

```
1. [검증자] PropertyNFT.updateLTV()
   ├─ 매개변수: tokenId, newLtv
   ├─ 권한: PROPERTY_VERIFIER_ROLE
   ├─ 조건: newLtv <= 10000 (100%)
   └─ 결과: LTV 비율 업데이트

2. [검증자] PropertyNFT.updateLandOwnershipAuthority()
   ├─ 매개변수: tokenId, hasAuthority
   ├─ 권한: PROPERTY_VERIFIER_ROLE
   └─ 결과: 땅의 소유권한 상태 업데이트

3. [검증자] PropertyNFT.updateLandTrustAuthority()
   ├─ 매개변수: tokenId, hasAuthority
   ├─ 권한: PROPERTY_VERIFIER_ROLE
   └─ 결과: 땅의 신탁권한 상태 업데이트

4. [검증자] PropertyNFT.updateRegistrationAddress()
   ├─ 매개변수: tokenId, newAddress
   ├─ 권한: PROPERTY_VERIFIER_ROLE
   └─ 결과: 등기 주소 업데이트

5. [임대인] PropertyNFT.updateDistributionChoice()
   ├─ 매개변수: tokenId, newChoice
   ├─ 조건: 매물 상태 != RENTED
   └─ 결과: 임대인 분배 방식 변경 (DIRECT ↔ POOL)
```

### 업데이트 제한사항
- **LTV 업데이트**: 검증자만 가능, 100% 초과 불가
- **권한 상태 업데이트**: 검증자만 가능 (소유권한, 신탁권한)
- **등기 주소 업데이트**: 검증자만 가능, 빈 문자열 불가
- **분배 방식 변경**: 임대인만 가능, 임대 중 변경 불가