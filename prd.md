# Re-Lease PoC Product Requirements Document v2.0

## Executive Summary

Re-Lease is a decentralized rental deposit management platform that eliminates fraud in Korean rental markets through smart contracts and a simplified P2P debt marketplace. This Proof of Concept (PoC) aims to validate the core token economics and workflow using yield-bearing tokens (cKRW) with flexible landlord distribution options.

### Project Scope
- **Frontend**: React web application (`app/`)
- **Smart Contracts**: Foundry-based Solidity contracts (`contracts/`)
- **Target Network**: Kaia (formerly Klaytn) for cost-effective transactions
- **Timeline**: 8-week development cycle for MVP validation

## 1. Product Vision & Objectives

### 1.1 Vision Statement
Create a trustless, transparent, and efficient rental deposit management system that protects tenants from fraud while providing landlords with immediate liquidity access through innovative tokenization.

### 1.2 Core Value Propositions

**For Tenants:**
- **Security**: Smart contract-guaranteed deposit recovery
- **Transparency**: Real-time contract status and fund tracking
- **Fraud Protection**: Elimination of traditional rental scams

**For Landlords:**
- **Flexible Access**: Choice between direct transfer or pool retention of cKRW tokens
- **Yield Generation**: Earn interest through platform optimization or independent DeFi strategies
- **Automated Management**: Smart contract-based lease administration

**For the Platform:**
- **Scalable Revenue**: Fee-based income from transactions and yield
- **Network Effects**: Growing value with increased user adoption
- **Innovation Leadership**: First-mover advantage in tokenized real estate

### 1.3 Success Metrics (PoC)
- **Technical Validation**: Complete simplified token flow (KRW → cKRW → Landlord Choice)
- **User Experience**: End-to-end property listing and rental process including P2P marketplace
- **Smart Contract Security**: Comprehensive testing and basic audit
- **Performance**: Sub-3-second transaction confirmations on Kaia

## 2. Technical Architecture Overview

### 2.1 System Components

```
┌─────────────────────────────────────────────┐
│             Frontend (React App)            │
│         Property Listing & Management       │
│         Wallet Integration & Web3 UI        │
└─────────────┬───────────────────────────────┘
              │ Web3 Provider (ethers.js)
┌─────────────▼───────────────────────────────┐
│              Kaia Network                   │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐   │
│  │Property  │ │  Token   │ │ Lending  │   │
│  │   NFT    │ │ System   │ │  Vault   │   │
│  │(ERC-721) │ │(ERC-5115)│ │(Custom)  │   │
│  └──────────┘ └──────────┘ └──────────┘   │
└─────────────────────────────────────────────┘
```

### 2.2 Token Flow Architecture

```
Tenant Deposit Flow:
KRW Stablecoin → cKRW (Yield-bearing) → Landlord Choice:
                                             │
                                    ┌────────┼────────┐
                                    │                 │
                              Direct Transfer    Pool Retention

Default Handling Flow:
Unsettled Contract → P2P Marketplace Listing → Investor Purchase → Tenant Recovery
                                                          │
                                                   Landlord Debt
```

### 2.3 Core Smart Contracts

1. **PropertyNFT Contract (ERC-721)**
   - Property registration and metadata management
   - Ownership verification and transfer
   - Lease status tracking (Available, Occupied, Settled, Unsettled)

2. **Deposit Pool Contract**
   - KRW to cKRW conversion and management
   - Landlord fund distribution choices (Direct Transfer vs Pool Retention)
   - Tenant deposit recovery process
   - Yield optimization for pool-retained funds

3. **P2P Debt Marketplace Contract**
   - Unsettled rental agreement listings as tradeable debt
   - Debt claim purchase and transfer mechanisms
   - Interest rate calculation and payment processing
   - Secondary market trading support

4. **Settlement Manager Contract**
   - Rental agreement maturity and settlement tracking
   - Automatic marketplace listing for unsettled contracts
   - Grace period management and status updates
   - Partial and full repayment handling

## 3. Functional Requirements

### 3.1 Property Management System

