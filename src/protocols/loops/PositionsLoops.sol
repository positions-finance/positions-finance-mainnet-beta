// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IERC20} from "@openzeppelin-contracts-5.3.0/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin-contracts-5.3.0/token/ERC20/extensions/IERC20Metadata.sol";

import {AccessControlUpgradeable} from "@openzeppelin-contracts-upgradeable-5.3.0/access/AccessControlUpgradeable.sol";
import {Initializable} from "@openzeppelin-contracts-upgradeable-5.3.0/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin-contracts-upgradeable-5.3.0/proxy/utils/UUPSUpgradeable.sol";
import {SafeERC20} from "@openzeppelin-contracts-5.3.0/token/ERC20/utils/SafeERC20.sol";
import {EnumerableSet} from "@openzeppelin-contracts-5.3.0/utils/structs/EnumerableSet.sol";

import {IBerachainRewardsVault} from "../../interfaces/handlers/pol/IBerachainRewardsVault.sol";
import {IPriceOracle} from "../../interfaces/oracle/IPriceOracle.sol";
import {IPositionsRelayer} from "../../interfaces/poc/IPositionsRelayer.sol";
import {IV2DexPair} from "@src/interfaces/protocols/loops/IV2DexPair.sol";
import {IV2DexRouter} from "@src/interfaces/protocols/loops/IV2DexRouter.sol";

import {PositionsBGTHandler} from "../../handlers/pol/PositionsBGTHandler.sol";
import {PositionsLendingPool} from "@src/protocols/lendingPool/PositionsLendingPool.sol";

