'use client'

import { useState, useEffect } from 'react'
import { useAccount, useWriteContract, useWaitForTransactionReceipt } from 'wagmi'
import { parseUnits } from 'viem'
import { useConnectModal } from '@rainbow-me/rainbowkit'
import { useGlobalToast } from '@/hooks/use-global-toast'
import { GlobalModal } from '@/components/ui/global-modal'
import { Button } from '@/components/ui/button'
import { ExternalLink, Loader2, Droplets, Coins } from 'lucide-react'
import { CONTRACTS } from '@/lib/constants'
import { KRWTokenABI } from '@/lib/abis/KRWToken'

interface FaucetModalProps {
  open: boolean
  onOpenChange: (open: boolean) => void
}

export function FaucetModal({ open, onOpenChange }: FaucetModalProps) {
  const { address, isConnected } = useAccount()
  const { openConnectModal } = useConnectModal()
  const toast = useGlobalToast()
  const [isConnecting, setIsConnecting] = useState(false)

  const { 
    writeContract, 
    data: hash, 
    isPending, 
    error 
  } = useWriteContract()

  const { isLoading: isConfirming, isSuccess, error: receiptError } = useWaitForTransactionReceipt({
    hash,
  })

  const handleOpenChange = (newOpen: boolean) => {
    // Prevent closing during wallet connection
    if (isConnecting && !newOpen) {
      return
    }
    onOpenChange(newOpen)
  }

  const handleConnectWallet = async () => {
    if (!openConnectModal) return

    setIsConnecting(true)
    try {
      openConnectModal()
    } catch (error) {
      console.error('Failed to open connect modal:', error)
      toast.error('Connection Failed', 'Failed to open wallet connection')
    }
    
    // Reset connecting state after a delay
    setTimeout(() => {
      setIsConnecting(false)
    }, 2000)
  }

  const handleKaiaFaucet = () => {
    window.open('https://www.kaia.io/faucet', '_blank')
  }

  const handleKrwcMint = async () => {
    if (!isConnected || !address) {
      handleConnectWallet()
      return
    }

    try {
      // Mint 1000 KRWC (with 18 decimals)
      await writeContract({
        address: CONTRACTS.KRWTOKEN,
        abi: KRWTokenABI,
        functionName: 'mint',
        args: [address, parseUnits('1000', 18)],
      })
    } catch (error) {
      console.error('KRWC mint error:', error)
      
      // Handle different types of errors - check for user rejection
      const errorObj = error as Record<string, unknown>
      const message = typeof errorObj?.message === 'string' ? errorObj.message : ''
      
      const isUserRejection = message.toLowerCase().includes('denied')
      
      if (isUserRejection) {
        toast.error('Transaction Rejected', 'Transaction was rejected by user')
      } else {
        toast.error('Mint Failed', 'Failed to mint KRWC tokens')
      }
    }
  }

  // Handle successful transaction
  useEffect(() => {
    if (isSuccess && hash) {
      toast.success('Mint Successful', 'Successfully minted 1000 KRWC tokens!')
      
      // Close modal after showing toast
      setTimeout(() => {
        onOpenChange(false)
      }, 1000)
    }
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [isSuccess, hash, onOpenChange])

  // Handle wagmi error state
  useEffect(() => {
    if (error) {
      // Handle different types of errors - check for user rejection
      const errorObj = error as Record<string, unknown>
      const message = typeof errorObj?.message === 'string' ? errorObj.message : ''
      
      const isUserRejection = message.toLowerCase().includes('denied')
      
      if (isUserRejection) {
        toast.error('Transaction Rejected', 'Transaction was rejected by user')
      } else {
        toast.error('Transaction Failed', 'Transaction failed')
      }
    }
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [error])

  useEffect(() => {
    if (receiptError) {
      toast.error('Confirmation Failed', 'Transaction confirmation failed')
    }
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [receiptError])

  return (
    <GlobalModal
      open={open}
      onOpenChange={handleOpenChange}
      title="Faucet"
      size="sm"
    >
      <div className="space-y-4">
        {/* Horizontal Faucet Buttons */}
        <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
          {/* KAIA Faucet Button */}
          <Button
            onClick={handleKaiaFaucet}
            variant="outline"
            className="h-auto p-3 flex items-center justify-start space-x-3 min-h-[80px]"
          >
            <Droplets className="w-5 h-5 text-blue-500 flex-shrink-0" />
            <div className="flex-1 text-left min-w-0">
              <div className="font-medium flex items-center gap-2 text-sm">
                <span className="truncate">KAIA Faucet</span>
                <ExternalLink className="w-3 h-3 opacity-60 flex-shrink-0" />
              </div>
              <div className="text-xs text-muted-foreground mt-1 break-words">
                Get KAIA tokens
              </div>
            </div>
          </Button>

          {/* KRWC Faucet Button */}
          <Button
            onClick={handleKrwcMint}
            variant="outline"
            className="h-auto p-3 flex items-center justify-start space-x-3 min-h-[80px]"
            disabled={isPending || isConfirming}
          >
            {isPending || isConfirming ? (
              <Loader2 className="w-5 h-5 text-green-500 animate-spin flex-shrink-0" />
            ) : (
              <Coins className="w-5 h-5 text-green-500 flex-shrink-0" />
            )}
            <div className="flex-1 text-left min-w-0">
              <div className="font-medium text-sm">
                <span className="truncate block">
                  KRWC Faucet
                </span>
              </div>
              <div className="text-xs text-muted-foreground mt-1 break-words">
                {isPending || isConfirming 
                  ? 'Processing...'
                  : 'Mint 1,000 KRWC'
                }
              </div>
            </div>
          </Button>
        </div>

        {/* Wallet Connection Notice */}
        {!isConnected && (
          <div className="mt-4 p-3 bg-muted/50 rounded-lg border border-dashed">
            <p className="text-sm text-muted-foreground text-center">
              Connect your wallet to mint KRWC tokens
            </p>
          </div>
        )}
      </div>
    </GlobalModal>
  )
}