#### 3.1.1 Property Registration
**User Story**: As a landlord, I want to register my property as an NFT so that it can be used for secure rental contracts.

**Acceptance Criteria:**
- Input property details (address, area, deposit amount, lease period)
- Upload ownership documentation
- Create ERC-721 NFT with embedded metadata
- Set initial property status (Available, Pending, Leased, Disputed)
- Generate unique property identifier

**Technical Implementation:**
- Property metadata stored on-chain with IPFS references for documents
- Integration with property verification oracles
- Multi-signature requirements for high-value properties

#### 3.1.2 Property Discovery
**User Story**: As a tenant, I want to search and filter available properties so that I can find suitable rental options.

**Acceptance Criteria:**
- Filter by location, price range, property size
- View property details and verification status
- Check landlord reputation and settlement history
- Verify smart contract integration status
- View landlord's fund distribution choice preference

### 3.2 Deposit Management System

#### 3.2.1 Deposit Submission
**User Story**: As a tenant, I want to securely submit my rental deposit so that I can enter into a rental agreement.

**Process Flow:**
1. **KRW Validation**: Verify stablecoin authenticity and sufficient balance
2. **Pool Deposit**: Transfer KRW to deposit pool contract
3. **Yield Conversion**: Convert KRW to cKRW (yield-bearing token)
4. **Landlord Choice Execution**: Process landlord's selected fund distribution option
5. **Contract Activation**: Update property status to "Occupied" and emit events

**Acceptance Criteria:**
- One-click deposit submission with wallet integration
- Real-time transaction status tracking
- Automatic token conversion and splitting
- Gas optimization for cost-effective transactions

#### 3.2.2 Deposit Recovery
**User Story**: As a tenant, I want to recover my deposit at the end of the lease period.

**Process Flow:**
1. **Settlement Verification**: Confirm landlord has returned cKRW to pool
2. **Conversion**: cKRW → KRW stablecoin at current exchange rate
3. **Transfer**: Return original deposit amount to tenant
4. **Contract Closure**: Update property status to "Settled"

### 3.3 Fund Management System

#### 3.3.1 Landlord Distribution Choice
**User Story**: As a landlord, I want to choose how to receive and manage my tenant's deposit funds.

**Distribution Options:**
1. **Direct Transfer**: Receive cKRW tokens directly for independent management
2. **Pool Retention**: Keep funds in platform's yield optimization pool

**Acceptance Criteria:**
- Clear choice selection during property registration
- Immediate fund availability based on chosen option
- Transparent yield generation mechanisms
- Ability to change preference for future contracts

#### 3.3.2 Yield Optimization
**User Story**: As a landlord, I want to earn yield on deposited funds during the rental period.

**Pool Retention Features:**
- Automated yield farming across multiple DeFi protocols
- Dynamic allocation based on APY rates and risk assessment
- Compound interest calculation and distribution
- Performance tracking and reporting

**Direct Transfer Features:**
- Independent access to external DeFi protocols
- Personal responsibility for yield optimization
- Educational resources and strategy recommendations
- Risk management guidance

### 3.4 Settlement and Default Management

#### 3.4.1 Standard Settlement
**Process Flow:**
1. **Maturity Check**: Verify lease period completion
2. **Fund Return**: Landlord returns cKRW to deposit pool
3. **Tenant Recovery**: Convert cKRW to KRW and transfer to tenant
4. **Yield Distribution**: Distribute generated yield to landlord
5. **Contract Closure**: Update property NFT status to "Settled"

#### 3.4.2 Default Scenarios and P2P Marketplace
**Automatic Unsettled Detection:**
- Grace period monitoring (7-30 days after lease maturity)
- Property status update to "Unsettled" if not settled
- Automatic debt claim listing generation

**P2P Marketplace Process:**
1. **Debt Listing**: Create tradeable debt claim with property collateral
2. **Investor Purchase**: Third-party investor pays outstanding amount
3. **Tenant Recovery**: Immediate deposit return to tenant
4. **Debt Management**: Investor becomes creditor with interest accrual
5. **Repayment Options**: Flexible repayment terms for landlord

