## Foundry

**Foundry is a blazing fast, portable and modular toolkit for Ethereum application development written in Rust.**

Foundry consists of:

-   **Forge**: Ethereum testing framework (like Truffle, Hardhat and DappTools).
-   **Cast**: Swiss army knife for interacting with EVM smart contracts, sending transactions and getting chain data.
-   **Anvil**: Local Ethereum node, akin to Ganache, Hardhat Network.
-   **Chisel**: Fast, utilitarian, and verbose solidity REPL.

## Documentation

https://book.getfoundry.sh/

## Usage

### Build

```shell
$ forge build
```

### Deploy

```shell
$ forge script script/Deploy.s.sol:Deploy --broadcast --legacy --slow --rpc-url kaia_testnet --private-key $DEPLOYER_PRIVATE_KEY -vvv
```

### Mint KRWC

```shell
$ forge script script/MintKRWC.s.sol:MintKRWC --broadcast --legacy --slow --rpc-url kaia_testnet --private-key $DEPLOYER_PRIVATE_KEY -vvv
```

### Initial Settings

```shell
cast send <KRWCToken> "transfer(address,uint256)()" <DepositPool> <KRWCAmount> --rpc-url kaia_testnet --private-key $DEPLOYER_PRIVATE_KEY -vvv
```

### Test

#### Unit Tests
```shell
# Run all tests
$ forge test

# Run unit tests
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

# Run all integration tests with gas report
$ forge test --match-path test/integration/ --gas-report
```