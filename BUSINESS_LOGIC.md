# Re-Lease Business Logic Documentation

## Project Overview

Re-Lease is a decentralized platform that eliminates rental fraud by connecting tenants and landlords through Ethereum Virtual Machine (EVM) smart contracts. The platform provides a simplified, secure, and transparent rental deposit management system using yield-bearing tokens and a peer-to-peer debt marketplace for default scenarios.

### Core Innovation

The platform transforms Korean Won (KRW) stablecoin deposits into yield-bearing tokens (cKRW) and provides landlords with flexible options for accessing their funds. When defaults occur, unpaid deposits automatically enter a P2P marketplace where investors can purchase debt claims and earn interest from landlords.

## System Architecture

### Simplified Token Flow Structure

```
KRW Stablecoin → cKRW (Yield-bearing) → Landlord Choice:
     ↓                    ↓                 ↓
Deposit Input    Yield Generation    1. Direct Transfer
                                    2. Pool Retention
```

### Smart Contract Components

1. **Property NFT Contract (ERC-721)**
   - Stores property metadata and rental terms
   - Tracks contract status and settlement state
   - Enables public verification of rental agreements

2. **Deposit Pool Contract**
   - Manages KRW to cKRW conversion
   - Handles landlord fund distribution choices
   - Manages tenant deposit recovery process

3. **P2P Debt Marketplace Contract**
   - Lists unsettled rental agreements as tradeable debt
   - Facilitates debt purchase by third-party investors
   - Manages interest payments from landlords to debt holders

4. **Settlement Manager Contract**
   - Tracks rental agreement maturity and settlement status
   - Automates marketplace listing for unsettled contracts
   - Handles partial and full repayment scenarios

## Detailed Workflow Processes

### Phase 1: Property Listing and Registration

#### 1.1 Landlord Property Registration
```solidity
function registerProperty(
    PropertyMetadata memory metadata,
    uint256 depositAmount,
    uint256 rentalPeriod,
    string memory legalDocuments
) external returns (uint256 tokenId)
```

**Process Flow:**
1. Landlord submits property details, rental terms, and legal documentation
2. System validates property information and creates ERC-721 NFT
3. Property NFT is minted with embedded metadata including:
   - Property address and specifications
   - Deposit amount and rental duration
   - Legal verification status
   - Current contract state (Available, Occupied, Settled, Unsettled)

#### 1.2 Property Verification
```solidity
function verifyProperty(uint256 tokenId, bytes memory verificationData) external onlyVerifier
```

**Verification Requirements:**
- Legal ownership documentation
- Property condition assessment
- Compliance with local rental regulations
- Integration with government property databases

### Phase 2: Rental Agreement Initiation

#### 2.1 Tenant Deposit Submission
```solidity
function submitDeposit(
    uint256 propertyTokenId,
    uint256 depositAmount
) external returns (uint256 cKRWAmount)
```

**Technical Process:**
1. **KRW Validation**: Verify stablecoin authenticity and amount
2. **Pool Deposit**: Transfer KRW to the deposit pool contract
3. **Yield Conversion**: Convert KRW to cKRW (yield-bearing token)
4. **Landlord Choice Execution**: Process landlord's selected fund distribution option

#### 2.2 Landlord Fund Distribution Options
```solidity
function chooseFundDistribution(
    uint256 propertyTokenId,
    DistributionChoice choice
) external
```

**Distribution Choices:**
1. **Direct Transfer**: Receive cKRW tokens directly in landlord's wallet
2. **Pool Retention**: Keep funds in deposit pool to earn yield

**Choice Implications:**
- **Direct Transfer**: Landlord gains immediate access to yield-bearing tokens but must manage them independently
- **Pool Retention**: Funds remain in platform's yield optimization strategies, automatic compounding

#### 2.3 Contract Activation
```solidity
function activateRentalContract(
    uint256 propertyTokenId,
    uint256 cKRWAmount,
    uint256 maturityDate
) external
```

