'use client'

import React from 'react'
import { createPortal } from 'react-dom'
import { useToast, Toast } from './toast-provider'
import { X, CheckCircle, XCircle, AlertCircle, Info } from 'lucide-react'

const typeConfig = {
  success: {
    icon: CheckCircle,
    bgColor: 'bg-green-50 dark:bg-green-900',
    borderColor: 'border-green-200 dark:border-green-700',
    iconColor: 'text-green-600 dark:text-green-400',
    titleColor: 'text-green-800 dark:text-green-200'
  },
  error: {
    icon: XCircle,
    bgColor: 'bg-red-50 dark:bg-red-900',
    borderColor: 'border-red-200 dark:border-red-700',
    iconColor: 'text-red-600 dark:text-red-400',
    titleColor: 'text-red-800 dark:text-red-200'
  },
  warning: {
    icon: AlertCircle,
    bgColor: 'bg-yellow-50 dark:bg-yellow-900',
    borderColor: 'border-yellow-200 dark:border-yellow-700',
    iconColor: 'text-yellow-600 dark:text-yellow-400',
    titleColor: 'text-yellow-800 dark:text-yellow-200'
  },
  info: {
    icon: Info,
    bgColor: 'bg-blue-50 dark:bg-blue-900',
    borderColor: 'border-blue-200 dark:border-blue-700',
    iconColor: 'text-blue-600 dark:text-blue-400',
    titleColor: 'text-blue-800 dark:text-blue-200'
  }
}

function ToastItem({ toast, onRemove }: { toast: Toast; onRemove: (id: string) => void }) {
  const config = typeConfig[toast.type]
  const IconComponent = config.icon

  return (
    <div 
      className={`
        ${config.bgColor} 
        ${config.borderColor} 
        border rounded-lg p-4 shadow-lg min-w-[350px] max-w-[500px]
        animate-in slide-in-from-right-full duration-300
        relative
      `}
      onClick={(e) => {
        e.stopPropagation()
        e.preventDefault()
      }}
      onPointerDown={(e) => {
        e.stopPropagation()
        e.preventDefault()
      }}
    >
      <div className="flex items-start gap-3">
        <IconComponent className={`w-5 h-5 ${config.iconColor} mt-0.5 flex-shrink-0`} />
        <div className="flex-1 min-w-0">
          <h4 className={`font-medium text-sm ${config.titleColor} mb-1`}>
            {toast.title}
          </h4>
          <p className="text-sm text-gray-700 dark:text-gray-300 break-words">
            {toast.message}
          </p>
        </div>
        <button
          type="button"
          onClick={(e) => {
            e.stopPropagation()
            e.preventDefault()
            e.nativeEvent.stopImmediatePropagation()
            onRemove(toast.id)
            return false
          }}
          onMouseDown={(e) => {
            e.stopPropagation()
            e.preventDefault()
            return false
          }}
          onPointerDown={(e) => {
            e.stopPropagation()
            e.preventDefault()
            return false
          }}
          onTouchStart={(e) => {
            e.stopPropagation()
            e.preventDefault()
            return false
          }}
          className="flex-shrink-0 p-1 rounded-md hover:bg-black/5 dark:hover:bg-white/5 transition-colors"
          style={{ isolation: 'isolate' }}
        >
          <X className="w-4 h-4 text-gray-500" />
        </button>
      </div>
    </div>
  )
}

export function ToastContainer() {
  const { toasts, removeToast } = useToast()

  if (toasts.length === 0) return null

  // Portal을 사용해서 body에 직접 렌더링
  if (typeof window === 'undefined') return null

  return createPortal(
    <div className="fixed bottom-4 right-4 z-[99999] space-y-2 pointer-events-none">
      <div 
        className="space-y-2 pointer-events-auto"
        onClick={(e) => {
          e.stopPropagation()
          e.preventDefault()
        }}
      >
        {toasts.map((toast) => (
          <ToastItem 
            key={toast.id} 
            toast={toast} 
            onRemove={removeToast} 
          />
        ))}
      </div>
    </div>,
    document.body
  )
}