**Liquidation Process (Extended Defaults):**
- Property disposal rights transfer to debt holder
- Market sale execution through authorized channels
- Proceeds distribution: Debt holder (priority), Platform fees, Landlord (remainder)

## 4. Frontend Requirements (app/)

### 4.1 Technology Stack
- **Framework**: React 18 with TypeScript
- **Styling**: Tailwind CSS for responsive design
- **Web3 Integration**: ethers.js with Web3Modal/RainbowKit
- **State Management**: React Query for server state, Zustand for client state
- **Routing**: React Router v6
- **Testing**: Jest + React Testing Library

### 4.2 Core Pages and Components

#### 4.2.1 Landing Page
- Project overview and value proposition
- Market statistics and TVL display
- Call-to-action for property owners and tenants
- Educational content about the platform

#### 4.2.2 Property Marketplace
- Property listing grid with filtering capabilities
- Property detail modal with comprehensive information
- Map integration for location visualization
- Advanced search and sorting functionality

#### 4.2.3 Dashboard (Role-Based)

**Landlord Dashboard:**
- Property portfolio overview
- cKRW token balances and distribution choices
- Active rental contracts and settlement status
- Yield generation performance (pool retention vs direct management)
- Property management tools
- Debt repayment status (if applicable)

**Tenant Dashboard:**
- Active lease agreements and status
- Deposit security and recovery timeline
- Contract settlement progress
- Transaction history and receipts
- P2P marketplace recovery status (for unsettled contracts)

**Investor Dashboard:**
- Available debt claims in P2P marketplace
- Active debt investments and returns
- Risk assessment and property valuations
- Portfolio management and secondary trading
- Repayment tracking and liquidation status

#### 4.2.4 Transaction Interface
- Wallet connection and account management
- Transaction preparation and gas estimation
- Real-time transaction status tracking
- Success/failure handling and user feedback

#### 4.2.5 P2P Debt Marketplace Interface
- Debt claim listings with detailed property information
- Risk assessment tools and scoring displays
- Investment purchase and management interface
- Secondary market trading functionality
- Interest rate calculation and payment tracking

### 4.3 Web3 Integration Requirements
- Multi-wallet support (MetaMask, WalletConnect, etc.)
- Network switching to Kaia
- Transaction signing and confirmation flows
- Smart contract interaction abstractions
- Error handling and user education

## 5. Smart Contract Requirements (contracts/)

### 5.1 Development Framework
- **Framework**: Foundry for development, testing, and deployment
- **Testing**: Forge for unit and integration testing
- **Deployment**: Forge scripts for automated deployment
- **Verification**: Contract source verification on block explorer

### 5.2 Contract Architecture

#### 5.2.1 PropertyNFT Contract
```solidity
contract PropertyNFT is ERC721, Ownable {
    struct PropertyMetadata {
        string location;
        uint256 area;
        uint256 depositAmount;
        uint256 leasePeriod;
        PropertyStatus status;
        string documentHash; // IPFS hash
        address verifier;
        uint256 createdAt;
    }
    
    enum PropertyStatus { Available, Pending, Leased, Disputed }
    
    function mintProperty(PropertyMetadata memory metadata) external returns (uint256);
    function updatePropertyStatus(uint256 tokenId, PropertyStatus status) external;
    function verifyProperty(uint256 tokenId) external;
}
```

#### 5.2.2 Deposit Pool Contract
```solidity
contract DepositPool {
    enum DistributionChoice { DirectTransfer, PoolRetention }
    
    struct DepositInfo {
        uint256 amount;
        uint256 cKRWAmount;
        address tenant;
        address landlord;
        uint256 maturityDate;
        DistributionChoice choice;
        bool isSettled;
    }
    
    // KRW to cKRW conversion
    function submitDeposit(
        uint256 propertyId,
        uint256 krwAmount,
        DistributionChoice choice
    ) external returns (uint256 cKRWAmount);
    
    // Landlord fund distribution
    function distributeFunds(uint256 depositId) external;
    
    // Tenant deposit recovery
    function recoverDeposit(uint256 depositId) external returns (uint256 krwAmount);
    
    // Yield optimization for pool retention
    function optimizePoolYield() external;
    
    // Settlement process
    function settleContract(uint256 depositId) external;
}
```

