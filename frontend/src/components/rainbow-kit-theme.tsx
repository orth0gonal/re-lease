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

  // Use resolvedTheme for more accurate theme detection
  // During SSR, assume light theme, but after mounting use actual theme
  const isDark = mounted ? (resolvedTheme || theme) === 'dark' : 
                 (typeof window !== 'undefined' && 
                  (localStorage.getItem('theme') === 'dark' || 
                   (localStorage.getItem('theme') === 'system' && 
                    window.matchMedia('(prefers-color-scheme: dark)').matches)))
  
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