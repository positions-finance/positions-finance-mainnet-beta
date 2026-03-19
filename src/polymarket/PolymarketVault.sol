// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// --- V5 Updated Imports ---
// Interfaces
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";

// Upgradeable contracts for stateful logic
import "@openzeppelin/contracts-upgradeable/token/ERC1155/utils/ERC1155HolderUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

// --- Interfaces ---

/**
 * @dev Interface for the Gnosis Conditional Tokens Framework (Polymarket's Core).
 */
interface IConditionalTokens {
    function getCollectionId(bytes32 parentCollectionId, bytes32 conditionId, uint256 indexSet) external view returns (bytes32);
    function getPositionId(address collateralToken, bytes32 collectionId) external view returns (uint256);
    function safeTransferFrom(address from, address to, uint256 id, uint256 value, bytes calldata data) external;
}

/**
 * @title PolymarketVault
 * @notice Accepts Polymarket ERC1155 tokens only for whitelisted markets.
 * @dev Validates Position IDs by calling the official CTF contract directly.
 */
contract PolymarketVault is
    Initializable,
    ERC1155HolderUpgradeable, // FIXED: Now using the Upgradeable version
    OwnableUpgradeable,
    ReentrancyGuardUpgradeable,
    UUPSUpgradeable
{

    // --- Constants ---

    address public constant CTF_ADDRESS = 0x4D97DCd97eC945f40cF65F87097ACe5EA0476045;
    address public constant USDC_E = 0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174;
    address public constant WRAPPED_COLLATERAL = 0x3A3BD7bb9528E159577F7C2e685CC81A765002E2;

    // --- State Variables ---

    mapping(bytes32 => bool) public whitelistedConditions;

    // INTERNAL LEDGERS
    // User Address => Token ID => Amount
    mapping(address => mapping(uint256 => uint256)) public userBalances;

    // NEW: Tracks funds that are actively pending withdrawal to prevent double-spending
    mapping(address => mapping(uint256 => uint256)) public lockedBalances;

    enum WithdrawalStatus { Pending, Approved, Processed, Rejected, Cancelled }

    // NEW: Gas-efficient outcome tracking instead of strings
    enum OutcomeType { NONE, OUTCOME_1, OUTCOME_2 }

    struct WithdrawalRequest {
        uint256 id;
        address user;
        uint256 tokenId;
        uint256 amount;
        WithdrawalStatus status;
    }

    uint256 public nextRequestId;
    mapping(uint256 => WithdrawalRequest) public withdrawalRequests;

    address public operator;

    // --- Events ---

    event ConditionWhitelistUpdated(bytes32 indexed conditionId, bool status);

    // FIXED: outcomeType is now an indexed uint8 (enum) instead of a gas-heavy string
    event TokenDeposited(
        address indexed user,
        uint256 indexed tokenId,
        uint256 amount,
        bool isNegRisk,
        uint8 indexed outcomeType
    );

    event WithdrawalRequested(uint256 indexed requestId, address indexed user, uint256 indexed tokenId, uint256 amount);
    event WithdrawalStatusUpdated(uint256 indexed requestId, WithdrawalStatus status);
    event WithdrawalFinalized(uint256 indexed requestId, address indexed user, uint256 indexed tokenId, uint256 amount);
    event LiquidationExecuted(address indexed borrower, address indexed liquidator, uint256 indexed tokenId, uint256 amount);
    event OperatorUpdated(address indexed newOperator);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address initialOwner, address _operator) public initializer {
        __Ownable_init(initialOwner);
        __ReentrancyGuard_init();
        __ERC1155Holder_init(); // FIXED: Initializing the upgradeable holder
        operator = _operator;
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    modifier onlyOwnerOrOperator() {
        require(msg.sender == owner() || msg.sender == operator, "Not owner or operator");
        _;
    }

    // --- Admin Functions ---

    function setOperator(address _operator) external onlyOwner {
        operator = _operator;
        emit OperatorUpdated(_operator);
    }

    function setWhitelistedConditionId(bytes32 _conditionId, bool _status) external onlyOwner {
        whitelistedConditions[_conditionId] = _status;
        emit ConditionWhitelistUpdated(_conditionId, _status);
    }

    /**
     * @notice Admin or Operator approves a withdrawal request.
     */
    function approveWithdrawal(uint256 _requestId) external onlyOwnerOrOperator {
        WithdrawalRequest storage request = withdrawalRequests[_requestId];
        require(request.user != address(0), "Request does not exist");
        require(request.status == WithdrawalStatus.Pending, "Not pending");

        request.status = WithdrawalStatus.Approved;
        emit WithdrawalStatusUpdated(_requestId, WithdrawalStatus.Approved);
    }

    /**
     * @notice Admin or Operator rejects a withdrawal request, returning funds to the user.
     */
    function rejectWithdrawal(uint256 _requestId) external onlyOwnerOrOperator {
        WithdrawalRequest storage request = withdrawalRequests[_requestId];
        require(request.user != address(0), "Request does not exist");
        require(request.status == WithdrawalStatus.Pending, "Not pending");

        request.status = WithdrawalStatus.Rejected;

        // Unlock the balance
        lockedBalances[request.user][request.tokenId] -= request.amount;
        userBalances[request.user][request.tokenId] += request.amount;

        emit WithdrawalStatusUpdated(_requestId, WithdrawalStatus.Rejected);
    }

    /**
     * @notice Executed by Admin to seize collateral from a borrower.
     * @dev Note: If a user has pending withdrawals, the admin should reject them first to seize locked funds.
     */
    function liquidateUserCollateral(
        address _borrower,
        address _liquidatorRecipient,
        uint256 _tokenId,
        uint256 _amount
    ) external onlyOwner nonReentrant {
        require(_liquidatorRecipient != address(0), "Invalid recipient");
        require(userBalances[_borrower][_tokenId] >= _amount, "Insufficient free collateral");

        // Deduct from Borrower
        userBalances[_borrower][_tokenId] -= _amount;

        // Transfer to Liquidator
        IConditionalTokens(CTF_ADDRESS).safeTransferFrom(
            address(this),
            _liquidatorRecipient,
            _tokenId,
            _amount,
            ""
        );

        emit LiquidationExecuted(_borrower, _liquidatorRecipient, _tokenId, _amount);
    }

    // --- User Functions ---

    /**
     * @notice Deposit Polymarket tokens.
     */
    function depositToken(
        bytes32 _conditionId,
        uint256 _tokenId,
        uint256 _amount,
        bool _isNegRisk
    ) external nonReentrant {
        require(whitelistedConditions[_conditionId], "Condition not whitelisted");
        require(_amount > 0, "Amount must be > 0");

        address collateralToken = _isNegRisk ? WRAPPED_COLLATERAL : USDC_E;
        bytes32 parentCollectionId = bytes32(0);

        bytes32 collectionIdIndex1 = IConditionalTokens(CTF_ADDRESS).getCollectionId(parentCollectionId, _conditionId, 1);
        bytes32 collectionIdIndex2 = IConditionalTokens(CTF_ADDRESS).getCollectionId(parentCollectionId, _conditionId, 2);

        uint256 positionIdIndex1 = IConditionalTokens(CTF_ADDRESS).getPositionId(collateralToken, collectionIdIndex1);
        uint256 positionIdIndex2 = IConditionalTokens(CTF_ADDRESS).getPositionId(collateralToken, collectionIdIndex2);

        OutcomeType outcomeType;
        if (_tokenId == positionIdIndex1) {
            outcomeType = OutcomeType.OUTCOME_1;
        } else if (_tokenId == positionIdIndex2) {
            outcomeType = OutcomeType.OUTCOME_2;
        } else {
            revert("Invalid Token ID: Does not match CTF");
        }

        // FIXED: Checks-Effects-Interactions (CEI) Pattern. Update state BEFORE external transfer.
        userBalances[msg.sender][_tokenId] += _amount;

        IConditionalTokens(CTF_ADDRESS).safeTransferFrom(
            msg.sender,
            address(this),
            _tokenId,
            _amount,
            ""
        );

        emit TokenDeposited(msg.sender, _tokenId, _amount, _isNegRisk, uint8(outcomeType));
    }

    /**
     * @notice Request withdrawal of tokens. Locks the balance to prevent double spending.
     */
    function requestWithdrawal(uint256 _tokenId, uint256 _amount) external {
        require(_amount > 0, "Amount must be > 0");
        require(userBalances[msg.sender][_tokenId] >= _amount, "Insufficient free balance");

        // FIXED: Lock the balance to prevent double spending
        userBalances[msg.sender][_tokenId] -= _amount;
        lockedBalances[msg.sender][_tokenId] += _amount;

        uint256 requestId = nextRequestId++;

        withdrawalRequests[requestId] = WithdrawalRequest({
            id: requestId,
            user: msg.sender,
            tokenId: _tokenId,
            amount: _amount,
            status: WithdrawalStatus.Pending
        });

        emit WithdrawalRequested(requestId, msg.sender, _tokenId, _amount);
    }

    /**
     * @notice Allows a user to cancel their pending withdrawal and unlock their tokens.
     */
    function cancelWithdrawal(uint256 _requestId) external {
        WithdrawalRequest storage request = withdrawalRequests[_requestId];
        require(request.user == msg.sender, "Not request owner");
        require(request.status == WithdrawalStatus.Pending, "Not pending");

        request.status = WithdrawalStatus.Cancelled;

        // Unlock the balance
        lockedBalances[msg.sender][request.tokenId] -= request.amount;
        userBalances[msg.sender][request.tokenId] += request.amount;

        emit WithdrawalStatusUpdated(_requestId, WithdrawalStatus.Cancelled);
    }

    /**
     * @notice Claim an approved withdrawal.
     */
    function claimWithdrawal(uint256 _requestId) external nonReentrant {
        WithdrawalRequest storage request = withdrawalRequests[_requestId];
        require(request.user == msg.sender, "Not request owner");
        require(request.status == WithdrawalStatus.Approved, "Not approved");
        require(lockedBalances[request.user][request.tokenId] >= request.amount, "Insufficient locked balance");

        // Update state
        request.status = WithdrawalStatus.Processed;
        lockedBalances[request.user][request.tokenId] -= request.amount;

        // Transfer tokens out
        IConditionalTokens(CTF_ADDRESS).safeTransferFrom(
            address(this),
            request.user,
            request.tokenId,
            request.amount,
            ""
        );

        emit WithdrawalFinalized(_requestId, request.user, request.tokenId, request.amount);
    }
}