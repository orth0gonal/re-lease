/**
 * Format KLAY amounts with proper decimals
 */
export function formatKlay(amount: string | number, decimals: number = 4): string {
  const num = typeof amount === 'string' ? parseFloat(amount) : amount
  if (isNaN(num)) return '0'
  return num.toFixed(decimals)
}

/**
 * Truncate wallet address for display
 */
export function truncateAddress(address: string, start: number = 6, end: number = 4): string {
  if (!address) return ''
  if (address.length <= start + end) return address
  return `${address.slice(0, start)}...${address.slice(-end)}`
}

/**
 * Generate block explorer URL for transaction or address
 */
export function getExplorerUrl(hash: string, type: 'tx' | 'address' = 'tx', isTestnet: boolean = false): string {
  const baseUrl = isTestnet 
    ? 'https://baobab.scope.klaytn.com'
    : 'https://scope.klaytn.com'
  
  return `${baseUrl}/${type}/${hash}`
}

/**
 * Validate Kaia address format
 */
export function validateKaiaAddress(address: string): boolean {
  const pattern = /^0x[a-fA-F0-9]{40}$/
  return pattern.test(address)
}

/**
 * Format large numbers with appropriate suffixes
 */
export function formatNumber(num: number): string {
  if (num >= 1e9) {
    return (num / 1e9).toFixed(2) + 'B'
  }
  if (num >= 1e6) {
    return (num / 1e6).toFixed(2) + 'M'
  }
  if (num >= 1e3) {
    return (num / 1e3).toFixed(2) + 'K'
  }
  return num.toString()
}