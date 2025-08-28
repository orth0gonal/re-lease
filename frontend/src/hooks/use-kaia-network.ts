'use client'

import { useAccount, useChainId, useSwitchChain } from 'wagmi'
import { kaiaMainnet, kaiaTestnet } from '@/lib/kaia'

export function useKaiaNetwork() {
  const { isConnected } = useAccount()
  const chainId = useChainId()
  const { switchChain, isPending } = useSwitchChain()

  // Currently only supporting Kairos testnet
  const isKaiaNetwork = chainId === kaiaTestnet.id
  const isMainnet = false // Mainnet support disabled temporarily
  const isTestnet = chainId === kaiaTestnet.id

  const switchToKaiaMainnet = () => {
    // Mainnet support temporarily disabled
    console.warn('Mainnet support is temporarily disabled')
  }

  const switchToKaiaTestnet = () => {
    switchChain({ chainId: kaiaTestnet.id })
  }

  const getCurrentNetwork = () => {
    // Currently only supporting Kairos testnet
    if (chainId === kaiaTestnet.id) return kaiaTestnet
    return null // Mainnet and other networks not supported currently
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