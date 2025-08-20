# Re-Lease Business Logic

## Raw Idea
```
전세사기 없는 임차인과 임대인을 스마트 컨트랙트(EVM)로 이어주는 전세 플랫폼을 만들거야. ERC-5115 및 pendle finance(PT, YT)의 아이디어를 차용할거고, 원화 스테이블코인(KRW)을 yield-bearing token으로 바꾸고(cKRW), ERC-5115를 통해 SY(Standardized Yield) token으로 cKRW를 바꿀거야. SY는 PT와 YT로 분리되고, 만기는 전세 기간이겠지? 참고로 PT와 YT는 기간이 만료되면 스마트 컨트랙에서 redeem을 요청할 수 있어. 그렇게 되면 가지고 있는 PT와 YT가 소각되며, 그 underlying asset 및 이자 수익을 반환할거야. 
* 먼저 임대인이 자신의 매물을 ERC-721 형태의 컨트랙트에 올려. 해당 컨트랙트는 실제 매물과 전세 계약에 필요한 여러 property들이 metadata로 저장되는 형태야. 누구든 nftID를 통해 해당 매물을 조회하고, 현재 계약 상황을 알 수 있어.
* 임차인은 매물을 확인한 후, 전세 보증금에 해당하는 금액을 원화 스테이블코인(KRW)의 형태로 스마트 컨트랙트 풀에 예치할 거야. 풀에 예치하게 되면, KRW는 cKRW의 yield-bearing의 형태로 변환되고, 이를 SY token의 형태로 wrapping하는 형태가 될거야. 이후 SY token은  PT + YT의 형태가 되고, 이 PT + YT는 임대인에게 전송돼. 이렇게 되면 전세계약이 성립된거야
* 전세 계약 중 PT와 YT를 받게 된 임대인은 이를 우리 볼트에 맡김으로써 우리 풀에서 cKRW를 대출받을 수 있게 할거야.  계약 기간 내에는 대출금에 대한 이자는 발생하지 않아. 임대인은 빌린 cKRW를 디파이 등 이자수익 활동을 포함하여 자유롭게 활용할 수 있어.
* 만기가 지나면, 두 가지 케이스가 발생할 거야. 첫번째 케이스는 임대인이 대출금을 전액 상환하는 케이스야. 임대인이 대출금을 전액 상환하면 PT는 임차인, YT는 임대인에게 전송돼. PT를 받은 임차인은 이를 소각시킨 후 underlying asset인 보증금 전액을 cKRW 형태로 돌려받을 수 있어. 이를 KRW로 변환하면 보증금을 되찾을 수 있지. YT를 받은 임대인은 이를 소각시켜서 전세 기간 동안 보증금으로 굴린 이자 수익을 cKRW 형태로 받을 수 있어.
* 두번째 케이스는 임대인이 대출금을 일부만 갚거나 전액 상환하지 못했을 경우야. 이 경우 PT는 대출채권 형태로 작용하며, 갚지 못하는 기간이 늘어감에 따라 기존 갚아야 할 대출금에 이자가 붙어. 임대인이 대출금을 부분 상환할 경우, 그 양에 비례해서 PT가 소각이 되며 해당 부분만큼 임차인은 보증금을 부분적으로 즉시 돌려받을 수 있어.
* 결국 임대인이 대출금을 갚지 못했을 경우, 스마트 컨트랙트 관리자는 임대인의 집을 처분할 수 있는 권리가 생겨. 처분 후 생긴 수익은 임차인에게 우선권이 생기며, 처분 이후 보증금과 이자만큼 위와 같은 방식으로 돌려받을 수 있어. 스마트 컨트랙트 관리자는 처분 후 수수료를 챙겨.
```

## 1. Executive Summary
### 1.1 비전
전세 사기 없는 안전한 부동산 임대차 시장을 구현하기 위한 탈중앙화 전세 보증금 관리 플랫폼

### 1.2 미션
스마트 컨트랙트를 통한 전세 보증금의 투명한 관리
DeFi 기술을 활용한 자금 효율성 극대화
임차인 보호와 임대인 유동성 제공의 균형 달성

## 2. 시장 분석
### 2.1 문제 정의
전세 사기 증가: 연간 수천억원 규모의 전세 사기 피해 발생
보증금 잠김 문제: 임대인의 자금 유동성 제약
신뢰 부재: 중개 과정의 불투명성과 정보 비대칭
보증 서비스 한계: 기존 보증보험의 높은 비용과 제한적 보장