**Activation Logic:**
- Verify deposit amount matches property requirements
- Set maturity date based on rental period
- Update property NFT status to "Occupied"
- Record landlord's fund distribution choice
- Emit contract activation events for off-chain monitoring

### Phase 3: Yield Management During Rental Period

#### 3.1 Pool-Based Yield Optimization
```solidity
function optimizePoolYield(
    address[] memory protocols,
    uint256[] memory allocations
) external onlyManager
```

**Optimization Strategies (Pool Retention Only):**
- Automated yield farming across multiple DeFi protocols
- Dynamic allocation based on APY rates
- Risk assessment and protocol safety scoring
- Automated compounding and rebalancing

#### 3.2 Direct Transfer Management
**For landlords who chose direct transfer:**
- Landlords independently manage their cKRW tokens
- Access to external DeFi protocols for yield farming
- Personal responsibility for yield optimization
- Platform provides educational resources and recommendations

### Phase 4: Contract Maturity and Settlement

#### 4.1 Standard Settlement Process
```solidity
function settleContract(uint256 propertyTokenId) external
```

**Settlement Process:**
1. **Maturity Check**: Verify lease period has ended
2. **Fund Return**: Landlord returns cKRW to deposit pool
3. **Tenant Recovery**: Convert cKRW back to KRW and transfer to tenant
4. **Contract Closure**: Update property NFT status to "Settled"
5. **Yield Distribution**: Distribute any generated yield to landlord

#### 4.2 Tenant Deposit Recovery
```solidity
function recoverDeposit(uint256 propertyTokenId) external returns (uint256 krwAmount)
```

**Recovery Mechanism:**
1. Verify contract settlement completion
2. Convert cKRW back to KRW stablecoin at current exchange rate
3. Transfer original deposit amount to tenant
4. Update contract records and close tenant position

### Phase 5: Default Scenarios and P2P Debt Marketplace

#### 5.1 Automatic Unsettled Contract Detection
```solidity
function checkSettlementStatus(uint256 propertyTokenId) external returns (bool isSettled)
```

**Settlement Monitoring:**
- Automated checks after lease maturity date
- Grace period (typically 7-30 days) before marking as unsettled
- Property NFT status updates to "Unsettled" if not settled within grace period
- Automatic listing generation for P2P marketplace

#### 5.2 P2P Debt Marketplace Listing
```solidity
function listDebtClaim(
    uint256 propertyTokenId,
    uint256 outstandingAmount,
    uint256 interestRate,
    uint256 liquidationValue
) external returns (uint256 debtClaimId)
```

**Marketplace Listing Process:**
1. **Automatic Listing Creation**: System generates debt claim listing after grace period
2. **Outstanding Amount Calculation**: Determine unpaid deposit amount
3. **Interest Rate Setting**: Set competitive interest rate based on risk assessment
4. **Property Valuation**: Include property value as collateral backing
5. **Listing Activation**: Make debt claim available for purchase by investors

#### 5.3 Debt Claim Purchase and Management
```solidity
function purchaseDebtClaim(
    uint256 debtClaimId,
    uint256 paymentAmount
) external returns (uint256 investmentId)
```

**Debt Purchase Process:**
1. **Investor Payment**: Third-party investor pays outstanding deposit amount
2. **Immediate Tenant Relief**: Tenant receives deposit back immediately
3. **Debt Claim Transfer**: Investor becomes creditor to landlord
4. **Interest Accrual**: Debt begins earning interest for investor
5. **Collateral Backing**: Property serves as underlying collateral

#### 5.4 Landlord Debt Repayment
```solidity
function repayDebt(
    uint256 investmentId,
    uint256 repaymentAmount
) external
```

**Repayment Mechanisms:**
- **Full Repayment**: Landlord repays principal + accrued interest
- **Partial Repayment**: Proportional reduction of debt with continued interest
- **Extended Terms**: Negotiated payment plans through smart contract governance
- **Interest Calculation**: Compound interest based on agreed rates

