'use client'

import { useCallback } from 'react'
import { useToast } from '@/components/ui/toast-provider'

export function useGlobalToast() {
  const { showToast } = useToast()

  const success = useCallback((title: string, message: string, duration?: number) => {
    showToast({ title, message, type: 'success', duration })
  }, [showToast])

  const error = useCallback((title: string, message: string, duration?: number) => {
    showToast({ title, message, type: 'error', duration })
  }, [showToast])

  const warning = useCallback((title: string, message: string, duration?: number) => {
    showToast({ title, message, type: 'warning', duration })
  }, [showToast])

  const info = useCallback((title: string, message: string, duration?: number) => {
    showToast({ title, message, type: 'info', duration })
  }, [showToast])

  return { success, error, warning, info }
}