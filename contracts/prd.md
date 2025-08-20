# Re-Lease Smart Contract Product Requirements Document v2.0

## 1. Overview

### 1.1 Product Name
Re-Lease Simplified Smart Contract Suite

### 1.2 Product Description
A streamlined smart contract system for a decentralized rental deposit platform built on Kaia Chain (EVM). The system eliminates complex tokenization in favor of a simple KRW→cKRW conversion with landlord choice mechanisms and a P2P debt marketplace for handling defaults.

### 1.3 Technology Stack
- **Blockchain**: Kaia (EVM Compatible)
- **Development Framework**: Foundry
- **Language**: Solidity ^0.8.20
- **Libraries**: OpenZeppelin Contracts v5.0+
- **Testing**: Forge, Foundry Test

### 1.4 Simplified Contract Architecture
1. **PropertyNFT**: Property registration with enhanced status tracking (ERC-721)
2. **DepositPool**: KRW/cKRW conversion and landlord distribution management
3. **P2PDebtMarketplace**: Debt claim trading for unsettled contracts
4. **SettlementManager**: Contract settlement and grace period monitoring

## 2. Detailed Contract Design

### 2.1 PropertyNFT Contract (ERC-721)

#### 2.1.1 Core Structure
```solidity
struct Property {
    address owner;              // Property owner
    string metadataURI;        // IPFS metadata URI
    uint256 depositAmount;     // Required deposit amount
    uint256 leasePeriod;       // Lease period in seconds
    PropertyStatus status;     // Enhanced property status
    address currentTenant;     // Current tenant
    uint256 leaseStartTime;    // Lease start time
    uint256 leaseEndTime;      // Lease end time
    DistributionChoice landlordChoice; // Landlord's fund distribution preference
    uint256 gracePeriod;       // Grace period for settlement
}

enum PropertyStatus {
    Available,    // Available for lease
    Occupied,     // Currently occupied with active lease
    Settled,      // Contract completed and settled
    Unsettled,    // Contract expired but not settled (P2P marketplace eligible)
    Disputed      // Under dispute resolution
}

enum DistributionChoice {
    DirectTransfer,  // Landlord receives cKRW directly
    PoolRetention    // Funds remain in yield optimization pool
}
```

#### 2.1.2 Key Functions
```solidity
function mintProperty(
    address to,
    string memory metadataURI,
    uint256 depositAmount,
    uint256 leasePeriod,
    DistributionChoice landlordChoice
) external returns (uint256 tokenId);

function updatePropertyStatus(uint256 tokenId, PropertyStatus status) external;
function setLeaseInfo(uint256 tokenId, address tenant, uint256 startTime, uint256 endTime) external;
function markUnsettled(uint256 tokenId) external;
function getPropertyDetails(uint256 tokenId) external view returns (Property memory);
function isAvailable(uint256 tokenId) external view returns (bool);
function isSettlementOverdue(uint256 tokenId) external view returns (bool);
function getLandlordChoice(uint256 tokenId) external view returns (DistributionChoice);
```

### 2.2 DepositPool Contract

#### 2.2.1 Core Structure
```solidity
contract DepositPool is AccessControl, Pausable, ReentrancyGuard {
    // KRW stablecoin integration
    IERC20 public immutable krwToken;
    
    // Yield-bearing token (cKRW) functionality built-in
    uint256 public totalPoolAssets;
    uint256 public totalPoolShares;
    uint256 public yieldRate; // Annual yield rate in basis points
    uint256 public lastYieldUpdate;
    
    struct DepositInfo {
        uint256 krwAmount;          // Original KRW deposit
        uint256 cKRWAmount;         // Converted cKRW amount
        address tenant;             // Tenant who deposited
        address landlord;           // Landlord receiving funds
        uint256 propertyId;         // Associated property NFT ID
        DistributionChoice choice;  // Landlord's distribution choice
        uint256 depositTime;        // When deposit was made
        uint256 maturityTime;       // When lease ends
        bool isSettled;            // Settlement status
    }
    
    mapping(uint256 => DepositInfo) public deposits;
    mapping(address => uint256[]) public landlordDeposits;
    mapping(address => uint256[]) public tenantDeposits;
    
    uint256 public nextDepositId;
}
```