#### 5.2.3 P2P Debt Marketplace Contract
```solidity
contract P2PDebtMarketplace {
    struct DebtClaim {
        uint256 propertyId;
        address originalLandlord;
        address currentHolder;
        uint256 principalAmount;
        uint256 interestRate;
        uint256 listingDate;
        uint256 maturityDate;
        bool isActive;
        uint256 collateralValue;
    }
    
    // List unsettled contract as debt claim
    function listDebtClaim(
        uint256 propertyId,
        uint256 outstandingAmount,
        uint256 interestRate
    ) external returns (uint256 claimId);
    
    // Purchase debt claim
    function purchaseDebtClaim(
        uint256 claimId,
        uint256 paymentAmount
    ) external returns (uint256 investmentId);
    
    // Transfer debt claim (secondary market)
    function transferDebtClaim(
        uint256 claimId,
        address newOwner,
        uint256 transferPrice
    ) external;
    
    // Landlord debt repayment
    function repayDebt(uint256 claimId, uint256 amount) external;
    
    // Calculate interest and total debt
    function calculateDebtAmount(uint256 claimId) external view returns (uint256);
}
```

#### 5.2.4 Settlement Manager Contract
```solidity
contract SettlementManager {
    struct ContractStatus {
        uint256 propertyId;
        address landlord;
        address tenant;
        uint256 maturityDate;
        uint256 gracePeriod;
        bool isSettled;
        bool isListed;
        uint256 listingTimestamp;
    }
    
    // Check if contract should be marked as unsettled
    function checkSettlementStatus(uint256 propertyId) external returns (bool);
    
    // Mark contract as unsettled and trigger marketplace listing
    function markUnsettled(uint256 propertyId) external;
    
    // Process settlement when landlord returns funds
    function processSettlement(uint256 propertyId, uint256 cKRWAmount) external;
    
    // Handle partial repayments
    function processPartialRepayment(
        uint256 propertyId,
        uint256 repaymentAmount
    ) external;
    
    // Grace period management
    function setGracePeriod(uint256 propertyId, uint256 period) external;
}
```

### 5.3 Security Requirements
- Comprehensive unit test coverage (>90%)
- Integration testing for contract interactions
- Formal verification for critical functions
- Multiple security audit preparations
- Emergency pause mechanisms
- Multi-signature administrative controls

## 6. Development Roadmap

### Phase 1: Foundation Setup (Weeks 1-2)
**Smart Contracts:**
- Set up Foundry development environment
- Implement basic token contracts (KRW, cKRW)
- Create PropertyNFT contract with basic functionality
- Write initial test suites

**Frontend:**
- Initialize React project with TypeScript
- Set up Tailwind CSS and component library
- Implement wallet connection functionality
- Create basic routing and page structure

### Phase 2: Simplified Token System (Weeks 3-4)
**Smart Contracts:**
- Implement Deposit Pool contract with cKRW conversion
- Develop landlord distribution choice mechanisms
- Create yield optimization strategies for pool retention
- Add interest calculation and accrual logic

**Frontend:**
- Build property listing and detail pages
- Implement cKRW balance displays and distribution choice selection
- Create deposit submission interface
- Add transaction status tracking

### Phase 3: P2P Marketplace and Settlement (Weeks 5-6)
**Smart Contracts:**
- Develop P2P Debt Marketplace contract
- Implement Settlement Manager contract
- Add automatic unsettled contract detection
- Create debt claim trading and liquidation mechanisms

**Frontend:**
- Build P2P marketplace interface for investors
- Implement landlord dashboard with settlement tracking
- Create tenant dashboard with enhanced security features
- Add debt claim management and trading UI

### Phase 4: Integration and Testing (Weeks 7-8)
**Smart Contracts:**
- Complete integration testing
- Deploy to Kaia testnet
- Perform security audit preparation
- Optimize gas usage

**Frontend:**
- End-to-end testing implementation
- Performance optimization
- Mobile responsiveness testing
- User acceptance testing

