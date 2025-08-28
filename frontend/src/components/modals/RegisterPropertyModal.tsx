'use client'

import { useState, useEffect } from 'react'
import { useAccount, useWriteContract, useWaitForTransactionReceipt } from 'wagmi'
import { useConnectModal } from '@rainbow-me/rainbowkit'
import { keccak256, toBytes } from 'viem'
import { useGlobalToast } from '@/hooks/use-global-toast'
import { GlobalModal } from '@/components/ui/global-modal'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Textarea } from '@/components/ui/textarea'
import { AlertCircle, Loader2, Wallet } from 'lucide-react'
import { CONTRACTS, TRUST_AUTHORITY_ADDRESS } from '@/lib/constants'
import { PropertyNFTABI } from '@/lib/abis/PropertyNFT'

// Helper function to truncate text for better UI
const truncateText = (text: string, maxLength: number = 120): string => {
  if (text.length <= maxLength) return text
  return text.substring(0, maxLength).trim() + '...'
}

interface RegisterPropertyModalProps {
  open: boolean
  onOpenChange: (open: boolean) => void
}

export function RegisterPropertyModal({ open, onOpenChange }: RegisterPropertyModalProps) {
  const { address, isConnected } = useAccount()
  const { openConnectModal } = useConnectModal()
  const toast = useGlobalToast()
  const [formData, setFormData] = useState({
    registrationAddress: '',
    ltv: ''
  })
  const [timeoutId, setTimeoutId] = useState<NodeJS.Timeout | null>(null)

  const { 
    writeContract, 
    data: hash, 
    isPending, 
    error 
  } = useWriteContract()

  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({
    hash,
  })

  const handleOpenChange = (newOpen: boolean) => {
    if (!newOpen) {
      // Reset form when closing
      setFormData({ registrationAddress: '', ltv: '' })
    }
    onOpenChange(newOpen)
  }

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    
    // If wallet is not connected, open connect modal
    if (!address || !isConnected) {
      openConnectModal?.()
      return
    }

    try {
      // Convert registration address string to bytes32 hash
      const registrationAddressHash = keccak256(toBytes(formData.registrationAddress))
      
      // Set 20-second timeout for loading state
      const timeout = setTimeout(() => {
        toast.warning("Transaction Timeout", "Transaction is taking longer than expected. Please check your wallet.", 5000)
      }, 20000)
      
      setTimeoutId(timeout)
      
      console.log('Starting writeContract...')
      
      try {
        const result = await writeContract({
          address: CONTRACTS.PROPERTY_NFT,
          abi: PropertyNFTABI,
          functionName: 'registerProperty',
          args: [
            address, // landlord (connected wallet address)
            TRUST_AUTHORITY_ADDRESS, // trustAuthority (fixed address)
            BigInt(Number(formData.ltv)), // ltv as BigInt
            registrationAddressHash // registrationAddress as bytes32 hash
          ]
          // Let wagmi handle gas estimation automatically for better UX
        })
        
        console.log('WriteContract completed successfully:', result)
        
        // Clear timeout immediately after successful writeContract
        clearTimeout(timeout)
        setTimeoutId(null)
        
        // writeContract returns undefined initially - this is normal
        // The actual result comes later through the hash from useWaitForTransactionReceipt
        console.log('WriteContract returned:', result)
        
      } catch (writeError: any) {
        console.log('WriteContract threw an error:', writeError)
        
        // Clear timeout on writeContract error
        clearTimeout(timeout)
        setTimeoutId(null)
        throw writeError // Re-throw to be caught by outer catch
      }
    } catch (error: any) {
      console.log('Catch block executed with error:', error)
      // This catch block might not be needed since wagmi handles errors through the error state
      // Let the useEffect handle the error display
    }
  }

  const handleConnectWallet = () => {
    openConnectModal?.()
  }

  const isFormValid = formData.registrationAddress && formData.ltv && isConnected
  const isLoading = isPending || isConfirming

  // Handle successful transaction
  useEffect(() => {
    if (isSuccess && hash) {
      // Clear any remaining timeout when transaction is confirmed
      if (timeoutId) {
        clearTimeout(timeoutId)
        setTimeoutId(null)
      }
      
      toast.success(
        "Property Registration Successful! 🎉",
        `Your property has been registered and is now pending verification. Transaction: ${hash?.slice(0, 6)}...${hash?.slice(-4)}`,
        5000
      )
      
      // Close modal after showing toast
      setTimeout(() => {
        onOpenChange(false)
      }, 1000)
    }
  }, [isSuccess, hash, onOpenChange, timeoutId])

  // Handle wagmi error state (for user rejection)
  useEffect(() => {
    if (error) {
      console.log('Wagmi error detected:', error)
      
      // Clear timeout on error
      if (timeoutId) {
        clearTimeout(timeoutId)
        setTimeoutId(null)
      }
      
      // Handle different types of errors - check multiple conditions
      const isUserRejection = 
        error?.code === 4001 || 
        error?.code === 'ACTION_REJECTED' ||
        error?.name === 'UserRejectedRequestError' ||
        error?.message?.toLowerCase().includes('rejected') || 
        error?.message?.toLowerCase().includes('denied') ||
        error?.message?.toLowerCase().includes('cancelled') ||
        error?.message?.toLowerCase().includes('user rejected') ||
        error?.message?.toLowerCase().includes('user denied') ||
        error?.cause?.code === 4001
      
      if (isUserRejection) {
        toast.error("Transaction Cancelled", "Transaction was cancelled by user.", 5000)
      } else {
        const errorMessage = error.message || "Failed to register property. Please try again."
        toast.error("Registration Failed", truncateText(errorMessage), 5000)
      }
    }
  }, [error, timeoutId])

  // Cleanup timeout on component unmount
  useEffect(() => {
    return () => {
      if (timeoutId) {
        clearTimeout(timeoutId)
      }
    }
  }, [timeoutId])

  return (
    <GlobalModal
      open={open}
      onOpenChange={handleOpenChange}
      title="Register Property"
      size="md"
    >
      <form onSubmit={handleSubmit} className="space-y-4">
        <div className="space-y-2">
          <Label htmlFor="registrationAddress">Registration Address</Label>
          <Textarea
            id="registrationAddress"
            value={formData.registrationAddress}
            onChange={(e) => setFormData(prev => ({ ...prev, registrationAddress: e.target.value }))}
            placeholder="Enter the official registration address..."
            disabled={isLoading}
            rows={3}
          />
          <p className="text-xs text-muted-foreground">
            Official registration address as recorded in government registry
          </p>
        </div>

        <div className="space-y-2">
          <Label htmlFor="ltv">LTV Ratio (%)</Label>
          <Input
            id="ltv"
            type="number"
            min="0"
            max="100"
            value={formData.ltv}
            onChange={(e) => setFormData(prev => ({ ...prev, ltv: e.target.value }))}
            placeholder="70"
            disabled={isLoading}
          />
          <p className="text-xs text-muted-foreground">
            Loan-to-Value ratio as percentage (e.g., 70 for 70%)
          </p>
        </div>

        <div className="bg-blue-50 dark:bg-blue-950/30 border border-blue-200 dark:border-blue-800 rounded-lg p-3">
          <div className="flex items-start gap-2">
            <AlertCircle className="w-4 h-4 text-blue-600 dark:text-blue-400 mt-0.5 flex-shrink-0" />
            <div className="text-xs text-blue-700 dark:text-blue-300">
              <p className="font-medium mb-1">Registration Process:</p>
              <ul className="space-y-1 list-disc list-inside ml-2">
                <li>Property will be in PENDING status for 14 days</li>
                <li>Verifier will approve or reject the property</li>
                <li>Only approved properties can create rental contracts</li>
              </ul>
            </div>
          </div>
        </div>

        <div className="flex gap-2 pt-2">
          <Button
            type="button"
            variant="outline"
            onClick={() => onOpenChange(false)}
            disabled={isLoading}
            className="flex-1"
          >
            Cancel
          </Button>
          
          {!isConnected ? (
            <Button
              type="button"
              onClick={handleConnectWallet}
              className="flex-1"
            >
              <Wallet className="w-4 h-4 mr-2" />
              Connect Wallet
            </Button>
          ) : (
            <Button
              type="submit"
              disabled={!isFormValid || isLoading}
              className="flex-1"
            >
              {isLoading ? (
                <>
                  <Loader2 className="w-4 h-4 mr-2 animate-spin" />
                  Registering...
                </>
              ) : (
                'Register Property'
              )}
            </Button>
          )}
        </div>
      </form>
    </GlobalModal>
  )
}