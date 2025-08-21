# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## About re:Lease Platform

**re:Lease** is a KRW stablecoin-powered smart contract platform for Korean Jeonse (전세) rental agreements, developed for the KAIA blockchain hackathon.

### Core Concept
- **KRW Stablecoin Integration**: Uses KRW-C (Korean Won stablecoin) as the primary payment method for Jeonse deposits, eliminating volatility risks through smart contract automation
- **Tokenization Structure**: Converts deposited KRW-C into Principal Tokens (PT) and Yield Tokens (YT) to provide landlords with liquidity and yield opportunities  
- **Automated Debt Recovery**: When landlords fail to return deposits, the system automatically creates creditor-debtor relationships with assignees who ensure tenant protection while earning interest income

### Key Stakeholders
- **Tenant (임차인)**: Renter who deposits KRW-C as Jeonse security deposit
- **Landlord (임대인)**: Property owner who receives PT/YT tokens and can trade them for liquidity
- **Assignee (채권양수인)**: Investor who purchases defaulted deposits as debt assets, earning interest while protecting tenants
- **Verifier (검증자)**: Authorized entity that validates property authenticity and contract legitimacy

### Process Flow

#### 1. Contract Initiation
1. **Property Registration**: Landlord registers property as NFT (ERC-721) with PropertyNFT contract
2. **Verification**: Verifier validates property authenticity and calls `PropertyNFT.verifyProperty(propertyId)`
3. **Contract Creation**: Landlord creates rental contract with tenant details and deposit amount
4. **Contract Verification**: Verifier approves the rental contract terms

#### 2. Deposit & Tokenization  
1. **Deposit Submission**: Tenant deposits KRW-C into DepositPool smart contract
2. **Token Generation**: System mints Principal Token (PT) and Yield Token (YT) for landlord
   - **PT**: Represents deposit principal (e.g., 200M KRW-C)
   - **YT**: Represents yield rights from deposit fund management (e.g., 3% annual)
3. **Fund Management**: DepositPool invests KRW-C in safe assets (government bonds, AAA-grade bonds)
4. **Landlord Options**:
   - Sell PT for immediate liquidity
   - Hold PT + sell YT for partial liquidity
   - Hold both PT + YT for maximum long-term returns

#### 3. Contract Maturity
- **Normal Return**: Landlord returns PT to contract → KRW-C returned to tenant → contract closed
- **Default Scenario**: If landlord cannot return PT → automatic debt-credit relationship activation

#### 4. Debt Recovery Process
1. **Assignee Intervention**: Assignee purchases the defaulted deposit claim
2. **Immediate Protection**: Assignee pays KRW-C to tenant, ensuring deposit return
3. **Debt Creation**: Landlord becomes debtor to assignee with legal interest rate (5% annual)
4. **Long-term Recovery**: If payment fails, assignee initiates legal proceedings (foreclosure, auction) according to Korean law
5. **Legal Integration**: Smart contract integrates with legal proceeding results through authorized updates
6. **Settlement**: Upon legal resolution, verified settlement data is input to smart contract for final distribution
   - Assignee receives principal + accumulated interest
   - Remaining proceeds (if any) are returned to landlord
   - All transactions are recorded on-chain for transparency

## Project Structure

This is a monorepo containing a React frontend and Foundry-based smart contracts:

- `frontend/` - Next.js 15 frontend application with React 19
- `contracts/` - Solidity smart contracts using Foundry framework

## Development Commands

### Frontend (Next.js App)
Navigate to `frontend/` directory for all frontend commands:

```bash
cd frontend
npm install          # Install dependencies
npm run dev         # Run development server with Turbopack (localhost:3000)
npm run build       # Build for production
npm start           # Start production server
npm run lint        # Run ESLint
```

### Smart Contracts (Foundry)
Navigate to `contracts/` directory for all contract commands:

```bash
cd contracts
forge build         # Compile contracts
forge test          # Run all tests
forge test --match-test <test_name>  # Run specific test
forge fmt           # Format Solidity code
forge snapshot      # Generate gas usage snapshots
anvil               # Start local Ethereum node
```

## Architecture Overview

### Frontend Architecture
- **Next.js 15** with React 19 and TypeScript
- **App Router** structure (`src/app/` directory)
- **Web3 Integration**: RainbowKit + Wagmi for wallet connectivity
- **UI Components**: Radix UI primitives with Tailwind CSS
- **Styling**: Tailwind CSS with CSS custom properties and dark mode
- **State Management**: TanStack Query for server state
- **Theme System**: next-themes with custom component theming
- **Blockchain**: Kaia network integration with balance tracking

### Smart Contract Architecture
- Foundry-based Solidity development environment
- Standard contract structure in `contracts/src/`
- Test contracts in `contracts/test/`
- Deployment scripts in `contracts/script/`
- Uses forge-std library for testing utilities

### Integration Points
This is a Web3 application where:
- **Frontend-Blockchain**: Wagmi + Viem for Ethereum/Kaia network interactions
- **Wallet Integration**: RainbowKit provides multi-wallet connectivity
- **Smart Contract Interaction**: Type-safe contract interactions with Wagmi
- **Network Support**: Configured for Kaia blockchain network
- **Deployment**: Frontend deploys to Vercel, contracts to Ethereum-compatible networks

## Development Workflow

1. **Frontend Development**: Work in `frontend/` directory using Next.js App Router patterns
2. **Contract Development**: Work in `contracts/` directory using Foundry workflows  
3. **Web3 Integration**: Use Wagmi hooks and RainbowKit components for blockchain interactions
4. **Styling**: Use Tailwind CSS classes with custom CSS properties for theming
5. **Local Development**: Use `npm run dev` for frontend with Turbopack, `anvil` for local blockchain