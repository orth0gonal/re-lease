// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "./interfaces/Events.sol";
import "./interfaces/Structs.sol";

/**
 * @title PropertyNFT
 * @dev NFT contract for Re-Lease rental property tokenization with enhanced status tracking
 */
contract PropertyNFT is ERC721Enumerable, AccessControl, Pausable, ReentrancyGuard, IPropertyNFTEvents {
    // Role definitions
    bytes32 public constant PROPERTY_VERIFIER_ROLE = keccak256("PROPERTY_VERIFIER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");


    // State variables
    mapping(uint256 => Property) public properties;
    mapping(uint256 => PropertyProposal) public propertyProposals;
    mapping(address => uint256[]) public landlordProperties;
    mapping(address => uint256[]) public landlordProposals;
    mapping(address => uint256) public tenantActiveProperty;
    
    uint256 private _tokenIdCounter;
    uint256 private _proposalIdCounter;
    uint256 public constant SETTLEMENT_GRACE_PERIOD = 30 days;
    uint256 public constant VERIFICATION_TIMEOUT = 7 days;
    uint256 public constant PROPOSAL_VERIFICATION_PERIOD = 14 days;


    /**
     * @dev Constructor initializes the contract with name and symbol
     */
    constructor() ERC721("Re-Lease Property", "RLP") {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(PROPERTY_VERIFIER_ROLE, msg.sender);
        _grantRole(PAUSER_ROLE, msg.sender);
        _tokenIdCounter = 1; // Start from 1 to avoid tokenId 0
        _proposalIdCounter = 1; // Start from 1 to avoid proposalId 0
    }

    /**
     * @dev Landlord proposes a property for listing
     * @param distributionChoice Landlord's preferred distribution method
     * @param depositAmount Required deposit amount in KRW
     * @param landOwnershipAuthority Whether landlord has land ownership authority
     * @param landTrustAuthority Whether landlord has land trust authority
     * @param ltv Loan-to-Value ratio for the property
     * @param registrationAddress Registration address of the property
     * @param propertyDescription Description of the property
     * @return proposalId The newly created proposal ID
     */
    function proposeProperty(
        DistributionChoice distributionChoice,
        uint256 depositAmount,
        bool landOwnershipAuthority,
        bool landTrustAuthority,
        uint256 ltv,
        bytes32 registrationAddress,
        bytes32 propertyDescription
    ) external whenNotPaused nonReentrant returns (uint256) {
        require(depositAmount > 0, "PropertyNFT: Deposit amount must be positive");
        require(registrationAddress.length > 0, "PropertyNFT: Registration address cannot be empty");
        require(propertyDescription.length > 0, "PropertyNFT: Property description cannot be empty");
        require(ltv <= 10000, "PropertyNFT: LTV cannot exceed 100% (10000 basis points)");

        uint256 proposalId = _proposalIdCounter++;

        // Create property proposal
        propertyProposals[proposalId] = PropertyProposal({
            landlord: msg.sender,
            distributionChoice: distributionChoice,
            depositAmount: depositAmount,
            landOwnershipAuthority: landOwnershipAuthority,
            landTrustAuthority: landTrustAuthority,
            ltv: ltv,
            registrationAddress: registrationAddress,
            propertyDescription: propertyDescription,
            proposalTime: block.timestamp,
            verificationDeadline: block.timestamp + PROPOSAL_VERIFICATION_PERIOD,
            isProcessed: false
        });

        // Update landlord's proposal list
        landlordProposals[msg.sender].push(proposalId);

        emit PropertyProposed(
            proposalId,
            msg.sender,
            distributionChoice,
            depositAmount,
            ltv,
            registrationAddress,
            propertyDescription
        );

        return proposalId;
    }

    /**
     * @dev Approve a property proposal and mint NFT
     * @param proposalId The proposal ID to approve
     * @return tokenId The newly minted token ID
     */
    function approvePropertyProposal(uint256 proposalId) 
        external 
        onlyRole(PROPERTY_VERIFIER_ROLE) 
        whenNotPaused 
        nonReentrant 
        returns (uint256) 
    {
        PropertyProposal storage proposal = propertyProposals[proposalId];
        require(proposal.landlord != address(0), "PropertyNFT: Proposal does not exist");
        require(!proposal.isProcessed, "PropertyNFT: Proposal already processed");
        require(block.timestamp <= proposal.verificationDeadline, "PropertyNFT: Proposal verification deadline passed");

        // Use internal _mintProperty function to create the NFT
        uint256 tokenId = _mintProperty(
            proposal.landlord,
            proposal.distributionChoice,
            proposal.depositAmount,
            proposal.landOwnershipAuthority,
            proposal.landTrustAuthority,
            proposal.ltv,
            proposal.registrationAddress
        );

        // Set the proposal ID to link property with its original proposal
        properties[tokenId].proposalId = proposalId;

        // Mark proposal as processed
        proposal.isProcessed = true;

        emit PropertyProposalApproved(proposalId, tokenId, msg.sender);

        return tokenId;
    }

    /**
     * @dev Reject a property proposal
     * @param proposalId The proposal ID to reject
     * @param reason Reason for rejection
     */
    function rejectPropertyProposal(
        uint256 proposalId,
        string calldata reason
    ) external onlyRole(PROPERTY_VERIFIER_ROLE) whenNotPaused {
        PropertyProposal storage proposal = propertyProposals[proposalId];
        require(proposal.landlord != address(0), "PropertyNFT: Proposal does not exist");
        require(!proposal.isProcessed, "PropertyNFT: Proposal already processed");
        require(bytes(reason).length > 0, "PropertyNFT: Rejection reason cannot be empty");

        // Mark proposal as processed
        proposal.isProcessed = true;

        emit PropertyProposalRejected(proposalId, msg.sender, reason);
    }

    /**
     * @dev Internal function to mint a new property NFT with landlord distribution choice and property details
     * @param landlord Address of the property owner
     * @param distributionChoice Landlord's preferred distribution method
     * @param depositAmount Required deposit amount in KRW
     * @param landOwnershipAuthority Whether landlord has land ownership authority
     * @param landTrustAuthority Whether landlord has land trust authority
     * @param ltv Loan-to-Value ratio for the property
     * @param registrationAddress Registration address of the property
     * @return tokenId The newly minted token ID
     */
    function _mintProperty(
        address landlord,
        DistributionChoice distributionChoice,
        uint256 depositAmount,
        bool landOwnershipAuthority,
        bool landTrustAuthority,
        uint256 ltv,
        bytes32 registrationAddress
    ) internal returns (uint256) {
        require(landlord != address(0), "PropertyNFT: Invalid landlord address");
        require(depositAmount > 0, "PropertyNFT: Deposit amount must be positive");
        require(registrationAddress.length > 0, "PropertyNFT: Registration address cannot be empty");
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
            contractStartTime: 0,
            contractEndTime: 0,
            settlementDeadline: 0,
            currentTenant: address(0),
            proposedTenant: address(0),
            proposedDepositAmount: 0,
            isVerified: false,
            createdAt: block.timestamp,
            proposalId: 0, // Direct minting, not from proposal
            landOwnershipAuthority: landOwnershipAuthority,
            landTrustAuthority: landTrustAuthority,
            ltv: ltv,
            registrationAddress: registrationAddress
        });

        // Update landlord's property list
        landlordProperties[landlord].push(tokenId);

        emit PropertyMinted(tokenId, landlord, distributionChoice, depositAmount, ltv, registrationAddress);

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
        
        properties[tokenId].registrationAddress = keccak256(bytes(newAddress));
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
     * @dev Get current proposal ID counter
     * @return Current proposal ID counter value
     */
    function getCurrentProposalId() external view returns (uint256) {
        return _proposalIdCounter;
    }

    /**
     * @dev Get property proposal information
     * @param proposalId The proposal ID
     * @return PropertyProposal struct containing all proposal data
     */
    function getPropertyProposal(uint256 proposalId) external view returns (PropertyProposal memory) {
        PropertyProposal memory proposal = propertyProposals[proposalId];
        require(proposal.landlord != address(0), "PropertyNFT: Proposal does not exist");
        return proposal;
    }

    /**
     * @dev Get proposals by a landlord
     * @param landlord The landlord address
     * @return Array of proposal IDs by the landlord
     */
    function getLandlordProposals(address landlord) external view returns (uint256[] memory) {
        return landlordProposals[landlord];
    }

    /**
     * @dev Get pending proposals (not processed and within deadline)
     * @return Array of pending proposal IDs
     */
    function getPendingProposals() external view returns (uint256[] memory) {
        uint256 totalProposals = _proposalIdCounter - 1;
        uint256[] memory tempPending = new uint256[](totalProposals);
        uint256 pendingCount = 0;

        for (uint256 i = 1; i <= totalProposals; i++) {
            PropertyProposal memory proposal = propertyProposals[i];
            if (!proposal.isProcessed && 
                proposal.landlord != address(0) &&
                block.timestamp <= proposal.verificationDeadline) {
                tempPending[pendingCount] = i;
                pendingCount++;
            }
        }

        // Create final array with exact size
        uint256[] memory pendingProposals = new uint256[](pendingCount);
        for (uint256 i = 0; i < pendingCount; i++) {
            pendingProposals[i] = tempPending[i];
        }

        return pendingProposals;
    }

    /**
     * @dev Check if a proposal is expired
     * @param proposalId The proposal ID to check
     * @return True if proposal is expired
     */
    function isProposalExpired(uint256 proposalId) external view returns (bool) {
        PropertyProposal memory proposal = propertyProposals[proposalId];
        require(proposal.landlord != address(0), "PropertyNFT: Proposal does not exist");
        
        return !proposal.isProcessed && block.timestamp > proposal.verificationDeadline;
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
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721Enumerable, AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    /**
     * @dev Override _update to add pause functionality and ERC721Enumerable support
     */
    function _update(
        address to,
        uint256 tokenId,
        address auth
    ) internal override(ERC721Enumerable) whenNotPaused returns (address) {
        return super._update(to, tokenId, auth);
    }
}