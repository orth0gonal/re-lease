'use client'

import { Navbar } from '@/components/ui/navbar'
import { Footer } from '@/components/ui/footer'
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card'
import { Button } from '@/components/ui/button'
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

        <div className="grid gap-6 md:grid-cols-2 lg:grid-cols-3 mb-16">
          <Card>
            <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
              <CardTitle className="text-sm font-medium">
                Available Investments
              </CardTitle>
              <Building2 className="h-4 w-4 text-muted-foreground" />
            </CardHeader>
            <CardContent>
              <div className="text-2xl font-bold">0</div>
              <p className="text-xs text-muted-foreground">
                Defaulted contracts available
              </p>
            </CardContent>
          </Card>

          <Card>
            <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
              <CardTitle className="text-sm font-medium">
                My Investments
              </CardTitle>
              <DollarSign className="h-4 w-4 text-muted-foreground" />
            </CardHeader>
            <CardContent>
              <div className="text-2xl font-bold">0 KRWC</div>
              <p className="text-xs text-muted-foreground">
                Total invested amount
              </p>
            </CardContent>
          </Card>

          <Card>
            <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
              <CardTitle className="text-sm font-medium">
                Expected Returns
              </CardTitle>
              <TrendingUp className="h-4 w-4 text-muted-foreground" />
            </CardHeader>
            <CardContent>
              <div className="text-2xl font-bold">5-8%</div>
              <p className="text-xs text-muted-foreground">
                Annual return + 5% interest
              </p>
            </CardContent>
          </Card>
        </div>

        <div className="grid gap-8 md:grid-cols-2 mb-16">
          <Card>
            <CardHeader>
              <CardTitle className="flex items-center gap-2">
                <Search className="w-5 h-5" />
                Browse Opportunities
              </CardTitle>
              <CardDescription>
                Find debt-credit relationships with real estate backing
              </CardDescription>
            </CardHeader>
            <CardContent className="space-y-4">
              <div className="space-y-2">
                <p className="text-sm font-medium">Investment Features:</p>
                <ul className="text-sm text-muted-foreground space-y-1">
                  <li>• Real estate collateral backing</li>
                  <li>• Priority recovery under Korean law</li>
                  <li>• 5% annual interest from landlords</li>
                  <li>• Transparent smart contracts</li>
                </ul>
              </div>
              <div className="text-center py-8 text-muted-foreground">
                <Building2 className="w-12 h-12 mx-auto mb-4 opacity-50" />
                <p>No opportunities available</p>
                <p className="text-sm">Check back later for new investments</p>
              </div>
            </CardContent>
          </Card>

          <Card>
            <CardHeader>
              <CardTitle className="flex items-center gap-2">
                <Users className="w-5 h-5" />
                My Portfolio
              </CardTitle>
              <CardDescription>
                Track your investments and returns
              </CardDescription>
            </CardHeader>
            <CardContent className="space-y-4">
              <div className="text-center py-8 text-muted-foreground">
                <TrendingUp className="w-12 h-12 mx-auto mb-4 opacity-50" />
                <p>No investments yet</p>
                <p className="text-sm">Purchase your first debt-credit relationship to start earning</p>
              </div>
              <Button className="w-full" disabled>
                <Search className="w-4 h-4 mr-2" />
                View Portfolio
              </Button>
            </CardContent>
          </Card>
        </div>

        <div className="mt-16">
          <Card>
            <CardHeader>
              <CardTitle>How Assignee Investment Works</CardTitle>
              <CardDescription>
                Understanding your role in the debt recovery system
              </CardDescription>
            </CardHeader>
            <CardContent>
              <div className="grid gap-4 md:grid-cols-4">
                <div className="text-center space-y-2">
                  <div className="w-12 h-12 bg-primary/10 rounded-lg flex items-center justify-center mx-auto">
                    <Search className="w-6 h-6 text-primary" />
                  </div>
                  <h3 className="font-medium">1. Find Opportunity</h3>
                  <p className="text-sm text-muted-foreground">
                    Browse defaulted contracts with real estate backing
                  </p>
                </div>
                <div className="text-center space-y-2">
                  <div className="w-12 h-12 bg-primary/10 rounded-lg flex items-center justify-center mx-auto">
                    <DollarSign className="w-6 h-6 text-primary" />
                  </div>
                  <h3 className="font-medium">2. Purchase Debt</h3>
                  <p className="text-sm text-muted-foreground">
                    Buy the debt-credit relationship at market price
                  </p>
                </div>
                <div className="text-center space-y-2">
                  <div className="w-12 h-12 bg-primary/10 rounded-lg flex items-center justify-center mx-auto">
                    <Shield className="w-6 h-6 text-primary" />
                  </div>
                  <h3 className="font-medium">3. Legal Protection</h3>
                  <p className="text-sm text-muted-foreground">
                    Get priority rights under Housing Lease Protection Act
                  </p>
                </div>
                <div className="text-center space-y-2">
                  <div className="w-12 h-12 bg-primary/10 rounded-lg flex items-center justify-center mx-auto">
                    <TrendingUp className="w-6 h-6 text-primary" />
                  </div>
                  <h3 className="font-medium">4. Earn Returns</h3>
                  <p className="text-sm text-muted-foreground">
                    Collect 5% annual interest plus recovery proceeds
                  </p>
                </div>
              </div>
            </CardContent>
          </Card>
        </div>

        <div className="mt-16">
          <Card className="border-yellow-200 bg-yellow-50 dark:bg-yellow-950 dark:border-yellow-800">
            <CardHeader>
              <CardTitle className="text-yellow-800 dark:text-yellow-200">Investment Notice</CardTitle>
            </CardHeader>
            <CardContent>
              <p className="text-sm text-yellow-700 dark:text-yellow-300">
                <strong>Risk Disclosure:</strong> Investments in debt-credit relationships involve risk. 
                While backed by real estate collateral and Korean legal protections, returns are not guaranteed. 
                Please carefully review all investment terms and consider your risk tolerance before investing.
              </p>
            </CardContent>
          </Card>
        </div>
      </main>

      <Footer />
    </div>
  )
}