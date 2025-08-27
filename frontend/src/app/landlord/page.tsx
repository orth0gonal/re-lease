'use client'

import { Navbar } from '@/components/ui/navbar'
import { Footer } from '@/components/ui/footer'
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card'
import { Button } from '@/components/ui/button'
import { Home, Coins, TrendingUp, Banknote, Clock, DollarSign } from 'lucide-react'

export default function LandlordPage() {
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

        <div className="grid gap-6 md:grid-cols-2 lg:grid-cols-3 mb-16">
          <Card>
            <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
              <CardTitle className="text-sm font-medium">
                yKRWC Holdings
              </CardTitle>
              <Coins className="h-4 w-4 text-muted-foreground" />
            </CardHeader>
            <CardContent>
              <div className="text-2xl font-bold">0 yKRWC</div>
              <p className="text-xs text-muted-foreground">
                Yield-bearing tokens owned
              </p>
            </CardContent>
          </Card>

          <Card>
            <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
              <CardTitle className="text-sm font-medium">
                Annual Yield
              </CardTitle>
              <TrendingUp className="h-4 w-4 text-muted-foreground" />
            </CardHeader>
            <CardContent>
              <div className="text-2xl font-bold">3.5%</div>
              <p className="text-xs text-muted-foreground">
                Current APY from deposit pool
              </p>
            </CardContent>
          </Card>

          <Card>
            <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
              <CardTitle className="text-sm font-medium">
                Earned Interest
              </CardTitle>
              <DollarSign className="h-4 w-4 text-muted-foreground" />
            </CardHeader>
            <CardContent>
              <div className="text-2xl font-bold">0 KRWC</div>
              <p className="text-xs text-muted-foreground">
                Total interest earned
              </p>
            </CardContent>
          </Card>
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
              <div className="space-y-2">
                <p className="text-sm font-medium">Token Options:</p>
                <ul className="text-sm text-muted-foreground space-y-1">
                  <li>• Hold for 3-5% annual yield</li>
                  <li>• Sell for immediate liquidity</li>
                  <li>• Trade on secondary markets</li>
                  <li>• Automatic yield accumulation</li>
                </ul>
              </div>
              <div className="flex gap-2">
                <Button className="flex-1">
                  <TrendingUp className="w-4 h-4 mr-2" />
                  Hold & Earn
                </Button>
                <Button variant="outline" className="flex-1">
                  <Banknote className="w-4 h-4 mr-2" />
                  Sell Tokens
                </Button>
              </div>
            </CardContent>
          </Card>

          <Card>
            <CardHeader>
              <CardTitle className="flex items-center gap-2">
                <Home className="w-5 h-5" />
                Property Management
              </CardTitle>
              <CardDescription>
                Manage your rental properties and contracts
              </CardDescription>
            </CardHeader>
            <CardContent className="space-y-4">
              <div className="text-center py-8 text-muted-foreground">
                <Home className="w-12 h-12 mx-auto mb-4 opacity-50" />
                <p>No properties listed</p>
                <p className="text-sm">Add your first property to start earning</p>
              </div>
              <Button className="w-full">
                <Home className="w-4 h-4 mr-2" />
                Add Property
              </Button>
            </CardContent>
          </Card>
        </div>

        <div className="mt-16">
          <Card>
            <CardHeader>
              <CardTitle>How It Works for Landlords</CardTitle>
              <CardDescription>
                Understanding your benefits and responsibilities
              </CardDescription>
            </CardHeader>
            <CardContent>
              <div className="grid gap-4 md:grid-cols-4">
                <div className="text-center space-y-2">
                  <div className="w-12 h-12 bg-primary/10 rounded-lg flex items-center justify-center mx-auto">
                    <Coins className="w-6 h-6 text-primary" />
                  </div>
                  <h3 className="font-medium">1. Receive yKRWC</h3>
                  <p className="text-sm text-muted-foreground">
                    Get yield-bearing tokens when tenant deposits
                  </p>
                </div>
                <div className="text-center space-y-2">
                  <div className="w-12 h-12 bg-primary/10 rounded-lg flex items-center justify-center mx-auto">
                    <TrendingUp className="w-6 h-6 text-primary" />
                  </div>
                  <h3 className="font-medium">2. Earn Yield</h3>
                  <p className="text-sm text-muted-foreground">
                    Tokens automatically earn 3-5% annual yield
                  </p>
                </div>
                <div className="text-center space-y-2">
                  <div className="w-12 h-12 bg-primary/10 rounded-lg flex items-center justify-center mx-auto">
                    <Banknote className="w-6 h-6 text-primary" />
                  </div>
                  <h3 className="font-medium">3. Choose Option</h3>
                  <p className="text-sm text-muted-foreground">
                    Hold for yield or sell for immediate cash
                  </p>
                </div>
                <div className="text-center space-y-2">
                  <div className="w-12 h-12 bg-primary/10 rounded-lg flex items-center justify-center mx-auto">
                    <Clock className="w-6 h-6 text-primary" />
                  </div>
                  <h3 className="font-medium">4. Contract End</h3>
                  <p className="text-sm text-muted-foreground">
                    Return deposit or become debtor with assignee system
                  </p>
                </div>
              </div>
            </CardContent>
          </Card>
        </div>
      </main>

      <Footer />
    </div>
  )
}