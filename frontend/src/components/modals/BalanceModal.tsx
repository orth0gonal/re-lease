'use client'

import { useAccount, useReadContract, useBalance } from 'wagmi'
import { formatUnits } from 'viem'
import { GlobalModal } from '@/components/ui/global-modal'
import { Wallet, Coins } from 'lucide-react'
import { CONTRACTS } from '@/lib/constants'
import { KRWTokenABI } from '@/lib/abis/KRWToken'

interface BalanceModalProps {
  open: boolean
  onOpenChange: (open: boolean) => void
}

export function BalanceModal({ open, onOpenChange }: BalanceModalProps) {
  const { address } = useAccount()
  

  // Read native KAIA balance
  const { data: kaiaBalance, isLoading: isLoadingKaia } = useBalance({
    address,
    query: {
      enabled: !!address && open, // Only fetch when modal is open
      refetchOnWindowFocus: false, // Prevent refetch on window focus
    },
  })

  // Read KRWC token balance
  const { data: krwcBalance, isLoading: isLoadingKrwc, error: krwcError } = useReadContract({
    address: CONTRACTS.KRWTOKEN,
    abi: KRWTokenABI,
    functionName: 'balanceOf',
    args: address ? [address] : undefined,
    query: {
      enabled: !!address && open,
      refetchOnWindowFocus: false,
    },
  })

  const formattedKaiaBalance = kaiaBalance ? 
    parseFloat(formatUnits(kaiaBalance.value, 18)).toFixed(4) : 
    '0.0000'

  const formattedKrwcBalance = (() => {
    if (krwcError) {
      console.error('KRWC balance error:', krwcError)
      return 'Error'
    }
    if (!krwcBalance) {
      return '0.00'
    }
    
    try {
      const formatted = formatUnits(krwcBalance, 18)
      const parsed = parseFloat(formatted)
      return parsed.toFixed(2)
    } catch (error) {
      console.error('KRWC balance formatting error:', error)
      return 'Error'
    }
  })()

  return (
    <GlobalModal
      open={open}
      onOpenChange={onOpenChange}
      title="Token Balances"
      description="View your current token balances"
      size="sm"
    >
      <div className="space-y-4">
        {/* KAIA Balance */}
        <div className="flex items-center justify-between p-4 bg-muted/30 border border-input rounded-lg">
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 rounded-full bg-blue-100 dark:bg-blue-900/30 flex items-center justify-center">
              <Wallet className="w-5 h-5 text-blue-600 dark:text-blue-400" />
            </div>
            <div>
              <div className="font-medium">KAIA</div>
              <div className="text-sm text-muted-foreground">Native Token</div>
            </div>
          </div>
          <div className="text-right">
            <div className="font-medium">
              {!address ? (
                <span className="text-muted-foreground">Connect wallet</span>
              ) : isLoadingKaia ? (
                <span className="text-muted-foreground">Loading...</span>
              ) : (
                <span>{formattedKaiaBalance}</span>
              )}
            </div>
            <div className="text-sm text-muted-foreground">KAIA</div>
          </div>
        </div>

        {/* KRWC Balance */}
        <div className="flex items-center justify-between p-4 bg-muted/30 border border-input rounded-lg">
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 rounded-full bg-green-100 dark:bg-green-900/30 flex items-center justify-center">
              <Coins className="w-5 h-5 text-green-600 dark:text-green-400" />
            </div>
            <div>
              <div className="font-medium">KRWC</div>
              <div className="text-sm text-muted-foreground">Korean Won Coin</div>
            </div>
          </div>
          <div className="text-right">
            <div className="font-medium">
              {!address ? (
                <span className="text-muted-foreground">Connect wallet</span>
              ) : isLoadingKrwc ? (
                <span className="text-muted-foreground">Loading...</span>
              ) : (
                <span>{formattedKrwcBalance}</span>
              )}
            </div>
            <div className="text-sm text-muted-foreground">KRWC</div>
          </div>
        </div>

        {!address && (
          <div className="text-center p-4 bg-muted/50 rounded-lg border border-dashed">
            <p className="text-sm text-muted-foreground">
              Connect your wallet to view token balances
            </p>
          </div>
        )}
      </div>
    </GlobalModal>
  )
}