#### 2.2.2 Key Functions
```solidity
function submitDeposit(
    uint256 propertyId,
    uint256 krwAmount,
    address landlord,
    DistributionChoice choice,
    uint256 maturityTime
) external returns (uint256 depositId, uint256 cKRWAmount);

function distributeFunds(uint256 depositId) external;
function recoverDeposit(uint256 depositId) external returns (uint256 krwAmount);
function settleContract(uint256 depositId, uint256 returnedAmount) external;
function optimizePoolYield() external onlyRole(POOL_MANAGER_ROLE);
function calculateYield(uint256 amount, uint256 duration) external view returns (uint256);
function getDepositDetails(uint256 depositId) external view returns (DepositInfo memory);
```

### 2.3 P2PDebtMarketplace Contract

#### 2.3.1 Debt Claim Structure
```solidity
contract P2PDebtMarketplace is AccessControl, Pausable, ReentrancyGuard {
    struct DebtClaim {
        uint256 propertyId;         // Associated property NFT ID
        uint256 depositId;          // Associated deposit ID
        address originalLandlord;   // Original landlord who defaulted
        address currentHolder;      // Current debt claim holder
        uint256 principalAmount;    // Original debt amount
        uint256 interestRate;       // Interest rate in basis points
        uint256 listingTime;        // When listed on marketplace
        uint256 purchaseTime;       // When purchased (0 if unsold)
        uint256 lastInterestUpdate; // Last interest calculation
        uint256 totalInterestAccrued; // Total interest accumulated
        bool isActive;              // Whether claim is active
        bool isRepaid;              // Whether fully repaid
        uint256 collateralValue;    // Estimated property value backing
        uint256 riskScore;          // Calculated risk score
    }
    
    mapping(uint256 => DebtClaim) public debtClaims;
    mapping(address => uint256[]) public investorClaims;
    mapping(address => uint256[]) public landlordDebts;
    mapping(uint256 => uint256) public propertyToDebtClaim;
    
    uint256 public nextClaimId;
    uint256 public platformFeeRate; // Platform fee in basis points
}
```

#### 2.3.2 Key Functions
```solidity
function listDebtClaim(
    uint256 propertyId,
    uint256 depositId,
    uint256 outstandingAmount,
    uint256 interestRate,
    uint256 collateralValue
) external returns (uint256 claimId);

function purchaseDebtClaim(uint256 claimId) external payable returns (bool success);
function repayDebt(uint256 claimId, uint256 amount) external;
function transferDebtClaim(uint256 claimId, address newOwner, uint256 price) external;
function calculateCurrentDebt(uint256 claimId) external view returns (uint256);
function calculateInterest(uint256 claimId) external view returns (uint256);
function getMarketplaceListings() external view returns (uint256[] memory);
function getInvestorPortfolio(address investor) external view returns (uint256[] memory);
function liquidateProperty(uint256 claimId) external;
```

### 2.4 SettlementManager Contract

#### 2.4.1 Settlement Tracking Structure
```solidity
contract SettlementManager is AccessControl, Pausable {
    struct ContractStatus {
        uint256 propertyId;         // Property NFT ID
        uint256 depositId;          // Deposit pool entry ID
        address landlord;           // Landlord address
        address tenant;             // Tenant address
        uint256 maturityTime;       // When contract should be settled
        uint256 gracePeriod;        // Grace period before marking unsettled
        bool isSettled;             // Whether properly settled
        bool isListed;              // Whether listed on P2P marketplace
        uint256 listingTime;        // When listed (0 if not listed)
        uint256 warningsSent;       // Number of settlement warnings sent
    }
    
    mapping(uint256 => ContractStatus) public contractStatuses;
    mapping(address => uint256[]) public landlordContracts;
    mapping(address => uint256[]) public tenantContracts;
    
    uint256 public defaultGracePeriod; // Default grace period (7-30 days)
    address public depositPool;
    address public p2pMarketplace;
}
```

