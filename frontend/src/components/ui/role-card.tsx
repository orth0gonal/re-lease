'use client'

import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card'
import { LucideIcon } from 'lucide-react'
import { cn } from '@/lib/utils'

interface RoleCardProps {
  title: string
  description: string
  icon: LucideIcon
  color: 'blue' | 'green' | 'purple'
  onClick?: () => void
  className?: string
}

export function RoleCard({ 
  title, 
  description, 
  icon: Icon, 
  color, 
  onClick,
  className 
}: RoleCardProps) {
  const colorClasses = {
    blue: {
      card: 'border-blue-200/50 hover:border-blue-300 dark:border-blue-800/50 dark:hover:border-blue-700 hover:bg-blue-50/50 dark:hover:bg-blue-950/50 hover:shadow-blue-200/25 dark:hover:shadow-blue-800/25',
      icon: 'text-blue-600 dark:text-blue-400 group-hover:text-blue-700 dark:group-hover:text-blue-300',
      iconBg: 'bg-blue-50 border-blue-200 group-hover:bg-blue-100 group-hover:border-blue-300 dark:bg-blue-950/50 dark:border-blue-800 dark:group-hover:bg-blue-900 dark:group-hover:border-blue-700'
    },
    green: {
      card: 'border-green-200/50 hover:border-green-300 dark:border-green-800/50 dark:hover:border-green-700 hover:bg-green-50/50 dark:hover:bg-green-950/50 hover:shadow-green-200/25 dark:hover:shadow-green-800/25',
      icon: 'text-green-600 dark:text-green-400 group-hover:text-green-700 dark:group-hover:text-green-300',
      iconBg: 'bg-green-50 border-green-200 group-hover:bg-green-100 group-hover:border-green-300 dark:bg-green-950/50 dark:border-green-800 dark:group-hover:bg-green-900 dark:group-hover:border-green-700'
    },
    purple: {
      card: 'border-purple-200/50 hover:border-purple-300 dark:border-purple-800/50 dark:hover:border-purple-700 hover:bg-purple-50/50 dark:hover:bg-purple-950/50 hover:shadow-purple-200/25 dark:hover:shadow-purple-800/25',
      icon: 'text-purple-600 dark:text-purple-400 group-hover:text-purple-700 dark:group-hover:text-purple-300',
      iconBg: 'bg-purple-50 border-purple-200 group-hover:bg-purple-100 group-hover:border-purple-300 dark:bg-purple-950/50 dark:border-purple-800 dark:group-hover:bg-purple-900 dark:group-hover:border-purple-700'
    }
  }

  const colors = colorClasses[color]

  return (
    <Card 
      className={cn(
        'relative h-full transition-all duration-300 cursor-pointer group select-none',
        'min-h-[240px] p-4 sm:p-6 border-2',
        'hover:shadow-xl hover:-translate-y-2 active:translate-y-0 active:shadow-lg',
        'focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2',
        colors.card,
        className
      )}
      onClick={onClick}
      role="button"
      tabIndex={0}
      onKeyDown={(e) => {
        if (e.key === 'Enter' || e.key === ' ') {
          e.preventDefault()
          onClick?.()
        }
      }}
    >
      <CardHeader className="text-center pb-6 space-y-4">
        <div className={cn(
          'mx-auto p-4 rounded-full w-fit transition-all duration-300',
          'group-hover:scale-110 group-active:scale-105 shadow-sm group-hover:shadow-md',
          colors.iconBg
        )}>
          <Icon className={cn('h-8 w-8 sm:h-10 sm:w-10 transition-colors duration-300', colors.icon)} />
        </div>
        <CardTitle className="text-xl sm:text-2xl font-bold group-hover:scale-105 transition-transform duration-300">
          {title}
        </CardTitle>
      </CardHeader>
      <CardContent className="text-center px-2 sm:px-4">
        <CardDescription className="text-base sm:text-lg leading-relaxed font-medium group-hover:opacity-90 transition-opacity duration-300">
          {description}
        </CardDescription>
      </CardContent>
    </Card>
  )
}