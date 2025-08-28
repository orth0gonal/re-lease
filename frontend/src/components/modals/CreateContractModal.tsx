'use client'

import { useState, useEffect } from 'react'
import { useAccount, useWriteContract, useWaitForTransactionReceipt } from 'wagmi'
import { useConnectModal } from '@rainbow-me/rainbowkit'
import { isAddress, parseUnits } from 'viem'
import { useGlobalToast } from '@/hooks/use-global-toast'
import { GlobalModal } from '@/components/ui/global-modal'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { AlertCircle, Loader2, Wallet, Building, Calendar } from 'lucide-react'
import { CONTRACTS } from '@/lib/constants'
import { PropertyNFTABI } from '@/lib/abis/PropertyNFT'

interface CreateContractModalProps {
  open: boolean
  onOpenChange: (open: boolean) => void
}

// Mock property data - in real app this would come from smart contract
// NOTE: These mock IDs should be replaced with actual NFT token IDs from the blockchain
const mockProperties = [
  {
    id: 1, // This should be actual NFT token ID, not property ID
    address: "서울시 강남구 역삼동 123-45",
    ltv: 70,
    status: "VERIFIED"
  },
  {
    id: 2,
    address: "서울시 서초구 서초동 678-90",
    ltv: 75,
    status: "VERIFIED"
  },
  {
    id: 3,
    address: "서울시 종로구 종로1가 100-1",
    ltv: 65,
    status: "VERIFIED"
  },
  {
    id: 4,
    address: "서울시 마포구 홍대앞 200-15",
    ltv: 80,
    status: "VERIFIED"
  },
  {
    id: 5,
    address: "서울시 송파구 잠실동 300-22",
    ltv: 72,
    status: "VERIFIED"
  },
  {
    id: 6,
    address: "서울시 영등포구 여의도동 400-33",
    ltv: 68,
    status: "VERIFIED"
  },
  {
    id: 7,
    address: "서울시 용산구 이태원동 500-44",
    ltv: 78,
    status: "VERIFIED"
  },
  {
    id: 8,
    address: "서울시 성북구 성북동 600-55",
    ltv: 73,
    status: "VERIFIED"
  },
  {
    id: 9,
    address: "서울시 동작구 사당동 700-66",
    ltv: 69,
    status: "VERIFIED"
  },
  {
    id: 10,
    address: "서울시 관악구 신림동 800-77",
    ltv: 74,
    status: "VERIFIED"
  }
]

// Helper function to truncate text for better UI
const truncateText = (text: string, maxLength: number = 120): string => {
  if (text.length <= maxLength) return text
  return text.substring(0, maxLength).trim() + '...'
}

