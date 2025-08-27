'use client'

import Link from 'next/link'
import { usePathname } from 'next/navigation'
import { cn } from '@/lib/utils'
import { useMemo } from 'react'

const navigationItems = [
  { name: 'Tenant', href: '/tenant' },
  { name: 'Landlord', href: '/landlord' },
  { name: 'Assignee', href: '/assignee' }
]

interface NavigationProps {
  className?: string
  onItemClick?: () => void
}

export function Navigation({ className, onItemClick }: NavigationProps) {
  const pathname = usePathname()

  // Memoize the navigation items to prevent unnecessary re-renders
  const memoizedItems = useMemo(() => {
    return navigationItems.map((item) => ({
      ...item,
      isActive: pathname === item.href
    }))
  }, [pathname])

  const handleItemClick = () => {
    if (onItemClick) {
      onItemClick()
    }
  }

  return (
    <nav className={cn('flex items-center space-x-6', className)}>
      {memoizedItems.map((item) => (
        <Link
          key={item.href}
          href={item.href}
          prefetch={true}
          onClick={handleItemClick}
          className={cn(
            'text-sm font-medium transition-colors hover:text-primary',
            item.isActive
              ? 'text-foreground'
              : 'text-muted-foreground'
          )}
        >
          {item.name}
        </Link>
      ))}
    </nav>
  )
}