#### 2.4.2 Key Functions
```solidity
function registerContract(
    uint256 propertyId,
    uint256 depositId,
    address landlord,
    address tenant,
    uint256 maturityTime
) external;

function checkSettlementStatus(uint256 propertyId) external returns (bool isOverdue);
function markUnsettled(uint256 propertyId) external;
function processSettlement(uint256 propertyId) external;
function setGracePeriod(uint256 propertyId, uint256 gracePeriod) external;
function getOverdueContracts() external view returns (uint256[] memory);
function sendSettlementWarning(uint256 propertyId) external;
function batchCheckSettlements(uint256[] calldata propertyIds) external;
```






## 3. Contract Interaction Flows

### 3.1 Simplified Deposit Contract Creation Flow

```
1. PropertyNFT.mintProperty() → Create property NFT with landlord choice
   ├─ Input: Property metadata, deposit amount, lease period, distribution choice
   └─ Output: Property NFT tokenId

2. DepositPool.submitDeposit() → Tenant submits deposit
   ├─ Input: Property ID, KRW amount, landlord address
   └─ Output: Deposit ID, cKRW amount

3. DepositPool.distributeFunds() → Execute landlord distribution choice
   ├─ Input: Deposit ID
   └─ Output: Direct transfer OR pool retention confirmation

4. SettlementManager.registerContract() → Register for settlement tracking
   ├─ Input: Property ID, deposit ID, landlord, tenant, maturity time
   └─ Output: Contract registration confirmation

5. PropertyNFT.updatePropertyStatus() → Update to "Occupied"
   ├─ Input: Property ID, new status
   └─ Output: Status update confirmation
```

### 3.2 Normal Settlement Flow

```
1. SettlementManager.checkSettlementStatus() → Monitor lease maturity
   ├─ Input: Property ID
   └─ Output: Settlement status

2. DepositPool.settleContract() → Landlord returns cKRW to pool
   ├─ Input: Deposit ID, returned cKRW amount
   └─ Output: Settlement confirmation

3. DepositPool.recoverDeposit() → Tenant recovers original deposit
   ├─ Input: Deposit ID
   └─ Output: KRW transfer to tenant

4. PropertyNFT.updatePropertyStatus() → Update to "Settled"
   ├─ Input: Property ID, new status
   └─ Output: Status update confirmation
```

### 3.3 Default and P2P Marketplace Flow

```
1. SettlementManager.checkSettlementStatus() → Detect overdue settlement
   ├─ Input: Property ID
   └─ Output: Overdue status after grace period

2. SettlementManager.markUnsettled() → Mark contract as unsettled
   ├─ Input: Property ID
   └─ Output: Unsettled status

3. P2PDebtMarketplace.listDebtClaim() → Auto-list debt claim
   ├─ Input: Property ID, deposit ID, outstanding amount
   └─ Output: Debt claim ID

4. P2PDebtMarketplace.purchaseDebtClaim() → Investor purchases debt
   ├─ Input: Claim ID, payment amount
   └─ Output: Debt ownership transfer

5. DepositPool.recoverDeposit() → Immediate tenant recovery
   ├─ Input: Deposit ID
   └─ Output: KRW transfer to tenant

6. P2PDebtMarketplace.repayDebt() → Landlord repays debt to investor
   ├─ Input: Claim ID, repayment amount
   └─ Output: Debt reduction/closure
```

### 3.1 Jeonse Contract Creation Flow
```
1. PropertyNFT.mintProperty() → Create property NFT
2. KRWStablecoin.transfer() → Tenant transfers deposit
3. CompoundKRW.deposit() → Convert KRW → cKRW
4. StandardizedYield.deposit() → Convert cKRW → SY
5. PrincipalToken.mint() + YieldToken.mint() → Split SY → PT + YT
6. LeaseManager.createLease() → Create contract
7. LeaseManager.executeLease() → Transfer PT to landlord, store YT
```

