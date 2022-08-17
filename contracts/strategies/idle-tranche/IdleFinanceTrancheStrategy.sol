pragma solidity 0.5.16;

import "@openzeppelin/contracts/math/Math.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";

import "../../base/interface/IStrategy.sol";
import "../../base/upgradability/BaseUpgradeableStrategyUL.sol";

import "./interface/IIdleCDO.sol";
import "./interface/IWstETH.sol";
import "./interface/IDistributor.sol";
import "./interface/ILiquidityGaugeV3.sol";

contract IdleFinanceTrancheStrategy is IStrategy, BaseUpgradeableStrategyUL {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    // additional storage slots (on top of BaseUpgradeableStrategy ones) are defined here
    bytes32 internal constant _IS_STETH = 0x9574989eae0060a39fe95049948b9a7bc2cfe07156ccbe6fea8f4f977bebcc04;
    bytes32 internal constant _IDLE_DISTRIBUTOR = 0xb2f7d491f85e6b66612eb5a10a2ed5d8285b176fec369924ce35cc46190bb048;
    bytes32 internal constant _LIQUIDITY_GAUGE = 0xdefb28cb4afe76becb36959ca990fb40075f668b97d0dbfc4c4da2c6e73e879a;
    bytes32 internal constant _LIQUIDITY_GAUGE_REWARD = 0xdb1165a9ca87102cffa27e10807f703b726c6ddabff7e9377e7b206ce2945fea;

    address public constant WETH = address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    address public constant STETH = address(0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84);
    address public constant WSTETH = address(0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0);
    address public constant IDLE = address(0x875773784Af8135eA0ef43b5a374AaD105c5D39e);

    uint256 public constant ONE_TRANCHE_TOKEN = 10**18;

    constructor() public BaseUpgradeableStrategyUL() {
        assert(_IS_STETH == bytes32(uint256(keccak256("eip1967.strategyStorage.isstETH")) - 1));
        assert(_IDLE_DISTRIBUTOR == bytes32(uint256(keccak256("eip1967.strategyStorage.idleDistributor")) - 1));
        assert(_LIQUIDITY_GAUGE == bytes32(uint256(keccak256("eip1967.strategyStorage.liquidityGauge")) - 1));
        assert(_LIQUIDITY_GAUGE_REWARD == bytes32(uint256(keccak256("eip1967.strategyStorage.liquidityGaugeReward")) - 1));
    }

    /* ========== Initialize ========== */

    function initializeBaseStrategy(
        //  "__" for storage because we shadow _storage from GovernableInit
        address __storage,
        address _underlying,
        address _vault,
        address _rewardPool,
        address _idleDistributor,
        address _liquidityGauge,
        address _liquidityGaugeReward
    ) public initializer {
        BaseUpgradeableStrategyUL.initialize({
            _storage: __storage,
            _underlying: _underlying,
            _vault: _vault,
            _rewardPool: _rewardPool,
            _rewardToken: WETH,
            _profitSharingNumerator: 300,
            _profitSharingDenominator: 1000,
            _sell: true,
            _sellFloor: 1e18,
            _implementationChangeDelay: 12 hours,
            _universalLiquidatorRegistry: address(0x7882172921E99d590E097cD600554339fBDBc480)
        });

        bool isSTETH = _underlying == WSTETH;
        address underlyingTokenCDO = IIdleCDO(_rewardPool).token();

        if(isSTETH) {
            require(underlyingTokenCDO == STETH, "Invalid underlying");
        } else {
            require(underlyingTokenCDO == _underlying, "Invalid underlying");
        }

        _setIsSTETH(isSTETH);
        _setIdleDistributor(_idleDistributor);
        _setLiquidityGauge(_liquidityGauge);
        _setLiquidityGaugeReward(_liquidityGaugeReward);
    }

    /* ========== View ========== */

    function depositArbCheck() public view returns (bool) {
        return true;
    }

    function unsalvagableTokens(address token) public view returns (bool) {
        return (token == rewardToken() || token == underlying());
    }

    function investedUnderlyingBalance() public view returns (uint256) {
        address _rewardPool = rewardPool();
        address tranche = IIdleCDO(_rewardPool).AATranche();
        uint256 trancheBalance = IERC20(tranche).balanceOf(address(this));
        uint256 liquidityGaugeBalance = ILiquidityGaugeV3(liquidityGauge()).balanceOf(address(this));
        uint256 tranchePrice = IIdleCDO(_rewardPool).tranchePrice(tranche);

        uint256 underlyingBalance = trancheBalance.add(liquidityGaugeBalance).mul(tranchePrice).div(ONE_TRANCHE_TOKEN);

        if(isSTETH()) {
            underlyingBalance = IWstETH(WSTETH).getWstETHByStETH(underlyingBalance);
        }

        return underlyingBalance;
    }

    /* ========== Internal ========== */

    function _investAll() internal {
        address _underlying = underlying();
        address _rewardPool = rewardPool();

        uint256 balance = IERC20(_underlying).balanceOf(address(this));

        if(balance == 0) {
            return;
        }
        
        if(isSTETH()) {
            IERC20(WSTETH).safeApprove(WSTETH, 0);
            IERC20(WSTETH).safeApprove(WSTETH, balance);

            balance = IWstETH(WSTETH).unwrap(balance);
            _underlying = STETH;
        }

        IERC20(_underlying).safeApprove(_rewardPool, 0);
        IERC20(_underlying).safeApprove(_rewardPool, balance);

        uint256 mintedShare = IIdleCDO(_rewardPool).depositAA(balance);
        address trancheToken = IIdleCDO(_rewardPool).AATranche();
        address _liquidityGauge = liquidityGauge();

        IERC20(trancheToken).safeApprove(_liquidityGauge, 0);
        IERC20(trancheToken).safeApprove(_liquidityGauge, mintedShare);
        ILiquidityGaugeV3(_liquidityGauge).deposit(mintedShare);
    }

    function _claimRewards() internal {
        IDistributor(idleDistributor()).distribute(liquidityGauge());
        if(liquidityGaugeReward() != address(0)) {
            ILiquidityGaugeV3(liquidityGauge()).claim_rewards();
        }
    }

    function _liquidateReward() internal {
        uint256 idleBalance = IERC20(IDLE).balanceOf(address(this));
        address _universalLiquidator = universalLiquidator();
        address _liquidityGaugeReward = liquidityGaugeReward();
        address _rewardToken = rewardToken();

        if(idleBalance != 0) {
            IERC20(IDLE).safeApprove(_universalLiquidator, 0);
            IERC20(IDLE).safeApprove(_universalLiquidator, idleBalance);

            ILiquidator(_universalLiquidator).swapTokenOnMultipleDEXes(
                idleBalance,
                1,
                address(this),
                storedLiquidationDexes[IDLE][_rewardToken],
                storedLiquidationPaths[IDLE][_rewardToken]
            );
        }

        if(_liquidityGaugeReward != address(0)) {
            uint256 liquidityGaugeRewardBalance = IERC20(_liquidityGaugeReward).balanceOf(address(this));
            if(liquidityGaugeRewardBalance != 0) {
                IERC20(_liquidityGaugeReward).safeApprove(_universalLiquidator, 0);
                IERC20(_liquidityGaugeReward).safeApprove(_universalLiquidator, liquidityGaugeRewardBalance);

                ILiquidator(_universalLiquidator).swapTokenOnMultipleDEXes(
                    liquidityGaugeRewardBalance,
                    1,
                    address(this),
                    storedLiquidationDexes[_liquidityGaugeReward][_rewardToken],
                    storedLiquidationPaths[_liquidityGaugeReward][_rewardToken]
                );
            }
        }
        
        uint256 rewardBalance = IERC20(_rewardToken).balanceOf(address(this));
        if (!sell() || rewardBalance < sellFloor()) {
            // Profits can be disabled for possible simplified and rapid exit
            emit ProfitsNotCollected(sell(), rewardBalance < sellFloor());
            return;
        }

        notifyProfitInRewardToken(rewardBalance);
        
        uint256 remainingRewardBalance = IERC20(_rewardToken).balanceOf(address(this));
        if (remainingRewardBalance == 0) {
        return;
        }

        IERC20(_rewardToken).safeApprove(_universalLiquidator, 0);
        IERC20(_rewardToken).safeApprove(_universalLiquidator, remainingRewardBalance);

        // we can accept 1 as minimum because this is called only by a trusted role
        ILiquidator(_universalLiquidator).swapTokenOnMultipleDEXes(
            remainingRewardBalance,
            1,
            address(this), // target
            storedLiquidationDexes[_rewardToken][underlying()],
            storedLiquidationPaths[_rewardToken][underlying()]
        );
    }

    /* ========== External ========== */

    function withdrawAllToVault() public restricted {
        address _rewardPool = rewardPool();
        address tranche = IIdleCDO(_rewardPool).AATranche();
        address _liquidityGauge = liquidityGauge();

        _claimRewards();
        _liquidateReward();

        
        uint256 liquidityGaugeBalance = ILiquidityGaugeV3(_liquidityGauge).balanceOf(address(this));
        ILiquidityGaugeV3(_liquidityGauge).withdraw(liquidityGaugeBalance);
        

        uint256 trancheBalance = IERC20(tranche).balanceOf(address(this));
        if(trancheBalance != 0) {
            uint256 redeemed = IIdleCDO(_rewardPool).withdrawAA(trancheBalance);

            if(isSTETH()) {
                IERC20(STETH).safeApprove(WSTETH, 0);
                IERC20(STETH).safeApprove(WSTETH, redeemed);
                IWstETH(WSTETH).wrap(redeemed);
            }
        }

        uint256 underlyingBalance = IERC20(underlying()).balanceOf(address(this));
        IERC20(underlying()).safeTransfer(vault(), underlyingBalance);
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
        _investAll();
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

    function _setIsSTETH(bool _value) internal {
        setBoolean(_IS_STETH, _value);
    }

    function isSTETH() public view returns (bool) {
        return getBoolean(_IS_STETH);
    }

    function _setIdleDistributor(address _addr) internal {
        setAddress(_IDLE_DISTRIBUTOR, _addr);
    }

    function idleDistributor() public view returns (address) {
        return getAddress(_IDLE_DISTRIBUTOR);
    }

    function _setLiquidityGauge(address _addr) internal {
        setAddress(_LIQUIDITY_GAUGE, _addr);
    }

    function liquidityGauge() public view returns (address) {
        return getAddress(_LIQUIDITY_GAUGE);
    }

    function _setLiquidityGaugeReward(address _addr) internal {
        setAddress(_LIQUIDITY_GAUGE_REWARD, _addr);
    }

    function liquidityGaugeReward() public view returns (address) {
        return getAddress(_LIQUIDITY_GAUGE_REWARD);
    }

    function() external payable {
        require(msg.sender == WETH, "direct eth transfer not allowed");
    }
}