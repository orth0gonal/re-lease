## Re-lease Smart Contract

Re-lease smart contract에 대한 자세한 문서는 [docs.md](docs.md)를 참고

## Usage

### Build

```shell
$ forge build
```

### Deploy Contracts

```shell
$ forge script script/Deploy.s.sol:Deploy --broadcast --legacy --slow --rpc-url kaia_testnet --private-key $DEPLOYER_PRIVATE_KEY -vvv
```

### Mint KRWC token

```shell
$ forge script script/MintKRWC.s.sol:MintKRWC --broadcast --legacy --slow --rpc-url kaia_testnet --private-key $DEPLOYER_PRIVATE_KEY -vvv
```

### Initial Settings

```shell
cast send <KRWCToken> "transfer(address,uint256)()" <DepositPool> <KRWCAmount> --rpc-url kaia_testnet --private-key $DEPLOYER_PRIVATE_KEY -vvv
```

### Test

#### Run All Tests

```shell
$ forge test
```

#### Unit Tests
```shell
$ forge test --match-contract PropertyNFTTest -v
$ forge test --match-contract DepositPoolTest -v
```

#### Integration Tests

##### Normal Settlement Process (정상 정산 프로세스)
```shell
# Run all normal settlement tests
$ forge test --match-path test/integration/NormalSettlement.t.sol -vv

# Test normal settlement with KRWC return
$ forge test --mt test_NormalSettlement_WithKRWC -vv

# Test normal settlement with yKRWC return
$ forge test --mt test_NormalSettlement_WithYKRWC -vv

# Test grace period boundary conditions
$ forge test --mt test_GracePeriod_BoundaryConditions -vv
```

##### Default and P2P Debt Trading Process (디폴트 및 P2P 거래 프로세스)
```shell
# Run all default and P2P trading tests
$ forge test --match-path test/integration/DefaultAndP2PTrading.t.sol -vv

# Test complete default lifecycle
$ forge test --mt test_CompleteDefaultLifecycle -vv

# Test P2P debt purchase flow
$ forge test --mt test_DebtPurchase_CompleteFlow -vv

# Test secondary market debt trading
$ forge test --mt test_SecondaryMarket_DebtTrading -vv

# Test interest accumulation
$ forge test --mt test_InterestAccumulation_OverTime -vv
```

##### Contract Expiration Process (계약 만료 프로세스)
```shell
# Run all contract expiration tests
$ forge test --match-path test/integration/ContractExpiration.t.sol -vv

# Test relationship transition (tenant-landlord to creditor-debtor)
$ forge test --mt test_RelationshipTransition_TenantToCreditor -vv

# Test timing boundary conditions
$ forge test --mt test_TimingBoundary_GracePeriodTransition -vv

# Test batch contract expiration
$ forge test --mt test_BatchExpiration_MultipleContracts -vv
```

##### Run All Integration Tests
```shell
# Run all integration tests with verbose output
$ forge test --match-path test/integration/ -vvv
```