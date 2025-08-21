# re:Lease Frontend

A revolutionary digital asset management platform built on the Kaia blockchain using Next.js, TypeScript, and cutting-edge Web3 technologies.

## 🚀 Tech Stack

- **Next.js 15** - React framework with App Router
- **TypeScript** - Type safety throughout
- **Tailwind CSS** - Utility-first styling
- **Shadcn UI** - Modern, accessible component library
- **Wagmi v2** - React hooks for Ethereum/EVM chains
- **Viem** - TypeScript interface for blockchain interactions
- **RainbowKit** - Wallet connection interface
- **Kaia Blockchain** - EVM-compatible Layer 1 blockchain

## 🌟 Features

- ✅ **Digital Asset Management** - Revolutionary approach to asset control
- ✅ **Wallet Integration** - Connect with popular Web3 wallets
- ✅ **Kaia Network Support** - Mainnet and testnet configurations
- ✅ **Real-time Balance Display** - Live KAIA balance updates
- ✅ **Network Switching** - Seamless network detection and switching
- ✅ **Dark/Light Theme** - System-aware theme switching
- ✅ **Responsive Design** - Mobile-first responsive interface
- ✅ **TypeScript** - Full type safety and autocompletion

## 🎨 Brand Identity

### Logo Design
The re:Lease logo combines:
- **Circular Network**: Representing blockchain connectivity
- **Stylized "R"**: Core brand element with modern typography
- **Release Arrow**: Symbolizing the freedom and flow of digital assets
- **Network Nodes**: Dots representing decentralized connections
- **Color Scheme**: Primary accent (#00D9FF) with neutral support colors

### Typography
- **Brand Name**: `re:Lease` with colon separator
- **Font**: Inter with custom weight and spacing
- **Style**: Modern, tech-forward, professional

## 🏗️ Project Structure

```
src/
├── app/                    # Next.js App Router
│   ├── globals.css        # Global styles with Tailwind
│   ├── layout.tsx         # Root layout with providers
│   └── page.tsx           # Homepage
├── components/
│   ├── ui/                # Shadcn UI + Logo components
│   ├── wallet/            # Wallet-specific components
│   └── theme-toggle.tsx   # Theme switcher
├── hooks/                 # Custom React hooks
│   ├── use-kaia-network.ts
│   └── use-account-balance.ts
├── lib/                   # Utility libraries
│   ├── wagmi.ts           # Wagmi configuration
│   ├── kaia.ts            # Kaia chain definitions
│   ├── utils.ts           # Shadcn utilities
│   └── format.ts          # Formatting helpers
└── providers/             # React context providers
    ├── web3-provider.tsx
    └── theme-provider.tsx
```

## 🚀 Getting Started

### Prerequisites

- Node.js 18+ and npm/yarn/pnpm
- A WalletConnect Project ID (optional but recommended)

### Installation

1. **Navigate to frontend directory:**
   ```bash
   cd frontend
   ```

2. **Install dependencies:**
   ```bash
   npm install
   ```

3. **Set up environment variables:**
   ```bash
   cp .env.local.example .env.local
   ```
   
   Edit `.env.local` and add your WalletConnect Project ID:
   ```
   NEXT_PUBLIC_WALLET_CONNECT_PROJECT_ID=your_project_id_here
   ```

4. **Start development server:**
   ```bash
   npm run dev
   ```

5. **Open your browser:**
   ```
   http://localhost:3000
   ```

## 🔧 Configuration

### Kaia Network Setup

The app is pre-configured for both Kaia networks:

- **Mainnet**: Chain ID 8217
- **Testnet**: Chain ID 1001

Network configurations are in `src/lib/kaia.ts`.

### Wallet Configuration

Supported wallets include:
- MetaMask
- WalletConnect
- Coinbase Wallet
- And many more via RainbowKit

## 🎨 UI Components

Built with Shadcn UI components:
- `Button` - Interactive buttons with variants
- `Card` - Content containers
- `Dialog` - Modal dialogs
- `Logo` - Custom re:Lease branding
- Plus easy addition of more components via CLI

Add new components:
```bash
npx shadcn@latest add [component-name]
```

## 🔗 Web3 Integration

### Key Hooks

- `useAccount()` - Wallet connection status
- `useBalance()` - Token balance queries
- `useKaiaNetwork()` - Custom Kaia network utilities
- `useAccountBalance()` - Formatted balance display

### Example Usage

```tsx
import { useAccount } from 'wagmi'
import { useKaiaNetwork } from '@/hooks/use-kaia-network'

function MyComponent() {
  const { isConnected } = useAccount()
  const { isKaiaNetwork, switchToKaiaMainnet } = useKaiaNetwork()

  if (!isConnected) {
    return <div>Please connect your wallet</div>
  }

  if (!isKaiaNetwork) {
    return (
      <button onClick={switchToKaiaMainnet}>
        Switch to Kaia Network
      </button>
    )
  }

  return <div>Connected to Kaia!</div>
}
```

## 📱 Responsive Design

Mobile-first approach with breakpoints:
- `sm`: 640px+
- `md`: 768px+
- `lg`: 1024px+
- `xl`: 1280px+
- `2xl`: 1536px+

## 🛠️ Development

### Available Scripts

```bash
npm run dev          # Start development server
npm run build        # Build for production
npm run start        # Start production server
npm run lint         # Run ESLint
```

### Adding Features

1. **New UI Components:**
   ```bash
   npx shadcn@latest add [component]
   ```

2. **Custom Hooks:**
   - Add to `src/hooks/`
   - Follow the `use-` naming convention

3. **Blockchain Interactions:**
   - Use Wagmi hooks for Web3 operations
   - Add custom utilities to `src/lib/`

## 🌐 Deployment

### Vercel (Recommended)

1. Push to GitHub
2. Connect to Vercel
3. Set environment variables
4. Deploy

### Other Platforms

Build and deploy the `out` directory:
```bash
npm run build
npm run start
```

## 🔒 Security

- Environment variables for sensitive data
- Input validation for addresses
- Network verification before transactions
- No private keys stored in frontend

## 📚 Learn More

- [Kaia Documentation](https://docs.kaia.io/)
- [Wagmi Documentation](https://wagmi.sh/)
- [RainbowKit Documentation](https://rainbowkit.com/)
- [Next.js Documentation](https://nextjs.org/docs)
- [Shadcn UI Documentation](https://ui.shadcn.com/)

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Submit a pull request

## 📄 License

[MIT License](LICENSE)