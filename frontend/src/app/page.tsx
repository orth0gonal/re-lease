'use client'

import { WalletConnectButton } from '@/components/wallet/wallet-connect-button'
import { AccountBalance } from '@/components/wallet/account-balance'
import { ThemeToggle } from '@/components/theme-toggle'
import { Logo, LogoIcon } from '@/components/ui/logo'
import { RoleCard } from '@/components/ui/role-card'
import { Home as HomeIcon, User as UserIcon, TrendingUp as TrendingUpIcon } from 'lucide-react'

export default function Home() {
  return (
    <div className="min-h-screen bg-gradient-to-br from-background to-muted">
      <header className="border-b bg-background/95 backdrop-blur supports-[backdrop-filter]:bg-background/60">
        <div className="container mx-auto px-4 h-16 flex items-center justify-between">
          <Logo />
          <div className="flex items-center space-x-4">
            <ThemeToggle />
            <WalletConnectButton />
          </div>
        </div>
      </header>

      <main className="container mx-auto px-4 py-12">
        <div className="text-center space-y-6 mb-16">
          <h2 className="text-4xl font-bold tracking-tight sm:text-6xl">
            <span className="text-primary">re:Lease</span> the Future
          </h2>
          <p className="text-xl text-muted-foreground max-w-3xl mx-auto">
            Stablecoin-powered platform for Korean Jeonse rental agreements.
          </p>
        </div>

        <div className="max-w-6xl mx-auto mb-12">
          <h3 className="text-2xl font-semibold text-center mb-8 text-foreground">Choose Your Role</h3>
          <div className="grid gap-6 sm:gap-8 grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 px-4 sm:px-0">
            <RoleCard
              title="Landlord"
              description="From landlord to debtor when lease ends"
              icon={HomeIcon}
              color="blue"
              onClick={() => {
                // TODO: Navigate to landlord dashboard
                console.log('Landlord selected')
              }}
            />
            
            <RoleCard
              title="Tenant"
              description="From tenant to creditor when lease ends"
              icon={UserIcon}
              color="green"
              onClick={() => {
                // TODO: Navigate to tenant dashboard
                console.log('Tenant selected')
              }}
            />
            
            <RoleCard
              title="Assignee"
              description="Third-party investor buying tenant claims"
              icon={TrendingUpIcon}
              color="purple"
              onClick={() => {
                // TODO: Navigate to assignee marketplace
                console.log('Assignee selected')
              }}
              className="sm:col-span-2 lg:col-span-1 sm:max-w-md sm:mx-auto lg:max-w-none lg:mx-0"
            />
          </div>
        </div>

        <div className="flex flex-col items-center space-y-6">
          <AccountBalance />
        </div>
      </main>

      <footer className="border-t bg-background/95 backdrop-blur supports-[backdrop-filter]:bg-background/60 mt-12">
        <div className="container mx-auto px-4 py-6">
          <div className="flex flex-col md:flex-row justify-between items-center space-y-4 md:space-y-0">
            <div className="flex items-center space-x-2">
              <LogoIcon size="sm" />
              <span className="text-sm text-muted-foreground">
                Powered by Kaia Blockchain
              </span>
            </div>
            <p className="text-sm text-muted-foreground">
              © 2024 re:Lease. All rights reserved.
            </p>
          </div>
        </div>
      </footer>
    </div>
  )
}
