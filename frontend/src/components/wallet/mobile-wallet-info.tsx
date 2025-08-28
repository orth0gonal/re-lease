'use client'

import { ConnectButton } from '@rainbow-me/rainbowkit'
import { Button } from '@/components/ui/button'
import { ThemeToggle } from '@/components/theme-toggle'
import { SwitchChainButton } from '@/components/wallet/switch-chain-button'
import { FaucetModal } from '@/components/modals/FaucetModal'
import { BalanceModal } from '@/components/modals/BalanceModal'
import { Wallet, Droplets } from 'lucide-react'
import { useState } from 'react'

export function MobileWalletInfo() {
  const [isFaucetModalOpen, setIsFaucetModalOpen] = useState(false)
  const [isBalanceModalOpen, setIsBalanceModalOpen] = useState(false)
  
  return (
    <>
      <ConnectButton.Custom>
      {({
        account,
        chain,
        authenticationStatus,
        mounted,
      }) => {
        const ready = mounted && authenticationStatus !== 'loading'
        const connected =
          ready &&
          account &&
          chain &&
          (!authenticationStatus ||
            authenticationStatus === 'authenticated')

        return (
          <div className="w-full">
            {connected ? (
              /* When connected: Theme + Switch Chain + Faucet + Balance (same order as main navbar) */
              <div className="flex gap-3 items-center w-full">
                <ThemeToggle />
                
                <SwitchChainButton />

                <Button
                  onClick={() => setIsFaucetModalOpen(true)}
                  variant="outline"
                  size="icon"
                  className="flex"
                >
                  <Droplets className="h-[1.2rem] w-[1.2rem]" />
                  <span className="sr-only">Open faucet</span>
                </Button>

                {/* Balance Display - takes remaining space */}
                {account.displayBalance && (
                  <Button
                    onClick={() => setIsBalanceModalOpen(true)}
                    variant="outline"
                    className="flex-1 flex items-center justify-between px-3 py-2 bg-muted border border-input rounded-md h-10 min-w-0 hover:bg-muted/80"
                  >
                    <Wallet className="w-4 h-4 text-muted-foreground flex-shrink-0" />
                    <span className="text-sm font-medium">
                      {(() => {
                        // Format balance to max 2 decimal places
                        const balance = account.displayBalance;
                        const match = balance.match(/^(\d+\.?\d*)\s*(.+)$/);
                        if (match) {
                          const [, number, currency] = match;
                          const formattedNumber = parseFloat(number).toFixed(2);
                          return `${formattedNumber} ${currency}`;
                        }
                        return balance;
                      })()}
                    </span>
                  </Button>
                )}
              </div>
            ) : (
              /* When not connected, show only theme toggle */
              <div className="flex items-center justify-center">
                <ThemeToggle />
              </div>
            )}
          </div>
        )
      }}
      </ConnectButton.Custom>

      {/* Faucet Modal */}
      <FaucetModal
        open={isFaucetModalOpen}
        onOpenChange={setIsFaucetModalOpen}
      />

      {/* Balance Modal */}
      <BalanceModal
        open={isBalanceModalOpen}
        onOpenChange={setIsBalanceModalOpen}
      />
    </>
  )
}