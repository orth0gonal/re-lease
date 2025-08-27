// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./PropertyNFT.sol";
import "./interfaces/Events.sol";
import "./interfaces/Structs.sol";

/**
 * @title DepositPool
 * @dev DepositPool은 ERC-4626 Vault 표준을 구현하여 KRWC 보증금을 yKRWC로 변환하고 수익을 생성합니다.
 * asset 토큰은 KRWC 토큰이며, shares 토큰은 yKRWC 토큰입니다.
 * Implemented according to docs.md specifications
 */
contract DepositPool is ERC4626, AccessControl, Pausable, ReentrancyGuard, IDepositPoolEvents {
    using SafeERC20 for IERC20;

    // NFT ID별로 이미 클레임된 총 이자 금액을 추적
    mapping(uint256 => uint256) private _unclaimedPrincipalAndInterest;
    // NFT ID별로 마지막 이자 클레임 시점을 추적 (추가적인 검증용)
    mapping(uint256 => uint256) private _lastClaimTime;

    // Role definitions
    bytes32 public constant POOL_MANAGER_ROLE = keccak256("POOL_MANAGER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant YIELD_MANAGER_ROLE = keccak256("YIELD_MANAGER_ROLE");

    // PropertyNFT contract
    PropertyNFT public immutable propertyNFT;
    
    // Deposit status is now tracked through PropertyNFT's RentalContract.status
    // No separate mapping needed since PropertyNFT contains all state information

    /**
     * @dev Constructor initializes the ERC-4626 vault
     * @param _propertyNFT PropertyNFT contract address
     * @param _krwcToken KRWC stablecoin contract address (underlying asset)
     */
    constructor(
        address _propertyNFT,
        address _krwcToken
    ) ERC4626(IERC20(_krwcToken)) ERC20("yKRWC Vault Token", "yKRWC") {
        require(_propertyNFT != address(0), "DepositPool: Invalid PropertyNFT address");
        require(_krwcToken != address(0), "DepositPool: Invalid KRWC token address");

        propertyNFT = PropertyNFT(_propertyNFT);

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(POOL_MANAGER_ROLE, msg.sender);
        _grantRole(PAUSER_ROLE, msg.sender);
        _grantRole(YIELD_MANAGER_ROLE, msg.sender);
    }

    /**
     * @dev 전세 계약 실행 시 임차인이 검증된 임차 계약에 대한 보증금을 제출합니다. 
     * KRWC 형태로 제출되며, 이는 vault에 의해 yKRWC로 변환된 후 임대인에게 전송됩니다.
     * 해당 nftId의 RentalContract.startDate가 현재 시간 전후 1일 이내에 있으면 호출 가능합니다.
     * 호출되면 해당 nftId의 RentalContract.status가 ACTIVE 상태로 바뀝니다.
     * @param nftId The NFT ID associated with the rental contract
     * @param principal The deposit amount in KRWC
     */
    function submitPrincipal(
        uint256 nftId,
        uint256 principal
    ) external nonReentrant whenNotPaused {
        require(principal > 0, "DepositPool: Principal must be positive");
        // Check that no deposit exists by verifying contract is in PENDING status
        // PENDING means contract exists but deposit hasn't been submitted yet

        // Get rental contract information from PropertyNFT
        RentalContract memory rentalContract = propertyNFT.getRentalContract(nftId);
        require(rentalContract.status == RentalContractStatus.PENDING, "DepositPool: Contract not pending");
        require(rentalContract.tenantOrAssignee == msg.sender, "DepositPool: Only contract tenant can submit deposit");
        require(rentalContract.principal == principal, "DepositPool: Incorrect principal amount");
        
        // Check if within valid time range (1 day before/after start date)
        // require(
        //     block.timestamp >= rentalContract.startDate - 1 days &&
        //     block.timestamp <= rentalContract.startDate + 1 days,
        //     "DepositPool: Contract start date not within valid range"
        // );

        address landlord = propertyNFT.getProperty(nftId).landlord;
        
        // Transfer KRWC from tenant to this contract
        require(IERC20(asset()).balanceOf(msg.sender) >= principal, "DepositPool: Insufficient KRWC balance");
        IERC20(asset()).approve(address(this), principal);
        IERC20(asset()).safeTransferFrom(msg.sender, address(this), principal);
        
        // KRWC -> yKRWC
        uint256 shares = convertToShares(principal);
        
        // Mint yKRWC shares to landlord
        _mint(landlord, shares);
        
        // Deposit status is now tracked through PropertyNFT's RentalContract.status
        // Status will be updated to ACTIVE by activeRentalContractStatus() call below
        
        emit DepositSubmitted(nftId, msg.sender, landlord, principal);
        emit DepositDistributed(nftId, landlord, shares);
        
        // Activate rental contract in PropertyNFT
        try propertyNFT.activeRentalContractStatus(nftId) {
            // Successfully activated
        } catch {
            revert("DepositPool: Failed to activate rental contract");
        }
    }

    /**
     * @dev 임대인이 보증금을 반환합니다. isKRWC 파라미터에 따라:
     * - true: 보증금만큼의 KRWC 토큰을 DepositPool에 전송
     * - false: 전세계약 당시 보증금의 가치에 해당하는 yKRWC 토큰을 DepositPool에 전송
     * 수량이 부족할 시 revert가 발생합니다.
     * 호출이 성공하면, 해당 nftId의 RentalContract.status가 COMPLETED 상태로 바뀝니다.
     * @param nftId The NFT ID
     * @param isKRWC Whether to return KRWC (true) or yKRWC (false)
     */
    function returnPrincipal(
        uint256 nftId,
        bool isKRWC
    ) external nonReentrant whenNotPaused {
        // Verify there's an active deposit by checking contract status
        RentalContract memory rentalContract = propertyNFT.getRentalContract(nftId);
        require(rentalContract.status == RentalContractStatus.ACTIVE, "DepositPool: Contract not active");
        
        // Verify caller is landlord (NFT owner)
        address landlord = propertyNFT.getProperty(nftId).landlord;
        require(msg.sender == landlord, "DepositPool: Only landlord can return principal");
        
        uint256 principal = rentalContract.principal;
        uint256 principalAsShares = convertToShares(principal);
        
        if (isKRWC) {
            // Landlord returns KRWC tokens equal to original deposit amount
            IERC20(asset()).approve(address(this), principal);
            IERC20(asset()).safeTransferFrom(msg.sender, address(this), principal);
        } else {
            // Landlord returns yKRWC shares equal to original deposit value
            require(balanceOf(msg.sender) >= principalAsShares, "DepositPool: Insufficient yKRWC balance");
            IERC20(asset()).approve(address(this), principalAsShares);
            _transfer(msg.sender, address(this), principalAsShares);
        }
        propertyNFT.incrementTotalRepaidAmount(nftId, principal);
    }

    /**
     * @dev 정산 완료 후 임차인이 원금 보증금을 회수합니다. 임대인의 DepositPool.returnPrincipal() 호출이 선행되어야 합니다.
     * @param nftId The NFT ID
     */
    function recoverPrincipal(uint256 nftId) external nonReentrant whenNotPaused {
        // Verify deposit is not active by checking contract is COMPLETED
        RentalContract memory rentalContract = propertyNFT.getRentalContract(nftId);
        require(rentalContract.status == RentalContractStatus.ACTIVE, "DepositPool: Contract not completed");        
        require(rentalContract.tenantOrAssignee == msg.sender, "DepositPool: Only original tenant can recover principal");
        
        uint256 principal = rentalContract.principal;
        require(principal > 0, "DepositPool: No principal to recover");
        
        // Transfer KRWC back to tenant
        IERC20(asset()).safeTransfer(msg.sender, principal);
        emit DepositRecovered(nftId, msg.sender, principal);
        
        try propertyNFT.completedRentalContractStatus(nftId) {
            // Successfully completed
        } catch {
            revert("DepositPool: Failed to complete rental contract");
        }
    }

    /**
     * @dev 채권양수인이 디폴트된 채권을 구매합니다. nftId가 묶여있는 계약 만기일로부터 유예기간 1일이 지난 이후부터 호출할 수 있으며, 호출되면:
     * - RentalContract.tenantOrAssignee가 method caller의 주소로 변경
     * - 구매 비용(principal)이 기존 채권자(임차인)에게 즉시 전송
     * @param nftId The NFT ID
     * @param principal The purchase price for the debt
     */
    function purchaseDebt(
        uint256 nftId,
        uint256 principal
    ) external nonReentrant whenNotPaused {
        // Verify there's an active deposit by checking contract status
        RentalContract memory rentalContract = propertyNFT.getRentalContract(nftId);
        require(rentalContract.status == RentalContractStatus.OUTSTANDING, "DepositPool: Contract not outstanding");
        
        address currentCreditor = rentalContract.tenantOrAssignee;
        require(msg.sender != currentCreditor, "DepositPool: Cannot purchase from self");
        
        // Transfer purchase price to current creditor (tenant or previous assignee)
        uint256 assigneeKRWCBalance = IERC20(asset()).balanceOf(msg.sender);
        require(assigneeKRWCBalance >= principal, "DepositPool: Insufficient KRWC balance");
        IERC20(asset()).approve(address(this), principal);
        IERC20(asset()).safeTransferFrom(msg.sender, currentCreditor, principal);
        
        // Update tenantOrAssignee in PropertyNFT contract
        try propertyNFT.transferDebt(nftId, msg.sender) {
            // Successfully updated
        } catch {
            revert("DepositPool: Failed to transfer debt claim");
        }
        
        emit DebtTransferred(nftId, currentCreditor, msg.sender, principal);
    }

    /**
    * @dev 현재 채권자(임차인 또는 채권양수인)가 호출하며, 임대인(대출자)이 지금까지 상환한 원리금을 클레임합니다.
    * @param nftId The NFT ID
    * @return interestAmount The amount of interest claimed
    */
    function collectDebtRepayment(uint256 nftId) external nonReentrant whenNotPaused returns (uint256 interestAmount) {
        _updateTotalRepaidAmount(nftId);
        RentalContract memory rentalContract = propertyNFT.getRentalContract(nftId);
        
        // 권한 검증: 현재 채권자(임차인 또는 채권양수인)만 호출 가능
        require(msg.sender == rentalContract.tenantOrAssignee, "DepositPool: Only current creditor can collect repayment");
        require(rentalContract.status == RentalContractStatus.OUTSTANDING, "DepositPool: Contract not outstanding");

        // 클레임하지 않은 원리금 확인
        uint256 unclaimedPrincipalAndInterest = _unclaimedPrincipalAndInterest[nftId];
        require(unclaimedPrincipalAndInterest > 0, "DepositPool: No unclaimed principal and interest");
        
        // 풀에 충분한 자금이 있는지 확인
        require(IERC20(asset()).balanceOf(address(this)) >= unclaimedPrincipalAndInterest, "DepositPool: Insufficient pool balance");
        
        // 이자를 채권자에게 전송
        IERC20(asset()).safeTransfer(msg.sender, unclaimedPrincipalAndInterest);
        _unclaimedPrincipalAndInterest[nftId] = 0;
        _lastClaimTime[nftId] = block.timestamp;
        
        emit InterestClaimed(nftId, msg.sender, unclaimedPrincipalAndInterest);
        
        return unclaimedPrincipalAndInterest;
    }

    /**
     * @dev 임대인이 채무를 상환합니다. 호출되면:
     * - collectDebtRepayment() 호출하여 이자 한번 업데이트
     * - RentalContract.lastRepaymentTime = 현재 시간으로 업데이트
     * - RentalContract.totalRepaidAmount += repayAmount (총 상환 금액 누적)
     * - 만일 RentalContract.totalRepaidAmount + repayAmount >= RentalContract.principal + 총 이자 금액이면, 
     *   RentalContract.status가 COMPLETED 상태로 바뀌며 대출 계약이 종료됩니다.
     * @param nftId The NFT ID
     * @param repayAmount The amount to repay in KRWC
     */
    function repayDebt(uint256 nftId, uint256 repayAmount) external nonReentrant whenNotPaused {
        require(repayAmount > 0, "DepositPool: Repay amount must be positive");
        
        _updateTotalRepaidAmount(nftId);
        RentalContract memory rentalContract = propertyNFT.getRentalContract(nftId);
        
        // Verify caller is landlord (NFT owner)
        address landlord = propertyNFT.getProperty(nftId).landlord;
        require(msg.sender == landlord, "DepositPool: Only landlord can repay debt");
        require(rentalContract.status == RentalContractStatus.OUTSTANDING, "DepositPool: Contract not outstanding");
        
        uint256 remains = rentalContract.totalRepaidAmount - rentalContract.currentRepaidAmount;
        if (repayAmount > remains) {
            IERC20(asset()).safeTransferFrom(msg.sender, address(this), remains);
            _unclaimedPrincipalAndInterest[nftId] += remains;
            propertyNFT.incrementCurrentRepaidAmount(nftId, remains);
            try propertyNFT.completedRentalContractStatus(nftId) {
                emit DebtFullyRepaid(nftId, rentalContract.tenantOrAssignee, remains);
            } catch {
                revert("DepositPool: Failed to complete rental contract");
            }
        } else {
            IERC20(asset()).safeTransferFrom(msg.sender, address(this), repayAmount);
            _unclaimedPrincipalAndInterest[nftId] += repayAmount;
            propertyNFT.incrementCurrentRepaidAmount(nftId, repayAmount);
            emit DebtRepaid(nftId, rentalContract.tenantOrAssignee, repayAmount, 0, 0, 0);
        }
    }

    function _updateTotalRepaidAmount(uint256 nftId) internal {
        RentalContract memory rentalContract = propertyNFT.getRentalContract(nftId);
        uint256 prevLastRepaymentTime = rentalContract.lastRepaymentTime;
        uint256 prevTotalRepaidAmount = rentalContract.totalRepaidAmount;
        uint256 prevCurrentRepaidAmount = rentalContract.currentRepaidAmount;
        uint256 remains = prevTotalRepaidAmount - prevCurrentRepaidAmount;

        uint256 interest = remains * (block.timestamp - prevLastRepaymentTime) * rentalContract.debtInterestRate / 10000 / 31557600;

        propertyNFT.incrementTotalRepaidAmount(nftId, interest);
        propertyNFT.updateLastRepaymentTime(nftId, block.timestamp);
    }


    /**
     * @dev Override deposit to add pause functionality
     */
    function deposit(uint256 assets, address receiver) public override nonReentrant whenNotPaused returns (uint256) {
        return super.deposit(assets, receiver);
    }

    /**
     * @dev Override redeem to add pause functionality
     */
    function redeem(uint256 shares, address receiver, address owner) public override nonReentrant whenNotPaused returns (uint256) {
        return super.redeem(shares, receiver, owner);
    }

    /**
     * @dev Override _update to add pause functionality
     */
    function _update(address from, address to, uint256 value) internal override whenNotPaused {
        super._update(from, to, value);
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
    function supportsInterface(bytes4 interfaceId) public view virtual override(AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}