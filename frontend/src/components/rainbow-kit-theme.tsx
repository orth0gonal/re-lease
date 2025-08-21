'use client'

import { ReactNode, useEffect, useState } from 'react'
import { RainbowKitProvider, lightTheme, darkTheme } from '@rainbow-me/rainbowkit'
import { useTheme } from 'next-themes'

import '@rainbow-me/rainbowkit/styles.css'

interface RainbowKitThemeProviderProps {
  children: ReactNode
}

export function RainbowKitThemeProvider({ children }: RainbowKitThemeProviderProps) {
  const { theme } = useTheme()
  const [mounted, setMounted] = useState(false)

  useEffect(() => {
    setMounted(true)
  }, [])

  if (!mounted) {
    return (
      <RainbowKitProvider
        theme={lightTheme({
          accentColor: '#00D9FF',
          accentColorForeground: 'white',
          borderRadius: 'medium',
          fontStack: 'system',
          overlayBlur: 'small',
        })}
        showRecentTransactions={true}
      >
        {children}
      </RainbowKitProvider>
    )
  }

  return (
    <RainbowKitProvider
      theme={theme === 'dark' ? darkTheme({
        accentColor: '#00D9FF',
        accentColorForeground: 'white',
        borderRadius: 'medium',
        fontStack: 'system',
        overlayBlur: 'small',
      }) : lightTheme({
        accentColor: '#00D9FF',
        accentColorForeground: 'white',
        borderRadius: 'medium',
        fontStack: 'system',
        overlayBlur: 'small',
      })}
      showRecentTransactions={true}
    >
      {children}
    </RainbowKitProvider>
  )
}