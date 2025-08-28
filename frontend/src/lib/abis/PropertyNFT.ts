// PropertyNFT Contract ABI - registerProperty and createRentalContract functions
export const PropertyNFTABI = [
  {
    type: 'function',
    name: 'registerProperty',
    inputs: [
      {
        name: 'landlord',
        type: 'address',
        internalType: 'address'
      },
      {
        name: 'trustAuthority', 
        type: 'address',
        internalType: 'address'
      },
      {
        name: 'ltv',
        type: 'uint256',
        internalType: 'uint256'
      },
      {
        name: 'registrationAddress',
        type: 'bytes32',
        internalType: 'bytes32'
      }
    ],
    outputs: [
      {
        name: 'propertyId',
        type: 'uint256',
        internalType: 'uint256'
      }
    ],
    stateMutability: 'nonpayable'
  },
  {
    type: 'function',
    name: 'createRentalContract',
    inputs: [
      {
        name: 'nftId',
        type: 'uint256',
        internalType: 'uint256'
      },
      {
        name: 'tenant',
        type: 'address',
        internalType: 'address'
      },
      {
        name: 'contractStartDate',
        type: 'uint256',
        internalType: 'uint256'
      },
      {
        name: 'contractEndDate',
        type: 'uint256',
        internalType: 'uint256'
      },
      {
        name: 'principal',
        type: 'uint256',
        internalType: 'uint256'
      },
      {
        name: 'debtInterestRate',
        type: 'uint256',
        internalType: 'uint256'
      }
    ],
    outputs: [],
    stateMutability: 'nonpayable'
  }
] as const