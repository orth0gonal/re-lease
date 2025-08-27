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
                    size="lg"
                    className="bg-primary hover:bg-primary/90 text-primary-foreground"
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
                    size="lg"
                  >
                    Wrong network
                  </Button>
                )
              }

              return (
                <div className="flex items-center gap-3">
                  {account.displayBalance && (
                    <div className="hidden sm:flex items-center gap-2 px-3 py-2 bg-muted rounded-lg">
                      <Wallet className="w-4 h-4 text-muted-foreground" />
                      <span className="text-sm font-medium">
                        {account.displayBalance}
                      </span>
                    </div>
                  )}
                  
                  <div className="flex gap-2">
                    <Button
                      onClick={openChainModal}
                      variant="outline"
                      size="sm"
                      className="flex items-center gap-2"
                    >
                      {chain.hasIcon && (
                        <div
                          style={{
                            background: chain.iconBackground,
                            width: 16,
                            height: 16,
                            borderRadius: 999,
                            overflow: 'hidden',
                            marginRight: 4,
                          }}
                        >
                          {chain.iconUrl && (
                            // eslint-disable-next-line @next/next/no-img-element
                            <img
                              alt={chain.name ?? 'Chain icon'}
                              src={chain.iconUrl}
                              style={{ width: 16, height: 16 }}
                            />
                          )}
                        </div>
                      )}
                      <span className="hidden sm:inline">{chain.name}</span>
                      <ChevronDown className="w-3 h-3" />
                    </Button>

                    <Button
                      onClick={openAccountModal}
                      variant="outline"
                      size="sm"
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