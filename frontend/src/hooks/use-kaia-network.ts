'use client'

import { useAccount, useChainId, useSwitchChain } from 'wagmi'
import { kaiaMainnet, kaiaTestnet } from '@/lib/kaia'

export function useKaiaNetwork() {
  const { isConnected } = useAccount()
  const chainId = useChainId()
  const { switchChain, isPending } = useSwitchChain()

  const isKaiaNetwork = chainId === kaiaMainnet.id || chainId === kaiaTestnet.id
  const isMainnet = chainId === kaiaMainnet.id
  const isTestnet = chainId === kaiaTestnet.id

  const switchToKaiaMainnet = () => {
    switchChain({ chainId: kaiaMainnet.id })
  }

  const switchToKaiaTestnet = () => {
    switchChain({ chainId: kaiaTestnet.id })
  }

  const getCurrentNetwork = () => {
    if (chainId === kaiaMainnet.id) return kaiaMainnet
    if (chainId === kaiaTestnet.id) return kaiaTestnet
    return null
  }

  return {
    isConnected,
    chainId,
    isKaiaNetwork,
    isMainnet,
    isTestnet,
    switchToKaiaMainnet,
    switchToKaiaTestnet,
    getCurrentNetwork,
    isSwitching: isPending,
  }
}