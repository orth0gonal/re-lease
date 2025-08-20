# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Structure

This is a monorepo containing a React frontend and Foundry-based smart contracts:

- `app/` - React frontend application (Create React App)
- `contracts/` - Solidity smart contracts using Foundry framework
- `vercel.json` - Deployment configuration for Vercel

## Development Commands

### Frontend (React App)
Navigate to `app/` directory for all frontend commands:

```bash
cd app
npm install          # Install dependencies
npm start           # Run development server (localhost:3000)
npm test            # Run tests in watch mode
npm run build       # Build for production
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

### Deployment
The project is configured for Vercel deployment. The frontend builds are automatically handled via the `vercel.json` configuration which points to the React app's build output.

## Architecture Overview

### Frontend Architecture
- Standard Create React App structure with React 19
- Component-based architecture using functional components
- Testing setup with React Testing Library and Jest
- Standard React development patterns and hooks

### Smart Contract Architecture
- Foundry-based Solidity development environment
- Standard contract structure in `contracts/src/`
- Test contracts in `contracts/test/`
- Deployment scripts in `contracts/script/`
- Uses forge-std library for testing utilities

### Integration Points
This appears to be a Web3 application where:
- The React frontend likely interacts with the smart contracts
- Smart contracts provide the blockchain/decentralized functionality
- Vercel handles frontend deployment while contracts deploy to Ethereum networks

## Development Workflow

1. **Frontend Development**: Work in `app/` directory using standard React patterns
2. **Contract Development**: Work in `contracts/` directory using Foundry workflows
3. **Testing**: Both environments have their own testing frameworks (Jest for React, Forge for Solidity)
4. **Local Development**: Use `npm start` for frontend and `anvil` for local blockchain if needed