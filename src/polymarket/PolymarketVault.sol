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
    address public constant P_USD = 0xC011a7E12a19f7B1f670d46F03B03f3342E82DFB;
    address public constant WRAPPED_COLLATERAL = 0x3A3BD7bb9528E159577F7C2e685CC81A765002E2;
    address public constant USDC_E = 0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174;

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

    // Resolved CTF metadata for a Position ID, recorded when the ID is registered.
    struct PositionInfo {
        bytes32 conditionId;
        bool isNegRisk;
        OutcomeType outcome;
    }

    uint256 public nextRequestId;
    mapping(uint256 => WithdrawalRequest) public withdrawalRequests;

    address public operator;

    // --- V6: Polymarket Deposit Wallet support ---
    // A Polymarket Deposit Wallet can only call contracts whitelisted by Polymarket's relayer, so it
    // reaches this vault by transferring CTF tokens in directly, and is paid out by the operator.

    // Polymarket Deposit Wallet => the Positions account it deposits on behalf of
    mapping(address => address) public depositWalletToOwner;

    // Position ID => CTF metadata. Populated by registerPositionId(), which validates the ID against
    // the CTF contract, so an incoming transfer can be verified without the sender passing any data.
    mapping(uint256 => PositionInfo) public registeredPositions;

    // Transfers from an unlinked sender are parked here instead of being credited.
    // Sender Address => Token ID => Amount
    mapping(address => mapping(uint256 => uint256)) public unattributedBalances;

    // Set while depositToken() performs its own pull transfer, so the ERC1155 receive hook does not
    // credit tokens that the deposit path has already accounted for.
    bool private isPullDeposit;

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

    // --- V6 Events ---

    event PositionIdRegistered(uint256 indexed tokenId, bytes32 indexed conditionId, uint8 indexed outcomeType);
    event DepositWalletLinked(address indexed depositWallet, address indexed owner);
    event DepositWalletUnlinked(address indexed depositWallet, address indexed previousOwner);
    /// @dev Emitted alongside TokenDeposited so the sending Deposit Wallet stays recoverable on-chain.
    event TokenTransferDeposited(address indexed user, address indexed from, uint256 indexed tokenId, uint256 amount);
    event UnattributedDeposit(address indexed from, uint256 indexed tokenId, uint256 amount);
    event UnattributedDepositCredited(address indexed from, address indexed user, uint256 indexed tokenId, uint256 amount);
    event OperatorWithdrawal(address indexed user, uint256 indexed tokenId, uint256 amount, address indexed to);

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

    modifier onlyOperator() {
        require(msg.sender == operator, "Not operator");
        _;
    }

    // --- Admin Functions ---

    function setOperator(address _operator) external onlyOwner {
        operator = _operator;
        emit OperatorUpdated(_operator);
    }

    function setWhitelistedConditionId(bytes32 _conditionId, bool _status) external onlyOperator {
        whitelistedConditions[_conditionId] = _status;
        emit ConditionWhitelistUpdated(_conditionId, _status);
    }

    function setWhitelistedConditionIds(bytes32[] calldata _conditionIds, bool _status) external onlyOperator {
        for (uint256 i = 0; i < _conditionIds.length; i++) {
            whitelistedConditions[_conditionIds[i]] = _status;
            emit ConditionWhitelistUpdated(_conditionIds[i], _status);
        }
    }

    /**
     * @notice Links a Polymarket Deposit Wallet to the Positions account it deposits for.
     * @dev Deposit Wallets cannot call this vault, so the link is asserted by the operator, which
     * verifies the Deposit Wallet <> owner relationship off-chain before calling. Any CTF tokens the
     * wallet transfers in after this point are credited to `_owner`.
     * @param _depositWallet The Polymarket Deposit Wallet (proxy) address.
     * @param _owner The Positions account that owns the Deposit Wallet.
     */
    function linkDepositWallet(address _depositWallet, address _owner) public onlyOperator {
        require(_depositWallet != address(0) && _owner != address(0), "Invalid address");
        require(depositWalletToOwner[_depositWallet] == address(0), "Wallet already linked");

        depositWalletToOwner[_depositWallet] = _owner;

        emit DepositWalletLinked(_depositWallet, _owner);
    }

    /**
     * @notice Links several Deposit Wallets in one call.
     */
    function linkDepositWallets(address[] calldata _depositWallets, address[] calldata _owners) external onlyOperator {
        require(_depositWallets.length == _owners.length, "Length mismatch");

        for (uint256 i = 0; i < _depositWallets.length; i++) {
            linkDepositWallet(_depositWallets[i], _owners[i]);
        }
    }

    /**
     * @notice Removes a Deposit Wallet link. Already credited balances are untouched; subsequent
     * transfers from this wallet are parked as unattributed.
     */
    function unlinkDepositWallet(address _depositWallet) external onlyOperator {
        address previousOwner = depositWalletToOwner[_depositWallet];
        require(previousOwner != address(0), "Wallet not linked");

        delete depositWalletToOwner[_depositWallet];

        emit DepositWalletUnlinked(_depositWallet, previousOwner);
    }

    /**
     * @notice Credits tokens received from an unlinked sender to a Positions account.
     * @dev Bounded to what that exact sender actually transferred in, so the operator can attribute
     * deposits but can never move an already credited balance.
     * @param _from The address the tokens were transferred from.
     * @param _tokenId The CTF Position ID.
     * @param _amount The amount to credit.
     * @param _user The Positions account to credit.
     */
    function creditUnattributedDeposit(address _from, uint256 _tokenId, uint256 _amount, address _user)
        external
        onlyOperator
    {
        require(_user != address(0), "Invalid user");
        _creditUnattributedDeposit(_from, _tokenId, _amount, _user);
    }

    /**
     * @notice Pushes tokens out of the vault on behalf of a user.
     * @dev A Deposit Wallet cannot call claimWithdrawal(), so the operator settles the withdrawal for
     * it after running the same health-factor checks it applies to approveWithdrawal().
     * @param _user The Positions account to debit.
     * @param _tokenId The CTF Position ID.
     * @param _amount The amount to withdraw.
     * @param _to The recipient of the tokens (typically the user's Deposit Wallet).
     */
    function operatorWithdraw(address _user, uint256 _tokenId, uint256 _amount, address _to)
        external
        onlyOperator
        nonReentrant
    {
        require(_to != address(0), "Invalid recipient");
        require(_amount > 0, "Amount must be > 0");
        require(userBalances[_user][_tokenId] >= _amount, "Insufficient free balance");

        userBalances[_user][_tokenId] -= _amount;

        IConditionalTokens(CTF_ADDRESS).safeTransferFrom(address(this), _to, _tokenId, _amount, "");

        emit OperatorWithdrawal(_user, _tokenId, _amount, _to);
    }

    /**
     * @notice Admin or Operator approves a withdrawal request.
     */
    function approveWithdrawal(uint256 _requestId) external onlyOperator {
        WithdrawalRequest storage request = withdrawalRequests[_requestId];
        require(request.user != address(0), "Request does not exist");
        require(request.status == WithdrawalStatus.Pending, "Not pending");

        request.status = WithdrawalStatus.Approved;
        emit WithdrawalStatusUpdated(_requestId, WithdrawalStatus.Approved);
    }

    /**
     * @notice Admin or Operator rejects a withdrawal request, returning funds to the user.
     */
    function rejectWithdrawal(uint256 _requestId) external onlyOperator {
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
    ) external onlyOperator nonReentrant {
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
     * @notice Records a Position ID against its whitelisted condition.
     * @dev Permissionless: the mapping is derived from the CTF contract, so a caller can only register
     * IDs that genuinely belong to an already whitelisted condition. Registration is what lets the
     * ERC1155 receive hook validate a bare transfer, which carries no condition ID of its own.
     * @param _conditionId The whitelisted condition ID.
     * @param _tokenId The CTF Position ID to register.
     * @param _isNegRisk Whether the market uses the neg-risk wrapped collateral.
     */
    function registerPositionId(bytes32 _conditionId, uint256 _tokenId, bool _isNegRisk)
        public
        returns (OutcomeType)
    {
        // An unregistered Position ID reads back as a zero conditionId, so without this a zero
        // conditionId would match the cache and skip validation entirely.
        require(_conditionId != bytes32(0), "Invalid condition Id");
        require(whitelistedConditions[_conditionId], "Condition not whitelisted");

        // Already resolved against the CTF contract; skip the four staticcalls.
        PositionInfo memory recorded = registeredPositions[_tokenId];
        if (recorded.conditionId == _conditionId && recorded.isNegRisk == _isNegRisk) return recorded.outcome;

        OutcomeType outcomeType = _resolveOutcome(_conditionId, _tokenId, _isNegRisk);
        require(outcomeType != OutcomeType.NONE, "Invalid Token ID: Does not match CTF");

        _recordPositionId(_conditionId, _tokenId, _isNegRisk, outcomeType);

        return outcomeType;
    }

    /**
     * @notice Registers several Position IDs of a single condition in one call.
     */
    function registerPositionIds(bytes32 _conditionId, uint256[] calldata _tokenIds, bool _isNegRisk) external {
        for (uint256 i = 0; i < _tokenIds.length; i++) {
            registerPositionId(_conditionId, _tokenIds[i], _isNegRisk);
        }
    }

    /**
     * @notice Registers Position IDs spanning many conditions in a single call.
     * @dev Parallel arrays, one entry per token, so a whole batch of markets registers in one
     * transaction instead of one per condition.
     *
     * Unlike registerPositionId, an entry that cannot be registered is skipped rather than reverting
     * the batch: bulk registration is fed from off-chain market data, where a single stale condition
     * would otherwise block every other token in the call. Already registered entries are skipped
     * too, so the caller can resend the same set safely. Compare the return value against the input
     * length to see whether anything was rejected.
     *
     * @param _conditionIds The condition each token belongs to.
     * @param _tokenIds The CTF Position IDs to register.
     * @param _isNegRisks Whether each token's market uses the neg-risk wrapped collateral.
     * @return registered The number of Position IDs newly registered.
     */
    function registerPositionIdsBatch(
        bytes32[] calldata _conditionIds,
        uint256[] calldata _tokenIds,
        bool[] calldata _isNegRisks
    ) external returns (uint256 registered) {
        require(
            _conditionIds.length == _tokenIds.length && _tokenIds.length == _isNegRisks.length, "Length mismatch"
        );

        for (uint256 i = 0; i < _tokenIds.length; i++) {
            if (_tryRegisterPositionId(_conditionIds[i], _tokenIds[i], _isNegRisks[i])) {
                ++registered;
            }
        }
    }

    /**
     * @notice Deposit Polymarket tokens.
     */
    function depositToken(
        bytes32 _conditionId,
        uint256 _tokenId,
        uint256 _amount,
        bool _isNegRisk
    ) external nonReentrant {
        require(_amount > 0, "Amount must be > 0");

        OutcomeType outcomeType = registerPositionId(_conditionId, _tokenId, _isNegRisk);

        // Update state
        userBalances[msg.sender][_tokenId] += _amount;

        // The pull below re-enters through onERC1155Received; flag it so the hook does not credit
        // this transfer a second time.
        isPullDeposit = true;

        IConditionalTokens(CTF_ADDRESS).safeTransferFrom(
            msg.sender,
            address(this),
            _tokenId,
            _amount,
            ""
        );

        isPullDeposit = false;

        emit TokenDeposited(msg.sender, _tokenId, _amount, _isNegRisk, uint8(outcomeType));
    }

    /**
     * @notice Credits CTF tokens transferred straight into the vault, with no contract call.
     * @dev This is the only path a Polymarket Deposit Wallet has: Polymarket's relayer refuses calls to
     * contracts it has not whitelisted, but it will relay a plain safeTransferFrom on the CTF contract.
     */
    function onERC1155Received(address, address _from, uint256 _id, uint256 _value, bytes memory)
        public
        override
        returns (bytes4)
    {
        _creditIncomingTransfer(_from, _id, _value);

        return this.onERC1155Received.selector;
    }

    /**
     * @notice Batch variant of the incoming transfer credit.
     */
    function onERC1155BatchReceived(
        address,
        address _from,
        uint256[] memory _ids,
        uint256[] memory _values,
        bytes memory
    ) public override returns (bytes4) {
        require(_ids.length == _values.length, "Length mismatch");

        for (uint256 i = 0; i < _ids.length; i++) {
            _creditIncomingTransfer(_from, _ids[i], _values[i]);
        }

        return this.onERC1155BatchReceived.selector;
    }

    /**
     * @notice Lets a sender claim tokens it transferred in before being linked.
     * @dev Only useful to senders that can transact themselves; a Deposit Wallet is credited by the
     * operator through creditUnattributedDeposit() instead.
     */
    function claimUnattributedDeposit(uint256 _tokenId, uint256 _amount) external {
        _creditUnattributedDeposit(msg.sender, _tokenId, _amount, msg.sender);
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

    // --- Internal Functions ---

    /**
     * @dev The non-reverting form of registerPositionId, used for bulk registration.
     * @return Whether the Position ID was newly registered.
     */
    function _tryRegisterPositionId(bytes32 _conditionId, uint256 _tokenId, bool _isNegRisk)
        internal
        returns (bool)
    {
        if (_conditionId == bytes32(0) || !whitelistedConditions[_conditionId]) return false;

        PositionInfo memory recorded = registeredPositions[_tokenId];
        if (recorded.conditionId == _conditionId && recorded.isNegRisk == _isNegRisk) return false;

        OutcomeType outcomeType = _resolveOutcome(_conditionId, _tokenId, _isNegRisk);
        if (outcomeType == OutcomeType.NONE) return false;

        _recordPositionId(_conditionId, _tokenId, _isNegRisk, outcomeType);

        return true;
    }

    function _recordPositionId(bytes32 _conditionId, uint256 _tokenId, bool _isNegRisk, OutcomeType _outcomeType)
        internal
    {
        registeredPositions[_tokenId] =
            PositionInfo({conditionId: _conditionId, isNegRisk: _isNegRisk, outcome: _outcomeType});

        emit PositionIdRegistered(_tokenId, _conditionId, uint8(_outcomeType));
    }

    /**
     * @dev Resolves which outcome of `_conditionId` a Position ID represents, by rebuilding the ID from
     * the CTF contract. Returns OutcomeType.NONE if the ID belongs to neither outcome.
     */
    function _resolveOutcome(bytes32 _conditionId, uint256 _tokenId, bool _isNegRisk)
        internal
        view
        returns (OutcomeType)
    {
        // Default to V2 Collateral
        address collateralToken = _isNegRisk ? WRAPPED_COLLATERAL : P_USD;
        bytes32 parentCollectionId = bytes32(0);

        bytes32 collectionIdIndex1 = IConditionalTokens(CTF_ADDRESS).getCollectionId(parentCollectionId, _conditionId, 1);
        bytes32 collectionIdIndex2 = IConditionalTokens(CTF_ADDRESS).getCollectionId(parentCollectionId, _conditionId, 2);

        // Calculate expected V2 Token IDs
        uint256 positionIdIndex1 = IConditionalTokens(CTF_ADDRESS).getPositionId(collateralToken, collectionIdIndex1);
        uint256 positionIdIndex2 = IConditionalTokens(CTF_ADDRESS).getPositionId(collateralToken, collectionIdIndex2);

        // 1. Check if it matches V2
        if (_tokenId == positionIdIndex1) {
            return OutcomeType.OUTCOME_1;
        } else if (_tokenId == positionIdIndex2) {
            return OutcomeType.OUTCOME_2;
        }
            // 2. FALLBACK: Check if it matches Legacy V1 (USDC.e)
        else if (!_isNegRisk) {
            uint256 v1PositionIdIndex1 = IConditionalTokens(CTF_ADDRESS).getPositionId(USDC_E, collectionIdIndex1);
            uint256 v1PositionIdIndex2 = IConditionalTokens(CTF_ADDRESS).getPositionId(USDC_E, collectionIdIndex2);

            if (_tokenId == v1PositionIdIndex1) {
                return OutcomeType.OUTCOME_1;
            } else if (_tokenId == v1PositionIdIndex2) {
                return OutcomeType.OUTCOME_2;
            }
        }

        return OutcomeType.NONE;
    }

    /**
     * @dev Credits one incoming CTF transfer. Called from the ERC1155 receive hooks, so it runs inside
     * the CTF transfer itself and must reject anything it cannot attribute to a whitelisted market.
     */
    function _creditIncomingTransfer(address _from, uint256 _tokenId, uint256 _amount) internal {
        require(msg.sender == CTF_ADDRESS, "Only CTF tokens accepted");

        // depositToken() credits its own pull before transferring.
        if (isPullDeposit) return;

        require(_amount > 0, "Amount must be > 0");

        PositionInfo memory position = registeredPositions[_tokenId];
        require(position.conditionId != bytes32(0), "Token ID not registered");
        require(whitelistedConditions[position.conditionId], "Condition not whitelisted");

        address owner = depositWalletToOwner[_from];

        // An unlinked sender cannot be resolved to a Positions account on-chain. Park the tokens rather
        // than crediting an address that may be a proxy nobody can withdraw from.
        if (owner == address(0)) {
            unattributedBalances[_from][_tokenId] += _amount;

            emit UnattributedDeposit(_from, _tokenId, _amount);

            return;
        }

        userBalances[owner][_tokenId] += _amount;

        emit TokenTransferDeposited(owner, _from, _tokenId, _amount);
        emit TokenDeposited(owner, _tokenId, _amount, position.isNegRisk, uint8(position.outcome));
    }

    /**
     * @dev Moves a parked transfer into a user's balance.
     */
    function _creditUnattributedDeposit(address _from, uint256 _tokenId, uint256 _amount, address _user) internal {
        require(_amount > 0, "Amount must be > 0");
        require(unattributedBalances[_from][_tokenId] >= _amount, "Insufficient unattributed balance");

        unattributedBalances[_from][_tokenId] -= _amount;
        userBalances[_user][_tokenId] += _amount;

        PositionInfo memory position = registeredPositions[_tokenId];

        emit UnattributedDepositCredited(_from, _user, _tokenId, _amount);
        emit TokenDeposited(_user, _tokenId, _amount, position.isNegRisk, uint8(position.outcome));
    }
}