// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./interfaces/Events.sol";
import "./interfaces/Structs.sol";

/**
 * @title PropertyNFT
 * @dev Re-Lease 플랫폼의 핵심 컨트랙트로, 부동산을 ERC-721 NFT로 토큰화하고 전세 계약의 전체 생명주기를 관리
 * Implemented according to docs.md specifications
 */
contract PropertyNFT is ERC721Enumerable, AccessControl, Pausable, ReentrancyGuard, IPropertyNFTEvents {
    // Role definitions
    bytes32 public constant PROPERTY_VERIFIER_ROLE = keccak256("PROPERTY_VERIFIER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    // State variables
    mapping(uint256 => Property) public properties;
    mapping(uint256 => RentalContract) public rentalContracts;
    
    uint256 private _propertyIdCounter = 1; // Start from 1 to avoid ID 0
    uint256 private _nextNftId = 1; // NFT IDs start from 1
    
    // Constants
    uint256 public constant VERIFICATION_PERIOD = 14 days;
    // uint256 public constant GRACE_PERIOD = 1 days;
    uint256 public constant GRACE_PERIOD = 1 seconds; // for prototyping


    /**
     * @dev Constructor initializes the contract
     */
    constructor() ERC721("Re-Lease Property", "RLP") {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(PROPERTY_VERIFIER_ROLE, msg.sender);
        _grantRole(PAUSER_ROLE, msg.sender);
    }

    /**
     * @dev 임대인이 매물을 제안합니다. Property.status가 PENDING 상태로 Property 구조체가 생성되며 14일의 검증 기간이 주어집니다.
     * @param landlord 임대인 이더리움 주소
     * @param trustAuthority 신탁사 이더리움 주소(없으면 zero address)
     * @param ltv LTV 비율
     * @param registrationAddress 등기 도로명 주소
     * @return propertyId The newly created property ID
     */
    function registerProperty(
        address landlord,
        address trustAuthority,
        uint256 ltv,
        bytes32 registrationAddress
    ) external whenNotPaused nonReentrant returns (uint256 propertyId) {
        require(landlord != address(0), "PropertyNFT: Invalid landlord address");
        require(registrationAddress != bytes32(0), "PropertyNFT: Registration address cannot be empty");
        require(ltv <= 10000, "PropertyNFT: LTV cannot exceed 100% (10000 basis points)");

        propertyId = _propertyIdCounter++;
        
        // Create property with PENDING status
        properties[propertyId] = Property({
            landlord: landlord,
            status: PropertyStatus.PENDING,
            trustAuthority: trustAuthority,
            registrationAddress: registrationAddress,
            ltv: ltv
        });

        emit PropertyProposed(
            propertyId,
            landlord,
            ltv,
            registrationAddress
        );

        return propertyId;
    }

    /**
     * @dev 검증자가 매물을 승인합니다. Property.status가 REGISTERED 상태로 변경되고 임대 가능한 상태가 됩니다.
     * @param propertyId The property ID to approve
     * @return nftId The newly minted NFT token ID
     */
    function approveProperty(uint256 propertyId) 
        external 
        onlyRole(PROPERTY_VERIFIER_ROLE) 
        whenNotPaused 
        returns (uint256 nftId) 
    {
        require(_propertyExists(propertyId), "PropertyNFT: Property does not exist");
        Property storage property = properties[propertyId];
        require(property.status == PropertyStatus.PENDING, "PropertyNFT: Property not in pending status");

        // Update property status to REGISTERED
        property.status = PropertyStatus.REGISTERED;
        
        // Mint NFT to landlord
        nftId = _nextNftId++;
        _mint(property.landlord, nftId);

        emit PropertyApproved(propertyId, msg.sender);
        emit PropertyStatusUpdated(propertyId, PropertyStatus.PENDING, PropertyStatus.REGISTERED);

        return nftId;
    }

    /**
     * @dev 검증자가 매물을 거부합니다. nft가 생성되지 않습니다.
     * @param propertyId The property ID to reject
     */
    function rejectProperty(uint256 propertyId) 
        external 
        onlyRole(PROPERTY_VERIFIER_ROLE) 
        whenNotPaused 
    {
        require(_propertyExists(propertyId), "PropertyNFT: Property does not exist");
        Property storage property = properties[propertyId];
        require(property.status == PropertyStatus.PENDING, "PropertyNFT: Property not in pending status");

        PropertyStatus oldStatus = property.status;
        property.status = PropertyStatus.SUSPENDED;

        emit PropertyRejected(propertyId, msg.sender, "Property rejected by verifier");
        emit PropertyStatusUpdated(propertyId, oldStatus, PropertyStatus.SUSPENDED);
    }

    /**
     * @dev 임대인이 특정 부동산에 대한 전세 계약을 생성합니다. 계약 생성 시 RentalContract.status가 PENDING 상태로 생성됩니다.
     * @param nftId 연관된 부동산 NFT ID
     * @param tenant 임차인 주소
     * @param contractStartDate 계약 시작 시간
     * @param contractEndDate 계약 만료 시간
     * @param principal 계약 보증금 (KRWC) - 원금
     * @param debtInterestRate 미상환 시 연간 이자율 (basis points, 예: 500 = 5%)
     */
    function createRentalContract(
        uint256 nftId,
        address tenant,
        uint256 contractStartDate,
        uint256 contractEndDate,
        uint256 principal,
        uint256 debtInterestRate
    ) external whenNotPaused nonReentrant {
        require(_ownerOf(nftId) == msg.sender, "PropertyNFT: Only NFT owner can create rental contract");
        require(tenant != address(0), "PropertyNFT: Invalid tenant address");
        require(principal > 0, "PropertyNFT: Principal must be positive");
        require(contractStartDate < contractEndDate, "PropertyNFT: Invalid contract period");
        require(debtInterestRate <= 10000, "PropertyNFT: Interest rate too high"); // Max 100%
        require(rentalContracts[nftId].nftId == 0, "PropertyNFT: Rental contract already exists for this NFT");

        // Create rental contract with PENDING status
        rentalContracts[nftId] = RentalContract({
            nftId: nftId,
            tenantOrAssignee: tenant,
            principal: principal,
            startDate: contractStartDate,
            endDate: contractEndDate,
            status: RentalContractStatus.PENDING,
            debtInterestRate: debtInterestRate,
            totalRepaidAmount: principal,
            currentRepaidAmount: 0,
            lastRepaymentTime: 0
        });

        emit RentalContractCreated(
            nftId,
            tenant,
            principal,
            contractStartDate,
            contractEndDate,
            debtInterestRate
        );
    }

    /**
     * @dev Activate rental contract (called by DepositPool after deposit submission)
     * @param nftId The NFT ID
     */
    function activeRentalContractStatus(uint256 nftId) external {
        require(_ownerOf(nftId) != address(0), "PropertyNFT: NFT does not exist");
        RentalContract storage rentalContract = rentalContracts[nftId];
        require(rentalContract.nftId != 0, "PropertyNFT: Rental contract does not exist");
        require(rentalContract.status == RentalContractStatus.PENDING, "PropertyNFT: Contract not pending");
        
        // Check if contract start date is within 1 day of current time (as per docs)
        // require(
        //     block.timestamp >= rentalContract.startDate - 1 days &&
        //     block.timestamp <= rentalContract.startDate + 1 days,
        //     "PropertyNFT: Contract start date not within valid range"
        // );

        rentalContract.status = RentalContractStatus.ACTIVE;
    }

    /**
     * @dev 계약 만료 후 1일 유예기간이 지난 매물에 대해 누구나 호출할 수 있는 함수입니다.
     * 호출되면 Property.status가 SUSPENDED 변경, RentalContract.status가 OUTSTANDING로 변경
     * @param nftId The NFT ID to list as debt
     */
    function outstandingProperty(uint256 nftId) external whenNotPaused {
        require(_ownerOf(nftId) != address(0), "PropertyNFT: NFT does not exist");
        RentalContract storage rentalContract = rentalContracts[nftId];
        require(rentalContract.nftId != 0, "PropertyNFT: Rental contract does not exist");
        require(rentalContract.status == RentalContractStatus.ACTIVE, "PropertyNFT: Contract not active");
        require(
            block.timestamp > rentalContract.endDate + GRACE_PERIOD,
            "PropertyNFT: Grace period not passed"
        );

        // Find property ID associated with this NFT (simplified approach)
        uint256 propertyId = _findPropertyIdByNftId(nftId);
        require(propertyId != 0, "PropertyNFT: Property not found for NFT");
        
        Property storage property = properties[propertyId];
        
        // Update statuses
        PropertyStatus oldStatus = property.status;
        property.status = PropertyStatus.SUSPENDED;
        rentalContract.status = RentalContractStatus.OUTSTANDING;

        emit PropertyStatusUpdated(propertyId, oldStatus, PropertyStatus.SUSPENDED);
        emit DebtPropertyListed(nftId, rentalContract.principal, rentalContract.debtInterestRate);
    }

    /**
     * @dev Complete rental contract (called by DepositPool)
     * @param nftId The NFT ID
     */
    function completedRentalContractStatus(uint256 nftId) external {
        require(_ownerOf(nftId) != address(0), "PropertyNFT: NFT does not exist");
        RentalContract storage rentalContract = rentalContracts[nftId];
        require(rentalContract.nftId != 0, "PropertyNFT: Rental contract does not exist");
        
        rentalContract.status = RentalContractStatus.COMPLETED;
        
        // Find and update property status
        uint256 propertyId = _findPropertyIdByNftId(nftId);
        if (propertyId != 0) {
            Property storage property = properties[propertyId];
            PropertyStatus oldStatus = property.status;
            property.status = PropertyStatus.REGISTERED; // Back to available for rent
            emit PropertyStatusUpdated(propertyId, oldStatus, PropertyStatus.REGISTERED);
        }
    }

    /**
     * @dev Transfer debt claim to new assignee (called by DepositPool)
     * @param nftId The NFT ID
     * @param newAssignee The new assignee address
     */
    function transferDebt(uint256 nftId, address newAssignee) external {
        require(_ownerOf(nftId) != address(0), "PropertyNFT: NFT does not exist");
        require(newAssignee != address(0), "PropertyNFT: Invalid assignee address");
        
        RentalContract storage rentalContract = rentalContracts[nftId];
        require(rentalContract.nftId != 0, "PropertyNFT: Rental contract does not exist");
        require(rentalContract.status == RentalContractStatus.OUTSTANDING, "PropertyNFT: Contract not outstanding");
        
        rentalContract.tenantOrAssignee = newAssignee;
    }

    function _incrementTotalRepaidAmount(uint256 nftId, uint256 amount) internal {
        RentalContract storage rentalContract = rentalContracts[nftId];
        rentalContract.totalRepaidAmount += amount;
    }
    function incrementTotalRepaidAmount(uint256 nftId, uint256 amount) external {
        _incrementTotalRepaidAmount(nftId, amount);
    }

    function _incrementCurrentRepaidAmount(uint256 nftId, uint256 amount) internal {
        RentalContract storage rentalContract = rentalContracts[nftId];
        rentalContract.currentRepaidAmount += amount;
    }

    function incrementCurrentRepaidAmount(uint256 nftId, uint256 amount) external {
        _incrementCurrentRepaidAmount(nftId, amount);
    }

    function _updateLastRepaymentTime(uint256 nftId, uint256 time) internal {
        RentalContract storage rentalContract = rentalContracts[nftId];
        require(time > rentalContract.lastRepaymentTime, "PropertyNFT: Invalid time");
        rentalContract.lastRepaymentTime = time;
    }
    function updateLastRepaymentTime(uint256 nftId, uint256 time) external {
        _updateLastRepaymentTime(nftId, time);
    }

    /**
     * @dev Get property information
     * @param propertyId The property ID
     * @return Property struct
     */
    function getProperty(uint256 propertyId) external view returns (Property memory) {
        require(_propertyExists(propertyId), "PropertyNFT: Property does not exist");
        return properties[propertyId];
    }

    /**
     * @dev Get rental contract information
     * @param nftId The NFT ID
     * @return RentalContract struct
     */
    function getRentalContract(uint256 nftId) external view returns (RentalContract memory) {
        require(_ownerOf(nftId) != address(0), "PropertyNFT: NFT does not exist");
        require(rentalContracts[nftId].nftId != 0, "PropertyNFT: Rental contract does not exist");
        return rentalContracts[nftId];
    }

    /**
     * @dev Check if property exists
     * @param propertyId The property ID
     * @return True if property exists
     */
    function _propertyExists(uint256 propertyId) internal view returns (bool) {
        return propertyId > 0 && propertyId < _propertyIdCounter;
    }

    /**
     * @dev Find property ID associated with NFT ID (simplified implementation)
     * In a production system, this would be more efficiently tracked
     * @param nftId The NFT ID
     * @return propertyId The associated property ID (0 if not found)
     */
    function _findPropertyIdByNftId(uint256 nftId) internal view returns (uint256 propertyId) {
        address nftOwner = _ownerOf(nftId);
        
        // Search through properties to find match by landlord
        // This is a simplified implementation - in production, use a mapping
        for (uint256 i = 1; i < _propertyIdCounter; i++) {
            if (properties[i].landlord == nftOwner && properties[i].status != PropertyStatus.PENDING) {
                return i;
            }
        }
        return 0;
    }

    /**
     * @dev Get properties owned by a landlord
     * @param landlord The landlord address
     * @return Array of property IDs owned by the landlord
     */
    function getLandlordProperties(address landlord) external view returns (uint256[] memory) {
        uint256[] memory tempResults = new uint256[](_propertyIdCounter - 1);
        uint256 resultCount = 0;
        
        for (uint256 i = 1; i < _propertyIdCounter; i++) {
            if (properties[i].landlord == landlord) {
                tempResults[resultCount] = i;
                resultCount++;
            }
        }
        
        // Create final array with exact size
        uint256[] memory results = new uint256[](resultCount);
        for (uint256 i = 0; i < resultCount; i++) {
            results[i] = tempResults[i];
        }
        
        return results;
    }

    /**
     * @dev Get all rental contracts with a specific status
     * @param status The status to filter by
     * @return Array of NFT IDs with rental contracts of the specified status
     */
    function getRentalContractsByStatus(RentalContractStatus status) external view returns (uint256[] memory) {
        uint256[] memory tempResults = new uint256[](_nextNftId - 1);
        uint256 resultCount = 0;
        
        for (uint256 i = 1; i < _nextNftId; i++) {
            if (rentalContracts[i].nftId != 0 && rentalContracts[i].status == status) {
                tempResults[resultCount] = i;
                resultCount++;
            }
        }
        
        // Create final array with exact size
        uint256[] memory results = new uint256[](resultCount);
        for (uint256 i = 0; i < resultCount; i++) {
            results[i] = tempResults[i];
        }
        
        return results;
    }

    /**
     * @dev Override _update to add automatic listDebtProperty call
     * This ensures listDebtProperty is called automatically when needed
     */
    function _update(address to, uint256 tokenId, address auth) 
        internal 
        override(ERC721Enumerable) 
        whenNotPaused 
        returns (address) 
    {
        // Check if we need to automatically list debt property
        if (_ownerOf(tokenId) != address(0)) {
            RentalContract storage rentalContract = rentalContracts[tokenId];
            if (rentalContract.nftId != 0 && 
                rentalContract.status == RentalContractStatus.ACTIVE &&
                block.timestamp > rentalContract.endDate + GRACE_PERIOD) {
                
                // Automatically list as debt property
                uint256 propertyId = _findPropertyIdByNftId(tokenId);
                if (propertyId != 0) {
                    Property storage property = properties[propertyId];
                    PropertyStatus oldStatus = property.status;
                    property.status = PropertyStatus.SUSPENDED;
                    rentalContract.status = RentalContractStatus.OUTSTANDING;
                    
                    emit PropertyStatusUpdated(propertyId, oldStatus, PropertyStatus.SUSPENDED);
                    emit DebtPropertyListed(tokenId, rentalContract.principal, rentalContract.debtInterestRate);
                }
            }
        }
        
        return super._update(to, tokenId, auth);
    }

    /**
     * @dev Pause contract functionality
     */
    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    /**
     * @dev Unpause contract functionality
     */
    function unpause() external onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    /**
     * @dev See {IERC165-supportsInterface}
     */
    function supportsInterface(bytes4 interfaceId) 
        public 
        view 
        virtual 
        override(ERC721Enumerable, AccessControl) 
        returns (bool) 
    {
        return super.supportsInterface(interfaceId);
    }
}