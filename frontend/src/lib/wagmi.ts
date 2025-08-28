import { getDefaultConfig } from '@rainbow-me/rainbowkit'
import { kaiaTestnet } from './kaia'
// import { kaiaMainnet } from './kaia' // Temporarily disabled

export const wagmiConfig = getDefaultConfig({
  appName: 're:Lease',
  projectId: process.env.NEXT_PUBLIC_WALLET_CONNECT_PROJECT_ID || 'temp-dev-id',
  chains: [kaiaTestnet], // Only Kairos testnet for now, mainnet will be added later
  ssr: true,
})

export default wagmiConfig