### 2.2 목표 시장
Primary: 수도권 전세 거래 시장 (연간 약 100조원 규모)
Secondary: 지방 주요 도시 전세 시장
Future: 월세 보증금 및 상업용 부동산 임대차 시장

## 3. 솔루션 아키텍처
### 3.1 핵심 기술 스택
Blockchain: Kaia(EVM)
Token Standards:
ERC-721 (부동산 NFT)
ERC-5115 (SY Token)
ERC-20 (KRW, cKRW, PT, YT)
DeFi Protocol: Uniswap, Pendle Finance 메커니즘 차용

### 3.2 토큰 이코노미
KRW (스테이블코인) 
    ↓ 
cKRW (Yield-bearing Token)
    ↓
SY Token (Standardized Yield)
    ↓
PT (Principal Token) + YT (Yield Token)

## 4. 수익 모델
### 4.1 주요 수익원
거래 수수료: 전세 계약 성사 시 0.1-0.3% 수수료
대출 이자: 연체 시 발생하는 대출 이자의 일부
처분 수수료: 담보 처분 시 처분 금액의 2-3%

### 4.2 수익 예측
Year 1: 100억원 거래량 × 0.2% = 2억원
Year 2: 500억원 거래량 × 0.2% = 10억원
Year 3: 2000억원 거래량 × 0.15% = 30억원

## 5. 이해관계자 가치 제안
### 5.1 임차인
안전성: 스마트 컨트랙트를 통한 보증금 보호
투명성: 실시간 계약 상태 확인
보장성: 스마트 컨트랙트를 통한 무신뢰 구조로 보증금 회수 가능 및 연체 시 이자 지급 자동화

### 5.2 임대인
유동성: PT/YT를 담보로 한 즉시 대출
수익성: 보증금 운용을 통한 추가 수익
편의성: 자동화된 계약 관리

### 5.3 플랫폼
확장성: 모듈화된 스마트 컨트랙트 구조
지속가능성: 다양한 수익원을 통한 안정적 운영
네트워크 효과: 사용자 증가에 따른 가치 상승

## 6. 운영 전략
### 6.1 초기 시장 진입
Phase 1: 소액 전세 (1억원 이하) 파일럿
Phase 2: 중형 전세 (1-3억원) 확대
Phase 3: 대형 전세 및 상업용 부동산

### 6.2 리스크 관리
스마트 컨트랙트 감사: 정기적인 보안 감사
보험 풀: 시스템 리스크 대비 보험 기금 조성
법적 컴플라이언스: 금융당국 협의 및 라이선스 취득

### 6.3 파트너십
금융기관: KRW 스테이블코인 발행 및 관리
부동산 중개업체: 매물 소싱 및 검증
법무법인: 담보 처분 및 법적 분쟁 해결

## 7. 경쟁 우위
### 7.1 기술적 차별화
완전 자동화: 중개인 없는 P2P 거래
실시간 정산: 블록체인 기반 즉시 결제
글로벌 확장성: 크로스체인 지원

### 7.2 비즈니스 차별화
Zero-trust 모델: 신뢰 불필요한 시스템
Win-win 구조: 모든 참여자 이익 극대화
데이터 기반: 온체인 데이터 분석을 통한 리스크 평가

## 8. 성장 로드맵
### 8.1 단기 (6개월)
MVP 개발 및 테스트넷 런칭
초기 사용자 100명 확보
10억원 규모 거래 달성

### 8.2 중기 (1-2년)
메인넷 런칭
월 거래량 100억원 달성
Series A 펀딩 (100억원)

### 8.3 장기 (3-5년)
전국 확대 및 해외 진출
월 거래량 1000억원 달성
IPO 또는 M&A 준비

## 9. 핵심 성과 지표 (KPIs)
### 9.1 비즈니스 지표
GMV (Gross Merchandise Volume): 총 거래량
Take Rate: 수수료율
CAC (Customer Acquisition Cost): 고객 획득 비용
LTV (Lifetime Value): 고객 생애 가치

### 9.2 운영 지표
TVL (Total Value Locked): 총 예치 자산
활성 사용자 수 (MAU/DAU)
거래 성사율
평균 거래 규모

