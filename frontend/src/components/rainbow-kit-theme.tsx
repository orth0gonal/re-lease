'use client'

import { ReactNode, useEffect, useState } from 'react'
import { RainbowKitProvider, lightTheme, darkTheme } from '@rainbow-me/rainbowkit'
import { useTheme } from 'next-themes'

import '@rainbow-me/rainbowkit/styles.css'

interface RainbowKitThemeProviderProps {
  children: ReactNode
}

export function RainbowKitThemeProvider({ children }: RainbowKitThemeProviderProps) {
  const { theme, resolvedTheme } = useTheme()
  const [mounted, setMounted] = useState(false)

  useEffect(() => {
    setMounted(true)
  }, [])

  // Prevent hydration mismatch by always using false on server
  const isDark = mounted ? (resolvedTheme || theme) === 'dark' : false
  
  const currentTheme = isDark ? darkTheme({
    accentColor: '#BFF009',
    accentColorForeground: 'black',
    borderRadius: 'medium',
    fontStack: 'system',
    overlayBlur: 'small',
  }) : lightTheme({
    accentColor: '#BFF009',
    accentColorForeground: 'black',
    borderRadius: 'medium',
    fontStack: 'system',
    overlayBlur: 'small',
  })

  if (!mounted) {
    return (
      <RainbowKitProvider
        theme={currentTheme}
        showRecentTransactions={true}
        modalSize="compact"
        initialChain={undefined}
      >
        {children}
      </RainbowKitProvider>
    )
  }

  return (
    <RainbowKitProvider
      theme={currentTheme}
      showRecentTransactions={true}
      modalSize="compact"
      initialChain={undefined}
    >
      {children}
    </RainbowKitProvider>
  )
}