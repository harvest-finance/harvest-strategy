pragma solidity 0.5.16;

import "@openzeppelin/contracts/math/Math.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20Detailed.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";

import "../upgradability/BaseUpgradeableStrategy.sol";

import "../interface/uniswap/IUniswapV2Pair.sol";
import "../interface/uniswap/IUniswapV2Router02.sol";
import "../interface/IStrategy.sol";
import "../interface/IVault.sol";
import "./interface/IDodo.sol";
import "./interface/IDodoLpToken.sol";
import "./interface/IDodoMine.sol";
import "./interface/IDodoV2Proxy02.sol";

contract DodoV1SingleLPStrategy is IStrategy, BaseUpgradeableStrategy {
    using Address for address;
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    // DODO token
    address public constant dodo =
        address(0x43Dfc4159D86F3A37A5A4B3D4580b888ad7d4DDd);

    // USDT token
    address public constant usdt =
        address(0xdAC17F958D2ee523a2206206994597C13D831ec7);

    // DODO/USDT pair on DODO V1
    address public constant dodoV1DodoUsdtPair =
        address(0x8876819535b48b551C9e97EBc07332C7482b4b2d);

    // Uniswap V2 router
    address public constant uniswapRouterV2 =
        address(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);

    // DODO V2 router
    address public constant dodoRouterV2 =
        address(0xa356867fDCEa8e71AEaF87805808803806231FdC);

    // DODO approve contract
    address public constant dodoApprove =
        address(0xCB859eA579b28e02B87A1FDE08d087ab9dbE5149);

    // Additional storage slots (on top of the BaseUpgradeableStrategy ones) are defined here
    bytes32 internal constant _POOLID_SLOT =
        0x3fd729bfa2e28b7806b03a6e014729f59477b530f995be4d51defc9dad94810b;
    bytes32 internal constant _DODOPAIR_SLOT =
        0x68fc1d4875ce1b76bd6b0a64be41568415a4eb4191e1e98844d3d16539828d7d;
    bytes32 internal constant _ISBASETOKEN_SLOT =
        0x270847aaa285e846a7e95e3d87e81ca02bd6074c49a58a7e2755bfc8386b43ab;

    // This would be reset on each upgrade
    mapping(address => address[]) public uniswapRoutes;

    // ---------------- Constructor ----------------

    constructor() public BaseUpgradeableStrategy() {
        assert(
            _POOLID_SLOT ==
                bytes32(
                    uint256(keccak256("eip1967.strategyStorage.poolId")) - 1
                )
        );
        assert(
            _DODOPAIR_SLOT ==
                bytes32(
                    uint256(keccak256("eip1967.strategyStorage.dodoPair")) - 1
                )
        );
        assert(
            _ISBASETOKEN_SLOT ==
                bytes32(
                    uint256(keccak256("eip1967.strategyStorage.isBaseToken")) -
                        1
                )
        );
    }

    // ---------------- Initializer ----------------

    function initializeBaseStrategy(
        address _storage,
        address _underlying,
        address _vault,
        address _rewardPool,
        address _dodoPair,
        bool _isBaseToken
    ) public initializer {
        BaseUpgradeableStrategy.initialize(
            _storage,
            _underlying,
            _vault,
            _rewardPool,
            // Rewards are actually given in DODO tokens. However, since
            // liquidity for DODO is very low on Uniswap, we swap the DODO
            // rewards to USDT on DODO (which has very good liquidity for
            // DODO/USDT) and use USDT as a reward token for more efficient
            // liquidation.
            usdt,
            300, // Profit sharing numerator
            1000, // Profit sharing denominator
            true, // Sell
            1e18, // Sell floor
            12 hours // Implementation change delay
        );

        uint256 poolId = IDodoMine(rewardPool()).getPid(underlying());
        setPoolId(poolId);

        setDodoPair(_dodoPair);
        setIsBaseToken(_isBaseToken);

        if (_isBaseToken) {
            require(
                IDodo(_dodoPair)._BASE_CAPITAL_TOKEN_() == underlying(),
                "Underlying LP token is not a base token in the DODO pair"
            );
        } else {
            require(
                IDodo(_dodoPair)._QUOTE_CAPITAL_TOKEN_() == underlying(),
                "Underlying LP token is not a quote token in the DODO pair"
            );
        }

        uniswapRoutes[IDodoLpToken(underlying()).originToken()] = new address[](
            0
        );
    }

    // ---------------- IStrategy methods ----------------

    function unsalvagableTokens(address token) public view returns (bool) {
        return (token == dodo || token == underlying());
    }

    /**
     * @dev Withdraws everything back to the vault.
     */
    function withdrawAllToVault() public restricted {
        if (address(rewardPool()) != address(0)) {
            exitRewardPool();
        }
        _liquidateReward();
        IERC20(underlying()).safeTransfer(
            vault(),
            IERC20(underlying()).balanceOf(address(this))
        );
    }

    function withdrawToVault(uint256 amount) public restricted {
        // Typically there wouldn't be any coins here - however, this would
        // still be possible because of an emergency exit
        uint256 currentBalance = IERC20(underlying()).balanceOf(address(this));

        if (amount > currentBalance) {
            // While we have the check above, we're still using SafeMath, just
            // for peace of mind (in case something gets changed in between)
            uint256 needToWithdraw = amount.sub(currentBalance);
            uint256 toWithdraw = Math.min(rewardPoolBalance(), needToWithdraw);
            IDodoMine(rewardPool()).withdraw(underlying(), toWithdraw);
        }

        IERC20(underlying()).safeTransfer(vault(), amount);
    }

    /**
     * @dev Note that we currently don't have a mechanism here to include
     *      the accrued rewards.
     */
    function investedUnderlyingBalance() external view returns (uint256) {
        if (address(rewardPool()) == address(0)) {
            return IERC20(underlying()).balanceOf(address(this));
        }
        // Add the amount locked in the reward pool and the amount that resides in this contract
        // (both are in the units of "underlying")
        // The second part is needed because of the emergency exit mechanism, which would break
        // the assumption that all funds are inside the reward pool
        return
            rewardPoolBalance().add(
                IERC20(underlying()).balanceOf(address(this))
            );
    }

    /**
     * @dev Governance or controller can claim coins that are somehow transferred
     *      into the contract (eg. by mistake). Note that the underlying LP token
     *      is not salvagable.
     */
    function salvage(
        address recipient,
        address token,
        uint256 amount
    ) external onlyControllerOrGovernance {
        // Make sure governance or controller cannot come in and take away the invested tokens
        require(
            !unsalvagableTokens(token),
            "Token is defined as non-salvagable"
        );
        IERC20(token).safeTransfer(recipient, amount);
    }

    function depositArbCheck() public view returns (bool) {
        return true;
    }

    function doHardWork() external onlyNotPausedInvesting restricted {
        claimRewards();
        _liquidateReward();
        investAllUnderlying();
    }

    // ---------------- Governance-only methods ----------------

    /**
     * @dev In case there are issues with the pool or underlying asset,
     *      governance can still trigger an emergency exit.
     */
    function emergencyExit() public onlyGovernance {
        emergencyExitRewardPool();
        _setPausedInvesting(true);
    }

    /**
     * @dev Resumes the ability to invest into the underlying rewards pool.
     */
    function continueInvesting() public onlyGovernance {
        _setPausedInvesting(false);
    }

    /**
     * @dev Can completely disable liquidation of DODO rewards. This can be
     *      useful in case of emergency exits.
     */
    function setSell(bool _sell) public onlyGovernance {
        _setSell(_sell);
    }

    /**
     * @dev Set the minimum amount of DODO needed to trigger a sale (for a liquidation).
     */
    function setSellFloor(uint256 _sellFloor) public onlyGovernance {
        setSellFloor(_sellFloor);
    }

    function setLiquidationPath(address _token, address[] memory _route)
        public
        onlyGovernance
    {
        uniswapRoutes[_token] = _route;
    }

    function finalizeUpgrade() external onlyGovernance {
        _finalizeUpgrade();

        // Reset the liquidation paths - they need to be reset manually
        uniswapRoutes[IDodoLpToken(underlying()).originToken()] = new address[](
            0
        );
    }

    // ---------------- Internal methods ----------------

    function rewardPoolBalance() internal view returns (uint256 balance) {
        (balance, ) = IDodoMine(rewardPool()).userInfo(poolId(), address(this));
    }

    function claimRewards() internal {
        IDodoMine(rewardPool()).claim(underlying());
    }

    function enterRewardPool() internal {
        uint256 currentBalance = IERC20(underlying()).balanceOf(address(this));
        IERC20(underlying()).safeApprove(rewardPool(), 0);
        IERC20(underlying()).safeApprove(rewardPool(), currentBalance);
        IDodoMine(rewardPool()).deposit(underlying(), currentBalance);
    }

    function exitRewardPool() internal {
        uint256 balance = rewardPoolBalance();
        if (balance != 0) {
            IDodoMine(rewardPool()).withdraw(underlying(), balance);
        }
    }

    function emergencyExitRewardPool() internal {
        uint256 balance = rewardPoolBalance();
        if (balance != 0) {
            IDodoMine(rewardPool()).emergencyWithdraw(underlying());
        }
    }

    /**
     * @dev Stakes everything the strategy holds into the reward pool.
     */
    function investAllUnderlying() internal onlyNotPausedInvesting {
        // This check is needed for avoiding reverts in case we stake 0
        if (IERC20(underlying()).balanceOf(address(this)) > 0) {
            enterRewardPool();
        }
    }

    // We assume that all trading can be done on Uniswap
    function _liquidateReward() internal {
        uint256 dodoBalance = IERC20(dodo).balanceOf(address(this));

        // Profits can be disabled for possible simplified and rapid exit
        if (!sell() || dodoBalance < sellFloor()) {
            emit ProfitsNotCollected(sell(), dodoBalance < sellFloor());
            return;
        }

        // Liquidate the DODO rewards via DODO's DODO/USDT pool

        IERC20(dodo).safeApprove(dodoApprove, 0);
        IERC20(dodo).safeApprove(dodoApprove, dodoBalance);

        address[] memory dodoV1Pairs = new address[](1);
        dodoV1Pairs[0] = dodoV1DodoUsdtPair;

        IDodoV2Proxy02(dodoRouterV2).dodoSwapV1(
            dodo,
            usdt,
            dodoBalance,
            1,
            dodoV1Pairs,
            0,
            false,
            block.timestamp
        );

        // Handle USDT as the reward token

        uint256 rewardBalance = IERC20(usdt).balanceOf(address(this));

        notifyProfitInRewardToken(rewardBalance);
        uint256 remainingRewardBalance =
            IERC20(rewardToken()).balanceOf(address(this));

        if (remainingRewardBalance == 0) {
            return;
        }

        // Liquidate the USDT via Uniswap

        address originToken = IDodoLpToken(underlying()).originToken();

        if (uniswapRoutes[originToken].length > 0) {
            IERC20(rewardToken()).safeApprove(uniswapRouterV2, 0);
            IERC20(rewardToken()).safeApprove(
                uniswapRouterV2,
                remainingRewardBalance
            );

            IUniswapV2Router02(uniswapRouterV2).swapExactTokensForTokens(
                remainingRewardBalance,
                1,
                uniswapRoutes[originToken],
                address(this),
                block.timestamp
            );
        }

        // Use the liquidated rewards to provide liqudity in order to get more underlying

        uint256 originTokenBalance =
            IERC20(originToken).balanceOf(address(this));

        IERC20(originToken).safeApprove(dodoApprove, 0);
        IERC20(originToken).safeApprove(dodoApprove, originTokenBalance);

        if (isBaseToken()) {
            IDodoV2Proxy02(dodoRouterV2).addLiquidityToV1(
                dodoPair(),
                originTokenBalance,
                0,
                1,
                0,
                0,
                block.timestamp
            );
        } else {
            IDodoV2Proxy02(dodoRouterV2).addLiquidityToV1(
                dodoPair(),
                0,
                originTokenBalance,
                0,
                1,
                0,
                block.timestamp
            );
        }
    }

    // ---------------- Helper methods ----------------

    function setPoolId(uint256 _poolId) internal {
        setUint256(_POOLID_SLOT, _poolId);
    }

    function poolId() public view returns (uint256) {
        return getUint256(_POOLID_SLOT);
    }

    function setDodoPair(address _dodoPair) internal {
        setAddress(_DODOPAIR_SLOT, _dodoPair);
    }

    function dodoPair() public view returns (address) {
        return getAddress(_DODOPAIR_SLOT);
    }

    function setIsBaseToken(bool _isBaseToken) internal {
        setBoolean(_ISBASETOKEN_SLOT, _isBaseToken);
    }

    function isBaseToken() public view returns (bool) {
        return getBoolean(_ISBASETOKEN_SLOT);
    }
}
