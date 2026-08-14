// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IERC20} from "@openzeppelin-contracts-5.3.0/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin-contracts-5.3.0/token/ERC20/extensions/IERC20Metadata.sol";

import {OwnableUpgradeable} from "@openzeppelin-contracts-upgradeable-5.3.0/access/OwnableUpgradeable.sol";
import {Initializable} from "@openzeppelin-contracts-upgradeable-5.3.0/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin-contracts-upgradeable-5.3.0/proxy/utils/UUPSUpgradeable.sol";
import {SafeERC20} from "@openzeppelin-contracts-5.3.0/token/ERC20/utils/SafeERC20.sol";
import {EnumerableSet} from "@openzeppelin-contracts-5.3.0/utils/structs/EnumerableSet.sol";

import {IPriceOracle} from "../../interfaces/oracle/IPriceOracle.sol";
import {IPositionsRelayer} from "../../interfaces/poc/IPositionsRelayer.sol";
import {IPositionsLendingPoolHandler} from "../../interfaces/handlers/IPositionsLendingPoolHandler.sol";

/// @title PositionsLendingPool.
/// @author Positions Team.
/// @notice A lending pool inspired from Aave V2 that integrates the Positions Nft
/// as collateral.
contract PositionsLendingPool is Initializable, UUPSUpgradeable, OwnableUpgradeable {
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.Bytes32Set;
    using EnumerableSet for EnumerableSet.AddressSet;

    /////////////////////////
    /// Type Declarations ///
    /////////////////////////

    struct InterestRateModel {
        uint256 baseRate;
        uint256 slope1;
        uint256 slope2;
        uint256 optimalUtilization;
    }

    struct PoolData {
        uint256 totalLent;
        uint256 totalBorrowed;
        uint256 supplyIndex;
        uint256 borrowIndex;
        InterestRateModel interestRateModel;
        uint256 lastAccrualTimestamp;
    }

    struct LenderInfo {
        uint256 depositAmount; // Principal deposited by the lender
        uint256 supplyIndexSnapshot; // Snapshot of supply index when user interacted last
    }

    struct BorrowerInfo {
        uint256 borrowedAmount; // Principal borrowed by the borrower
        uint256 borrowIndexSnapshot; // Snapshot of borrow index when user interacted last
    }

    struct ReserveData {
        uint256 totalLiquidity;
        uint256 availableLiquidity;
        uint256 totalBorrows;
        uint256 reserveFactor;
        uint256 baseRate;
        uint256 slope1;
        uint256 slope2;
        uint256 optimalUtilization;
        uint256 lastUpdateTimestamp;
        uint256 supplyIndex;
        uint256 borrowIndex;
        uint256 supplyRate;
        uint256 borrowRate;
        uint256 utilization;
    }

    struct SupplierData {
        address asset;
        uint256 balanceWithInterest;
    }

    ///////////////////////
    /// State Variables ///
    ///////////////////////

    uint256 private constant BPS = 1e4;
    uint256 private constant E9 = 1e9;
    uint256 private constant E27 = 1e27;
    uint256 private constant YEAR = 365 days;

    /// @notice The position relayer address to create borrow requests on.
    address public positionsRelayer;
    /// @notice The oracle to query lent asset prices from.
    address public oracle;

    /// @notice The reserve factor for lending. This is the percentage of the supply interest that goes to the protocol.
    uint256 public reserveFactor;
    /// @notice The recipient of the protocol's cut of the interest.
    address public treasury;

    /// @dev A set of supported assets for lending.
    EnumerableSet.AddressSet private supportedAssets;
    /// @notice Tracks the lending pool data (interest rate model and supply and borrow indices) for each asset.
    mapping(address asset => PoolData poolData) public poolData;
    /// @notice Tracks each user's supplied assets and their associated supply index snapshots.
    mapping(address user => mapping(address asset => LenderInfo lendingInfo)) public userToAssetToLendingInfo;
    /// @notice Tracks each user's Nft's borrowed assets and their associated borrow index snapshots.
    mapping(uint256 tokenId => mapping(address asset => BorrowerInfo borrowInfo)) public tokenIdToAssetToBorrowInfo;
    /// @dev Tracks the borrow request Ids per user's Nft per asset. If a borrow position is liquidated or repaid,
    /// the requestId is removed.
    mapping(uint256 tokenId => mapping(address asset => EnumerableSet.Bytes32Set requestIds)) private
    userToAssetToRequestIds;

    /// @notice The protocol backend authorised to settle bare token transfers into positions, and to push
    /// borrowed or withdrawn funds out on behalf of users who cannot call this pool themselves.
    /// @dev A Polymarket Deposit Wallet is one such user: Polymarket's relayer only relays calls to
    /// contracts it has whitelisted, so the wallet can transfer tokens here but never call this contract.
    address public operator;
    /// @notice The amount of each asset this pool has already recognised in its internal ledger.
    /// @dev Anything held above this figure arrived as a bare transfer and is settleable. Bounding the
    /// operator to that surplus means it can attribute incoming funds but never credit funds that never
    /// arrived.
    mapping(address asset => uint256 amount) public accountedBalance;
    /// @notice Whether an asset's accounted balance has been snapshotted against its real balance.
    /// @dev Settlement is refused until it has. Without this an asset that predates the transfer
    /// settlement upgrade and was missed at initialization would read as having its entire balance
    /// unaccounted, and so be creditable to anyone.
    mapping(address asset => bool synced) public accountedBalanceSynced;
    /// @notice The lending pool handler, which holds every collateral position on behalf of Nfts.
    /// @dev Settled deposits are supplied under the handler and attributed to an Nft by it, so that a
    /// transfer-based deposit becomes collateral exactly like one made through the entrypoint.
    address public lendingPoolHandler;

    //////////////
    /// Events ///
    //////////////

    event PositionsRelayerSet(address indexed newPositionsRelayer);
    event OracleSet(address indexed newOracle);
    event ReserveFactorUpdated(uint256 indexed newReserveFactor);
    event TreasurySet(address indexed newTreasury);
    event LendingPoolCreated(address indexed asset, PoolData indexed lendingPoolData);
    event LendingPoolInterestRateModelUpdated(address indexed asset, InterestRateModel indexed interestRateModel);
    event Supply(address user, address indexed asset, uint256 indexed amount, address indexed onBehalfOf);
    event Withdraw(address indexed by, uint256 indexed amount, uint256 indexed interest, address to);
    event BorrowRequestFulfilled(uint256 indexed tokenId, address indexed asset, uint256 indexed amount);
    event Repay(address by, address indexed asset, uint256 indexed amount, uint256 indexed tokenId);
    event BorrowRequest(bytes32 indexed requestId);
    event OperatorSet(address indexed newOperator);
    event LendingPoolHandlerSet(address indexed newHandler);
    event AccountedBalanceSynced(address indexed asset, uint256 indexed amount);
    event TransferSettled(
        address indexed user, address indexed asset, uint256 indexed tokenId, uint256 repaid, uint256 supplied
    );
    event OperatorBorrow(uint256 indexed tokenId, address indexed asset, uint256 indexed amount, address to);
    event OperatorBorrowFee(uint256 indexed tokenId, address indexed asset, uint256 indexed fee, address recipient);

    //////////////
    /// Errors ///
    //////////////

    error NotPositionsRelayer(address caller, address positionsRelayer);
    error AddressZero();
    error InvalidReserveFactor(uint256 newReserveFactor);
    error InvalidLendingPoolConfig();
    error AmountZero();
    error InsufficientLiquidityInLendingPool();
    error InvalidRequest(IPositionsRelayer.PositionsCollateralRequest collateralRequest);
    error RequestAlreadyFulfilled(bytes32 requestId);
    error InvalidRequestId(bytes32 requestId);
    error LendingPoolDoesNotExist(PoolData lendingPoolData);
    error InsufficientBalance();
    error NotRelayer();
    error NotOperator(address caller, address operator);
    error UnaccountedTransferTooSmall(uint256 requested, uint256 available);
    error AccountedBalanceNotSynced(address asset);
    error LendingPoolHandlerNotSet();

    /////////////////
    /// Modifiers ///
    /////////////////

    modifier onlyRelayer() {
        if (msg.sender != positionsRelayer) {
            revert NotPositionsRelayer(msg.sender, positionsRelayer);
        }
        _;
    }

    modifier onlyOperator() {
        if (msg.sender != operator) {
            revert NotOperator(msg.sender, operator);
        }
        _;
    }

    ///////////////////
    /// Constructor ///
    ///////////////////

    /// @notice Sets the admin, the positions relayer, and the initial reserve factor.
    /// @param _admin The initial admin address.
    /// @param _positionsRelayer The positions relayer address.
    /// @param _priceOracle The price oracle contract address.
    /// @param _initialReserveFactor The initial reserve factor (in bps).
    function initialize(address _admin, address _positionsRelayer, address _priceOracle, uint256 _initialReserveFactor)
    public
    initializer
    {
        __Ownable_init(_admin);

        positionsRelayer = _positionsRelayer;
        oracle = _priceOracle;
        reserveFactor = _initialReserveFactor;
    }

    /// @notice Sets the operator and takes the initial snapshot of the pool's accounted balances.
    /// @dev Must run in the same transaction as the upgrade that introduces transfer settlement.
    /// Skipping it would leave every asset already held by the pool looking like an unaccounted
    /// transfer, and therefore creditable by the operator.
    /// @param _operator The protocol backend address.
    /// @param _assets The assets to snapshot. Pass every asset the pool currently holds.
    function initializeTransferSettlement(address _operator, address[] calldata _assets)
        external
        onlyOwner
        reinitializer(2)
    {
        _setOperator(_operator);
        _syncAccountedBalance(_assets);
    }

    //////////////////////////
    /// External functions ///
    //////////////////////////

    /// @notice Allows the protocol admin to set the operator (protocol backend) address.
    /// @param _newOperator The new operator address.
    function setOperator(address _newOperator) external onlyOwner {
        _setOperator(_newOperator);
    }

    /// @notice Allows the protocol admin to set the lending pool handler.
    /// @param _newHandler The handler that holds collateral positions on behalf of Nfts.
    function setLendingPoolHandler(address _newHandler) external onlyOwner {
        if (_newHandler == address(0)) revert AddressZero();

        lendingPoolHandler = _newHandler;

        emit LendingPoolHandlerSet(_newHandler);
    }

    /// @notice Re-snapshots the pool's accounted balance for the given assets.
    /// @dev Needed for assets whose lending pool is created after the transfer settlement upgrade, since
    /// they hold no balance at that point. Only ever call this when there is no unsettled transfer in
    /// flight for the asset: any surplus held at the time of the call is absorbed and stops being
    /// creditable.
    /// @param _assets The assets to snapshot.
    function syncAccountedBalance(address[] calldata _assets) external onlyOwner {
        _syncAccountedBalance(_assets);
    }

    /// @notice Allows the protocol admin to set the positions relayer contract address.
    /// @param _newRelayer The new positions relayer contract address.
    function setPositionsRelayer(address _newRelayer) external onlyOwner {
        if (_newRelayer == address(0)) revert AddressZero();

        positionsRelayer = _newRelayer;

        emit PositionsRelayerSet(_newRelayer);
    }

    /// @notice Allows the protocol admin to set the oracle contract address.
    /// @param _newOracle The new oracle contract address.
    function setOracle(address _newOracle) external onlyOwner {
        if (_newOracle == address(0)) revert AddressZero();

        oracle = _newOracle;

        emit OracleSet(_newOracle);
    }

    /// @notice Allows the protocol admin to update the reserve factor.
    /// @param _newReserveFactor The new reserve factor (in bps).
    function updateReserveFactor(uint256 _newReserveFactor) external onlyOwner {
        if (_newReserveFactor >= BPS) revert InvalidReserveFactor(_newReserveFactor);

        reserveFactor = _newReserveFactor;

        emit ReserveFactorUpdated(_newReserveFactor);
    }

    /// @notice Allows the owner to set the treasury address.
    /// @param _newTreasury The new treasury address.
    function setTreasury(address _newTreasury) external onlyOwner {
        if (_newTreasury == address(0)) revert AddressZero();

        treasury = _newTreasury;

        emit TreasurySet(_newTreasury);
    }

    /// @notice Allows the protocol admin to create lending pools with custom interest rate models for different
    /// assets.
    /// @param _asset The asset to create a lending pool for.
    /// @param _interestRateModel The interest rate model which dynamically adjusts interest rates depending
    /// on lending pool utilization.
    function createLendingPool(address _asset, InterestRateModel calldata _interestRateModel) external onlyOwner {
        if (
            _asset == address(0) || _interestRateModel.slope1 == 0 || _interestRateModel.slope2 == 0
            || _interestRateModel.optimalUtilization == 0 || _interestRateModel.baseRate > E27
            || _interestRateModel.slope1 > E27 || _interestRateModel.slope2 > E27
            || _interestRateModel.optimalUtilization > E27
        ) revert InvalidLendingPoolConfig();

        PoolData memory lendingPoolData = PoolData({
            totalLent: 0,
            totalBorrowed: 0,
            supplyIndex: E27,
            borrowIndex: E27,
            interestRateModel: _interestRateModel,
            lastAccrualTimestamp: block.timestamp
        });
        poolData[_asset] = lendingPoolData;
        supportedAssets.add(_asset);

        // Snapshots whatever the pool already holds, so a balance sent here before the pool existed
        // does not read as a settleable transfer.
        _syncAccountedBalance(_asset);

        emit LendingPoolCreated(_asset, lendingPoolData);
    }

    /// @notice Allows the protocol admin to update the interest rate model for an existing lending pool.
    /// @param _asset The asset address.
    /// @param _interestRateModel The new interest rate model.
    function updateLendingPoolInterestRateModel(address _asset, InterestRateModel calldata _interestRateModel)
    external
    onlyOwner
    {
        if (
            _asset == address(0) || _interestRateModel.slope1 == 0 || _interestRateModel.slope2 == 0
            || _interestRateModel.optimalUtilization == 0 || _interestRateModel.baseRate > E27
            || _interestRateModel.slope1 > E27 || _interestRateModel.slope2 > E27
            || _interestRateModel.optimalUtilization > E27
        ) revert InvalidLendingPoolConfig();

        poolData[_asset].interestRateModel = _interestRateModel;

        emit LendingPoolInterestRateModelUpdated(_asset, _interestRateModel);
    }

    /// @notice Enables any user to supply supported assets for lending and start earning interest (depending on
    /// utilization).
    /// @param _asset The asset to supply.
    /// @param _amount The amount of asset to supply.
    /// @param _for Open a supply position on behalf of another address.
    function supply(address _asset, uint256 _amount, address _for) external {
        if (_asset == address(0)) revert AddressZero();
        if (_amount == 0) revert AmountZero();
        if (_for == address(0)) revert AddressZero();

        PoolData storage lendingPoolData = poolData[_asset];

        _revertIfLendingPoolDoesNotExist(lendingPoolData);
        _accrueInterest(_asset, lendingPoolData);
        _supply(_asset, _amount, _for, lendingPoolData);

        accountedBalance[_asset] += _amount;

        IERC20(_asset).safeTransferFrom(msg.sender, address(this), _amount);

        emit Supply(msg.sender, _asset, _amount, _for);
    }

    /// @notice Allows users with a valid supply position to exit the position with any accumulated interest.
    /// @param _asset The asset to withdraw.
    /// @param _amount The amount of asset to withdraw.
    /// @param _to The address to direct the withdrawn asset amount to.
    function withdraw(address _asset, uint256 _amount, address _to) external {
        if (_asset == address(0) || _to == address(0)) revert AddressZero();
        if (_amount == 0) revert AmountZero();

        PoolData storage lendingPoolData = poolData[_asset];

        _revertIfLendingPoolDoesNotExist(lendingPoolData);
        _accrueInterest(_asset, lendingPoolData);

        uint256 accruedInterest = _withdraw(msg.sender, _asset, _amount, _to, lendingPoolData);

        emit Withdraw(msg.sender, _amount, accruedInterest, _to);
    }

    /// @notice Create a collateral request on the positions relayer to allow the user to open a borrow position
    /// on the specified lending pool.
    /// @param _collateralRequest The collateral request details.
    /// @param _signature The signature associated with the request. To be verified on the relayer backend.
    function borrowRequest(
        IPositionsRelayer.PositionsCollateralRequest memory _collateralRequest,
        bytes memory _signature
    ) external returns (bytes32) {
        if (
            _collateralRequest.protocol != address(this) || !supportedAssets.contains(_collateralRequest.token)
        || _collateralRequest.owner != msg.sender || _collateralRequest.tokenAmount == 0
        ) revert InvalidRequest(_collateralRequest);

        bytes32 requestId = IPositionsRelayer(positionsRelayer).requestCollateral(_collateralRequest, _signature);

        emit BorrowRequest(requestId);

        return requestId;
    }

    /// @notice Callback by the positions relayer into the lending pool if a borrow request was approved.
    /// A borrow position is opened on the lending pool from the collateral request details.
    /// @param _requestId The borrow requestId.
    function fullfillCollateralRequest(bytes32 _requestId) external onlyRelayer {
        IPositionsRelayer.PositionsCollateralRequest memory collateralRequest =
                                IPositionsRelayer(positionsRelayer).collateralRequests(_requestId);

        PoolData storage lendingPoolData = poolData[collateralRequest.token];
        BorrowerInfo storage borrowerInfo =
                            tokenIdToAssetToBorrowInfo[collateralRequest.tokenId][collateralRequest.token];

        if (collateralRequest.tokenAmount == 0) revert AmountZero();
        _revertIfLendingPoolDoesNotExist(lendingPoolData);
        _accrueInterest(collateralRequest.token, lendingPoolData);
        if (lendingPoolData.totalLent <= lendingPoolData.totalBorrowed) revert InsufficientLiquidityInLendingPool();

        if (!userToAssetToRequestIds[collateralRequest.tokenId][collateralRequest.token].add(_requestId)) {
            revert RequestAlreadyFulfilled(_requestId);
        }

        borrowerInfo.borrowedAmount += collateralRequest.tokenAmount;
        borrowerInfo.borrowIndexSnapshot = lendingPoolData.borrowIndex;

        lendingPoolData.totalBorrowed += collateralRequest.tokenAmount;

        _decreaseAccountedBalance(collateralRequest.token, collateralRequest.tokenAmount);

        IERC20(collateralRequest.token).safeTransfer(positionsRelayer, collateralRequest.tokenAmount);

        emit BorrowRequestFulfilled(collateralRequest.tokenId, collateralRequest.token, collateralRequest.tokenAmount);
    }

    /// @notice Allows anyone to repay debt amount for any valid borrow position.
    /// @param _asset The asset address.
    /// @param _amount The amount of debt to cover.
    /// @param _tokenId A user's Nft tokenId to repay the debt of.
    function repayDebt(address _asset, uint256 _amount, uint256 _tokenId) external {
        if (_asset == address(0)) revert AddressZero();
        if (_amount == 0) revert AmountZero();

        PoolData storage lendingPoolData = poolData[_asset];

        _accrueInterest(_asset, lendingPoolData);

        uint256 repaid = _repay(_asset, _amount, _tokenId, lendingPoolData);

        accountedBalance[_asset] += repaid;

        IERC20(_asset).safeTransferFrom(msg.sender, address(this), repaid);

        emit Repay(msg.sender, _asset, repaid, _tokenId);
    }

    /// @notice Settles assets transferred straight into the pool, with no contract call.
    /// @dev A Polymarket Deposit Wallet can only move ERC20s by plain transfer, and an ERC20 transfer
    /// leaves no hook for this pool to react to. The operator watches for the transfer and calls this to
    /// bind it to a position. The settled amount is capped by the pool's unaccounted surplus, so the
    /// operator can only ever attribute funds that genuinely arrived.
    /// Incoming funds clear debt before they earn: the amount covers the position's outstanding borrow
    /// first, and only what is left over is supplied.
    /// @param _user The account to credit any supplied remainder to.
    /// @param _tokenId The Nft tokenId whose debt the transfer repays.
    /// @param _asset The transferred asset.
    /// @param _amount The transferred amount to settle.
    /// @return repaid The portion applied to outstanding debt.
    /// @return supplied The portion supplied on the user's behalf.
    function settleTransfer(address _user, uint256 _tokenId, address _asset, uint256 _amount)
        external
        onlyOperator
        returns (uint256 repaid, uint256 supplied)
    {
        if (_user == address(0) || _asset == address(0)) revert AddressZero();
        if (_amount == 0) revert AmountZero();

        PoolData storage lendingPoolData = poolData[_asset];

        _revertIfLendingPoolDoesNotExist(lendingPoolData);
        if (!accountedBalanceSynced[_asset]) revert AccountedBalanceNotSynced(_asset);

        uint256 balance = IERC20(_asset).balanceOf(address(this));
        uint256 accounted = accountedBalance[_asset];
        uint256 unaccounted = balance > accounted ? balance - accounted : 0;
        if (_amount > unaccounted) revert UnaccountedTransferTooSmall(_amount, unaccounted);

        accountedBalance[_asset] += _amount;

        _accrueInterest(_asset, lendingPoolData);

        repaid = _repay(_asset, _amount, _tokenId, lendingPoolData);
        supplied = _amount - repaid;

        if (supplied > 0) {
            address handler = lendingPoolHandler;
            if (handler == address(0)) revert LendingPoolHandlerNotSet();

            // Supplied under the handler, not the depositor. The handler is the lender of record for
            // every collateral position, and crediting the depositor directly would instead create a
            // bare lender position they could withdraw at will, leaving their debt unbacked.
            _supply(_asset, supplied, handler, lendingPoolData);
            IPositionsLendingPoolHandler(handler).creditSettledDeposit(_asset, supplied, _tokenId);
        }

        emit TransferSettled(_user, _asset, _tokenId, repaid, supplied);

        // Mirrored so the existing indexers pick transfer based deposits and repayments up unchanged.
        if (repaid > 0) emit Repay(msg.sender, _asset, repaid, _tokenId);
        if (supplied > 0) emit Supply(msg.sender, _asset, supplied, _user);
    }

    /// @notice Opens or increases a borrow position on behalf of a user, and pushes the funds out.
    /// @dev The relayer borrow flow starts with the borrower calling borrowRequest(), which a Deposit
    /// Wallet cannot do. The operator runs the same collateral and health checks the relayer backend
    /// applies to a collateral request, then calls this.
    /// @param _tokenId The borrower's Nft tokenId.
    /// @param _asset The asset to borrow.
    /// @param _amount The amount to borrow.
    /// @param _to The recipient of the borrowed funds.
    function operatorBorrow(uint256 _tokenId, address _asset, uint256 _amount, address _to) external onlyOperator {
        if (_asset == address(0) || _to == address(0)) revert AddressZero();
        if (_amount == 0) revert AmountZero();

        PoolData storage lendingPoolData = poolData[_asset];
        BorrowerInfo storage borrowerInfo = tokenIdToAssetToBorrowInfo[_tokenId][_asset];

        _revertIfLendingPoolDoesNotExist(lendingPoolData);
        _accrueInterest(_asset, lendingPoolData);

        if (lendingPoolData.totalBorrowed + _amount > lendingPoolData.totalLent) {
            revert InsufficientLiquidityInLendingPool();
        }

        // Fold the interest accrued so far into the principal before resetting the snapshot, otherwise
        // moving the snapshot forward would write that interest off.
        borrowerInfo.borrowedAmount = _calculateBorrowerDebt(lendingPoolData, borrowerInfo) + _amount;
        borrowerInfo.borrowIndexSnapshot = lendingPoolData.borrowIndex;

        lendingPoolData.totalBorrowed += _amount;

        // The relayer charges an origination fee on every borrow it fulfils, and this path does not go
        // through the relayer. Charging the same fee here keeps a Deposit Wallet borrow priced exactly
        // like an Nft owner's, rather than making this the cheaper way to borrow. Read live so the two
        // paths cannot drift apart. Debt is the full amount either way, matching the relayer.
        uint256 fee = (_amount * IPositionsRelayer(positionsRelayer).feePercentage()) / BPS;
        address feeRecipient = IPositionsRelayer(positionsRelayer).feeReceipient();

        if (fee > 0 && feeRecipient == address(0)) revert AddressZero();

        _decreaseAccountedBalance(_asset, _amount);

        if (fee > 0) IERC20(_asset).safeTransfer(feeRecipient, fee);
        IERC20(_asset).safeTransfer(_to, _amount - fee);

        emit OperatorBorrow(_tokenId, _asset, _amount, _to);
        emit OperatorBorrowFee(_tokenId, _asset, fee, feeRecipient);
    }

    // Note: there is deliberately no operatorWithdraw here. Collateral is held by the handler, not by
    // the depositor, so exiting a position means debiting the handler's Nft accounting as well as the
    // pool's ledger. That lives on the handler, which calls withdraw() here as the lender of record.

    /// @notice Utility function to accrue interest and update the supply and borrow indices.
    /// @param _asset The asset address.
    function accrueInterest(address _asset) external {
        _accrueInterest(_asset, poolData[_asset]);
    }

    //////////////////////////
    /// Internal functions ///
    //////////////////////////

    function _authorizeUpgrade(address _newImplementation) internal view override onlyOwner {}

    function _revertIfLendingPoolDoesNotExist(PoolData memory _lendingPoolData) internal pure {
        if (_lendingPoolData.lastAccrualTimestamp == 0) revert LendingPoolDoesNotExist(_lendingPoolData);
    }

    function _setOperator(address _newOperator) internal {
        if (_newOperator == address(0)) revert AddressZero();

        operator = _newOperator;

        emit OperatorSet(_newOperator);
    }

    function _syncAccountedBalance(address[] calldata _assets) internal {
        for (uint256 i; i < _assets.length; ++i) {
            _syncAccountedBalance(_assets[i]);
        }
    }

    function _syncAccountedBalance(address _asset) internal {
        uint256 balance = IERC20(_asset).balanceOf(address(this));

        accountedBalance[_asset] = balance;
        accountedBalanceSynced[_asset] = true;

        emit AccountedBalanceSynced(_asset, balance);
    }

    /// @dev Saturating, so an asset that was never snapshotted cannot brick withdrawals and borrows by
    /// underflowing. The floor only ever understates what the pool has accounted for.
    function _decreaseAccountedBalance(address _asset, uint256 _amount) internal {
        uint256 accounted = accountedBalance[_asset];
        accountedBalance[_asset] = accounted > _amount ? accounted - _amount : 0;
    }

    /// @dev Credits a supply position. Expects interest to have been accrued for the pool already.
    function _supply(address _asset, uint256 _amount, address _for, PoolData storage _lendingPoolData) internal {
        LenderInfo storage lenderInfo = userToAssetToLendingInfo[_for][_asset];

        uint256 accruedInterest = _calculateAccruedLenderInterest(_lendingPoolData, lenderInfo);
        lenderInfo.depositAmount += _amount + accruedInterest;
        lenderInfo.supplyIndexSnapshot = _lendingPoolData.supplyIndex;

        _lendingPoolData.totalLent += _amount + accruedInterest;
    }

    /// @dev Exits part of a supply position and transfers the assets out. Expects interest to have been
    /// accrued for the pool already.
    function _withdraw(
        address _user,
        address _asset,
        uint256 _amount,
        address _to,
        PoolData storage _lendingPoolData
    ) internal returns (uint256 accruedInterest) {
        LenderInfo storage lenderInfo = userToAssetToLendingInfo[_user][_asset];

        accruedInterest = _calculateAccruedLenderInterest(_lendingPoolData, lenderInfo);
        if (_amount > lenderInfo.depositAmount + accruedInterest) revert InsufficientBalance();

        lenderInfo.depositAmount = lenderInfo.depositAmount + accruedInterest - _amount;
        lenderInfo.supplyIndexSnapshot = _lendingPoolData.supplyIndex;

        _lendingPoolData.totalLent -= _amount;

        _decreaseAccountedBalance(_asset, _amount);

        IERC20(_asset).safeTransfer(_to, _amount);
    }

    /// @dev Applies up to `_amount` against a position's outstanding debt and reports how much was used.
    /// Does not move any assets. Expects interest to have been accrued for the pool already.
    function _repay(address _asset, uint256 _amount, uint256 _tokenId, PoolData storage _lendingPoolData)
        internal
        returns (uint256 repaid)
    {
        BorrowerInfo storage borrowerInfo = tokenIdToAssetToBorrowInfo[_tokenId][_asset];

        uint256 totalDebt = _calculateBorrowerDebt(_lendingPoolData, borrowerInfo);
        if (totalDebt == 0) return 0;

        repaid = _amount > totalDebt ? totalDebt : _amount;

        borrowerInfo.borrowedAmount = totalDebt - repaid;
        borrowerInfo.borrowIndexSnapshot = _lendingPoolData.borrowIndex;

        _lendingPoolData.totalBorrowed -= (repaid * E27) / _lendingPoolData.borrowIndex;
    }

    function _accrueInterest(address _asset, PoolData storage _lendingPoolData) internal {
        if (_lendingPoolData.totalLent == 0) {
            _lendingPoolData.lastAccrualTimestamp = block.timestamp;
            return;
        }

        (uint256 updatedSupplyIndex, uint256 updatedBorrowIndex, uint256 updatedSupplyIndexWithReserveFactor) =
                        _currentSupplyAndBorrowIndex(_lendingPoolData);

        uint256 interestCutForTreasury = (
            (
                ((updatedSupplyIndexWithReserveFactor * _lendingPoolData.totalLent) / _lendingPoolData.supplyIndex)
                - _lendingPoolData.totalLent
            ) * reserveFactor
        ) / BPS;
        uint256 treasurySupplyInterest =
                        _calculateAccruedLenderInterest(_lendingPoolData, userToAssetToLendingInfo[treasury][_asset]);

        userToAssetToLendingInfo[treasury][_asset].depositAmount += interestCutForTreasury + treasurySupplyInterest;
        userToAssetToLendingInfo[treasury][_asset].supplyIndexSnapshot = updatedSupplyIndex;
        _lendingPoolData.totalLent += interestCutForTreasury + treasurySupplyInterest;

        _lendingPoolData.supplyIndex = updatedSupplyIndex;
        _lendingPoolData.borrowIndex = updatedBorrowIndex;

        _lendingPoolData.lastAccrualTimestamp = block.timestamp;
    }

    function _currentSupplyAndBorrowIndex(PoolData memory _lendingPoolData)
    internal
    view
    returns (uint256, uint256, uint256)
    {
        uint256 timeElapsed = block.timestamp - _lendingPoolData.lastAccrualTimestamp;

        if (timeElapsed == 0) {
            return (_lendingPoolData.supplyIndex, _lendingPoolData.borrowIndex, _lendingPoolData.supplyIndex);
        }

        uint256 currentUtilization = _currentUtilization(_lendingPoolData);
        (uint256 supplyRate, uint256 borrowRate) = _getInterestRates(_lendingPoolData, currentUtilization);

        uint256 borrowInterestFactor = (_lendingPoolData.borrowIndex * borrowRate * timeElapsed) / (E27 * YEAR);
        uint256 supplyInterestFactor = (_lendingPoolData.supplyIndex * supplyRate * timeElapsed) / (E27 * YEAR);

        uint256 reserveInterestFactor = (supplyInterestFactor * reserveFactor) / BPS;

        return (
            _lendingPoolData.supplyIndex + supplyInterestFactor - reserveInterestFactor,
            _lendingPoolData.borrowIndex + borrowInterestFactor,
            _lendingPoolData.supplyIndex + supplyInterestFactor
        );
    }

    function _currentUtilization(PoolData memory _lendingPoolData) internal pure returns (uint256) {
        if (_lendingPoolData.totalBorrowed == 0) return 0;
        return (_lendingPoolData.totalBorrowed * E27) / _lendingPoolData.totalLent;
    }

    function _getInterestRates(PoolData memory _lendingPoolData, uint256 _utilization)
    internal
    view
    returns (uint256 supplyRate, uint256 borrowRate)
    {
        InterestRateModel memory interestRateModel = _lendingPoolData.interestRateModel;

        if (_utilization <= interestRateModel.optimalUtilization) {
            borrowRate = interestRateModel.baseRate
                + (_utilization * interestRateModel.slope1) / interestRateModel.optimalUtilization;
        } else {
            uint256 excessUtilization = _utilization - interestRateModel.optimalUtilization;
            borrowRate = interestRateModel.baseRate + interestRateModel.slope1
                + (excessUtilization * interestRateModel.slope2) / (E27 - interestRateModel.optimalUtilization);
        }

        supplyRate = (borrowRate * _utilization * (BPS - reserveFactor)) / (E27 * BPS);
    }

    function _calculateAccruedLenderInterest(PoolData memory _lendingPoolData, LenderInfo memory _lenderInfo)
    internal
    view
    returns (uint256)
    {
        if (_lenderInfo.supplyIndexSnapshot == 0) {
            return 0;
        }

        (uint256 currentSupplyIndex,,) = _currentSupplyAndBorrowIndex(_lendingPoolData);

        return (currentSupplyIndex * _lenderInfo.depositAmount) / _lenderInfo.supplyIndexSnapshot
            - _lenderInfo.depositAmount;
    }

    function _calculateBorrowerDebt(PoolData memory _lendingPoolData, BorrowerInfo memory _borrowerInfo)
    internal
    view
    returns (uint256)
    {
        if (_borrowerInfo.borrowIndexSnapshot == 0) {
            return 0;
        }

        (, uint256 updatedBorrowIndex,) = _currentSupplyAndBorrowIndex(_lendingPoolData);
        uint256 borrowGrowth = (updatedBorrowIndex * _borrowerInfo.borrowedAmount) / _borrowerInfo.borrowIndexSnapshot
            - _borrowerInfo.borrowedAmount;

        return _borrowerInfo.borrowedAmount + borrowGrowth;
    }

    ///////////////////////////////
    /// View and Pure functions ///
    ///////////////////////////////

    /// @notice Gets all the assets supported for lending and borrowing.
    function getSupportedAssets() external view returns (address[] memory) {
        return supportedAssets.values();
    }

    /// @notice Gets the current supply and borrow indices (Masterchef algorithm based interest tarcking mechanism).
    /// @param _asset The asset address.
    /// @return The supply index.
    /// @return The borrow index.
    function getCurrentSupplyAndBorrowIndex(address _asset) external view returns (uint256, uint256) {
        PoolData memory lendingPoolData = poolData[_asset];

        (uint256 supplyIndex, uint256 borrowIndex,) = _currentSupplyAndBorrowIndex(lendingPoolData);
        return (supplyIndex, borrowIndex);
    }

    /// @notice Gets all the borrow request Ids for a user per asset.
    /// @param _tokenId The borrower's Nft tokenId.
    /// @param _asset The asset address.
    function getBorrowRequestIds(uint256 _tokenId, address _asset) external view returns (bytes32[] memory) {
        return userToAssetToRequestIds[_tokenId][_asset].values();
    }

    /// @notice Gets a borrower's debt (with interest) for a given asset (lending pool).
    /// @param _asset The asset address.
    /// @param _tokenId The borrower's Nft tokenId address.
    function getborrowerDebt(address _asset, uint256 _tokenId) public view returns (uint256) {
        PoolData memory lendingPoolData = poolData[_asset];
        BorrowerInfo memory borrowerInfo = tokenIdToAssetToBorrowInfo[_tokenId][_asset];

        return _calculateBorrowerDebt(lendingPoolData, borrowerInfo);
    }

    /// @notice Gets the interest accrued for a lender based on their supply position for an asset and their supply
    /// index snapshot.
    /// @param _asset The asset address.
    /// @param _lender The lender's address.
    function getAccruedLenderInterest(address _asset, address _lender) external view returns (uint256) {
        PoolData memory lendingPoolData = poolData[_asset];
        LenderInfo memory lenderInfo = userToAssetToLendingInfo[_lender][_asset];

        return _calculateAccruedLenderInterest(lendingPoolData, lenderInfo);
    }

    /// @notice Gets the total amount of assets borrowed by a user's Nft tokenId accross all assets in usd
    /// (e6 denomination).
    /// @param _tokenId The borrower's Nft tokenId.
    function utilization(uint256 _tokenId) external view returns (uint256) {
        address priceOracle = oracle;
        address[] memory assets = supportedAssets.values();
        uint256 totalBorrowedAmountInUsd;

        for (uint256 i; i < assets.length; ++i) {
            uint256 debt = getborrowerDebt(assets[i], _tokenId);
            if (debt > 0) {
                totalBorrowedAmountInUsd +=
                    (debt * IPriceOracle(priceOracle).getPrice(assets[i])) / 10 ** IERC20Metadata(assets[i]).decimals();
            }
        }

        return totalBorrowedAmountInUsd;
    }

    /// @notice Utility function to get all the relevant data associated with a lending pool for an asset.
    /// @param _asset The asset address.
    function getReserveData(address _asset) public view returns (ReserveData memory) {
        PoolData memory lendingPoolData = poolData[_asset];
        InterestRateModel memory interestRateModel = lendingPoolData.interestRateModel;

        uint256 currentUtilization = _currentUtilization(lendingPoolData);
        (uint256 supplyRate, uint256 borrowRate) = _getInterestRates(lendingPoolData, currentUtilization);

        return ReserveData({
            totalLiquidity: lendingPoolData.totalLent,
            availableLiquidity: lendingPoolData.totalLent - lendingPoolData.totalBorrowed,
            totalBorrows: lendingPoolData.totalBorrowed,
            reserveFactor: reserveFactor,
            baseRate: interestRateModel.baseRate,
            slope1: interestRateModel.slope1,
            slope2: interestRateModel.slope2,
            optimalUtilization: interestRateModel.optimalUtilization,
            lastUpdateTimestamp: lendingPoolData.lastAccrualTimestamp,
            supplyIndex: lendingPoolData.supplyIndex,
            borrowIndex: lendingPoolData.borrowIndex,
            supplyRate: supplyRate,
            borrowRate: borrowRate,
            utilization: currentUtilization
        });
    }

    /// @notice Gets the user's balance (along with any accrued interest) accross all supported lending pools.
    /// @param _supplier The user's address.
    function getBalanceWithInterestAccrossAllAssets(address _supplier) external view returns (SupplierData[] memory) {
        address[] memory assets = supportedAssets.values();
        uint256 length = assets.length;
        SupplierData[] memory supplierData = new SupplierData[](length);

        for (uint256 i; i < length; ++i) {
            LenderInfo memory supplierInfo = userToAssetToLendingInfo[_supplier][assets[i]];

            supplierData[i] = SupplierData({
                asset: assets[i],
                balanceWithInterest: (poolData[assets[i]].supplyIndex * supplierInfo.depositAmount)
            / supplierInfo.supplyIndexSnapshot
            });
        }

        return supplierData;
    }
}