#### 5.5 Liquidation Process for Continued Defaults
```solidity
function initiateLiquidation(uint256 investmentId) external onlyDebtHolder
```

**Liquidation Workflow:**
1. **Default Threshold**: Trigger after extended non-payment period
2. **Asset Seizure**: Transfer property disposal rights to debt holder or platform
3. **Market Sale**: Execute property sale through authorized channels
4. **Proceeds Distribution**:
   - Debt holder: Principal + accrued interest (priority)
   - Platform liquidation fees (2-3% of sale price)
   - Remaining proceeds to original landlord (if any)

## P2P Debt Marketplace Design

### Market Mechanics

#### 5.6 Pricing and Risk Assessment
```solidity
function calculateDebtClaimValue(
    uint256 propertyTokenId,
    uint256 landlordCreditScore,
    uint256 propertyValue,
    uint256 marketConditions
) external view returns (uint256 suggestedPrice, uint256 riskScore)
```

**Pricing Factors:**
- Property market value and location
- Landlord credit history and reputation
- Local market conditions and foreclosure rates
- Time since default and amount outstanding
- Legal environment and enforcement strength

#### 5.7 Secondary Market Trading
```solidity
function transferDebtClaim(
    uint256 investmentId,
    address newOwner,
    uint256 transferPrice
) external
```

**Secondary Market Features:**
- Debt claims can be traded between investors
- Market-driven pricing based on performance and risk
- Fractional ownership through tokenization of large debt claims
- Automated market makers for improved liquidity

### Interest Rate Management

#### 5.8 Dynamic Interest Rate Calculation
```solidity
function calculateInterestRate(
    uint256 riskScore,
    uint256 marketRate,
    uint256 propertyValue,
    uint256 debtAmount
) external pure returns (uint256 rate)
```

**Interest Rate Formula:**
```
Base Rate = Market Rate + Risk Premium
Risk Premium = f(Credit Score, Property Value, Market Conditions)
Final Rate = Base Rate + Platform Fee (0.5-1.0%)
```

**Rate Factors:**
- Base market interest rates for Korean market
- Property-specific risk assessment
- Landlord creditworthiness and history
- Regional economic indicators
- Platform risk management requirements

## Risk Management Framework

### Automated Risk Assessment

#### 5.9 Multi-Factor Risk Scoring
```solidity
function assessRiskScore(
    address landlord,
    uint256 propertyTokenId,
    uint256 depositAmount
) external view returns (uint256 riskScore)
```

**Risk Factors:**
- Property location and market trends
- Landlord rental history and payment behavior
- Property condition and maintenance records
- Local economic indicators and employment rates
- Legal framework strength and enforcement history

#### 5.10 Investor Protection Mechanisms
```solidity
function checkInvestorProtections(uint256 investmentId) external view returns (
    bool hasPropertyCollateral,
    bool hasInsurance,
    uint256 collateralRatio,
    uint256 maxLossExposure
)
```

**Protection Features:**
- Property-backed collateral for all debt claims
- Optional insurance pool for additional protection
- Maximum loan-to-value ratios to limit exposure
- Diversification requirements for large investors

## Economic Incentive Mechanisms

### Platform Revenue Model

#### 6.1 Simplified Fee Structure
```solidity
struct FeeStructure {
    uint256 contractFee;        // 0.1-0.2% of deposit (reduced complexity)
    uint256 marketplaceFee;     // 1-2% of debt claim value
    uint256 liquidationFee;     // 2-3% of liquidation proceeds
    uint256 yieldOptimizationFee; // 5-10% of generated yield (pool retention only)
}
```

#### 6.2 Revenue Distribution
**Platform Revenue Sources:**
- Contract initiation fees from successful rental agreements
- Marketplace transaction fees from debt claim trades
- Yield optimization fees from pool-retained funds
- Liquidation processing fees

**Revenue Allocation:**
- Platform development and maintenance: 60%
- Insurance and risk fund: 25%
- Token holder rewards: 10%
- Ecosystem development: 5%

### Incentive Alignment

