// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin-contracts-5.3.0/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin-contracts-5.3.0/token/ERC20/extensions/IERC20Metadata.sol";

import {OwnableUpgradeable} from "@openzeppelin-contracts-upgradeable-5.3.0/access/OwnableUpgradeable.sol";
import {Initializable} from "@openzeppelin-contracts-upgradeable-5.3.0/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin-contracts-upgradeable-5.3.0/proxy/utils/UUPSUpgradeable.sol";
import {SafeERC20} from "@openzeppelin-contracts-5.3.0/token/ERC20/utils/SafeERC20.sol";
import {EnumerableSet} from "@openzeppelin-contracts-5.3.0/utils/structs/EnumerableSet.sol";

import {IPriceOracle} from "../../interfaces/oracle/IPriceOracle.sol";
import {IPositionsRelayer} from "../../interfaces/poc/IPositionsRelayer.sol";

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
    event Repay(address by, uint256 indexed amount, uint256 indexed tokenId);
    event BorrowRequest(bytes32 indexed requestId);

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

    /////////////////
    /// Modifiers ///
    /////////////////

    modifier onlyRelayer() {
        if (msg.sender != positionsRelayer) {
            revert NotPositionsRelayer(msg.sender, positionsRelayer);
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

    //////////////////////////
    /// External functions ///
    //////////////////////////

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

        PoolData storage lendingPoolData = poolData[_asset];
        LenderInfo storage lenderInfo = userToAssetToLendingInfo[_for][_asset];

        _revertIfLendingPoolDoesNotExist(lendingPoolData);
        _accrueInterest(_asset, lendingPoolData);

        uint256 accruedInterest = _calculateAccruedLenderInterest(_asset, lendingPoolData, lenderInfo);
        lenderInfo.depositAmount += _amount + accruedInterest;
        lenderInfo.supplyIndexSnapshot = lendingPoolData.supplyIndex;

        lendingPoolData.totalLent += _amount + accruedInterest;

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
        LenderInfo storage lenderInfo = userToAssetToLendingInfo[msg.sender][_asset];

        _revertIfLendingPoolDoesNotExist(lendingPoolData);
        _accrueInterest(_asset, lendingPoolData);

        uint256 accruedInterest = _calculateAccruedLenderInterest(_asset, lendingPoolData, lenderInfo);
        if (_amount > lenderInfo.depositAmount + accruedInterest) revert InsufficientBalance();

        uint256 withdrawAmount = _amount;
        lenderInfo.depositAmount = lenderInfo.depositAmount + accruedInterest - _amount;
        lenderInfo.supplyIndexSnapshot = lendingPoolData.supplyIndex;

        lendingPoolData.totalLent -= ((withdrawAmount * E27) / lendingPoolData.supplyIndex);

        IERC20(_asset).safeTransfer(_to, withdrawAmount);

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
                || _collateralRequest.owner != msg.sender
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
        BorrowerInfo storage borrowerInfo = tokenIdToAssetToBorrowInfo[_tokenId][_asset];

        _accrueInterest(_asset, lendingPoolData);
        uint256 totalDebt = _calculateBorrowerDebt(_asset, lendingPoolData, borrowerInfo);
        _amount = _amount > totalDebt ? totalDebt : _amount;

        borrowerInfo.borrowedAmount = totalDebt - _amount;
        borrowerInfo.borrowIndexSnapshot = lendingPoolData.borrowIndex;

        lendingPoolData.totalBorrowed -= (_amount * E27) / lendingPoolData.borrowIndex;

        IERC20(_asset).safeTransferFrom(msg.sender, address(this), _amount);

        emit Repay(msg.sender, _amount, _tokenId);
    }

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

    function _accrueInterest(address _asset, PoolData storage _lendingPoolData) internal {
        if (_lendingPoolData.totalLent == 0) {
            _lendingPoolData.lastAccrualTimestamp = block.timestamp;
            return;
        }

        (uint256 updatedSupplyIndex, uint256 updatedBorrowIndex, uint256 updatedSupplyIndexWithReserveFactor) =
            _currentSupplyAndBorrowIndex(_asset, _lendingPoolData);

        uint256 interestCutForTreasury = (
            (
                ((updatedSupplyIndexWithReserveFactor * _lendingPoolData.totalLent) / _lendingPoolData.supplyIndex)
                    - _lendingPoolData.totalLent
            ) * reserveFactor
        ) / BPS;

        userToAssetToLendingInfo[treasury][_asset].depositAmount += interestCutForTreasury;
        userToAssetToLendingInfo[treasury][_asset].supplyIndexSnapshot = updatedSupplyIndex;
        _lendingPoolData.totalLent += interestCutForTreasury;

        _lendingPoolData.supplyIndex = updatedSupplyIndex;
        _lendingPoolData.borrowIndex = updatedBorrowIndex;

        _lendingPoolData.lastAccrualTimestamp = block.timestamp;
    }

    function _currentSupplyAndBorrowIndex(address _asset, PoolData memory _lendingPoolData)
        internal
        view
        returns (uint256, uint256, uint256)
    {
        uint256 timeElapsed = block.timestamp - _lendingPoolData.lastAccrualTimestamp;

        if (timeElapsed == 0) {
            return (_lendingPoolData.supplyIndex, _lendingPoolData.borrowIndex, _lendingPoolData.supplyIndex);
        }

        uint256 currentUtilization = _currentUtilization(_lendingPoolData);
        (uint256 supplyRate, uint256 borrowRate) = _getInterestRates(_asset, _lendingPoolData, currentUtilization);

        uint256 borrowInterestFactor = (_lendingPoolData.borrowIndex * borrowRate * timeElapsed) / (E27 * YEAR);
        uint256 supplyInterestFactor =
            (((_lendingPoolData.supplyIndex * currentUtilization) / E27) * ((supplyRate * timeElapsed) / YEAR)) / E27;
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

    function _getInterestRates(address _asset, PoolData memory _lendingPoolData, uint256 _utilization)
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

        uint256 totalBorrowedWithIndex =
            ((_lendingPoolData.totalBorrowed * E27) / 10 ** IERC20Metadata(_asset).decimals());

        supplyRate = (_overallBorrowRate(totalBorrowedWithIndex, borrowRate) * _utilization) / E27;
    }

    function _overallBorrowRate(uint256 totalVariableDebt, uint256 currentBorrowRate) internal pure returns (uint256) {
        uint256 totalDebt = totalVariableDebt;

        if (totalDebt == 0) return 0;

        uint256 weightedVariableRate = (totalDebt) * (currentBorrowRate);

        uint256 overallBorrowRate = weightedVariableRate / (totalDebt);

        return overallBorrowRate;
    }

    function _calculateAccruedLenderInterest(
        address _asset,
        PoolData memory _lendingPoolData,
        LenderInfo memory _lenderInfo
    ) internal view returns (uint256) {
        if (_lenderInfo.supplyIndexSnapshot == 0) {
            return 0;
        }

        (uint256 currentSupplyIndex,,) = _currentSupplyAndBorrowIndex(_asset, _lendingPoolData);

        return (currentSupplyIndex * _lenderInfo.depositAmount) / _lenderInfo.supplyIndexSnapshot
            - _lenderInfo.depositAmount;
    }

    function _calculateBorrowerDebt(address _asset, PoolData memory _lendingPoolData, BorrowerInfo memory _borrowerInfo)
        internal
        view
        returns (uint256)
    {
        if (_borrowerInfo.borrowIndexSnapshot == 0) {
            return 0;
        }

        (, uint256 updatedBorrowIndex,) = _currentSupplyAndBorrowIndex(_asset, _lendingPoolData);
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

        (uint256 supplyIndex, uint256 borrowIndex,) = _currentSupplyAndBorrowIndex(_asset, lendingPoolData);
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

        return _calculateBorrowerDebt(_asset, lendingPoolData, borrowerInfo);
    }

    /// @notice Gets the interest accrued for a lender based on their supply position for an asset and their supply
    /// index snapshot.
    /// @param _asset The asset address.
    /// @param _lender The lender's address.
    function getAccruedLenderInterest(address _asset, address _lender) external view returns (uint256) {
        PoolData memory lendingPoolData = poolData[_asset];
        LenderInfo memory lenderInfo = userToAssetToLendingInfo[_lender][_asset];

        return _calculateAccruedLenderInterest(_asset, lendingPoolData, lenderInfo);
    }

    /// @notice Gets the total amount of assets borrowed by a user's Nft tokenId accross all assets in usd
    /// (e6 denomination).
    /// @param _tokenId The borrower's Nft tokenId.
    function utilization(uint256 _tokenId) external view returns (uint256) {
        address priceOracle = oracle;
        address[] memory assets = supportedAssets.values();
        uint256 totalBorrowedAmountInUsd;

        for (uint256 i; i < assets.length; ++i) {
            totalBorrowedAmountInUsd += (
                getborrowerDebt(assets[i], _tokenId) * IPriceOracle(priceOracle).getPrice(assets[i])
            ) / 10 ** IERC20Metadata(assets[i]).decimals();
        }

        return totalBorrowedAmountInUsd;
    }

    /// @notice Utility function to get all the relevant data associated with a lending pool for an asset.
    /// @param _asset The asset address.
    function getReserveData(address _asset) public view returns (ReserveData memory) {
        PoolData memory lendingPoolData = poolData[_asset];
        InterestRateModel memory interestRateModel = lendingPoolData.interestRateModel;

        uint256 currentUtilization = _currentUtilization(lendingPoolData);
        (uint256 supplyRate, uint256 borrowRate) = _getInterestRates(_asset, lendingPoolData, currentUtilization);

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
