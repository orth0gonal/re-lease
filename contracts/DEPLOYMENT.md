# Re-Lease Smart Contracts Deployment Guide

## Kaia Testnet Deployment

### Deployed Contracts

All contracts have been successfully deployed to Kaia Testnet (Chain ID: 1001):

| Contract | Address | Description |
|----------|---------|-------------|
| **PropertyNFT** | `0xBB09bD6461cE02aE0F5C093a733A00C1478c82A4` | ERC-721 property tokenization with status tracking |
| **DepositPool** | `0x153bA726357a76e91f23b715E5d349cC96b799B6` | Deposit management with KRW↔cKRW conversion |
| **P2PDebtMarketplace** | `0x06E8bf9a48b6692e633836ee87460139235A462E` | P2P debt trading marketplace |
| **SettlementManager** | `0x291D1b60Cecf94a2e0a90D1366877f7a2309c4E4` | Automated settlement monitoring |

### Configuration

- **Deployer Address**: `0x541070bECf02bdE10Fbd347bb7EedC8033609A48`
- **Mock KRW Token**: `0x1234567890123456789012345678901234567890`
- **Initial Exchange Rate**: 1:1 KRW to cKRW (1e18)
- **Initial Yield Rate**: 5% annual (5e16)
- **Deployment Time**: 1755672464 (Unix timestamp)

### Contract References Verification ✅

All contract references have been verified successfully:

- DepositPool → PropertyNFT: ✅ `0xBB09bD6461cE02aE0F5C093a733A00C1478c82A4`
- P2PDebtMarketplace → PropertyNFT: ✅ `0xBB09bD6461cE02aE0F5C093a733A00C1478c82A4`
- P2PDebtMarketplace → DepositPool: ✅ `0x153bA726357a76e91f23b715E5d349cC96b799B6`
- SettlementManager → PropertyNFT: ✅ `0xBB09bD6461cE02aE0F5C093a733A00C1478c82A4`
- SettlementManager → DepositPool: ✅ `0x153bA726357a76e91f23b715E5d349cC96b799B6`
- SettlementManager → P2PDebtMarketplace: ✅ `0x06E8bf9a48b6692e633836ee87460139235A462E`

### Access Control Configuration ✅

Access control relationships have been properly configured:

- **SettlementManager** has `POOL_MANAGER_ROLE` in DepositPool: ✅
- **SettlementManager** has `MARKETPLACE_ADMIN_ROLE` in P2PDebtMarketplace: ✅

### Admin Roles

The deployer (`0x541070bECf02bdE10Fbd347bb7EedC8033609A48`) has admin roles on all contracts:

- **PropertyNFT**: `DEFAULT_ADMIN_ROLE`, `PROPERTY_VERIFIER_ROLE`
- **DepositPool**: `DEFAULT_ADMIN_ROLE`, `POOL_MANAGER_ROLE`
- **P2PDebtMarketplace**: `DEFAULT_ADMIN_ROLE`, `MARKETPLACE_ADMIN_ROLE`
- **SettlementManager**: `DEFAULT_ADMIN_ROLE`, `SETTLEMENT_MANAGER_ROLE`

## Contract Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   PropertyNFT   │────│   DepositPool   │────│P2PDebtMarketplace│
│                 │    │                 │    │                 │
│ - Property NFTs │    │ - KRW/cKRW      │    │ - Debt Trading  │
│ - Status Track. │    │ - Yield Optim.  │    │ - Interest Calc.│
│ - Verification  │    │ - Distribution  │    │ - Liquidation   │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         └───────────────────────┼───────────────────────┘
                                 │
                    ┌─────────────────┐
                    │SettlementManager│
                    │                 │
                    │ - Monitoring    │
                    │ - Grace Period  │
                    │ - Batch Process │
                    │ - Auto Escalate │
                    └─────────────────┘
```

## Gas Usage Summary

All contracts have been deployed with optimizer enabled:

- **PropertyNFT**: ~2.3M gas
- **DepositPool**: ~1.8M gas  
- **P2PDebtMarketplace**: ~2.3M gas
- **SettlementManager**: ~4.3M gas

**Total Deployment Cost**: ~10.7M gas

## Usage Instructions

### 1. Property Registration

```solidity
// PropertyNFT contract
function mintProperty(
    address landlord,
    DistributionChoice distributionChoice,
    uint256 depositAmount,
    uint256 monthlyRent,
    string calldata propertyURI
) external returns (uint256)
```

### 2. Deposit Submission

```solidity
// DepositPool contract
function submitDeposit(
    uint256 propertyTokenId,
    uint256 krwAmount
) external
```

### 3. Settlement Management

```solidity
// SettlementManager contract
function registerContract(
    uint256 propertyTokenId,
    address tenant,
    uint256 contractEndTime,
    bool autoProcessing
) external
```

### 4. P2P Debt Trading

```solidity
// P2PDebtMarketplace contract
function purchaseDebtClaim(uint256 claimId) external
```

## Important Notes

⚠️ **Mock KRW Token**: The current deployment uses a mock KRW token address. For production, this should be replaced with the actual KRW stablecoin contract.

⚠️ **Testnet Only**: These contracts are deployed on Kaia Testnet for testing purposes only.

⚠️ **Admin Keys**: The deployer currently holds admin privileges on all contracts. For production, consider using a multi-sig wallet or DAO governance.

## Next Steps

1. ✅ Contract deployment completed
2. ✅ Access control configured
3. ✅ Integration verified
4. 🔄 Integration testing with frontend
5. 🔄 Comprehensive test suite
6. 🔄 Security audit preparation
7. 🔄 Mainnet deployment planning

## Files

- **Deployment Script**: `script/Deploy.s.sol`
- **Configuration**: `foundry.toml`
- **Addresses**: `deployments/kaia_testnet.json`
- **Environment**: `.env` (private)