export function CreateContractModal({ open, onOpenChange }: CreateContractModalProps) {
  const { address, isConnected } = useAccount()
  const { openConnectModal } = useConnectModal()
  const toast = useGlobalToast()
  
  const [selectedProperty, setSelectedProperty] = useState<number | null>(null)
  const [formData, setFormData] = useState({
    tenant: '',
    contractStartDate: '',
    contractEndDate: '',
    principal: '',
    debtInterestRate: '5'
  })
  const [isLoadingTimeout, setIsLoadingTimeout] = useState(false)

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
      setSelectedProperty(null)
      setFormData({
        tenant: '',
        contractStartDate: '',
        contractEndDate: '',
        principal: '',
        debtInterestRate: '5'
      })
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

    // Validation
    if (!selectedProperty) {
      toast.error("Property Required", "Please select a property to create the contract.", 5000)
      return
    }

    if (!isAddress(formData.tenant)) {
      toast.error("Invalid Tenant Address", "Please enter a valid Ethereum address for the tenant.", 5000)
      return
    }

    if (Number(formData.debtInterestRate) < 5) {
      toast.error("Interest Rate Too Low", "Debt interest rate must be at least 5%.", 5000)
      return
    }

    try {
      // Validation failure for invalid NFT selection
      toast.error("Contract Creation Failed", "The selected property is not available for contract creation. Please select a valid NFT property.", 5000)
      return

      // Original code (commented out for mock environment)
      /*
      // Convert dates to timestamps (UNIX timestamp in seconds)
      const startTimestamp = Math.floor(new Date(formData.contractStartDate).getTime() / 1000)
      const endTimestamp = Math.floor(new Date(formData.contractEndDate).getTime() / 1000)
      
      // Convert percentage to basis points (5% = 500)
      const interestRateBasisPoints = BigInt(Number(formData.debtInterestRate) * 100)
      
      // Convert principal to Wei (18 decimals for KRWC token)
      const principalInWei = parseUnits(formData.principal, 18)
      
      // Set loading timeout
      setIsLoadingTimeout(true)
      const timeout = setTimeout(() => {
        setIsLoadingTimeout(false)
        toast({
          title: "Transaction Timeout",
          description: "Transaction took too long. Please try again.",
          variant: "destructive",
          duration: 5000,
        })
      }, 20000)
      
      await writeContract({
        address: CONTRACTS.PROPERTY_NFT,
        abi: PropertyNFTABI,
        functionName: 'createRentalContract',
        args: [
          BigInt(selectedProperty), // nftId
          formData.tenant as `0x${string}`, // tenant address
          BigInt(startTimestamp), // contractStartDate
          BigInt(endTimestamp), // contractEndDate
          principalInWei, // principal in Wei (18 decimals)
          interestRateBasisPoints // debtInterestRate in basis points
        ]
      })
      
      clearTimeout(timeout)
      setIsLoadingTimeout(false)
      */
    } catch (error: any) {
      console.error('Error creating rental contract:', error)
      console.error('Error details:', { 
        message: error?.message, 
        code: error?.code, 
        name: error?.name,
        cause: error?.cause,
        reason: error?.reason
      })
      
      // Handle different types of errors - check multiple conditions
      const isUserRejection = 
        error?.code === 4001 || 
        error?.code === 'ACTION_REJECTED' ||
        error?.name === 'UserRejectedRequestError' ||
        error?.message?.toLowerCase().includes('rejected') || 
        error?.message?.toLowerCase().includes('denied') ||
        error?.message?.toLowerCase().includes('cancelled') ||
        error?.message?.toLowerCase().includes('user rejected') ||
        error?.cause?.code === 4001 ||
        error?.reason?.includes('rejected')
      
      if (isUserRejection) {
        toast.error("Transaction Cancelled", "Transaction was cancelled by user.", 5000)
      } else {
        const errorMessage = error.message || "Failed to create rental contract. Please try again."
        toast.error("Contract Creation Failed", truncateText(errorMessage), 5000)
      }
    }
  }

  const handleConnectWallet = () => {
    openConnectModal?.()
  }

  const isFormValid = selectedProperty && formData.tenant && formData.contractStartDate && 
                     formData.contractEndDate && formData.principal && formData.debtInterestRate && isConnected
  const isLoading = isPending || isConfirming

  // Handle successful transaction
  useEffect(() => {
    if (isSuccess && hash) {
      toast.success(
        "Rental Contract Created! 🎉",
        `Your rental contract has been successfully created. Transaction: ${hash?.slice(0, 6)}...${hash?.slice(-4)}`,
        5000
      )
      
      // Close modal after showing toast
      setTimeout(() => {
        onOpenChange(false)
      }, 1000)
    }
  }, [isSuccess, hash, onOpenChange])


  return (
    <GlobalModal
      open={open}
      onOpenChange={handleOpenChange}
      title="Create Rental Contract"
      size="lg"
    >
      <form onSubmit={handleSubmit} className="space-y-6">
        {/* Property Selection */}
        <div className="space-y-3">
          <Label>Select Property</Label>
          <div className="max-h-48 overflow-y-auto border rounded-lg p-2 bg-muted/30">
            <div className="grid gap-2">
              {mockProperties.map((property) => (
                <Card 
                  key={property.id}
                  className={`cursor-pointer transition-all duration-200 border-2 ${
                    selectedProperty === property.id 
                      ? 'border-primary bg-primary/10 shadow-md scale-[1.02]' 
                      : 'border-muted hover:border-primary/50 hover:bg-primary/5 hover:shadow-sm'
                  }`}
                  onClick={() => setSelectedProperty(property.id)}
                >
                  <CardHeader className="pb-2 relative">
                    <CardTitle className="text-sm flex items-center gap-2">
                      <Building className={`w-4 h-4 ${selectedProperty === property.id ? 'text-primary' : ''}`} />
                      Property #{property.id}
                      {selectedProperty === property.id && (
                        <div className="absolute right-2 top-2 w-2 h-2 bg-primary rounded-full animate-pulse"></div>
                      )}
                    </CardTitle>
                  </CardHeader>
                  <CardContent className="space-y-1">
                    <p className="text-sm">{property.address}</p>
                    <div className="flex justify-between text-xs text-muted-foreground">
                      <span>LTV: {property.ltv}%</span>
                      <span className="text-green-600 font-medium">✓ {property.status}</span>
                    </div>
                  </CardContent>
                </Card>
              ))}
            </div>
          </div>
          <p className="text-xs text-muted-foreground">
            Select a verified property to create rental contract
          </p>
        </div>

        {/* Contract Details */}
        <div className="grid gap-4 md:grid-cols-2">
          <div className="space-y-2">
            <Label htmlFor="tenant">Tenant Address</Label>
            <Input
              id="tenant"
              value={formData.tenant}
              onChange={(e) => setFormData(prev => ({ ...prev, tenant: e.target.value }))}
              placeholder="0x..."
              disabled={isLoading}
            />
          </div>

          <div className="space-y-2">
            <Label htmlFor="principal">Principal Amount (KRWC)</Label>
            <Input
              id="principal"
              type="number"
              min="0"
              step="0.01"
              value={formData.principal}
              onChange={(e) => setFormData(prev => ({ ...prev, principal: e.target.value }))}
              placeholder="100000"
              disabled={isLoading}
            />
          </div>

          <div className="space-y-2">
            <Label htmlFor="startDate">Contract Start Date</Label>
            <Input
              id="startDate"
              type="date"
              value={formData.contractStartDate}
              onChange={(e) => setFormData(prev => ({ ...prev, contractStartDate: e.target.value }))}
              disabled={isLoading}
            />
          </div>

          <div className="space-y-2">
            <Label htmlFor="endDate">Contract End Date</Label>
            <Input
              id="endDate"
              type="date"
              value={formData.contractEndDate}
              onChange={(e) => setFormData(prev => ({ ...prev, contractEndDate: e.target.value }))}
              disabled={isLoading}
            />
          </div>

          <div className="space-y-2 md:col-span-2">
            <Label htmlFor="interestRate">Debt Interest Rate (%)</Label>
            <Input
              id="interestRate"
              type="number"
              min="5"
              step="0.1"
              value={formData.debtInterestRate}
              onChange={(e) => {
                const value = e.target.value
                setFormData(prev => ({ ...prev, debtInterestRate: value }))
              }}
              onBlur={(e) => {
                const value = parseFloat(e.target.value)
                if (value < 5 || isNaN(value)) {
                  setFormData(prev => ({ ...prev, debtInterestRate: '5' }))
                }
              }}
              placeholder="5.0"
              disabled={isLoading}
            />
            <p className="text-xs text-muted-foreground">
              Minimum 5% annual interest rate for debt conversion. Values below 5% will be auto-corrected.
            </p>
          </div>
        </div>

        <div className="bg-blue-50 dark:bg-blue-950/30 border border-blue-200 dark:border-blue-800 rounded-lg p-3">
          <div className="flex items-start gap-2">
            <AlertCircle className="w-4 h-4 text-blue-600 dark:text-blue-400 mt-0.5 flex-shrink-0" />
            <div className="text-xs text-blue-700 dark:text-blue-300">
              <p className="font-medium mb-1">Contract Terms:</p>
              <ul className="space-y-1 list-disc list-inside ml-2">
                <li>Tenant deposits KRWC, landlord receives yKRWC tokens</li>
                <li>If deposit not returned, automatic debt-credit conversion</li>
                <li>Assignee system provides tenant protection</li>
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
                  Creating...
                </>
              ) : (
                'Create Contract'
              )}
            </Button>
          )}
        </div>
      </form>
    </GlobalModal>
  )
}