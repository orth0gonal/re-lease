'use client'

import { useState } from 'react'
import { Navbar } from '@/components/ui/navbar'
import { Footer } from '@/components/ui/footer'
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card'
import { Button } from '@/components/ui/button'
import { RegisterPropertyModal } from '@/components/modals/RegisterPropertyModal'
import { CreateContractModal } from '@/components/modals/CreateContractModal'
import { Home, Coins, TrendingUp, Banknote, Clock, Building, FileText, AlertTriangle, AlertCircle, Minus, PlusCircle } from 'lucide-react'

export default function LandlordPage() {
  const [registerModalOpen, setRegisterModalOpen] = useState(false)
  const [createContractModalOpen, setCreateContractModalOpen] = useState(false)
  return (
    <div className="min-h-screen bg-gradient-to-br from-background to-muted flex flex-col">
      <Navbar />

      <main className="container mx-auto px-6 py-12 flex-grow">
        <div className="mb-12">
          <div className="flex items-center gap-3 mb-2">
            <Home className="w-8 h-8 text-primary" />
            <h1 className="text-2xl font-bold tracking-tight">
              Landlord <span className="text-primary">Dashboard</span>
            </h1>
          </div>
          <p className="text-sm text-muted-foreground">
            Receive yKRWC tokens earning 3-5% yield. Hold for returns or sell for liquidity
          </p>
        </div>

        {/* Portfolio Overview Section */}
        <div className="mb-8">
          <div className="flex items-center gap-2 mb-4">
            <TrendingUp className="w-5 h-5 text-primary" />
            <h2 className="text-lg font-semibold">Portfolio Overview</h2>
          </div>
        </div>

        <div className="grid gap-6 md:grid-cols-2 lg:grid-cols-4 mb-12">
          <Card className="bg-gradient-to-br from-blue-50 to-blue-100/50 dark:from-blue-950/30 dark:to-blue-900/20 border-blue-200 dark:border-blue-800">
            <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
              <CardTitle className="text-sm font-medium text-blue-700 dark:text-blue-300">
                Properties
              </CardTitle>
              <Building className="h-4 w-4 text-blue-600 dark:text-blue-400" />
            </CardHeader>
            <CardContent>
              <div className="text-2xl font-bold text-blue-900 dark:text-blue-100">0</div>
              <p className="text-xs text-blue-600 dark:text-blue-400">
                Registered properties
              </p>
            </CardContent>
          </Card>

          <Card className="bg-gradient-to-br from-green-50 to-green-100/50 dark:from-green-950/30 dark:to-green-900/20 border-green-200 dark:border-green-800">
            <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
              <CardTitle className="text-sm font-medium text-green-700 dark:text-green-300">
                Active Contracts
              </CardTitle>
              <FileText className="h-4 w-4 text-green-600 dark:text-green-400" />
            </CardHeader>
            <CardContent>
              <div className="text-2xl font-bold text-green-900 dark:text-green-100">0</div>
              <p className="text-xs text-green-600 dark:text-green-400">
                All active contracts (Jeonse + Debt)
              </p>
            </CardContent>
          </Card>

          <Card className="bg-gradient-to-br from-purple-50 to-purple-100/50 dark:from-purple-950/30 dark:to-purple-900/20 border-purple-200 dark:border-purple-800">
            <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
              <CardTitle className="text-sm font-medium text-purple-700 dark:text-purple-300">
                yKRWC Holdings
              </CardTitle>
              <Coins className="h-4 w-4 text-purple-600 dark:text-purple-400" />
            </CardHeader>
            <CardContent>
              <div className="text-2xl font-bold text-purple-900 dark:text-purple-100">0 yKRWC</div>
              <p className="text-xs text-purple-600 dark:text-purple-400">
                Yield-bearing tokens owned
              </p>
            </CardContent>
          </Card>

          <Card className="bg-gradient-to-br from-amber-50 to-amber-100/50 dark:from-amber-950/30 dark:to-amber-900/20 border-amber-200 dark:border-amber-800">
            <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
              <CardTitle className="text-sm font-medium text-amber-700 dark:text-amber-300">
                Total Principals
              </CardTitle>
              <Banknote className="h-4 w-4 text-amber-600 dark:text-amber-400" />
            </CardHeader>
            <CardContent>
              <div className="text-2xl font-bold text-amber-900 dark:text-amber-100">0 KRWC</div>
              <p className="text-xs text-amber-600 dark:text-amber-400">
                Total deposits from all contracts
              </p>
            </CardContent>
          </Card>
        </div>

        {/* Risk Management Section */}
        <div className="mb-8">
          <div className="flex items-center gap-2 mb-4">
            <AlertTriangle className="w-5 h-5 text-orange-500" />
            <h2 className="text-lg font-semibold">Risk Management</h2>
          </div>
        </div>

        <div className="grid gap-6 md:grid-cols-2 lg:grid-cols-3 mb-12">
          <Card className="bg-gradient-to-br from-orange-50 to-orange-100/50 dark:from-orange-950/30 dark:to-orange-900/20 border-orange-200 dark:border-orange-800">
            <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
              <CardTitle className="text-sm font-medium text-orange-700 dark:text-orange-300">
                Expiring Soon
              </CardTitle>
              <Clock className="h-4 w-4 text-orange-600 dark:text-orange-400" />
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
                Debt Contracts
              </CardTitle>
              <AlertCircle className="h-4 w-4 text-red-600 dark:text-red-400" />
            </CardHeader>
            <CardContent>
              <div className="text-2xl font-bold text-red-900 dark:text-red-100">0</div>
              <p className="text-xs text-red-600 dark:text-red-400">
                Contracts converted to debt
              </p>
            </CardContent>
          </Card>

          <Card className="bg-gradient-to-br from-rose-50 to-rose-100/50 dark:from-rose-950/30 dark:to-rose-900/20 border-rose-200 dark:border-rose-800">
            <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
              <CardTitle className="text-sm font-medium text-rose-700 dark:text-rose-300">
                Total Debt Amount
              </CardTitle>
              <Minus className="h-4 w-4 text-rose-600 dark:text-rose-400" />
            </CardHeader>
            <CardContent>
              <div className="text-2xl font-bold text-rose-900 dark:text-rose-100">0 KRWC</div>
              <p className="text-xs text-rose-600 dark:text-rose-400">
                Principal + interest owed
              </p>
            </CardContent>
          </Card>
        </div>

        {/* Properties Management Section */}
        <div className="mb-12">
          <div className="flex items-center justify-between mb-6">
            <div className="flex items-center gap-2">
              <Building className="w-5 h-5 text-primary" />
              <h2 className="text-lg font-semibold">My Properties (0)</h2>
            </div>
            <Button onClick={() => setRegisterModalOpen(true)} className="px-4">
              <PlusCircle className="w-4 h-4 mr-1" />
              Register
            </Button>
          </div>

          <div className="grid gap-6 md:grid-cols-2 lg:grid-cols-3">
            {/* Empty State */}
            <Card className="col-span-full">
              <CardContent className="py-12">
                <div className="text-center">
                  <h3 className="text-lg font-medium mb-2">No Properties Yet</h3>
                  <p className="text-muted-foreground">
                    Register your first property to start creating Jeonse contracts
                  </p>
                </div>
              </CardContent>
            </Card>
          </div>
        </div>

        {/* Contract Management Section */}
        <div className="mb-12">
          <div className="flex items-center justify-between mb-6">
            <div className="flex items-center gap-2">
              <FileText className="w-5 h-5 text-primary" />
              <h2 className="text-lg font-semibold">My Contracts (0)</h2>
            </div>
            <Button className="px-4" onClick={() => setCreateContractModalOpen(true)}>
              <FileText className="w-4 h-4 mr-1" />
              Create
            </Button>
          </div>

          <div className="space-y-4">
            {/* Empty State */}
            <Card>
              <CardContent className="py-12">
                <div className="text-center">
                  <h3 className="text-lg font-medium mb-2">No Contracts Yet</h3>
                  <p className="text-muted-foreground">
                    Create your first Jeonse contract with registered properties
                  </p>
                </div>
              </CardContent>
            </Card>
          </div>
        </div>

        {/* Token & Activity Section */}
        <div className="mb-8">
          <div className="flex items-center gap-2 mb-4">
            <Coins className="w-5 h-5 text-primary" />
            <h2 className="text-lg font-semibold">Token & Activity</h2>
          </div>
        </div>

        <div className="grid gap-8 md:grid-cols-2 mb-16">
          <Card>
            <CardHeader>
              <CardTitle className="flex items-center gap-2">
                <Banknote className="w-5 h-5" />
                Manage yKRWC Tokens
              </CardTitle>
              <CardDescription>
                Your yield-bearing tokens from tenant deposits
              </CardDescription>
            </CardHeader>
            <CardContent className="space-y-4">
              <div className="space-y-4">
                <div className="space-y-2">
                  <p className="text-sm font-medium">Token Benefits:</p>
                  <ul className="text-sm text-muted-foreground space-y-1">
                    <li>• Automatic yield accumulation</li>
                    <li>• Tradeable on secondary markets</li>
                    <li>• Instant liquidity conversion</li>
                  </ul>
                </div>
                
                <div className="bg-green-50 dark:bg-green-950/30 p-4 rounded-lg border border-green-200 dark:border-green-800">
                  <div className="flex items-center justify-between">
                    <div>
                      <p className="text-sm font-medium text-green-700 dark:text-green-300">Expected APR</p>
                      <p className="text-2xl font-bold text-green-900 dark:text-green-100">3.5%</p>
                    </div>
                    <TrendingUp className="w-8 h-8 text-green-600 dark:text-green-400" />
                  </div>
                  <p className="text-xs text-green-600 dark:text-green-400 mt-2">
                    Annual yield from holding yKRWC tokens
                  </p>
                </div>
              </div>
              <div className="bg-orange-50 dark:bg-orange-950/30 p-3 rounded-lg border border-orange-200 dark:border-orange-800 mb-4">
                <p className="text-sm text-orange-700 dark:text-orange-300">
                  ⚠️ Cashing out will forfeit ongoing APR benefits
                </p>
              </div>
              <Button variant="outline" className="w-full text-muted-foreground">
                <Banknote className="w-4 h-4 mr-2" />
                Cash Out
              </Button>
            </CardContent>
          </Card>

          <Card className="flex flex-col">
            <CardHeader>
              <CardTitle className="flex items-center gap-2">
                <TrendingUp className="w-5 h-5" />
                Recent Activity
              </CardTitle>
              <CardDescription>
                Latest property and contract updates
              </CardDescription>
            </CardHeader>
            <CardContent className="flex-1 flex items-center justify-center">
              <div className="text-center text-muted-foreground">
                <Clock className="w-12 h-12 mx-auto mb-4 opacity-50" />
                <p>No recent activity</p>
              </div>
            </CardContent>
          </Card>
        </div>

        {/* How It Works Guide Section */}
        <div className="mt-16 bg-gradient-to-r from-primary/5 to-primary/10 rounded-2xl p-8 border border-primary/20">
          <div className="text-center mb-8">
            <h2 className="text-2xl font-bold mb-2">How It Works for Landlords</h2>
            <p className="text-muted-foreground">
              Understanding your benefits and responsibilities
            </p>
          </div>
          
          <div className="grid gap-6 md:grid-cols-4">
            <div className="text-center space-y-3 group">
              <div className="w-16 h-16 bg-white dark:bg-background rounded-2xl shadow-lg flex items-center justify-center mx-auto group-hover:scale-105 transition-transform">
                <Coins className="w-8 h-8 text-primary" />
              </div>
              <h3 className="font-semibold text-lg">1. Receive yKRWC</h3>
              <p className="text-sm text-muted-foreground leading-relaxed">
                Get yield-bearing tokens when tenant deposits
              </p>
            </div>
            <div className="text-center space-y-3 group">
              <div className="w-16 h-16 bg-white dark:bg-background rounded-2xl shadow-lg flex items-center justify-center mx-auto group-hover:scale-105 transition-transform">
                <TrendingUp className="w-8 h-8 text-primary" />
              </div>
              <h3 className="font-semibold text-lg">2. Earn Yield</h3>
              <p className="text-sm text-muted-foreground leading-relaxed">
                Tokens automatically earn 3-5% annual yield
              </p>
            </div>
            <div className="text-center space-y-3 group">
              <div className="w-16 h-16 bg-white dark:bg-background rounded-2xl shadow-lg flex items-center justify-center mx-auto group-hover:scale-105 transition-transform">
                <Banknote className="w-8 h-8 text-primary" />
              </div>
              <h3 className="font-semibold text-lg">3. Choose Option</h3>
              <p className="text-sm text-muted-foreground leading-relaxed">
                Hold for yield or sell for immediate cash
              </p>
            </div>
            <div className="text-center space-y-3 group">
              <div className="w-16 h-16 bg-white dark:bg-background rounded-2xl shadow-lg flex items-center justify-center mx-auto group-hover:scale-105 transition-transform">
                <Clock className="w-8 h-8 text-primary" />
              </div>
              <h3 className="font-semibold text-lg">4. Contract End</h3>
              <p className="text-sm text-muted-foreground leading-relaxed">
                Return deposit or become debtor with assignee system
              </p>
            </div>
          </div>
        </div>
      </main>

      <Footer />
      
      <RegisterPropertyModal 
        open={registerModalOpen} 
        onOpenChange={setRegisterModalOpen} 
      />
      
      <CreateContractModal 
        open={createContractModalOpen} 
        onOpenChange={setCreateContractModalOpen} 
      />
    </div>
  )
}