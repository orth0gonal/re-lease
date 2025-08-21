import React from 'react'

interface LogoProps {
  className?: string
  size?: 'sm' | 'md' | 'lg'
}

export function Logo({ className = '', size = 'md' }: LogoProps) {
  const sizeClasses = {
    sm: 'w-6 h-6',
    md: 'w-8 h-8',
    lg: 'w-12 h-12'
  }

  return (
    <div className={`flex items-center space-x-2 ${className}`}>
      <svg
        viewBox="0 0 40 40"
        className={`${sizeClasses[size]} text-primary`}
        fill="none"
        xmlns="http://www.w3.org/2000/svg"
      >
        {/* Outer circle representing blockchain/network */}
        <circle
          cx="20"
          cy="20"
          r="18"
          stroke="currentColor"
          strokeWidth="2"
          className="opacity-30"
        />
        
        {/* Inner geometric pattern representing "release" concept */}
        <g className="text-primary">
          {/* Central release symbol - stylized "r" with arrow */}
          <path
            d="M12 12 L12 28 M12 12 L20 12 Q24 12 24 16 Q24 20 20 20 L12 20 M18 20 L24 28"
            stroke="currentColor"
            strokeWidth="2.5"
            strokeLinecap="round"
            strokeLinejoin="round"
            fill="none"
          />
          
          {/* Release arrow/indicator */}
          <path
            d="M26 14 L30 18 L26 22 M28 18 L22 18"
            stroke="currentColor"
            strokeWidth="2"
            strokeLinecap="round"
            strokeLinejoin="round"
            fill="none"
            className="opacity-80"
          />
        </g>
        
        {/* Decorative dots representing network nodes */}
        <circle cx="8" cy="20" r="1.5" fill="currentColor" className="opacity-40" />
        <circle cx="32" cy="20" r="1.5" fill="currentColor" className="opacity-40" />
        <circle cx="20" cy="8" r="1.5" fill="currentColor" className="opacity-40" />
        <circle cx="20" cy="32" r="1.5" fill="currentColor" className="opacity-40" />
      </svg>
      
      <span className="font-bold text-xl tracking-tight">
        re<span className="text-primary">:</span>Lease
      </span>
    </div>
  )
}

export function LogoIcon({ className = '', size = 'md' }: LogoProps) {
  const sizeClasses = {
    sm: 'w-6 h-6',
    md: 'w-8 h-8',
    lg: 'w-12 h-12'
  }

  return (
    <svg
      viewBox="0 0 40 40"
      className={`${sizeClasses[size]} text-primary ${className}`}
      fill="none"
      xmlns="http://www.w3.org/2000/svg"
    >
      {/* Outer circle representing blockchain/network */}
      <circle
        cx="20"
        cy="20"
        r="18"
        stroke="currentColor"
        strokeWidth="2"
        className="opacity-30"
      />
      
      {/* Inner geometric pattern representing "release" concept */}
      <g className="text-primary">
        {/* Central release symbol - stylized "r" with arrow */}
        <path
          d="M12 12 L12 28 M12 12 L20 12 Q24 12 24 16 Q24 20 20 20 L12 20 M18 20 L24 28"
          stroke="currentColor"
          strokeWidth="2.5"
          strokeLinecap="round"
          strokeLinejoin="round"
          fill="none"
        />
        
        {/* Release arrow/indicator */}
        <path
          d="M26 14 L30 18 L26 22 M28 18 L22 18"
          stroke="currentColor"
          strokeWidth="2"
          strokeLinecap="round"
          strokeLinejoin="round"
          fill="none"
          className="opacity-80"
        />
      </g>
      
      {/* Decorative dots representing network nodes */}
      <circle cx="8" cy="20" r="1.5" fill="currentColor" className="opacity-40" />
      <circle cx="32" cy="20" r="1.5" fill="currentColor" className="opacity-40" />
      <circle cx="20" cy="8" r="1.5" fill="currentColor" className="opacity-40" />
      <circle cx="20" cy="32" r="1.5" fill="currentColor" className="opacity-40" />
    </svg>
  )
}