'use client'

import { ReactNode } from 'react'
import { Dialog, DialogContent, DialogHeader, DialogTitle } from '@/components/ui/dialog'

interface GlobalModalProps {
  open: boolean
  onOpenChange: (open: boolean) => void
  title: string
  children: ReactNode
  size?: 'sm' | 'md' | 'lg' | 'xl'
  className?: string
}

const sizeClasses = {
  sm: 'sm:max-w-[400px]',
  md: 'sm:max-w-[500px]',
  lg: 'sm:max-w-[600px]',
  xl: 'sm:max-w-[800px]'
}

export function GlobalModal({ 
  open, 
  onOpenChange, 
  title, 
  children, 
  size = 'md',
  className = ''
}: GlobalModalProps) {
  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className={`${sizeClasses[size]} ${className} flex flex-col`}>
        <DialogHeader className="flex-shrink-0">
          <DialogTitle className="text-lg font-semibold">
            {title}
          </DialogTitle>
        </DialogHeader>
        <div className="flex-1 overflow-y-auto min-h-0 p-2">
          {children}
        </div>
      </DialogContent>
    </Dialog>
  )
}