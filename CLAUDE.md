# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## About re:Lease Platform

re:Lease is a blockchain-based Jeonse (전세) deposit protection platform that fundamentally solves the Korean Jeonse fraud problem through automated debt-credit relationship establishment and tokenization.

### Platform Name Meaning

re:Lease: Combines 'Re (Again, New)' and 'Lease', meaning redefining the rental system
Double meaning of 'Release': Unlocking landlords' tied assets and releasing tenants' anxiety

### Core Problem Solved

Korean Jeonse fraud has become a serious social issue with:
- 4.5 trillion KRW in guarantee insurance accidents in 2024 (7x increase from 2021)
- Over 30,400 confirmed fraud victims as of May 2025
- Organized fraud schemes involving brokers, fake landlords, and trust companies

### Solution Architecture

1. KRW Stablecoin Integration
- Primary Currency: Uses KRWC (Korean Won stablecoin) for all Jeonse deposits
- Smart Contract Automation: All transactions and conditions automated through blockchain
- Transparency: Real-time tracking of fund flows and contract states on-chain

2. Deposit Tokenization System
- yKRWC Token: ERC-4626 based yield-bearing token that increases in value over time
- Deposit Pool: Central vault where all KRWC deposits are pooled and managed
- Asset Management: Pool funds invested in safe assets (government bonds, AAA-grade bonds, stablecoin protocols) generating 3-5% annual returns
- Revenue Distribution: 70% to yKRWC holders, 20% platform fees, 10% risk buffer

3. Guaranteed Return Mechanism
- Automatic Conversion: If landlord fails to return deposit, contract automatically converts to debt-credit relationship
- Assignee System: Assignees can purchase the debt, immediately returning deposit to tenant
- Legal Integration: Smart contracts integrated with legal proceedings for property foreclosure if needed

### Key Stakeholders

1. Tenant (임차인)
- Benefits: Guaranteed deposit safety, transparent fund tracking, legal interest protection
- Process: Deposits KRWC → Receives protection through smart contract and assignee system

2. Landlord (임대인)
- Benefits: Immediate liquidity through yKRWC trading, yield earnings from holding, potential tax benefits
- Options:
- - Option 1: Sell yKRWC for immediate cash
- - Option 2: Hold yKRWC to earn yield while maintaining principal

3. Assignee (채권양수인)
- Benefits: Stable investment with real estate collateral, higher returns than traditional insurance
- Protection: Priority in debt recovery under Korean Housing Lease Protection Act

4. Verifier (운영사)
- Role: Deposit pool management, property verification, smart contract operations
- Revenue: Pool management fees, transaction fees, premium services

### Process Flow

#### 1. Contract Initiation

1. Tenant deposits KRWC into smart contract
2. Smart contract deposits KRWC into deposit pool
3. Pool issues yKRWC tokens to landlord
4. Landlord chooses to hold (earn yield) or sell (get liquidity)

#### 2. During Contract Period

1. yKRWC value increases automatically through pool yield generation
2. All parties can track contract status on blockchain
3. No intermediary involvement required

#### 3. Contract Maturity

1. Within 1-day grace period:
- If landlord has yKRWC: Converts to KRWC, returns deposit to tenant, keeps yield
- If landlord sold yKRWC: Must deposit KRWC directly to return to tenant

2. After grace period (Default):
- Automatic debt-credit relationship establishment
- Assignee can purchase debt, immediately protecting tenant
- Landlord owes principal + 5% annual interest to assignee

#### 4. Debt Recovery
- Assignee earns interest from landlord
- If long-term default: Legal proceedings for property foreclosure
- Smart contract integrates with legal resolution for final settlement

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
- **Web3 Integration**: RainbowKit + Wagmi for wallet connectivity
- **UI Components**: Shadcn UI primitives with Tailwind CSS
- **Styling**: Tailwind CSS with CSS custom properties and dark mode
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

## Key Innovations

### 1. Fraud Prevention Mechanisms

- 깡통전세 (Underwater Jeonse): Pre-verification of property value and LTV limits
- Fake Landlords: On-chain verification with government registry
- Trust Company Fraud: Automatic trust authority verification
- Double Contracts: Blockchain prevents duplicate contracts on same property
- Loan Execution Fraud: Financial authority integration for loan detection

### 2. Economic Sustainability

- Revenue Sources: Pool management fees (1% annual), transaction fees (0.5%), premium services
- Market Size: Targeting 0.1% of 400 trillion KRW Korean Jeonse market
- Expansion: Extensible to monthly rent, commercial real estate, international markets

### 3. Technical Advantages

- Automatic Execution: Smart contracts eliminate manual intervention
- Transparency: All transactions visible on blockchain
- Composability: Integration with other DeFi protocols
- Scalability: KAIA's high TPS supports mass adoption