'use client'

import { ConnectButton } from '@rainbow-me/rainbowkit'
import { Button } from '@/components/ui/button'
import { Wallet, ChevronDown } from 'lucide-react'

export function WalletConnectButton() {
  return (
    <ConnectButton.Custom>
      {({
        account,
        chain,
        openAccountModal,
        openChainModal,
        openConnectModal,
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
          <div
            {...(!ready && {
              'aria-hidden': true,
              'style': {
                opacity: 0,
                pointerEvents: 'none',
                userSelect: 'none',
              },
            })}
          >
            {(() => {
              if (!connected) {
                return (
                  <Button
                    onClick={openConnectModal}
                    size="sm"
                    className="bg-primary hover:bg-primary/90 text-primary-foreground h-9"
                  >
                    <Wallet className="w-4 h-4 mr-2" />
                    Connect Wallet
                  </Button>
                )
              }

              if (chain.unsupported) {
                return (
                  <Button
                    onClick={openChainModal}
                    variant="destructive"
                    size="sm"
                    className="h-9"
                  >
                    Wrong network
                  </Button>
                )
              }

              return (
                <div className="flex items-center gap-4">
                  <div className="flex gap-4">
                    {/* Chain button - hidden on mobile (same breakpoint as menu) */}
                    <Button
                      onClick={openChainModal}
                      variant="outline"
                      size="icon"
                      className="hidden md:flex"
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

                    {/* Balance Display - positioned next to chain button */}
                    {account.displayBalance && (
                      <div className="hidden md:flex items-center justify-between px-3 py-2 bg-muted border border-input rounded-md h-10 min-w-0">
                        <Wallet className="w-4 h-4 text-muted-foreground flex-shrink-0" />
                        <span className="text-sm font-medium ml-2">
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

                    {/* Account button - visible on mobile */}
                    <Button
                      onClick={openAccountModal}
                      variant="outline"
                      size="default"
                      className="flex items-center gap-2"
                    >
                      <span className="font-mono text-xs">
                        {account.displayName}
                      </span>
                      <ChevronDown className="w-3 h-3" />
                    </Button>
                  </div>
                </div>
              )
            })()}
          </div>
        )
      }}
    </ConnectButton.Custom>
  )
}