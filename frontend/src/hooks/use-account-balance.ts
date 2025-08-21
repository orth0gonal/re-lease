'use client'

import { useAccount, useBalance } from 'wagmi'
import { formatEther } from 'viem'

export function useAccountBalance() {
  const { address, isConnected } = useAccount()
  const { data: balance, isLoading, refetch } = useBalance({
    address,
  })

  const formatBalance = (decimals: number = 4) => {
    if (!balance) return '0'
    return parseFloat(formatEther(balance.value)).toFixed(decimals)
  }

  const balanceInEther = balance ? formatEther(balance.value) : '0'

  return {
    address,
    isConnected,
    balance,
    balanceInEther,
    formatBalance,
    isLoading,
    refetch,
    symbol: balance?.symbol || 'KLAY',
  }
}