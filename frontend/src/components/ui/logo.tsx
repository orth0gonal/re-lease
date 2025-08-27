import React from 'react'
import Image from 'next/image'

interface LogoProps {
  className?: string
  size?: 'sm' | 'md' | 'lg'
}

export function Logo({ className = '', size = 'md' }: LogoProps) {
  const sizeClasses = {
    sm: 'h-6',
    md: 'h-8',
    lg: 'h-12'
  }

  return (
    <>
      <Image
        src="/logo-release-black-transparent.png"
        alt="re:Lease"
        width={0}
        height={0}
        sizes="100vw"
        className={`${sizeClasses[size]} w-auto block dark:hidden ${className}`}
        priority
      />
      <Image
        src="/logo-release-white-transparent.png"
        alt="re:Lease"
        width={0}
        height={0}
        sizes="100vw"
        className={`${sizeClasses[size]} w-auto hidden dark:block ${className}`}
        priority
      />
    </>
  )
}

export function LogoIcon({ className = '', size = 'md' }: LogoProps) {
  const sizeClasses = {
    sm: 'h-6',
    md: 'h-8',
    lg: 'h-12'
  }

  return (
    <>
      <Image
        src="/logo-release-black-transparent.png"
        alt="re:Lease"
        width={0}
        height={0}
        sizes="100vw"
        className={`${sizeClasses[size]} w-auto block dark:hidden ${className}`}
        priority
      />
      <Image
        src="/logo-release-white-transparent.png"
        alt="re:Lease"
        width={0}
        height={0}
        sizes="100vw"
        className={`${sizeClasses[size]} w-auto hidden dark:block ${className}`}
        priority
      />
    </>
  )
}