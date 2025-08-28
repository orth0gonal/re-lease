// Re-lease Smart Contract Addresses on Kaia Testnet (Kairos)
export const CONTRACTS = {
  KRWTOKEN: '0xd3E4A72238F9BcB75BfFF82B35c243605FabE6d9' as `0x${string}`,
  PROPERTY_NFT: '0xEA9C6002471aA57f1BaE0B6F6F2e49c0e1E83663' as `0x${string}`,
  DEPOSIT_POOL: '0xb41fa057FA4890A12F0eA8a8Cf1C2F02e1E3B171' as `0x${string}`,
} as const

// Fixed Trust Authority Address
export const TRUST_AUTHORITY_ADDRESS = '0x542e4610B63FcEDeF7e645dd12D1f7Ddf3d1E64E' as `0x${string}`

// Network Configuration
export const NETWORK_CONFIG = {
  chainId: 1001, // Kaia Testnet (Kairos)
  chainName: 'Kairos Testnet', 
  rpcUrl: 'https://public-en-kairos.node.kaia.io',
  blockExplorer: 'https://kairos.kaiascan.io',
} as const