### 3.2 Lending Execution Flow
```
1. PrincipalToken.approve() → Approve PT usage
2. YieldToken.approve() → Approve YT usage
3. LendingVault.borrow() → Execute loan with PT+YT collateral
4. CompoundKRW.mint() → Issue loan amount
5. CompoundKRW.transfer() → Transfer loan to landlord
```

### 3.3 Contract Termination Flow
```
1. LeaseManager.terminateLease() → Request contract termination
2. PrincipalToken.transfer() → Return PT to tenant
3. YieldToken.transfer() → Return YT to tenant
4. PrincipalToken.redeem() → Redeem PT
5. YieldToken.claimYield() → Claim YT yield
6. StandardizedYield.redeem() → Convert SY → cKRW
7. CompoundKRW.withdraw() → Convert cKRW → KRW
```

## 4. Security and Access Control

### 4.1 Simplified Role-Based Access Control (RBAC)
```solidity
// Core system roles
bytes32 public constant ADMIN_ROLE = DEFAULT_ADMIN_ROLE;
bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
bytes32 public constant EMERGENCY_ROLE = keccak256("EMERGENCY_ROLE");

// Property management roles
bytes32 public constant PROPERTY_VERIFIER_ROLE = keccak256("PROPERTY_VERIFIER_ROLE");

// Pool management roles
bytes32 public constant POOL_MANAGER_ROLE = keccak256("POOL_MANAGER_ROLE");

// Settlement monitoring roles
bytes32 public constant SETTLEMENT_MANAGER_ROLE = keccak256("SETTLEMENT_MANAGER_ROLE");

// P2P marketplace roles
bytes32 public constant MARKETPLACE_ADMIN_ROLE = keccak256("MARKETPLACE_ADMIN_ROLE");
```

### 4.2 Security Mechanisms
1. **ReentrancyGuard**: Prevent reentrancy attacks across all contracts
2. **Pausable**: Emergency contract pause functionality for each contract
3. **Access Control**: Simplified permission-based function access
4. **SafeERC20**: Safe token transfers for KRW/cKRW operations
5. **Grace Period Protection**: Automated settlement monitoring with grace periods
6. **Debt Validation**: Comprehensive validation of P2P marketplace transactions
7. **Multi-signature**: Multi-sig requirement for admin functions only

### 4.3 Audit Requirements
```solidity
contract AuditableContract {
    event AuditLog(
        address indexed actor,
        string action,
        uint256 indexed entityId,
        uint256 amount,
        uint256 timestamp
    );
    
    modifier auditLog(string memory action, uint256 entityId, uint256 amount) {
        emit AuditLog(msg.sender, action, entityId, amount, block.timestamp);
        _;
    }
}
```

## 5. Gas Optimization Strategies

### 5.1 Simplified Storage Optimization
```solidity
// Optimized structs for simplified system
struct PackedProperty {
    uint128 depositAmount;      // 16 bytes
    uint64 leaseStartTime;      // 8 bytes
    uint64 leaseEndTime;        // 8 bytes = 32 bytes (1 slot)
    uint32 gracePeriod;         // 4 bytes
    uint8 status;               // 1 byte
    uint8 distributionChoice;   // 1 byte = 6 bytes total (fits in slot)
}

struct PackedDebtClaim {
    uint128 principalAmount;    // 16 bytes
    uint128 totalInterest;      // 16 bytes = 32 bytes (1 slot)
    uint64 listingTime;         // 8 bytes
    uint64 lastUpdate;          // 8 bytes
    uint32 interestRate;        // 4 bytes
    uint32 riskScore;           // 4 bytes = 24 bytes (fits in slot)
}
```

### 5.2 Gas Optimization Targets (Simplified System)
- **Property NFT Minting**: < 150,000 gas (simplified metadata)
- **Deposit Submission**: < 200,000 gas (single KRW→cKRW conversion)
- **Landlord Distribution**: < 100,000 gas (simple transfer/pool logic)
- **P2P Debt Listing**: < 150,000 gas (marketplace listing)
- **Debt Purchase**: < 180,000 gas (debt transfer + tenant recovery)
- **Settlement Processing**: < 120,000 gas (status updates)
- **Contract Termination**: < 130,000 gas (multi-contract updates)

