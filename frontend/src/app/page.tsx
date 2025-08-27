'use client'

import { WalletConnectButton } from '@/components/wallet/wallet-connect-button'
import { ThemeToggle } from '@/components/theme-toggle'
import { Logo } from '@/components/ui/logo'
import { RoleCard } from '@/components/ui/role-card'
import { Home as HomeIcon, User as UserIcon, TrendingUp as TrendingUpIcon } from 'lucide-react'

export default function Home() {
  return (
    <div className="min-h-screen bg-gradient-to-br from-background to-muted flex flex-col">
      <header className="border-b bg-background/95 backdrop-blur supports-[backdrop-filter]:bg-background/60">
        <div className="container mx-auto px-4 h-16 flex items-center justify-between">
          <Logo />
          <div className="flex items-center space-x-4">
            <ThemeToggle />
            <WalletConnectButton />
          </div>
        </div>
      </header>

      <main className="container mx-auto px-4 py-12 flex-grow">
        <div className="text-center space-y-6 mb-16">
          <h2 className="text-4xl font-bold tracking-tight sm:text-6xl">
            <span className="text-primary">re:</span>Lease the <span className="text-primary">Future</span>
          </h2>
          <p className="text-xl text-muted-foreground max-w-3xl mx-auto">
            Stablecoin-powered Jeonse Platform with Auto-Debt Conversion
          </p>
        </div>

        <div className="max-w-6xl mx-auto mb-12">
          <h3 className="text-2xl font-semibold text-center mb-8 text-foreground">Choose Your Role</h3>
          <div className="grid gap-6 sm:gap-8 grid-cols-1 lg:grid-cols-3 px-4 sm:px-0">
            <RoleCard
              title="Tenant"
              description="Deposit KRWC for guaranteed protection. Become creditor with automatic recovery system."
              icon={UserIcon}
              color="green"
              onClick={() => {
                // TODO: Navigate to tenant dashboard
                console.log('Tenant selected')
              }}
            />
            
            <RoleCard
              title="Landlord"
              description="Receive yKRWC tokens earning 3-5% yield. Hold for returns or sell for liquidity."
              icon={HomeIcon}
              color="blue"
              onClick={() => {
                // TODO: Navigate to landlord dashboard
                console.log('Landlord selected')
              }}
            />
            
            <RoleCard
              title="Assignee"
              description="Purchase defaulted debt with real estate collateral and priority recovery rights."
              icon={TrendingUpIcon}
              color="purple"
              onClick={() => {
                // TODO: Navigate to assignee marketplace
                console.log('Assignee selected')
              }}
            />
          </div>
        </div>

      </main>

      <footer className="border-t bg-background/95 backdrop-blur supports-[backdrop-filter]:bg-background/60 mt-auto">
        <div className="container mx-auto px-4 py-6">
          <div className="flex flex-col md:flex-row justify-between items-center space-y-4 md:space-y-0">
            <span className="text-sm text-muted-foreground">
              Powered by re:Lease
            </span>
            <p className="text-sm text-muted-foreground">
              © 2025 re:Lease. All rights reserved.
            </p>
          </div>
        </div>
      </footer>
    </div>
  )
}
