// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

/**
 * @title PropertyNFT
 * @dev NFT contract for Re-Lease rental property tokenization with enhanced status tracking
 * Gas optimization target: <150,000 gas for minting
 */
contract PropertyNFT is ERC721, AccessControl, Pausable, ReentrancyGuard {
    // Role definitions
    bytes32 public constant PROPERTY_VERIFIER_ROLE = keccak256("PROPERTY_VERIFIER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    // Property status enumeration
    enum PropertyStatus {
        PENDING,           // Property listed but not verified
        ACTIVE,            // Property verified and available for rental
        CONTRACT_PENDING,  // Rental contract created by landlord, awaiting verification
        CONTRACT_VERIFIED, // Contract verified by admin, awaiting tenant deposit
        RENTED,            // Property currently rented with deposit
        SETTLEMENT,        // In settlement period
        OVERDUE,           // Settlement overdue, needs P2P marketplace
        COMPLETED,         // Settlement completed successfully
        DISPUTED,          // In dispute resolution
        SUSPENDED          // Property suspended/delisted
    }

    // Landlord distribution choice for deposits
    enum DistributionChoice {
        DIRECT,       // Direct KRW distribution to landlord
        POOL          // Hold in cKRW pool for yield optimization
    }

    // Property information structure
    struct Property {
        address landlord;                    // Property owner address
        PropertyStatus status;               // Current property status
        DistributionChoice distributionChoice; // Landlord's preferred distribution method
        uint256 depositAmount;              // Required deposit amount in KRW
        uint256 monthlyRent;                // Monthly rent amount in KRW
        uint256 contractStartTime;          // Rental contract start timestamp
        uint256 contractEndTime;            // Rental contract end timestamp
        uint256 settlementDeadline;         // Settlement deadline timestamp
        address currentTenant;              // Current tenant address
        address proposedTenant;             // Proposed tenant during contract creation
        uint256 proposedDepositAmount;      // Proposed deposit amount during contract creation
        bool isVerified;                    // Property verification status
        uint256 createdAt;                  // Property creation timestamp
        // New fields added
        bool landOwnershipAuthority;        // 땅의 소유권한
        bool landTrustAuthority;            // 땅의 신탁권한  
        uint256 ltv;                        // LTV (Loan-to-Value ratio)
        string registrationAddress;         // 등기 주소
    }

    // State variables
    mapping(uint256 => Property) public properties;
    mapping(address => uint256[]) public landlordProperties;
    mapping(address => uint256) public tenantActiveProperty;
    
    uint256 private _tokenIdCounter;
    uint256 public constant SETTLEMENT_GRACE_PERIOD = 30 days;
    uint256 public constant VERIFICATION_TIMEOUT = 7 days;

    // Events
    event PropertyMinted(
        uint256 indexed tokenId,
        address indexed landlord,
        DistributionChoice distributionChoice,
        uint256 depositAmount,
        uint256 monthlyRent,
        uint256 ltv,
        string registrationAddress
    );

    event PropertyStatusUpdated(
        uint256 indexed tokenId,
        PropertyStatus oldStatus,
        PropertyStatus newStatus
    );

    event PropertyRented(
        uint256 indexed tokenId,
        address indexed tenant,
        uint256 contractStartTime,
        uint256 contractEndTime
    );

    event SettlementInitiated(
        uint256 indexed tokenId,
        uint256 settlementDeadline
    );

    event PropertyOverdue(
        uint256 indexed tokenId,
        uint256 overdueTimestamp
    );

    event DistributionChoiceUpdated(
        uint256 indexed tokenId,
        DistributionChoice oldChoice,
        DistributionChoice newChoice
    );

    event RentalContractCreated(
        uint256 indexed tokenId,
        address indexed proposedTenant,
        uint256 contractStartTime,
        uint256 contractEndTime,
        uint256 proposedDepositAmount
    );

    event RentalContractVerified(
        uint256 indexed tokenId,
        address indexed verifier
    );

    event RentalContractFinalized(
        uint256 indexed tokenId,
        address indexed tenant
    );

    /**
     * @dev Constructor initializes the contract with name and symbol
     */
    constructor() ERC721("Re-Lease Property", "RLP") {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(PROPERTY_VERIFIER_ROLE, msg.sender);
        _grantRole(PAUSER_ROLE, msg.sender);
        _tokenIdCounter = 1; // Start from 1 to avoid tokenId 0
    }

    /**
     * @dev Mint a new property NFT with landlord distribution choice and property details
     * @param landlord Address of the property owner
     * @param distributionChoice Landlord's preferred distribution method
     * @param depositAmount Required deposit amount in KRW
     * @param monthlyRent Monthly rent amount in KRW
     * @param landOwnershipAuthority Whether landlord has land ownership authority
     * @param landTrustAuthority Whether landlord has land trust authority
     * @param ltv Loan-to-Value ratio for the property
     * @param registrationAddress Registration address of the property
     * @return tokenId The newly minted token ID
     */
    function mintProperty(
        address landlord,
        DistributionChoice distributionChoice,
        uint256 depositAmount,
        uint256 monthlyRent,
        bool landOwnershipAuthority,
        bool landTrustAuthority,
        uint256 ltv,
        string calldata registrationAddress
    ) external onlyRole(PROPERTY_VERIFIER_ROLE) whenNotPaused nonReentrant returns (uint256) {
        require(landlord != address(0), "PropertyNFT: Invalid landlord address");
        require(depositAmount > 0, "PropertyNFT: Deposit amount must be positive");
        require(monthlyRent > 0, "PropertyNFT: Monthly rent must be positive");
        require(bytes(registrationAddress).length > 0, "PropertyNFT: Registration address cannot be empty");
        require(ltv <= 10000, "PropertyNFT: LTV cannot exceed 100% (10000 basis points)");

        uint256 tokenId = _tokenIdCounter++;

        // Mint the NFT to the landlord
        _mint(landlord, tokenId);

        // Initialize property data
        properties[tokenId] = Property({
            landlord: landlord,
            status: PropertyStatus.PENDING,
            distributionChoice: distributionChoice,
            depositAmount: depositAmount,
            monthlyRent: monthlyRent,
            contractStartTime: 0,
            contractEndTime: 0,
            settlementDeadline: 0,
            currentTenant: address(0),
            proposedTenant: address(0),
            proposedDepositAmount: 0,
            isVerified: false,
            createdAt: block.timestamp,
            landOwnershipAuthority: landOwnershipAuthority,
            landTrustAuthority: landTrustAuthority,
            ltv: ltv,
            registrationAddress: registrationAddress
        });

        // Update landlord's property list
        landlordProperties[landlord].push(tokenId);

        emit PropertyMinted(tokenId, landlord, distributionChoice, depositAmount, monthlyRent, ltv, registrationAddress);

        return tokenId;
    }

    /**
     * @dev Verify a property and set it to ACTIVE status
     * @param tokenId The property token ID to verify
     */
    function verifyProperty(uint256 tokenId) external onlyRole(PROPERTY_VERIFIER_ROLE) {
        require(_tokenExists(tokenId), "PropertyNFT: Property does not exist");
        Property storage property = properties[tokenId];
        require(property.status == PropertyStatus.PENDING, "PropertyNFT: Property not in pending status");
        require(!property.isVerified, "PropertyNFT: Property already verified");

        property.isVerified = true;
        _updatePropertyStatus(tokenId, PropertyStatus.ACTIVE);
    }

    /**
     * @dev Set property as rented with tenant and contract details
     * @param tokenId The property token ID
     * @param tenant Address of the tenant
     * @param contractStartTime Rental contract start timestamp
     * @param contractEndTime Rental contract end timestamp
     */
    function setPropertyRented(
        uint256 tokenId,
        address tenant,
        uint256 contractStartTime,
        uint256 contractEndTime
    ) external onlyRole(PROPERTY_VERIFIER_ROLE) {
        require(_tokenExists(tokenId), "PropertyNFT: Property does not exist");
        require(tenant != address(0), "PropertyNFT: Invalid tenant address");
        require(contractStartTime < contractEndTime, "PropertyNFT: Invalid contract period");
        require(contractStartTime >= block.timestamp, "PropertyNFT: Contract start time in the past");

        Property storage property = properties[tokenId];
        require(property.status == PropertyStatus.ACTIVE, "PropertyNFT: Property not available for rent");
        require(tenantActiveProperty[tenant] == 0, "PropertyNFT: Tenant already has active property");

        property.currentTenant = tenant;
        property.contractStartTime = contractStartTime;
        property.contractEndTime = contractEndTime;
        tenantActiveProperty[tenant] = tokenId;

        _updatePropertyStatus(tokenId, PropertyStatus.RENTED);

        emit PropertyRented(tokenId, tenant, contractStartTime, contractEndTime);
    }

    /**
     * @dev Create a rental contract proposal by landlord
     * @param tokenId The property token ID
     * @param tenant Address of the proposed tenant
     * @param contractStartTime Rental contract start timestamp
     * @param contractEndTime Rental contract end timestamp
     * @param proposedDepositAmount Proposed deposit amount
     */
    function createRentalContract(
        uint256 tokenId,
        address tenant,
        uint256 contractStartTime,
        uint256 contractEndTime,
        uint256 proposedDepositAmount
    ) external {
        require(_tokenExists(tokenId), "PropertyNFT: Property does not exist");
        require(tenant != address(0), "PropertyNFT: Invalid tenant address");
        require(contractStartTime < contractEndTime, "PropertyNFT: Invalid contract period");
        require(contractStartTime >= block.timestamp, "PropertyNFT: Contract start time in the past");
        require(proposedDepositAmount > 0, "PropertyNFT: Deposit amount must be positive");

        Property storage property = properties[tokenId];
        require(msg.sender == property.landlord, "PropertyNFT: Only property owner can create rental contract");
        require(property.status == PropertyStatus.ACTIVE, "PropertyNFT: Property not available for rent");
        require(tenantActiveProperty[tenant] == 0, "PropertyNFT: Tenant already has active property");

        property.proposedTenant = tenant;
        property.contractStartTime = contractStartTime;
        property.contractEndTime = contractEndTime;
        property.proposedDepositAmount = proposedDepositAmount;

        _updatePropertyStatus(tokenId, PropertyStatus.CONTRACT_PENDING);

        emit RentalContractCreated(tokenId, tenant, contractStartTime, contractEndTime, proposedDepositAmount);
    }

    /**
     * @dev Verify rental contract by admin
     * @param tokenId The property token ID
     */
    function verifyRentalContract(uint256 tokenId) external onlyRole(PROPERTY_VERIFIER_ROLE) {
        require(_tokenExists(tokenId), "PropertyNFT: Property does not exist");
        Property storage property = properties[tokenId];
        require(property.status == PropertyStatus.CONTRACT_PENDING, "PropertyNFT: Contract not pending verification");
        require(property.proposedTenant != address(0), "PropertyNFT: No proposed tenant");

        _updatePropertyStatus(tokenId, PropertyStatus.CONTRACT_VERIFIED);

        emit RentalContractVerified(tokenId, msg.sender);
    }

    /**
     * @dev Finalize rental contract after deposit is submitted
     * @param tokenId The property token ID
     */
    function finalizeRentalContract(uint256 tokenId) external onlyRole(PROPERTY_VERIFIER_ROLE) {
        require(_tokenExists(tokenId), "PropertyNFT: Property does not exist");
        Property storage property = properties[tokenId];
        require(property.status == PropertyStatus.CONTRACT_VERIFIED, "PropertyNFT: Contract not verified");
        require(property.proposedTenant != address(0), "PropertyNFT: No proposed tenant");

        // Set current tenant and clear proposed tenant
        property.currentTenant = property.proposedTenant;
        tenantActiveProperty[property.proposedTenant] = tokenId;
        
        // Clear proposed data
        property.proposedTenant = address(0);
        property.proposedDepositAmount = 0;

        _updatePropertyStatus(tokenId, PropertyStatus.RENTED);

        emit RentalContractFinalized(tokenId, property.currentTenant);
    }

    /**
     * @dev Initiate settlement process for a property
     * @param tokenId The property token ID
     */
    function initiateSettlement(uint256 tokenId) external {
        require(_tokenExists(tokenId), "PropertyNFT: Property does not exist");
        Property storage property = properties[tokenId];
        require(property.status == PropertyStatus.RENTED, "PropertyNFT: Property not rented");
        require(
            msg.sender == property.landlord || msg.sender == property.currentTenant,
            "PropertyNFT: Only landlord or tenant can initiate settlement"
        );
        require(block.timestamp >= property.contractEndTime, "PropertyNFT: Contract period not ended");

        property.settlementDeadline = block.timestamp + SETTLEMENT_GRACE_PERIOD;
        _updatePropertyStatus(tokenId, PropertyStatus.SETTLEMENT);

        emit SettlementInitiated(tokenId, property.settlementDeadline);
    }

    /**
     * @dev Complete settlement for a property
     * @param tokenId The property token ID
     */
    function completeSettlement(uint256 tokenId) external onlyRole(PROPERTY_VERIFIER_ROLE) {
        require(_tokenExists(tokenId), "PropertyNFT: Property does not exist");
        Property storage property = properties[tokenId];
        require(property.status == PropertyStatus.SETTLEMENT, "PropertyNFT: Property not in settlement");

        // Clear tenant data
        address tenant = property.currentTenant;
        property.currentTenant = address(0);
        property.contractStartTime = 0;
        property.contractEndTime = 0;
        property.settlementDeadline = 0;
        
        if (tenant != address(0)) {
            tenantActiveProperty[tenant] = 0;
        }

        _updatePropertyStatus(tokenId, PropertyStatus.COMPLETED);
    }

    /**
     * @dev Check and mark properties as overdue if settlement deadline passed
     * @param tokenId The property token ID to check
     */
    function checkSettlementOverdue(uint256 tokenId) external {
        require(_tokenExists(tokenId), "PropertyNFT: Property does not exist");
        Property storage property = properties[tokenId];
        require(property.status == PropertyStatus.SETTLEMENT, "PropertyNFT: Property not in settlement");
        require(block.timestamp > property.settlementDeadline, "PropertyNFT: Settlement deadline not passed");

        _updatePropertyStatus(tokenId, PropertyStatus.OVERDUE);
        emit PropertyOverdue(tokenId, block.timestamp);
    }

    /**
     * @dev Update landlord distribution choice
     * @param tokenId The property token ID
     * @param newChoice New distribution choice
     */
    function updateDistributionChoice(
        uint256 tokenId,
        DistributionChoice newChoice
    ) external {
        require(_tokenExists(tokenId), "PropertyNFT: Property does not exist");
        Property storage property = properties[tokenId];
        require(msg.sender == property.landlord, "PropertyNFT: Only landlord can update distribution choice");
        require(property.status != PropertyStatus.RENTED, "PropertyNFT: Cannot change while rented");

        DistributionChoice oldChoice = property.distributionChoice;
        property.distributionChoice = newChoice;

        emit DistributionChoiceUpdated(tokenId, oldChoice, newChoice);
    }

    /**
     * @dev Update property LTV (Loan-to-Value ratio)
     * @param tokenId The property token ID
     * @param newLtv New LTV value (in basis points, max 10000 = 100%)
     */
    function updateLTV(uint256 tokenId, uint256 newLtv) external onlyRole(PROPERTY_VERIFIER_ROLE) {
        require(_tokenExists(tokenId), "PropertyNFT: Property does not exist");
        require(newLtv <= 10000, "PropertyNFT: LTV cannot exceed 100% (10000 basis points)");
        
        properties[tokenId].ltv = newLtv;
    }

    /**
     * @dev Update land ownership authority
     * @param tokenId The property token ID
     * @param hasAuthority Whether landlord has land ownership authority
     */
    function updateLandOwnershipAuthority(uint256 tokenId, bool hasAuthority) external onlyRole(PROPERTY_VERIFIER_ROLE) {
        require(_tokenExists(tokenId), "PropertyNFT: Property does not exist");
        
        properties[tokenId].landOwnershipAuthority = hasAuthority;
    }

    /**
     * @dev Update land trust authority
     * @param tokenId The property token ID
     * @param hasAuthority Whether landlord has land trust authority
     */
    function updateLandTrustAuthority(uint256 tokenId, bool hasAuthority) external onlyRole(PROPERTY_VERIFIER_ROLE) {
        require(_tokenExists(tokenId), "PropertyNFT: Property does not exist");
        
        properties[tokenId].landTrustAuthority = hasAuthority;
    }

    /**
     * @dev Update registration address
     * @param tokenId The property token ID
     * @param newAddress New registration address
     */
    function updateRegistrationAddress(uint256 tokenId, string calldata newAddress) external onlyRole(PROPERTY_VERIFIER_ROLE) {
        require(_tokenExists(tokenId), "PropertyNFT: Property does not exist");
        require(bytes(newAddress).length > 0, "PropertyNFT: Registration address cannot be empty");
        
        properties[tokenId].registrationAddress = newAddress;
    }

    /**
     * @dev Internal function to update property status with event emission
     * @param tokenId The property token ID
     * @param newStatus New status to set
     */
    function _updatePropertyStatus(uint256 tokenId, PropertyStatus newStatus) internal {
        Property storage property = properties[tokenId];
        PropertyStatus oldStatus = property.status;
        property.status = newStatus;
        
        emit PropertyStatusUpdated(tokenId, oldStatus, newStatus);
    }

    /**
     * @dev Internal helper function to check if token exists
     * @param tokenId The token ID to check
     * @return True if token exists
     */
    function _tokenExists(uint256 tokenId) internal view returns (bool) {
        return _ownerOf(tokenId) != address(0);
    }

    /**
     * @dev Get property information
     * @param tokenId The property token ID
     * @return Property struct containing all property data
     */
    function getProperty(uint256 tokenId) external view returns (Property memory) {
        require(_tokenExists(tokenId), "PropertyNFT: Property does not exist");
        return properties[tokenId];
    }

    /**
     * @dev Get properties owned by a landlord
     * @param landlord The landlord address
     * @return Array of token IDs owned by the landlord
     */
    function getLandlordProperties(address landlord) external view returns (uint256[] memory) {
        return landlordProperties[landlord];
    }

    /**
     * @dev Check if settlement is overdue for a property
     * @param tokenId The property token ID
     * @return True if settlement is overdue
     */
    function isSettlementOverdue(uint256 tokenId) external view returns (bool) {
        require(_tokenExists(tokenId), "PropertyNFT: Property does not exist");
        Property memory property = properties[tokenId];
        
        return property.status == PropertyStatus.SETTLEMENT && 
               property.settlementDeadline > 0 && 
               block.timestamp > property.settlementDeadline;
    }

    /**
     * @dev Get current token ID counter
     * @return Current token ID counter value
     */
    function getCurrentTokenId() external view returns (uint256) {
        return _tokenIdCounter;
    }

    /**
     * @dev Override tokenURI to return property-specific metadata
     * @param tokenId The property token ID
     * @return The URI for the token metadata
     */
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        require(_tokenExists(tokenId), "PropertyNFT: URI query for nonexistent token");
        
        // Return a default metadata URI based on token ID
        // In production, this could be a proper metadata service
        return string(abi.encodePacked(
            "https://api.re-lease.kr/metadata/",
            Strings.toString(tokenId),
            ".json"
        ));
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
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721, AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    /**
     * @dev Override _update to add pause functionality
     */
    function _update(
        address to,
        uint256 tokenId,
        address auth
    ) internal override whenNotPaused returns (address) {
        return super._update(to, tokenId, auth);
    }
}