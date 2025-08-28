'use client'

import { ConnectButton } from '@rainbow-me/rainbowkit'
import { Button } from '@/components/ui/button'
import { ChevronDown } from 'lucide-react'

export function SwitchChainButton() {
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

        if (!connected) {
          return null
        }

        if (chain.unsupported) {
          return (
            <Button
              onClick={openChainModal}
              variant="destructive"
              size="icon"
            >
              <ChevronDown className="h-[1.2rem] w-[1.2rem]" />
              <span className="sr-only">Wrong network - Switch chain</span>
            </Button>
          )
        }

        return (
          <Button
            onClick={openChainModal}
            variant="outline"
            size="icon"
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
        )
      }}
    </ConnectButton.Custom>
  )
}