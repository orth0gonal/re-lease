'use client'

import { useAccount, useBalance } from 'wagmi'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { Wallet } from 'lucide-react'
import { formatEther } from 'viem'

export function AccountBalance() {
  const { address, isConnected } = useAccount()
  const { data: balance, isLoading } = useBalance({
    address,
  })

  if (!isConnected) {
    return null
  }

  return (
    <Card className="w-full max-w-md">
      <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
        <CardTitle className="text-sm font-medium">
          Wallet Balance
        </CardTitle>
        <Wallet className="h-4 w-4 text-muted-foreground" />
      </CardHeader>
      <CardContent>
        <div className="text-2xl font-bold">
          {isLoading ? (
            <div className="animate-pulse bg-muted h-8 w-20 rounded" />
          ) : balance ? (
            `${parseFloat(formatEther(balance.value)).toFixed(4)} ${balance.symbol}`
          ) : (
            '0.0000 KLAY'
          )}
        </div>
        <p className="text-xs text-muted-foreground">
          {address && `${address.slice(0, 6)}...${address.slice(-4)}`}
        </p>
      </CardContent>
    </Card>
  )
}