pragma solidity 0.5.16;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/math/Math.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20Detailed.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "../../base/interface/IStrategy.sol";
import "../../base/interface/IVault.sol";
import "../../base/upgradability/BaseUpgradeableStrategyUL.sol";

import "./interfaces/Types.sol";
import "./interfaces/NotionalProxy.sol";
import "./interfaces/IBVault.sol";
import "../../base/interface/weth/Weth9.sol";

contract NotionalStrategy is IStrategy, BaseUpgradeableStrategyUL {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    // additional storage slots (on top of BaseUpgradeableStrategy ones) are defined here
    bytes32 internal constant _CURRENCY_ID = 0x50e4d02f6a8e4ab57be67cc4efcac8a19562797dc2257fdc7515b53622905dde;
    bytes32 internal constant _BVAULT_SLOT = 0x85cbd475ba105ca98d9a2db62dcf7cf3c0074b36303ef64160d68a3e0fdd3c67;
    bytes32 internal constant _NOTE2WETH_POOLID_SLOT =
        0x8eae010b847722fa95e85dfc0113c19f46531a85595a4a8aeb38cb97657d35c4;
    bytes32 internal constant _NTOKEN_UNDERLYING = 0xca1ad68fb46e1d177e14769fefa6ec6792476f949c8cd88042b7f02ed2f5d2e2;

    address public constant weth = address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    address public constant note = address(0xCFEAead4947f0705A14ec42aC3D44129E1Ef3eD5);

    constructor() public BaseUpgradeableStrategyUL() {
        assert(_CURRENCY_ID == bytes32(uint256(keccak256("eip1967.strategyStorage.currencyId")) - 1));
        assert(_BVAULT_SLOT == bytes32(uint256(keccak256("eip1967.strategyStorage.bVault")) - 1));
        assert(_NOTE2WETH_POOLID_SLOT == bytes32(uint256(keccak256("eip1967.strategyStorage.note2WethPoolId")) - 1));
        assert(_NTOKEN_UNDERLYING == bytes32(uint256(keccak256("eip1967.strategyStorage.nTokenUnderlying")) - 1));
    }

    /* ========== Initialize ========== */

    function initializeBaseStrategy(
        //  "__" for storage because we shadow _storage from GovernableInit
        address __storage,
        address _underlying,
        address _vault,
        address _rewardPool, // always the notional proxy, could be constant,
        address _bVault,
        bytes32 _note2wethpid,
        uint16 _currencyId
    ) public initializer {
        BaseUpgradeableStrategyUL.initialize({
            _storage: __storage,
            _underlying: _underlying,
            _vault: _vault,
            _rewardPool: _rewardPool,
            _rewardToken: weth,
            _profitSharingNumerator: 300,
            _profitSharingDenominator: 1000,
            _sell: true,
            _sellFloor: 1e18,
            _implementationChangeDelay: 12 hours,
            _universalLiquidatorRegistry: address(0x7882172921E99d590E097cD600554339fBDBc480)
        });
        require(_currencyId != 0, "Invalid currencyId");
        address nTokenAddress = NotionalProxy(_rewardPool).nTokenAddress(_currencyId);
        require(nTokenAddress == _underlying, "Invalid underlying");
        (, Types.Token memory underlyingToken) = NotionalProxy(_rewardPool).getCurrency(_currencyId);

        _setCurrencyId(bytes32(uint256(_currencyId)));
        _setBVault(_bVault);
        _setNote2WethPoolId(_note2wethpid);
        _setNTokenUnderlying(underlyingToken.tokenAddress);
    }

    /* ========== View ========== */

    function depositArbCheck() public view returns (bool) {
        return true;
    }

    function unsalvagableTokens(address token) public view returns (bool) {
        return (token == rewardToken() || token == underlying());
    }

    function investedUnderlyingBalance() public view returns (uint256) {
        uint256 underlyingBalance = IERC20(underlying()).balanceOf(address(this));

        return underlyingBalance;
    }

    /* ========== Internal ========== */

    function _mintNTokens() internal {
        address _nTokenUnderlying = nTokenUnderlying();
        address _rewardPool = rewardPool();

        uint256 underlyingBalance;

        if (_nTokenUnderlying == address(0)) {
            underlyingBalance = IERC20(weth).balanceOf(address(this));
            WETH9(weth).withdraw(underlyingBalance);
        } else {
            underlyingBalance = IERC20(_nTokenUnderlying).balanceOf(address(this));
            IERC20(_nTokenUnderlying).safeApprove(_rewardPool, 0);
            IERC20(_nTokenUnderlying).safeApprove(_rewardPool, underlyingBalance);
        }

        Types.BalanceAction memory action = Types.BalanceAction(
            Types.DepositActionType.DepositUnderlyingAndMintNToken,
            currencyId(),
            underlyingBalance,
            0,
            false,
            false
        );
        Types.BalanceAction[] memory actions = new Types.BalanceAction[](1);
        actions[0] = action;

        if (_nTokenUnderlying != address(0)) {
            underlyingBalance = 0;
        }

        NotionalProxy(_rewardPool).batchBalanceAction.value(underlyingBalance)(address(this), actions);
    }

    function _claimRewards() internal {
        NotionalProxy(rewardPool()).nTokenClaimIncentives();
    }

    function _note2WETH() internal {
        uint256 noteAmount = IERC20(note).balanceOf(address(this));

        if (noteAmount == 0) {
            return;
        }

        //swap note to weth on balancer
        IBVault.SingleSwap memory singleSwap;
        IBVault.SwapKind swapKind = IBVault.SwapKind.GIVEN_IN;

        singleSwap.poolId = note2WethPoolId();
        singleSwap.kind = swapKind;
        singleSwap.assetIn = IAsset(note);
        singleSwap.assetOut = IAsset(weth);
        singleSwap.amount = noteAmount;
        singleSwap.userData = abi.encode(0);

        IBVault.FundManagement memory funds;
        funds.sender = address(this);
        funds.fromInternalBalance = false;
        funds.recipient = address(uint160(address(this)));
        funds.toInternalBalance = false;

        IERC20(note).safeApprove(bVault(), 0);
        IERC20(note).safeApprove(bVault(), noteAmount);

        IBVault(bVault()).swap(singleSwap, funds, 1, block.timestamp);
    }

    function _liquidateReward() internal {
        _note2WETH();

        uint256 rewardBalance = IERC20(weth).balanceOf(address(this));
        if (!sell() || rewardBalance < sellFloor()) {
            // Profits can be disabled for possible simplified and rapid exit
            emit ProfitsNotCollected(sell(), rewardBalance < sellFloor());
            return;
        }

        notifyProfitInRewardToken(rewardBalance);
        uint256 remainingRewardBalance = IERC20(weth).balanceOf(address(this));
        if (remainingRewardBalance == 0) {
            return;
        }

        address _nTokenUnderlying = nTokenUnderlying();
        if (_nTokenUnderlying != address(0)) {
            address _universalLiquidator = universalLiquidator();
            IERC20(weth).safeApprove(_universalLiquidator, 0);
            IERC20(weth).safeApprove(_universalLiquidator, remainingRewardBalance);

            ILiquidator(_universalLiquidator).swapTokenOnMultipleDEXes(
                remainingRewardBalance,
                1,
                address(this), // target
                storedLiquidationDexes[weth][_nTokenUnderlying],
                storedLiquidationPaths[weth][_nTokenUnderlying]
            );
        }

        _mintNTokens();
    }

    /* ========== External ========== */

    function withdrawAllToVault() public restricted {
        _claimRewards();
        _liquidateReward();
        IERC20(underlying()).safeTransfer(vault(), investedUnderlyingBalance());
    }

    function withdrawToVault(uint256 amount) external restricted {
        uint256 entireBalance = IERC20(underlying()).balanceOf(address(this));

        if (amount >= entireBalance) {
            withdrawAllToVault();
        } else {
            IERC20(underlying()).safeTransfer(vault(), amount);
        }
    }

    function salvage(
        address recipient,
        address token,
        uint256 amount
    ) external onlyControllerOrGovernance {
        // To make sure that governance cannot come in and take away the coins
        require(!unsalvagableTokens(token), "token is defined as not salvagable");
        IERC20(token).safeTransfer(recipient, amount);
    }

    /*
     *   Get the reward, sell it in exchange for underlying, invest what you got.
     *   It's not much, but it's honest work.
     *
     *   Note that although `onlyNotPausedInvesting` is not added here,
     *   calling `investAllUnderlying()` affectively blocks the usage of `doHardWork`
     *   when the investing is being paused by governance.
     */
    function doHardWork() external onlyNotPausedInvesting restricted {
        _claimRewards();
        _liquidateReward();
    }

    function setSell(bool s) external onlyGovernance {
        _setSell(s);
    }

    function setSellFloor(uint256 floor) external onlyGovernance {
        _setSellFloor(floor);
    }

    function finalizeUpgrade() external onlyGovernance {
        _finalizeUpgrade();
    }

    /* ========== Storage ========== */

    function setBytes32(bytes32 slot, bytes32 _value) internal {
        // solhint-disable-next-line no-inline-assembly
        assembly {
            sstore(slot, _value)
        }
    }

    function getBytes32(bytes32 slot) internal view returns (bytes32 str) {
        // solhint-disable-next-line no-inline-assembly
        assembly {
            str := sload(slot)
        }
    }

    function _setCurrencyId(bytes32 _value) internal {
        setBytes32(_CURRENCY_ID, _value);
    }

    function currencyId() public view returns (uint16) {
        return uint16(uint256(getBytes32(_CURRENCY_ID)));
    }

    function _setBVault(address _address) internal {
        setAddress(_BVAULT_SLOT, _address);
    }

    function bVault() public view returns (address) {
        return getAddress(_BVAULT_SLOT);
    }

    function _setNote2WethPoolId(bytes32 _value) internal {
        setBytes32(_NOTE2WETH_POOLID_SLOT, _value);
    }

    function note2WethPoolId() public view returns (bytes32) {
        return getBytes32(_NOTE2WETH_POOLID_SLOT);
    }

    function _setNTokenUnderlying(address _address) internal {
        setAddress(_NTOKEN_UNDERLYING, _address);
    }

    function nTokenUnderlying() public view returns (address) {
        return getAddress(_NTOKEN_UNDERLYING);
    }

    function() external payable {
        require(msg.sender == weth, "direct eth transfer not allowed");
    }
}
