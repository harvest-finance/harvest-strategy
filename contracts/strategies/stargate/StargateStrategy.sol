pragma solidity ^0.5.16;

import "@openzeppelin/contracts/math/Math.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20Detailed.sol";
import "../../base/interface/IStrategy.sol";
import "../../base/interface/curve/ICurvePoolV2.sol";
import "../../base/interface/curve/ICurveDeposit_3token.sol";
import "../../base/upgradability/BaseUpgradeableStrategy.sol";

import "./interfaces/IStargateFarmingPool.sol";
import "./interfaces/IStargateRouter.sol";
import "./interfaces/IStargateToken.sol";

contract StargateStrategy is BaseUpgradeableStrategy {
    using SafeMath for uint256;

    // additional storage slots (on top of BaseUpgradeableStrategy ones) are defined here
    bytes32 internal constant _DEPOSIT_TOKEN_SLOT =
        0x219270253dbc530471c88a9e7c321b36afda219583431e7b6c386d2d46e70c86;
    bytes32 internal constant _STARGATE_ROUTER_SLOT =
        0x50cf24350c52fb388d41633efadcddb2fcfdac560121bd804c614894e1344423;
    bytes32 internal constant _STARGATE_POOL_ID_SLOT =
        0xdde5da573f4abb9d5adeea4ab5f76d1ae01e04e01a2bfcb11322b4001c69c146;
    bytes32 internal constant _STARGATE_REWARD_PID_SLOT =
        0x893cb48ac83aa0075866e20e9a91e0211aed1b871dfb764e3a6054cd6082714e;

    address public constant curve_stg_pool =
        address(0x3211C6cBeF1429da3D0d58494938299C92Ad5860);
    address public constant curve_3pool =
        address(0xbEbc44782C7dB0a1A60Cb6fe97d0b483032FF1C7);
    address public constant usdc =
        address(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    address public constant stg = 
        address(0xAf5191B0De278C7286d6C7CC6ab6BB8A73bA2Cd6);

    constructor() public BaseUpgradeableStrategy() {
        assert(
            _DEPOSIT_TOKEN_SLOT ==
                bytes32(
                    uint256(keccak256("eip1967.strategyStorage.depositToken")) -
                        1
                )
        );
        assert(
            _STARGATE_ROUTER_SLOT ==
                bytes32(
                    uint256(
                        keccak256("eip1967.strategyStorage.stargateRouter")
                    ) - 1
                )
        );
        assert(
            _STARGATE_POOL_ID_SLOT ==
                bytes32(
                    uint256(
                        keccak256("eip1967.strategyStorage.stargatePoolId")
                    ) - 1
                )
        );
        assert(
            _STARGATE_REWARD_PID_SLOT ==
                bytes32(
                    uint256(
                        keccak256("eip1967.strategyStorage.stargateRewardPid")
                    ) - 1
                )
        );
    }

    function initializeStargateStrategy(
        address _storage,
        address _underlying,
        address _vault,
        address _rewardPool,
        address _depositToken,
        address _stargateRouter,
        uint256 _stargatePoolId,
        uint256 _stargateRewardPid
    ) public initializer {
        BaseUpgradeableStrategy.initialize(
            _storage,
            _underlying,
            _vault,
            _rewardPool,
            usdc,
            300, // profit sharing numerator
            1000, // profit sharing denominator
            true, // sell
            1e18, // sell floor
            12 hours // implementation change delay
        );

        require(
            IStargateToken(_underlying).token() == _depositToken,
            "underlying does not match deposit token"
        );
        require(
            IStargateToken(_underlying).poolId() == _stargatePoolId,
            "underlying does not match pool ID"
        );

        (address foundLpToken, , , ) = IStargateFarmingPool(_rewardPool)
            .poolInfo(_stargateRewardPid);
        require(
            foundLpToken == _underlying,
            "reward pool LP token does not match underlying"
        );

        _setDepositToken(_depositToken);
        _setStargateRouter(_stargateRouter);
        _setStargatePoolId(_stargatePoolId);
        _setStargateRewardPid(_stargateRewardPid);
    }

    function depositArbCheck() external view returns (bool) {
        return true;
    }

    function depositToken() public view returns (address) {
        return getAddress(_DEPOSIT_TOKEN_SLOT);
    }

    function stargateRouter() public view returns (address) {
        return getAddress(_STARGATE_ROUTER_SLOT);
    }

    function stargatePoolId() public view returns (uint256) {
        return getUint256(_STARGATE_POOL_ID_SLOT);
    }

    function stargateRewardPid() public view returns (uint256) {
        return getUint256(_STARGATE_REWARD_PID_SLOT);
    }

    function getRewardPoolValues() public returns (uint256[] memory values) {
        values = new uint256[](1);
        values[0] = IStargateFarmingPool(rewardPool()).pendingStargate(
            stargateRewardPid(),
            address(this)
        );
    }

    // ========================= Internal Functions =========================

    function _setDepositToken(address _depositToken) internal {
        setAddress(_DEPOSIT_TOKEN_SLOT, _depositToken);
    }

    function _setStargatePoolId(uint256 _stargatePoolId) internal {
        setUint256(_STARGATE_POOL_ID_SLOT, _stargatePoolId);
    }

    function _setStargateRewardPid(uint256 _stargateRewardPid) internal {
        setUint256(_STARGATE_REWARD_PID_SLOT, _stargateRewardPid);
    }

    function _setStargateRouter(address _stargateRouter) internal {
        setAddress(_STARGATE_ROUTER_SLOT, _stargateRouter);
    }

    function _finalizeUpgrade() internal {}

    function _rewardPoolBalance() internal view returns (uint256) {
        (uint256 balance, ) = IStargateFarmingPool(rewardPool()).userInfo(
            stargateRewardPid(),
            address(this)
        );
        return balance;
    }

    function _partialExitRewardPool(uint256 _amount) internal {
        if (_amount > 0) {
            IStargateFarmingPool(rewardPool()).withdraw(
                stargateRewardPid(),
                _amount
            );
        }
    }

    function _enterRewardPool() internal {
        address _underlying = underlying();
        address _rewardPool = rewardPool();

        uint256 entireBalance = IERC20(_underlying).balanceOf(address(this));
        IERC20(_underlying).safeApprove(_rewardPool, 0);
        IERC20(_underlying).safeApprove(_rewardPool, entireBalance);
        IStargateFarmingPool(_rewardPool).deposit(
            stargateRewardPid(),
            entireBalance
        ); // deposit and stake
    }

    function _claimRewards() internal {
        // claiming is done by depositing 0 into the pool
        IStargateFarmingPool(rewardPool()).deposit(stargateRewardPid(), 0);
    }

    function _liquidateReward() internal {

        uint256 stgBalance = IERC20(stg).balanceOf(address(this));

        if (stgBalance > 0) {
            IERC20(stg).safeApprove(curve_stg_pool, 0);
            IERC20(stg).safeApprove(curve_stg_pool, stgBalance);
            ICurvePoolV2(curve_stg_pool).exchange(0, 1, stgBalance, 1);

            address _rewardToken = rewardToken();
            uint256 rewardBalance = IERC20(_rewardToken).balanceOf(address(this));

            if (rewardBalance > 0) {
                notifyProfitInRewardToken(rewardBalance);
            }

            if (usdc != depositToken()) {
                uint256 usdcBalance = IERC20(usdc).balanceOf(address(this));
                IERC20(usdc).safeApprove(curve_3pool, 0);
                IERC20(usdc).safeApprove(curve_3pool, usdcBalance);
                ICurveDeposit_3token(curve_3pool).exchange(1, 2, usdcBalance, 1);
            }
        }

        uint256 tokenBalance = IERC20(depositToken()).balanceOf(address(this));
        if (tokenBalance > 0) {
            _mintLiquidityTokens();
        }
    }

    function _mintLiquidityTokens() internal {
        address _depositToken = depositToken();
        address _router = stargateRouter();
        uint256 tokenBalance = IERC20(_depositToken).balanceOf(address(this));
        IERC20(_depositToken).safeApprove(_router, 0);
        IERC20(_depositToken).safeApprove(_router, tokenBalance);

        IStargateRouter(_router).addLiquidity(
            stargatePoolId(),
            tokenBalance,
            address(this)
        );
    }

    function enterRewardPool()
        external
        onlyNotPausedInvesting
        restricted
    {
        _enterRewardPool();
    }

    function withdrawAllToVault() external restricted {
        if (address(rewardPool()) != address(0)) {
            _partialExitRewardPool(_rewardPoolBalance());
        }
        _liquidateReward();
        IERC20(underlying()).safeTransfer(
            vault(),
            IERC20(underlying()).balanceOf(address(this))
        );
    }

    /**
     * Withdraws `amount` of assets to the vault
     */
    function withdrawToVault(uint256 amount) external restricted {
        // Typically there wouldn't be any amount here
        // however, it is possible because of the emergencyExit
        uint256 entireBalance = IERC20(underlying()).balanceOf(address(this));

        if (amount > entireBalance) {
            // While we have the check above, we still using SafeMath below for the peace of mind (in case something
            // gets changed in between)
            uint256 needToWithdraw = amount.sub(entireBalance);
            uint256 toWithdraw = Math.min(_rewardPoolBalance(), needToWithdraw);
            _partialExitRewardPool(toWithdraw);
        }
        IERC20(underlying()).safeTransfer(vault(), amount);
    }

    function investedUnderlyingBalance() external view returns (uint256) {
        return
            _rewardPoolBalance().add(
                IERC20(underlying()).balanceOf(address(this))
            );
    }

    function doHardWork() external onlyNotPausedInvesting restricted {
        _claimRewards();
        _liquidateReward();
        _enterRewardPool();
    }

    function unsalvagableTokens(address token) public view returns (bool) {
        return (token == rewardToken() || token == underlying());
    }

    function salvageToken(
        address _recipient,
        address _token,
        uint256 _amount
    ) public onlyControllerOrGovernance {
        // To make sure that governance cannot come in and take away the coins
        require(!unsalvagableTokens(_token), "The token must be salvageable");
        IERC20(_token).safeTransfer(_recipient, _amount);
    }
}
