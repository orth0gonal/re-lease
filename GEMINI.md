# GEMINI.md

## Project Overview

This is a monorepo project that contains a React-based frontend and Foundry-based smart contracts.

- **Frontend**: The frontend is a React application located in the `app` directory. It was initialized with `create-react-app`.
- **Smart Contracts**: The smart contracts are developed using Foundry and are located in the `contracts` directory.

## Building and Running

### Frontend

To run the frontend application, navigate to the `app` directory and run:

```bash
npm install
npm start
```

To build the application for production, run:

```bash
npm run build
```

### Smart Contracts

To build the smart contracts, navigate to the `contracts` directory and run:

```bash
forge build
```

To run tests for the smart contracts, run:

```bash
forge test
```

## Deployment

This project is configured for deployment on Vercel. The `vercel.json` file in the root directory specifies the build configuration for the frontend application.