## 7. Testing Strategy

### 7.1 Smart Contract Testing
- **Unit Tests**: Individual contract function testing
- **Integration Tests**: Multi-contract interaction scenarios
- **Fuzzing Tests**: Property-based testing for edge cases
- **Gas Optimization Tests**: Cost-effective transaction validation

### 7.2 Frontend Testing
- **Component Tests**: Individual React component functionality
- **Integration Tests**: User flow testing
- **E2E Tests**: Complete user journey validation
- **Web3 Integration Tests**: Blockchain interaction testing

### 7.3 Security Testing
- **Static Analysis**: Slither and other security scanners
- **Manual Code Review**: Line-by-line security assessment
- **Testnet Deployment**: Real-world testing environment
- **Third-party Audit Preparation**: Documentation and test coverage

## 8. Risk Assessment and Mitigation

### 8.1 Technical Risks
**Smart Contract Vulnerabilities**
- Mitigation: Comprehensive testing, multiple audits, gradual deployment

**Oracle Failures**
- Mitigation: Multiple oracle sources, fallback mechanisms

**Gas Price Volatility**
- Mitigation: Layer 2 deployment (Kaia), meta-transaction support

### 8.2 Market Risks
**Low Adoption**
- Mitigation: Strong incentive design, user education, partnership development

**Regulatory Changes**
- Mitigation: Legal compliance framework, regulatory monitoring

**Competition**
- Mitigation: First-mover advantage, strong network effects, continuous innovation

### 8.3 Operational Risks
**Key Management**
- Mitigation: Multi-signature wallets, hardware security modules

**System Downtime**
- Mitigation: Decentralized architecture, redundant systems

## 9. Success Criteria and KPIs

### 9.1 Technical KPIs
- **Smart Contract Security**: Zero critical vulnerabilities in audit
- **Transaction Success Rate**: >99% successful transactions
- **Gas Efficiency**: <$1 average transaction cost on Kaia
- **Response Time**: <3 seconds for UI interactions

### 9.2 Business KPIs
- **User Acquisition**: 100+ registered users during PoC (landlords, tenants, investors)
- **Transaction Volume**: $100K+ equivalent in KRW processed
- **Property Listings**: 50+ verified properties
- **P2P Marketplace Activity**: 20+ debt claims traded with 80%+ tenant recovery rate

### 9.3 User Experience KPIs
- **Onboarding Time**: <5 minutes from wallet connection to first transaction
- **User Satisfaction**: >4.0/5.0 rating in user testing
- **Completion Rate**: >80% of started transactions completed
- **Support Tickets**: <10% of users requiring assistance

## 10. Post-PoC Roadmap

### 10.1 Production Readiness
- Security audit completion and remediation
- Mainnet deployment and monitoring
- Customer support infrastructure
- Legal and regulatory compliance

### 10.2 Feature Expansion
- Advanced yield optimization strategies for pool retention
- Multi-property portfolio management for landlords
- Insurance product integration for enhanced tenant protection
- Mobile application development
- Credit scoring integration for improved risk assessment

### 10.3 Ecosystem Growth
- Partnership with real estate agencies
- Integration with traditional financial institutions
- Expansion to commercial real estate
- International market exploration

## Conclusion

This PoC will validate the core technical and business assumptions of the simplified Re-Lease platform. Success will be measured by the seamless execution of the KRW → cKRW → Landlord Choice flow, effective P2P debt marketplace operations, and demonstration of the platform's potential for eliminating rental fraud through simplified yet secure mechanisms.

The streamlined architecture reduces complexity while maintaining security and transparency, ensuring broad accessibility without sacrificing the essential fraud prevention and liquidity benefits. The P2P debt marketplace creates sustainable default resolution while providing attractive investment opportunities for third parties.

The simplified approach facilitates faster development, lower gas costs, and improved user experience while preserving the core value propositions that make Re-Lease a viable solution for the Korean rental market.

---

*Detailed implementation specifications for each component are available in the respective directory PRDs:*
- *Frontend specifications: `/app/prd.md`*
- *Smart contract specifications: `/contracts/prd.md`*