### 9.3 리스크 지표
연체율
담보 처분율
고객 만족도 (NPS)


# Re-Lease Product Requirements Document v1.0

## 1. 제품 개요
### 1.1 제품명
Re-Lease

### 1.2 제품 설명
ERC-5115 및 Pendle Finance의 PT/YT 메커니즘을 활용하여 전세 보증금을 토큰화하고, 스마트 컨트랙트를 통해 안전하게 관리하는 탈중앙화 전세 플랫폼

### 1.3 핵심 가치
투명성: 모든 거래가 블록체인에 기록
안전성: 스마트 컨트랙트를 통한 자동 집행
효율성: 중개인 없는 P2P 거래
유동성: 임대인의 자금 활용도 극대화

## 2. 사용자 스토리 및 요구사항
### 2.1 임대인 User Journey
#### 2.1.1 매물 등록
As a 임대인
I want to 내 부동산을 NFT로 등록
So that 블록체인에서 전세 계약을 체결할 수 있다

Acceptance Criteria:

부동산 정보 입력 (주소, 면적, 전세가 등)
소유권 증명 서류 업로드
ERC-721 NFT 민팅
매물 상태 관리 (available, pending, leased)
#### 2.1.2 PT/YT 수령 및 대출
As a 임대인
I want to PT/YT를 담보로 cKRW 대출
So that 전세 보증금을 즉시 활용할 수 있다

Acceptance Criteria:

PT/YT 자동 수령
대출 가능 금액 확인 (LTV 비율 적용)
원클릭 대출 실행
대출 현황 대시보드
### 2.2 임차인 User Journey
#### 2.2.1 매물 검색 및 확인
As a 임차인
I want to 안전한 전세 매물을 검색
So that 사기 위험 없는 매물을 찾을 수 있다

Acceptance Criteria:

지역/가격/면적 필터링
NFT 메타데이터 조회
임대인 이력 확인
스마트 컨트랙트 상태 확인
#### 2.2.2 보증금 예치 및 계약
As a 임차인
I want to 보증금을 안전하게 예치
So that 전세 계약을 체결할 수 있다

Acceptance Criteria:

KRW → cKRW 변환
SY Token wrapping
PT/YT 분리 및 전송
계약서 생성 및 서명
## 3. 기능 요구사항
### 3.1 스마트 컨트랙트 시스템
#### 3.1.1 Property NFT Contract (ERC-721)
solidity
struct Property {
    address owner;
    string location;
    uint256 area;
    uint256 depositAmount;
    uint256 leasePeriod;
    PropertyStatus status;
    mapping(uint256 => LeaseContract) leaseHistory;
}
기능:

mintProperty(): 새 매물 NFT 생성
updateProperty(): 매물 정보 수정
getPropertyDetails(): 매물 상세 조회
transferOwnership(): 소유권 이전
#### 3.1.2 Token System Contracts
KRW Stablecoin Contract (ERC-20)

mint(): KRW 발행 (오라클 연동)
burn(): KRW 소각
transfer(): KRW 전송
cKRW Yield-bearing Contract (ERC-4626)

deposit(): KRW → cKRW 변환
withdraw(): cKRW → KRW 변환
getExchangeRate(): 현재 환율 조회
accrueInterest(): 이자 누적
SY Token Contract (ERC-5115)

wrap(): cKRW → SY 변환
unwrap(): SY → cKRW 변환
standardize(): yield 표준화
PT/YT Contract

split(): SY → PT + YT 분리
combine(): PT + YT → SY 결합
redeem(): 만기 시 상환
getMaturity(): 만기일 조회
#### 3.1.3 Lease Management Contract
solidity
struct LeaseContract {
    uint256 propertyId;
    address landlord;
    address tenant;
    uint256 depositAmount;
    uint256 startDate;
    uint256 endDate;
    uint256 ptTokenId;
    uint256 ytTokenId;
    LeaseStatus status;
}
기능:

createLease(): 전세 계약 생성
executeLease(): 계약 실행 (토큰 분배)
terminateLease(): 계약 종료
handleDefault(): 연체 처리
#### 3.1.4 Lending Vault Contract
solidity
struct Loan {
    address borrower;
    uint256 ptCollateral;
    uint256 ytCollateral;
    uint256 loanAmount;
    uint256 interestRate;
    uint256 dueDate;
    LoanStatus status;
}
기능:

