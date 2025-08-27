'use client'

import { ConnectButton } from '@rainbow-me/rainbowkit'
import { Button } from '@/components/ui/button'
import { ThemeToggle } from '@/components/theme-toggle'
import { Wallet, ChevronDown } from 'lucide-react'

export function MobileWalletInfo() {
  return (
    <ConnectButton.Custom>
      {({
        account,
        chain,
        openChainModal,
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
              /* When connected: Theme + Chain + Balance (same order as main navbar) */
              <div className="flex gap-4 items-center w-full">
                <ThemeToggle />
                
                <Button
                  onClick={openChainModal}
                  variant="outline"
                  size="icon"
                  className="flex"
                >
                  {chain.hasIcon && chain.iconUrl ? (
                    <div
                      style={{
                        background: chain.iconBackground,
                        width: 16,
                        height: 16,
                        borderRadius: 999,
                        overflow: 'hidden',
                      }}
                    >
                      {/* eslint-disable-next-line @next/next/no-img-element */}
                      <img
                        alt={chain.name ?? 'Chain icon'}
                        src={chain.iconUrl}
                        style={{ width: 16, height: 16 }}
                      />
                    </div>
                  ) : (
                    <ChevronDown className="h-[1.2rem] w-[1.2rem]" />
                  )}
                  <span className="sr-only">Switch chain</span>
                </Button>

                {/* Balance Display - takes remaining space */}
                {account.displayBalance && (
                  <div className="flex-1 flex items-center justify-between px-3 py-2 bg-muted border border-input rounded-md h-10 min-w-0">
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
                  </div>
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
  )
}