import { defineChain } from 'viem'

export const kaiaMainnet = defineChain({
  id: 8217,
  name: 'Kaia Mainnet',
  nativeCurrency: {
    decimals: 18,
    name: 'KAIA',
    symbol: 'KAIA',
  },
  rpcUrls: {
    default: {
      http: ['https://public-en.node.kaia.io'],
    },
  },
  blockExplorers: {
    default: {
      name: 'Kaiascan',
      url: 'https://kaiascan.io/',
    },
  },
  contracts: {
    multicall3: {
      address: '0x5f5f0d1b9ff8b3dcace308e39b13b203354906e9',
      blockCreated: 91582357,
    },
  },
})

export const kaiaTestnet = defineChain({
  id: 1001,
  name: 'Kaia Testnet',
  nativeCurrency: {
    decimals: 18,
    name: 'KAIA',
    symbol: 'KAIA',
  },
  rpcUrls: {
    default: {
      http: ['https://public-en-kairos.node.kaia.io'],
    },
  },
  blockExplorers: {
    default: {
      name: 'Kaiascan Testnet',
      url: 'https://kairos.kaiascan.io/',
    },
  },
  contracts: {
    multicall3: {
      address: '0x40643b8aeaaca0b87ea1a1e596e64a0e14b1d244',
      blockCreated: 87232478,
    },
  },
  testnet: true,
})

export const supportedChains = [kaiaMainnet, kaiaTestnet] as const