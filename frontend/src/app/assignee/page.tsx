'use client'

import { Navbar } from '@/components/ui/navbar'
import { Footer } from '@/components/ui/footer'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { TrendingUp, Shield, Building2, Search, DollarSign, Users } from 'lucide-react'

export default function AssigneePage() {
  return (
    <div className="min-h-screen bg-gradient-to-br from-background to-muted flex flex-col">
      <Navbar />

      <main className="container mx-auto px-6 py-12 flex-grow">
        <div className="mb-12">
          <div className="flex items-center gap-3 mb-2">
            <TrendingUp className="w-8 h-8 text-primary" />
            <h1 className="text-2xl font-bold tracking-tight">
              Assignee <span className="text-primary">Marketplace</span>
            </h1>
          </div>
          <p className="text-sm text-muted-foreground">
            Purchase defaulted debt with real estate collateral and priority recovery rights
          </p>
        </div>

        {/* Portfolio Overview Section */}
        <div className="mb-8">
          <div className="flex items-center gap-2 mb-4">
            <TrendingUp className="w-5 h-5 text-primary" />
            <h2 className="text-lg font-semibold">Portfolio Overview</h2>
          </div>
        </div>

        <div className="grid gap-6 md:grid-cols-3 mb-12">
          <Card className="bg-gradient-to-br from-green-50 to-green-100/50 dark:from-green-950/30 dark:to-green-900/20 border-green-200 dark:border-green-800">
            <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
              <CardTitle className="text-sm font-medium text-green-700 dark:text-green-300">
                Purchased Bonds
              </CardTitle>
              <Building2 className="h-4 w-4 text-green-600 dark:text-green-400" />
            </CardHeader>
            <CardContent>
              <div className="text-2xl font-bold text-green-900 dark:text-green-100">0</div>
              <p className="text-xs text-green-600 dark:text-green-400">
                Number of debt bonds owned
              </p>
            </CardContent>
          </Card>

          <Card className="bg-gradient-to-br from-blue-50 to-blue-100/50 dark:from-blue-950/30 dark:to-blue-900/20 border-blue-200 dark:border-blue-800">
            <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
              <CardTitle className="text-sm font-medium text-blue-700 dark:text-blue-300">
                Total Invested
              </CardTitle>
              <DollarSign className="h-4 w-4 text-blue-600 dark:text-blue-400" />
            </CardHeader>
            <CardContent>
              <div className="text-2xl font-bold text-blue-900 dark:text-blue-100">0 KRWC</div>
              <p className="text-xs text-blue-600 dark:text-blue-400">
                Total KRWC spent on bonds
              </p>
            </CardContent>
          </Card>

          <Card className="bg-gradient-to-br from-purple-50 to-purple-100/50 dark:from-purple-950/30 dark:to-purple-900/20 border-purple-200 dark:border-purple-800">
            <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
              <CardTitle className="text-sm font-medium text-purple-700 dark:text-purple-300">
                Expected Recovery
              </CardTitle>
              <TrendingUp className="h-4 w-4 text-purple-600 dark:text-purple-400" />
            </CardHeader>
            <CardContent>
              <div className="text-2xl font-bold text-purple-900 dark:text-purple-100">0 KRWC</div>
              <p className="text-xs text-purple-600 dark:text-purple-400">
                Principal + interest recoverable
              </p>
            </CardContent>
          </Card>
        </div>

        {/* Marketplace Section */}
        <div className="mb-12">
          <div className="flex items-center justify-between mb-6">
            <div className="flex items-center gap-2">
              <Search className="w-5 h-5 text-primary" />
              <h2 className="text-lg font-semibold">Marketplace (0)</h2>
            </div>
          </div>

          <div className="space-y-4">
            {/* Empty State */}
            <Card>
              <CardContent className="py-12">
                <div className="text-center">
                  <h3 className="text-lg font-medium mb-2">No Investment Opportunities</h3>
                  <p className="text-muted-foreground">
                    Defaulted Jeonse contracts available for purchase will appear here
                  </p>
                </div>
              </CardContent>
            </Card>
          </div>
        </div>

        {/* My Investments Section */}
        <div className="mb-12">
          <div className="flex items-center justify-between mb-6">
            <div className="flex items-center gap-2">
              <Users className="w-5 h-5 text-primary" />
              <h2 className="text-lg font-semibold">My Investments (0)</h2>
            </div>
          </div>

          <div className="space-y-4">
            {/* Empty State */}
            <Card>
              <CardContent className="py-12">
                <div className="text-center">
                  <h3 className="text-lg font-medium mb-2">No Investments Yet</h3>
                  <p className="text-muted-foreground">
                    Your purchased debt bonds will appear here once acquired
                  </p>
                </div>
              </CardContent>
            </Card>
          </div>
        </div>

        {/* Investment Notice Section */}
        <div className="mb-12">
          <div className="bg-yellow-50 dark:bg-yellow-950/30 border border-yellow-200 dark:border-yellow-800 rounded-lg p-6">
            <h3 className="font-semibold text-yellow-800 dark:text-yellow-200 mb-3">Investment Notice</h3>
            <div className="space-y-2 text-sm text-yellow-700 dark:text-yellow-300">
              <p>
                <strong>Risk Disclosure:</strong> Investments involve risk despite real estate backing and legal protections under Korean law. Returns are not guaranteed.
              </p>
              <p>
                <strong>Important:</strong> Please review all terms carefully and consider your risk tolerance before investing. Only invest amounts you can afford to lose.
              </p>
            </div>
          </div>
        </div>

        {/* How It Works Guide Section */}
        <div className="mt-16 bg-gradient-to-r from-primary/5 to-primary/10 rounded-2xl p-8 border border-primary/20">
          <div className="text-center mb-8">
            <h2 className="text-2xl font-bold mb-2">How Assignee Investment Works</h2>
            <p className="text-muted-foreground">
              Understanding your role in the debt recovery system
            </p>
          </div>
          
          <div className="grid gap-6 md:grid-cols-4">
            <div className="text-center space-y-3 group">
              <div className="w-16 h-16 bg-white dark:bg-background rounded-2xl shadow-lg flex items-center justify-center mx-auto group-hover:scale-105 transition-transform">
                <Search className="w-8 h-8 text-primary" />
              </div>
              <h3 className="font-semibold text-lg">1. Find Opportunity</h3>
              <p className="text-sm text-muted-foreground leading-relaxed">
                Browse defaulted contracts with real estate backing
              </p>
            </div>
            <div className="text-center space-y-3 group">
              <div className="w-16 h-16 bg-white dark:bg-background rounded-2xl shadow-lg flex items-center justify-center mx-auto group-hover:scale-105 transition-transform">
                <DollarSign className="w-8 h-8 text-primary" />
              </div>
              <h3 className="font-semibold text-lg">2. Purchase Debt</h3>
              <p className="text-sm text-muted-foreground leading-relaxed">
                Buy the debt-credit relationship at market price
              </p>
            </div>
            <div className="text-center space-y-3 group">
              <div className="w-16 h-16 bg-white dark:bg-background rounded-2xl shadow-lg flex items-center justify-center mx-auto group-hover:scale-105 transition-transform">
                <Shield className="w-8 h-8 text-primary" />
              </div>
              <h3 className="font-semibold text-lg">3. Legal Protection</h3>
              <p className="text-sm text-muted-foreground leading-relaxed">
                Get priority rights under Housing Lease Protection Act
              </p>
            </div>
            <div className="text-center space-y-3 group">
              <div className="w-16 h-16 bg-white dark:bg-background rounded-2xl shadow-lg flex items-center justify-center mx-auto group-hover:scale-105 transition-transform">
                <TrendingUp className="w-8 h-8 text-primary" />
              </div>
              <h3 className="font-semibold text-lg">4. Earn Returns</h3>
              <p className="text-sm text-muted-foreground leading-relaxed">
                Collect 5% annual interest plus recovery proceeds
              </p>
            </div>
          </div>
        </div>

      </main>

      <Footer />
    </div>
  )
}