### 5.3 Function Optimization
1. **Batch Settlement Checks**: Process multiple contracts in single call
2. **View Functions**: Optimize read-only operations for off-chain queries
3. **Event-Based Logging**: Reduce storage costs with comprehensive events
4. **Packed Parameters**: Optimize function parameters for calldata efficiency

## 6. Testing Strategy

### 6.1 Unit Tests
```solidity
// Foundry test structure
contract PropertyNFTTest is Test {
    PropertyNFT propertyNFT;
    address owner = address(0x1);
    address tenant = address(0x2);
    
    function setUp() public {
        propertyNFT = new PropertyNFT();
    }
    
    function testMintProperty() public {
        // Test logic
    }
    
    function testFailUnauthorizedMint() public {
        // Failure case testing
    }
}
```

### 6.2 Integration Tests
```solidity
contract IntegrationTest is Test {
    // Full system integration testing
    function testFullLeaseFlow() public {
        // 1. Create Property NFT
        // 2. Deposit funds
        // 3. Split PT/YT
        // 4. Create contract
        // 5. Execute loan
        // 6. Terminate contract
    }
}
```

### 6.3 Fuzzing Tests
```solidity
function testFuzzDeposit(uint256 amount) public {
    vm.assume(amount > 0 && amount <= MAX_DEPOSIT);
    // Test with random values
}
```

### 6.4 Gas Testing
```solidity
function testGasUsage() public {
    uint256 gasBefore = gasleft();
    propertyNFT.mintProperty(owner, "uri", 1000, 365 days);
    uint256 gasUsed = gasBefore - gasleft();
    
    assertLt(gasUsed, 200_000); // Less than 200k gas
}
```

## 7. Simplified Deployment and Initialization

### 7.1 Simplified Deployment Script (Foundry)
```solidity
contract SimplifiedDeployScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        
        // 1. Deploy basic KRW token (or use existing)
        address krwToken = address(0x123); // Use existing KRW stablecoin
        
        // 2. Deploy DepositPool (includes cKRW functionality)
        DepositPool depositPool = new DepositPool(krwToken);
        
        // 3. Deploy PropertyNFT with enhanced status tracking
        PropertyNFT propertyNFT = new PropertyNFT();
        
        // 4. Deploy P2P Debt Marketplace
        P2PDebtMarketplace marketplace = new P2PDebtMarketplace();
        
        // 5. Deploy Settlement Manager
        SettlementManager settlementManager = new SettlementManager(
            address(depositPool),
            address(marketplace)
        );
        
        // 6. Initialize contract relationships
        depositPool.setSettlementManager(address(settlementManager));
        marketplace.setDepositPool(address(depositPool));
        marketplace.setPropertyNFT(address(propertyNFT));
        
        // 7. Set up access control
        propertyNFT.grantRole(propertyNFT.PROPERTY_VERIFIER_ROLE(), msg.sender);
        depositPool.grantRole(depositPool.POOL_MANAGER_ROLE(), msg.sender);
        marketplace.grantRole(marketplace.MARKETPLACE_ADMIN_ROLE(), msg.sender);
        settlementManager.grantRole(settlementManager.SETTLEMENT_MANAGER_ROLE(), msg.sender);
        
        vm.stopBroadcast();
        
        // Log deployed addresses
        console.log("KRW Token (existing):", krwToken);
        console.log("DepositPool:", address(depositPool));
        console.log("PropertyNFT:", address(propertyNFT));
        console.log("P2PDebtMarketplace:", address(marketplace));
        console.log("SettlementManager:", address(settlementManager));
    }
}
```

