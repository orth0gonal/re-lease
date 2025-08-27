'use client'

import { useState } from 'react'
import { WalletConnectButton } from '@/components/wallet/wallet-connect-button'
import { MobileWalletInfo } from '@/components/wallet/mobile-wallet-info'
import { ThemeToggle } from '@/components/theme-toggle'
import { Logo } from '@/components/ui/logo'
import { Navigation } from '@/components/ui/navigation'
import { Button } from '@/components/ui/button'
import { Menu, X } from 'lucide-react'
import { cn } from '@/lib/utils'

export function Navbar() {
  const [isMenuOpen, setIsMenuOpen] = useState(false)

  const toggleMenu = () => setIsMenuOpen(!isMenuOpen)
  const closeMenu = () => setIsMenuOpen(false)

  return (
    <header className="border-b border-gray-200/50 dark:border-gray-700/50 bg-background/95 backdrop-blur supports-[backdrop-filter]:bg-background/60">
      <div className="container mx-auto px-4 h-16 flex items-center justify-between">
        <div className="flex items-center space-x-8">
          <Logo />
          <Navigation className="hidden md:flex" />
        </div>
        
        {/* Desktop: Theme + Wallet */}
        <div className="hidden md:flex items-center space-x-4">
          <ThemeToggle />
          <WalletConnectButton />
        </div>

        {/* Mobile: Wallet + Hamburger Menu */}
        <div className="md:hidden flex items-center space-x-2">
          <WalletConnectButton />
          <Button
            variant="ghost"
            size="sm"
            onClick={toggleMenu}
            aria-label="Toggle menu"
          >
            {isMenuOpen ? <X className="h-5 w-5" /> : <Menu className="h-5 w-5" />}
          </Button>
        </div>
      </div>

      {/* Mobile Navigation Menu */}
      <div className={cn(
        "md:hidden border-t border-gray-200/50 dark:border-gray-700/50 bg-background/95 backdrop-blur transition-all duration-200 ease-in-out",
        isMenuOpen ? "block" : "hidden"
      )}>
        <div className="container mx-auto px-4 py-3">
          {/* Controls: Theme + Chain + Balance (at top) */}
          <div className="mb-3 pb-3 border-b border-gray-200/50 dark:border-gray-700/50">
            <MobileWalletInfo />
          </div>
          
          {/* Navigation Items (at bottom) */}
          <Navigation className="flex flex-col space-y-2 space-x-0" onItemClick={closeMenu} />
        </div>
      </div>
    </header>
  )
}