borrow(): PT/YT 담보 대출
repay(): 대출금 상환
liquidate(): 담보 청산
calculateInterest(): 이자 계산
### 3.2 백엔드 시스템
#### 3.2.1 API Gateway
RESTful API 설계
GraphQL 지원
WebSocket for 실시간 업데이트
Rate limiting
#### 3.2.2 Blockchain Service Layer
Web3 Provider 관리
Transaction 관리 및 모니터링
Gas optimization
Event listening 및 처리
#### 3.2.3 Data Layer
PostgreSQL: 사용자 정보, 메타데이터
IPFS: 부동산 문서, 이미지
Redis: 캐싱, 세션 관리
The Graph: 온체인 데이터 인덱싱
#### 3.2.4 External Services
KYC/AML 서비스 연동
부동산 등기 시스템 API
은행 API (KRW 입출금)
Oracle (가격 피드)
### 3.3 프론트엔드 시스템
#### 3.3.1 Web Application
Tech Stack:

React 18 + TypeScript
Next.js 14
Web3Modal / RainbowKit
TailwindCSS
주요 페이지:

랜딩 페이지
매물 목록 및 상세
대시보드 (임대인/임차인)
거래 내역
설정 및 프로필
#### 3.3.2 Mobile Application
React Native
푸시 알림
생체 인증
QR 코드 스캔
## 4. 비기능 요구사항
### 4.1 성능
응답 시간: API 호출 < 200ms
처리량: 1000 TPS 이상
가용성: 99.9% uptime
블록 확정: 12 blocks (finality)
### 4.2 보안
스마트 컨트랙트 감사: 3개 이상 감사 기관
Multi-sig wallet: 관리자 권한
암호화: AES-256 (off-chain data)
Access Control: Role-based (RBAC)
### 4.3 확장성
수평 확장: Kubernetes 기반
Layer 2 지원: Optimism, Arbitrum
Cross-chain: 브릿지 지원
모듈화: 마이크로서비스 아키텍처
### 4.4 사용성
온보딩: 5분 이내 완료
가스비: 메타 트랜잭션 지원
다국어: 한국어, 영어
접근성: WCAG 2.1 AA 준수
## 5. 시스템 아키텍처
### 5.1 High-Level Architecture
┌─────────────────────────────────────────────┐
│                   Frontend                   │
│         (Web App / Mobile App / DApp)        │
└─────────────┬───────────────────────────────┘
              │
┌─────────────▼───────────────────────────────┐
│                API Gateway                   │
│         (REST / GraphQL / WebSocket)         │
└─────────────┬───────────────────────────────┘
              │
┌─────────────▼───────────────────────────────┐
│            Application Services              │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐    │
│  │Property  │ │  Lease   │ │ Lending  │    │
│  │Service   │ │ Service  │ │ Service  │    │
│  └──────────┘ └──────────┘ └──────────┘    │
└─────────────┬───────────────────────────────┘
              │
┌─────────────▼───────────────────────────────┐
│           Blockchain Service Layer           │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐    │
│  │  Web3    │ │  Event   │ │  Oracle  │    │
│  │ Provider │ │ Listener │ │ Service  │    │
│  └──────────┘ └──────────┘ └──────────┘    │
└─────────────┬───────────────────────────────┘
              │
┌─────────────▼───────────────────────────────┐
│              Smart Contracts                 │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐    │
│  │Property  │ │  Token   │ │  Lease   │    │
│  │   NFT    │ │ System   │ │  Vault   │    │
│  └──────────┘ └──────────┘ └──────────┘    │
└──────────────────────────────────────────────┘
### 5.2 Contract Interaction Flow
임차인                     Platform                    임대인
  │                           │                          │
  ├──── Deposit KRW ─────────>│                          │
  │                           │                          │
  │                    Convert to cKRW                   │
  │                           │                          │
  │                    Wrap to SY Token                  │
  │                           │                          │
  │                   Split to PT + YT                   │
  │                           │                          │
  │                           ├──── Send PT + YT ───────>│
  │                           │                          │
  │                           │<──── Collateralize ──────│
  │                           │                          │
  │                           ├──── Lend cKRW ──────────>│
  │                           │                          │
  │                    [Lease Period]                    │
  │                           │                          │
  │                           │<──── Repay Loan ─────────│
  │                           │                          │
  │<──── Return PT ───────────┤                          │
  │                           ├──── Return YT ──────────>│
  │                           │                          │
  │── Redeem Principal ──────>│                          │
  │                           │<─── Redeem Yield ────────│