### 7.2 Simplified Deployment Sequence (4 Contracts)
1. **Token Setup**: Use existing KRW stablecoin or deploy basic ERC-20
2. **Core Pool**: Deploy DepositPool with built-in cKRW functionality
3. **Property Management**: Deploy PropertyNFT with enhanced status tracking
4. **P2P Infrastructure**: Deploy P2PDebtMarketplace for debt trading
5. **Settlement Monitoring**: Deploy SettlementManager for automated tracking
6. **Contract Integration**: Connect contracts with proper references
7. **Access Control**: Set up simplified role-based permissions
8. **Verification**: Run deployment tests and integration verification

**Deployment Benefits:**
- **60% Fewer Contracts**: 4 contracts instead of 10+
- **Reduced Gas Costs**: ~40% lower deployment costs
- **Simpler Integration**: Fewer inter-contract dependencies
- **Faster Deployment**: Single script execution in <5 minutes

### 7.3 Kaia Chain Configuration
```toml
# foundry.toml
[profile.kaia]
src = "src"
out = "out"
libs = ["lib"]
remappings = [
    "@openzeppelin/=lib/openzeppelin-contracts/"
    # Removed Pendle dependency
]

[rpc_endpoints]
kaia_mainnet = "https://klaytn-mainnet-rpc.allthatnode.com:8551"
kaia_testnet = "https://klaytn-baobab-rpc.allthatnode.com:8551"

[etherscan]
kaia = { key = "${KLAYTNSCOPE_API_KEY}", url = "https://scope.klaytn.com/api" }
```

## 8. Monitoring and Upgrades

### 8.1 Proxy Pattern (UUPS)
```solidity
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract PropertyNFTUpgradeable is PropertyNFT, UUPSUpgradeable {
    function _authorizeUpgrade(address newImplementation) 
        internal 
        override 
        onlyRole(DEFAULT_ADMIN_ROLE) 
    {}
}
```

### 8.2 Simplified Event-based Monitoring
```solidity
// Core system events
event PropertyMinted(uint256 indexed tokenId, address indexed owner, uint256 depositAmount, DistributionChoice choice);
event DepositSubmitted(uint256 indexed depositId, uint256 indexed propertyId, address indexed tenant, uint256 krwAmount, uint256 cKRWAmount);
event FundsDistributed(uint256 indexed depositId, address indexed landlord, DistributionChoice choice, uint256 amount);
event EmergencyPaused(address indexed caller, uint256 timestamp);
```

## 9. Regulatory Compliance and KYC

### 9.1 KYC Integration Structure
```solidity
contract KYCManager is AccessControl {
    enum KYCStatus { Pending, Approved, Rejected, Suspended }
    
    struct KYCInfo {
        KYCStatus status;
        uint256 approvedAt;
        uint256 expiresAt;
        string kycProvider;
    }
    
    mapping(address => KYCInfo) public kycStatus;
    
    modifier onlyKYCApproved() {
        require(kycStatus[msg.sender].status == KYCStatus.Approved, "KYC not approved");
        require(kycStatus[msg.sender].expiresAt > block.timestamp, "KYC expired");
        _;
    }
}
```

## 10. Performance Requirements

### 10.1 Gas Optimization Targets
- Property NFT Minting: < 200,000 gas
- Jeonse Contract Creation: < 300,000 gas
- PT/YT Splitting: < 250,000 gas
- Loan Execution: < 350,000 gas
- Contract Termination: < 200,000 gas

### 10.2 Throughput Targets
- TPS: 100 transactions/second
- Block Finality Time: 1 second (Kaia Chain)
- Contract Call Success Rate: 99.5%

## 11. Deployment Checklist

### 11.1 Pre-deployment Validation
- [ ] All unit tests passing (100% coverage)
- [ ] Integration tests passing
- [ ] Gas usage optimization completed
- [ ] Security audit completed (3 audit firms)
- [ ] Testnet deployment and validation completed
- [ ] Documentation completed

### 11.2 Post-deployment Monitoring
- [ ] Event log monitoring setup
- [ ] Gas usage alerts configured
- [ ] Transaction failure monitoring
- [ ] Collateral ratio monitoring
- [ ] Liquidity pool monitoring