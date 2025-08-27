'use client'

import { useState } from 'react'
import { ConnectButton } from '@rainbow-me/rainbowkit'
import { Button } from '@/components/ui/button'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { Copy, ExternalLink, LogOut, ChevronDown, ChevronUp } from 'lucide-react'
import { cn } from '@/lib/utils'

export function MobileAccountInfo() {
  const [isExpanded, setIsExpanded] = useState(false)

  const copyToClipboard = (text: string) => {
    navigator.clipboard.writeText(text)
    // You could add a toast notification here
  }

  return (
    <ConnectButton.Custom>
      {({
        account,
        chain,
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

        if (!connected) {
          return null
        }

        return (
          <div className="w-full">
            {/* Collapsible Account Button */}
            <Button
              onClick={() => setIsExpanded(!isExpanded)}
              variant="outline"
              size="sm"
              className="w-full flex items-center justify-between h-10"
            >
              <span className="font-mono text-xs truncate">
                {account.displayName}
              </span>
              {isExpanded ? <ChevronUp className="w-3 h-3" /> : <ChevronDown className="w-3 h-3" />}
            </Button>

            {/* Expanded Account Details */}
            <div className={cn(
              "mt-2 transition-all duration-200 ease-in-out overflow-hidden",
              isExpanded ? "max-h-96 opacity-100" : "max-h-0 opacity-0"
            )}>
              <Card className="w-full">
                <CardHeader className="pb-3">
                  <CardTitle className="text-sm">Account Details</CardTitle>
                </CardHeader>
                <CardContent className="pt-0 space-y-3">
                  {/* Balance */}
                  {account.displayBalance && (
                    <div className="flex items-center justify-between p-3 bg-muted rounded-lg">
                      <span className="text-sm text-muted-foreground">Balance</span>
                      <span className="text-sm font-medium">{account.displayBalance}</span>
                    </div>
                  )}

                  {/* Address */}
                  <div className="space-y-2">
                    <span className="text-xs text-muted-foreground">Address</span>
                    <div className="flex items-center gap-2 p-2 bg-muted rounded">
                      <span className="font-mono text-xs flex-1 truncate">
                        {account.address}
                      </span>
                      <Button
                        size="sm"
                        variant="ghost"
                        onClick={() => copyToClipboard(account.address)}
                        className="h-6 w-6 p-0"
                      >
                        <Copy className="w-3 h-3" />
                      </Button>
                    </div>
                  </div>

                  {/* Chain Info */}
                  <div className="space-y-2">
                    <span className="text-xs text-muted-foreground">Network</span>
                    <Button
                      onClick={openChainModal}
                      variant="outline"
                      size="sm"
                      className="w-full flex items-center justify-center gap-2 h-9"
                    >
                      {chain.hasIcon && (
                        <div
                          style={{
                            background: chain.iconBackground,
                            width: 16,
                            height: 16,
                            borderRadius: 999,
                            overflow: 'hidden',
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
                      <span className="text-sm">{chain.name}</span>
                    </Button>
                  </div>

                  {/* Action Buttons */}
                  <div className="flex gap-2 pt-2">
                    {account.ensName && (
                      <Button
                        size="sm"
                        variant="outline"
                        className="flex-1 h-9"
                        onClick={() => window.open(`https://etherscan.io/address/${account.address}`, '_blank')}
                      >
                        <ExternalLink className="w-3 h-3 mr-2" />
                        View
                      </Button>
                    )}
                    <Button
                      size="sm"
                      variant="outline"
                      className="flex-1 h-9"
                      onClick={() => {
                        // This will trigger RainbowKit's disconnect
                        // You might want to implement custom disconnect logic here
                      }}
                    >
                      <LogOut className="w-3 h-3 mr-2" />
                      Disconnect
                    </Button>
                  </div>
                </CardContent>
              </Card>
            </div>
          </div>
        )
      }}
    </ConnectButton.Custom>
  )
}