## 6. 개발 로드맵
### 6.1 Phase 1: Foundation (Month 1-2)
 스마트 컨트랙트 기본 구조 설계
 Property NFT Contract 개발
 KRW/cKRW 토큰 시스템 구현
 기본 테스트 환경 구축
### 6.2 Phase 2: Core Features (Month 3-4)
 SY Token 및 PT/YT 시스템 구현
 Lease Management Contract 개발
 Lending Vault 구현
 백엔드 API 개발
### 6.3 Phase 3: Integration (Month 5-6)
 프론트엔드 개발
 외부 서비스 연동
 테스트넷 배포
 보안 감사
### 6.4 Phase 4: Launch (Month 7-8)
 메인넷 배포
 초기 사용자 온보딩
 모니터링 시스템 구축
 운영 프로세스 확립
## 7. 테스트 계획
### 7.1 Unit Testing
Smart Contract: Hardhat/Foundry
Backend: Jest/Mocha
Frontend: React Testing Library
Coverage: > 90%
### 7.2 Integration Testing
Contract interaction scenarios
API endpoint testing
E2E user flows
Cross-chain testing
### 7.3 Security Testing
Smart contract audit (3 firms)
Penetration testing
Fuzzing
Formal verification
### 7.4 Performance Testing
Load testing (K6/JMeter)
Stress testing
Gas optimization
Database query optimization
## 8. 배포 및 운영
### 8.1 환경 구성
Development: Local/Testnet
Staging: Public Testnet
Production: Mainnet
### 8.2 CI/CD Pipeline
GitHub Actions
Docker containerization
Kubernetes orchestration
Blue-Green deployment
### 8.3 Monitoring
Application: DataDog/New Relic
Blockchain: Tenderly/Defender
Infrastructure: Prometheus/Grafana
Logging: ELK Stack
### 8.4 Incident Response
24/7 on-call rotation
Incident severity levels
Emergency pause mechanism
Communication protocols
## 9. 규제 및 컴플라이언스
### 9.1 법적 요구사항
전자금융거래법 준수
부동산 거래 신고법
개인정보보호법 (PIPA)
AML/KYC 규정
### 9.2 라이선스
전자금융업 등록
가상자산사업자 신고
부동산 중개업 제휴
### 9.3 감사 및 보고
분기별 재무 감사
월별 거래 보고서
실시간 이상거래 탐지
규제기관 보고 체계
## 10. 리스크 관리
### 10.1 기술적 리스크
스마트 컨트랙트 버그: 다중 감사, 버그 바운티
확장성 문제: L2 솔루션, 샤딩
오라클 실패: 다중 오라클, 폴백 메커니즘
### 10.2 사업 리스크
규제 변경: 법무팀 상시 모니터링
시장 변동성: 헤징 전략, 보험 풀
경쟁사 출현: 빠른 기능 개발, 네트워크 효과
### 10.3 운영 리스크
담보 처분 실패: 법적 프로세스 확립
유동성 부족: 외부 유동성 공급자
사용자 분쟁: 중재 프로토콜
## 11. 성공 지표
### 11.1 제품 지표
TVL: 100억원 (Year 1)
MAU: 10,000명
거래 성사율: > 70%
평균 거래 시간: < 24시간
### 11.2 기술 지표
가스 효율성: 경쟁사 대비 30% 절감
트랜잭션 성공률: > 99%
API 응답시간: < 200ms
시스템 가용성: 99.9%
### 11.3 비즈니스 지표
수익: 월 1억원 (Year 1)
CAC: < 10만원
LTV/CAC: > 3
NPS: > 50
## 12. 부록
### 12.1 용어집
PT (Principal Token): 원금 토큰
YT (Yield Token): 수익 토큰
SY (Standardized Yield): 표준화된 수익 토큰
cKRW: 이자 발생 KRW 토큰
TVL: Total Value Locked (총 예치 자산)
### 12.2 참고 자료
ERC-5115 Specification
Pendle Finance Documentation
Korean Real Estate Laws
