'use client'

import { Navbar } from '@/components/ui/navbar'
import { Footer } from '@/components/ui/footer'
import { RoleCard } from '@/components/ui/role-card'
import { Home as HomeIcon, User as UserIcon, TrendingUp as TrendingUpIcon } from 'lucide-react'
import { useRouter } from 'next/navigation'

export default function Home() {
  const router = useRouter()

  return (
    <div className="min-h-screen bg-gradient-to-br from-background to-muted flex flex-col">
      <Navbar />

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
              onClick={() => router.push('/tenant')}
            />
            
            <RoleCard
              title="Landlord"
              description="Receive yKRWC tokens earning 3-5% yield. Hold for returns or sell for liquidity."
              icon={HomeIcon}
              color="blue"
              onClick={() => router.push('/landlord')}
            />
            
            <RoleCard
              title="Assignee"
              description="Purchase defaulted debt with real estate collateral and priority recovery rights."
              icon={TrendingUpIcon}
              color="purple"
              onClick={() => router.push('/assignee')}
            />
          </div>
        </div>

      </main>

      <Footer />
    </div>
  )
}
