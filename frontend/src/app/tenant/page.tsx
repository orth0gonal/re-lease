'use client'

import { Navbar } from '@/components/ui/navbar'
import { Footer } from '@/components/ui/footer'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { Shield, Coins, FileText, TrendingUp } from 'lucide-react'

export default function TenantPage() {
  return (
    <div className="min-h-screen bg-gradient-to-br from-background to-muted flex flex-col">
      <Navbar />

      <main className="container mx-auto px-6 py-12 flex-grow">
        <div className="mb-12">
          <div className="flex items-center gap-3 mb-2">
            <Shield className="w-8 h-8 text-primary" />
            <h1 className="text-2xl font-bold tracking-tight">
              Tenant <span className="text-primary">Dashboard</span>
            </h1>
          </div>
          <p className="text-sm text-muted-foreground">
            Secure your Jeonse deposit with KRWC stablecoin and smart contract protection
          </p>
        </div>

        {/* Portfolio Overview Section */}
        <div className="mb-8">
          <div className="flex items-center gap-2 mb-4">
            <TrendingUp className="w-5 h-5 text-primary" />
            <h2 className="text-lg font-semibold">Portfolio Overview</h2>
          </div>
        </div>

        <div className="grid gap-6 md:grid-cols-2 mb-12">
          <Card className="bg-gradient-to-br from-green-50 to-green-100/50 dark:from-green-950/30 dark:to-green-900/20 border-green-200 dark:border-green-800">
            <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
              <CardTitle className="text-sm font-medium text-green-700 dark:text-green-300">
                Current Contracts
              </CardTitle>
              <FileText className="h-4 w-4 text-green-600 dark:text-green-400" />
            </CardHeader>
            <CardContent>
              <div className="text-2xl font-bold text-green-900 dark:text-green-100">0</div>
              <p className="text-xs text-green-600 dark:text-green-400">
                Active Jeonse contracts
              </p>
            </CardContent>
          </Card>

          <Card className="bg-gradient-to-br from-blue-50 to-blue-100/50 dark:from-blue-950/30 dark:to-blue-900/20 border-blue-200 dark:border-blue-800">
            <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
              <CardTitle className="text-sm font-medium text-blue-700 dark:text-blue-300">
                Total Deposits
              </CardTitle>
              <Coins className="h-4 w-4 text-blue-600 dark:text-blue-400" />
            </CardHeader>
            <CardContent>
              <div className="text-2xl font-bold text-blue-900 dark:text-blue-100">0 KRWC</div>
              <p className="text-xs text-blue-600 dark:text-blue-400">
                Total deposited amount
              </p>
            </CardContent>
          </Card>
        </div>

        {/* Risk Management Section */}
        <div className="mb-8">
          <div className="flex items-center gap-2 mb-4">
            <Shield className="w-5 h-5 text-orange-500" />
            <h2 className="text-lg font-semibold">Contract Status</h2>
          </div>
        </div>

        <div className="grid gap-6 md:grid-cols-2 lg:grid-cols-3 mb-12">
          <Card className="bg-gradient-to-br from-orange-50 to-orange-100/50 dark:from-orange-950/30 dark:to-orange-900/20 border-orange-200 dark:border-orange-800">
            <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
              <CardTitle className="text-sm font-medium text-orange-700 dark:text-orange-300">
                Expiring Soon
              </CardTitle>
              <FileText className="h-4 w-4 text-orange-600 dark:text-orange-400" />
            </CardHeader>
            <CardContent>
              <div className="text-2xl font-bold text-orange-900 dark:text-orange-100">0</div>
              <p className="text-xs text-orange-600 dark:text-orange-400">
                Contracts expiring within 30 days
              </p>
            </CardContent>
          </Card>

          <Card className="bg-gradient-to-br from-red-50 to-red-100/50 dark:from-red-950/30 dark:to-red-900/20 border-red-200 dark:border-red-800">
            <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
              <CardTitle className="text-sm font-medium text-red-700 dark:text-red-300">
                Converted to Debt
              </CardTitle>
              <Shield className="h-4 w-4 text-red-600 dark:text-red-400" />
            </CardHeader>
            <CardContent>
              <div className="text-2xl font-bold text-red-900 dark:text-red-100">0</div>
              <p className="text-xs text-red-600 dark:text-red-400">
                Contracts converted to debt
              </p>
            </CardContent>
          </Card>

          <Card className="bg-gradient-to-br from-purple-50 to-purple-100/50 dark:from-purple-950/30 dark:to-purple-900/20 border-purple-200 dark:border-purple-800">
            <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
              <CardTitle className="text-sm font-medium text-purple-700 dark:text-purple-300">
                Recoverable Amount
              </CardTitle>
              <Coins className="h-4 w-4 text-purple-600 dark:text-purple-400" />
            </CardHeader>
            <CardContent>
              <div className="text-2xl font-bold text-purple-900 dark:text-purple-100">0 KRWC</div>
              <p className="text-xs text-purple-600 dark:text-purple-400">
                Principal + interest recoverable
              </p>
            </CardContent>
          </Card>
        </div>

        {/* Contract Management Section */}
        <div className="mb-12">
          <div className="flex items-center justify-between mb-6">
            <div className="flex items-center gap-2">
              <FileText className="w-5 h-5 text-primary" />
              <h2 className="text-lg font-semibold">My Contracts (0)</h2>
            </div>
          </div>

          <div className="space-y-4">
            {/* Empty State */}
            <Card>
              <CardContent className="py-12">
                <div className="text-center">
                  <h3 className="text-lg font-medium mb-2">No Contracts Yet</h3>
                  <p className="text-muted-foreground">
                    Your Jeonse contracts will appear here once created
                  </p>
                </div>
              </CardContent>
            </Card>
          </div>
        </div>

        {/* How It Works Guide Section */}
        <div className="mt-16 bg-gradient-to-r from-primary/5 to-primary/10 rounded-2xl p-8 border border-primary/20">
          <div className="text-center mb-8">
            <h2 className="text-2xl font-bold mb-2">How It Works</h2>
            <p className="text-muted-foreground">
              Understanding your protection as a tenant
            </p>
          </div>
          
          <div className="grid gap-6 md:grid-cols-3">
            <div className="text-center space-y-3 group">
              <div className="w-16 h-16 bg-white dark:bg-background rounded-2xl shadow-lg flex items-center justify-center mx-auto group-hover:scale-105 transition-transform">
                <Coins className="w-8 h-8 text-primary" />
              </div>
              <h3 className="font-semibold text-lg">1. Deposit KRWC</h3>
              <p className="text-sm text-muted-foreground leading-relaxed">
                Deposit your Jeonse amount in KRWC stablecoin into our smart contract
              </p>
            </div>
            <div className="text-center space-y-3 group">
              <div className="w-16 h-16 bg-white dark:bg-background rounded-2xl shadow-lg flex items-center justify-center mx-auto group-hover:scale-105 transition-transform">
                <Shield className="w-8 h-8 text-primary" />
              </div>
              <h3 className="font-semibold text-lg">2. Get Protection</h3>
              <p className="text-sm text-muted-foreground leading-relaxed">
                Your deposit is protected by smart contracts and the assignee system
              </p>
            </div>
            <div className="text-center space-y-3 group">
              <div className="w-16 h-16 bg-white dark:bg-background rounded-2xl shadow-lg flex items-center justify-center mx-auto group-hover:scale-105 transition-transform">
                <TrendingUp className="w-8 h-8 text-primary" />
              </div>
              <h3 className="font-semibold text-lg">3. Auto Recovery</h3>
              <p className="text-sm text-muted-foreground leading-relaxed">
                If landlord defaults, assignees ensure immediate deposit recovery
              </p>
            </div>
          </div>
        </div>
      </main>

      <Footer />
    </div>
  )
}