/// @title PositionsLoops.
/// @author Positions Team.
/// @notice A loops contract to open leveraged positions using the positions lending pool.
contract PositionsLoops is Initializable, UUPSUpgradeable, AccessControlUpgradeable, PositionsBGTHandler {
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.Bytes32Set;
    using EnumerableSet for EnumerableSet.AddressSet;

    enum Status {
        NOT_FOUND,
        PENDING,
        ACCEPTED,
        COMPLETED,
        REJECTED
    }

    struct RequestData {
        Status status;
        uint256 tokenId;
        address token;
        uint256 amount;
        uint256 minSwapAmounOut;
        uint256 deadline;
        uint256 minAmountBorrowToken;
        uint256 minAmountOtherToken;
        uint256 minLpTokensToReceive;
    }

    struct PositionData {
        uint256 lpTokens;
        uint256 amount;
        uint256 borrowIndexSnapshot;
        uint256 unclaimedReward;
        uint256 rewardsPerTokenPaid;
    }

    struct CloseParams {
        uint256 tokenId;
        address token;
        uint256 buffer;
        uint256 amountLpTokens;
        bytes32[] proof;
        uint256 amountTokenMin;
        uint256 amountOtherTokenMin;
        uint256 minSwapAmountOut;
        uint256 deadline;
    }

    /// @dev Relayer role can call relayer functions.
    bytes32 public constant RELAYER_ROLE = keccak256("RELAYER_ROLE");
    /// @dev Upgrader role can upgrade the contract.
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    /// @notice Pricesion for BGT.
    uint256 internal constant PRECISION = 1e18;

    address public relayer;
    address public lendingPool;
    address public oracle;
    address public v2DexRouter;
    address public pool;
    address public vault;
    /// @notice Tracking used nonces for each proof of collateral Nft tokenId.
    mapping(uint256 tokenId => uint256 nonces) public nonces;
    /// @notice Tracking data for each withdrawal request.
    mapping(bytes32 requestId => RequestData requestData) public requestData;
    mapping(uint256 tokenId => mapping(address token => PositionData positionData)) public positionData;

    event RequestOpenLeveragedPosition(
        address caller, uint256 indexed tokenId, address indexed borrowToken, uint256 indexed amount
    );
    event PositionOpened(address indexed by, bytes32 indexed requestId, RequestData indexed positionRequestData);
    event PositionClosed(address indexed caller, uint256 indexed tokenId, address indexed token);
    event RedeemBGTForBera(address indexed receiver, uint256 indexed tokenId, uint256 indexed earnedAmount);

    error PositionsLoops__InvalidToken();
    error PositionsLoops__UnacceptedRequest(bytes32 requestId);
    error PositionsLoops__ArrayLengthMismatch();
    error PositionsLoops__NFTOwnershipVerificationFailed(address caller, uint256 tokenId);

    function initialize(
        address _admin,
        address _positionsRelayer,
        address _priceOracle,
        address _lendingPool,
        address _v2DexRouter,
        address _pool,
        address _vault,
        address _bgt
    ) public initializer {
        __UUPSUpgradeable_init();
        __AccessControl_init();
        __PositionsBGTHandler_init(_bgt);

        _grantRole(DEFAULT_ADMIN_ROLE, _admin);

        relayer = _positionsRelayer;
        oracle = _priceOracle;
        lendingPool = _lendingPool;
        v2DexRouter = _v2DexRouter;
        pool = _pool;
        vault = _vault;

        IERC20(pool).approve(vault, type(uint256).max);
    }

    function requestOpenLeveragedPosition(
        uint256 _tokenId,
        address _borrowToken,
        uint256 _amount,
        uint256 _minSwapAmountOut,
        uint256 _deadline,
        uint256 _minAmountBorrowToken,
        uint256 _minAmountOtherToken,
        uint256 _minLpTokensToReceive,
        bytes32[] memory _proof
    ) external {
        _validateNFTOwnership(_tokenId, _proof);

        if (_borrowToken != IV2DexPair(pool).token0() && _borrowToken != IV2DexPair(pool).token1()) {
            revert PositionsLoops__InvalidToken();
        }

        bytes32 requestId = keccak256(abi.encode(_tokenId, ++nonces[_tokenId]));
        requestData[requestId] = RequestData({
            status: Status.PENDING,
            tokenId: _tokenId,
            token: _borrowToken,
            amount: _amount,
            minSwapAmounOut: _minSwapAmountOut,
            deadline: _deadline,
            minAmountBorrowToken: _minAmountBorrowToken,
            minAmountOtherToken: _minAmountOtherToken,
            minLpTokensToReceive: _minLpTokensToReceive
        });

        emit RequestOpenLeveragedPosition(msg.sender, _tokenId, _borrowToken, _amount);
    }

    function setRequestStatus(bytes32[] memory _requestIds, Status[] memory _statuses)
        external
        onlyRole(RELAYER_ROLE)
    {
        if (_requestIds.length != _statuses.length) {
            revert PositionsLoops__ArrayLengthMismatch();
        }

        for (uint256 i; i < _requestIds.length; i++) {
            requestData[_requestIds[i]].status = _statuses[i];
        }
    }

    function openLeveragedPosition(bytes32 _requestId) external {
        RequestData memory positionRequestData = requestData[_requestId];

        if (positionRequestData.status != Status.ACCEPTED) revert PositionsLoops__UnacceptedRequest(_requestId);

        PositionsLendingPool(lendingPool).borrowForLoops(positionRequestData.token, positionRequestData.amount);

        address otherToken = positionRequestData.token == IV2DexPair(pool).token0()
            ? IV2DexPair(pool).token1()
            : IV2DexPair(pool).token0();

        address[] memory path = new address[](2);
        path[0] = positionRequestData.token;
        path[1] = otherToken;

        IERC20(positionRequestData.token).approve(v2DexRouter, positionRequestData.amount);
        IV2DexRouter(v2DexRouter).swapExactTokensForTokens(
            positionRequestData.amount / 2,
            positionRequestData.minSwapAmounOut,
            path,
            address(this),
            positionRequestData.deadline
        );

        uint256 balance = IERC20(otherToken).balanceOf(address(this));
        IERC20(otherToken).approve(v2DexRouter, balance);
        (,, uint256 lpTokens) = IV2DexRouter(v2DexRouter).addLiquidity(
            positionRequestData.token,
            otherToken,
            positionRequestData.amount / 2,
            balance,
            positionRequestData.minAmountBorrowToken,
            positionRequestData.minAmountOtherToken,
            address(this),
            positionRequestData.deadline
        );

        uint256 currentBorrowIndex =
            PositionsLendingPool(lendingPool).getReserveData(positionRequestData.token).borrowIndex;

        uint256 amountWithInterest = (
            currentBorrowIndex * positionData[positionRequestData.tokenId][positionRequestData.token].amount
        ) / positionData[positionRequestData.tokenId][positionRequestData.token].borrowIndexSnapshot;

        _updateReward(vault, positionRequestData.tokenId);
        IBerachainRewardsVault(vault).stake(lpTokens);

        positionData[positionRequestData.tokenId][positionRequestData.token].lpTokens += lpTokens;
        positionData[positionRequestData.tokenId][positionRequestData.token].amount =
            amountWithInterest + positionRequestData.amount;
        positionData[positionRequestData.tokenId][positionRequestData.token].borrowIndexSnapshot =
            PositionsLendingPool(lendingPool).getReserveData(positionRequestData.token).borrowIndex;

        emit PositionOpened(msg.sender, _requestId, positionRequestData);
    }

    function closeLeveragedPosition(CloseParams memory _params) external {
        if (!hasRole(RELAYER_ROLE, msg.sender)) _validateNFTOwnership(_params.tokenId, _params.proof);

        _updateReward(vault, _params.tokenId);
        IBerachainRewardsVault(vault).withdraw(_params.amountLpTokens);
        IERC20(_params.token).safeTransferFrom(msg.sender, address(this), _params.buffer);

        address otherToken =
            _params.token == IV2DexPair(pool).token0() ? IV2DexPair(pool).token1() : IV2DexPair(pool).token0();

        IERC20(pool).approve(v2DexRouter, _params.amountLpTokens);
        IV2DexRouter(v2DexRouter).removeLiquidity(
            _params.token,
            otherToken,
            _params.amountLpTokens,
            _params.amountTokenMin,
            _params.amountOtherTokenMin,
            address(this),
            _params.deadline
        );

        address[] memory path = new address[](2);
        path[0] = otherToken;
        path[1] = _params.token;

        uint256 amount = IERC20(otherToken).balanceOf(address(this));
        IERC20(otherToken).approve(v2DexRouter, amount);
        IV2DexRouter(v2DexRouter).swapExactTokensForTokens(
            amount, _params.minSwapAmountOut, path, address(this), _params.deadline
        );

        uint256 currentBorrowIndex = PositionsLendingPool(lendingPool).getReserveData(_params.token).borrowIndex;

        uint256 amountWithInterest = (currentBorrowIndex * positionData[_params.tokenId][_params.token].amount)
            / positionData[_params.tokenId][_params.token].borrowIndexSnapshot;

        PositionsLendingPool(lendingPool).repayDebt(
            _params.token, IERC20(_params.token).balanceOf(address(this)), uint256(uint160(address(this)))
        );

        currentBorrowIndex = PositionsLendingPool(lendingPool).getReserveData(_params.token).borrowIndex;

        positionData[_params.tokenId][_params.token].lpTokens -= _params.amountLpTokens;
        positionData[_params.tokenId][_params.token].amount = amountWithInterest;
        positionData[_params.tokenId][_params.token].borrowIndexSnapshot = currentBorrowIndex;

        emit PositionClosed(msg.sender, _params.tokenId, _params.token);
    }

    /// @notice Redeems BGT rewards for bera native gas token.
    /// @param _tokenId The user's nft tokenId.
    /// @param _proof The merkle proof to verify Nft tokenId ownership.
    function redeemBGTForBera(uint256 _tokenId, bytes32[] calldata _proof) external {
        _validateNFTOwnership(_tokenId, _proof);
        address receiver = msg.sender;

        IBerachainRewardsVault(vault).getReward(address(this));

        uint256 earnedAmount = earned(vault, _tokenId);

        positionData[_tokenId][vault].unclaimedReward = 0;
        positionData[_tokenId][vault].rewardsPerTokenPaid = rewardPerToken(vault);

        if (address(this).balance < earnedAmount) {
            _redeemBGTForBera();
        }

        if (address(this).balance < earnedAmount) {
            revert PositionsBGTHandler__RedeemBGTForBeraFailed(receiver, _tokenId, earnedAmount);
        }

        (bool success,) = receiver.call{value: earnedAmount}("");

        if (!success) {
            revert PositionsBGTHandler__RedeemBGTForBeraFailed(receiver, _tokenId, earnedAmount);
        }

        emit RedeemBGTForBera(receiver, _tokenId, earnedAmount);
    }

    function _validateNFTOwnership(uint256 _tokenId, bytes32[] memory _proof) internal view {
        if (!IPositionsRelayer(relayer).verifyNFTOwnership(msg.sender, _tokenId, _proof)) {
            revert PositionsLoops__NFTOwnershipVerificationFailed(msg.sender, _tokenId);
        }
    }

    function _checkAndUpdateUnclaimedBGTBalance(address receiver, uint256 _amount) internal override {}

    function _updateReward(address _rewardVault, uint256 _tokenId) internal {
        uint256 _rewardPerToken = rewardPerToken(_rewardVault);

        PositionData storage info = positionData[_tokenId][_rewardVault];
        (info.unclaimedReward, info.rewardsPerTokenPaid) = (earned(_rewardVault, _tokenId), _rewardPerToken);
    }

    /// @notice Gets the total BGT a user earned from a reward vault.
    /// @param _rewardVault The reward vault address.
    /// @param _tokenId The user's Nft tokenId.
    function earned(address _rewardVault, uint256 _tokenId) public view returns (uint256) {
        PositionData storage info = positionData[_tokenId][_rewardVault];

        (uint256 balance, uint256 unclaimedReward, uint256 rewardsPerTokenPaid) =
            (info.amount, info.unclaimedReward, info.rewardsPerTokenPaid);
        uint256 rewardPerTokenDelta;
        unchecked {
            rewardPerTokenDelta = rewardPerToken(_rewardVault) - rewardsPerTokenPaid;
        }
        return unclaimedReward + (balance * rewardPerTokenDelta) / PRECISION;
    }

    /// Gets the value of reward per token of a reward vault.
    /// @param _rewardVault The reward vault address.
    function rewardPerToken(address _rewardVault) public view returns (uint256) {
        return IBerachainRewardsVault(_rewardVault).rewardPerToken();
    }

    function _authorizeUpgrade(address newImplementation) internal virtual override onlyRole(UPGRADER_ROLE) {}
}