#### 6.3 Stakeholder Incentives
**Tenants:**
- Guaranteed deposit recovery through marketplace mechanism
- No additional fees for deposit protection
- Faster resolution through investor involvement

**Landlords:**
- Choice between immediate liquidity and yield optimization
- Access to competitive debt financing when needed
- Preserved credit rating through structured repayment

**Investors:**
- Attractive risk-adjusted returns on debt investments
- Property-backed collateral for security
- Liquid secondary market for position management

## Security and Compliance

### Smart Contract Security

#### 7.1 Simplified Security Model
```solidity
modifier onlyAuthorizedParties(uint256 contractId) {
    require(
        isAuthorizedParty(msg.sender, contractId),
        "Unauthorized access"
    );
    _;
}
```

**Security Measures:**
- Multi-signature controls for critical functions
- Time-locked upgrades for contract modifications
- Circuit breaker mechanisms for emergency situations
- Regular third-party security audits

#### 7.2 Marketplace Security
```solidity
function validateDebtClaim(uint256 debtClaimId) external view returns (bool isValid) {
    // Validate property ownership
    // Verify outstanding debt amount
    // Confirm legal compliance
    // Check collateral sufficiency
}
```

**Marketplace Protections:**
- Automated validation of all debt claims
- KYC requirements for large debt purchases
- Anti-fraud measures and identity verification
- Legal compliance monitoring and reporting

## Performance Optimization

### Gas Efficiency

#### 8.1 Optimized Contract Design
```solidity
struct CompactContractData {
    uint128 depositAmount;      // Sufficient for KRW amounts
    uint64 maturityDate;        // Unix timestamp
    uint32 interestRate;        // Basis points
    uint16 propertyRegion;      // Geographic identifier
    uint8 contractStatus;       // Status enumeration
    uint8 distributionChoice;   // Landlord choice
}
```

### Scalability Solutions

#### 8.2 Layer 2 Integration
- Deployment on Kaia (formerly Klaytn) for low-cost transactions
- Batch processing for multiple contract operations
- Optimized state management for reduced storage costs
- Cross-chain compatibility for expanded market access

## Monitoring and Analytics

### System Health Monitoring

#### 9.1 Key Performance Indicators
```solidity
function getSystemMetrics() external view returns (
    uint256 totalValueLocked,
    uint256 activeContracts,
    uint256 settlementRate,
    uint256 marketplaceVolume,
    uint256 averageYield
)
```

**Critical Metrics:**
- Total Value Locked (TVL) in the platform
- Contract settlement success rate (target: >95%)
- P2P marketplace transaction volume and liquidity
- Average yield rates for different distribution choices
- Investor return rates and default recovery rates

#### 9.2 Risk Monitoring Dashboard
- Real-time risk assessment for active contracts
- Early warning system for potential defaults
- Market condition monitoring and adjustment
- Regulatory compliance tracking and reporting

## Future Enhancements

### Platform Evolution

#### 10.1 Advanced Features
- Multi-currency support beyond KRW
- Integration with traditional credit scoring systems
- AI-powered risk assessment and pricing models
- Cross-border rental agreement support

#### 10.2 Ecosystem Expansion
- Partnership with traditional real estate platforms
- Integration with mortgage providers and banks
- Insurance product development for enhanced protection
- Expansion to commercial real estate markets

#### 10.3 DeFi Integration
- Advanced yield farming strategies
- Integration with major DeFi protocols
- Liquidity mining programs for marketplace participants
- Governance token implementation for platform decisions

## Conclusion

This simplified business logic eliminates the complexity of ERC-5115 token splitting while maintaining the core value propositions of fraud prevention and liquidity provision. The P2P debt marketplace creates a sustainable mechanism for handling defaults while providing investment opportunities for third parties. The system balances simplicity with effectiveness, ensuring broad accessibility while maintaining security and transparency.

The streamlined approach reduces technical complexity, gas costs, and user confusion while preserving the essential security and economic benefits that make Re-Lease a viable solution for rental fraud prevention in the Korean market.