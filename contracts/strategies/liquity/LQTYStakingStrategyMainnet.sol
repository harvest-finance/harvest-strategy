pragma solidity 0.5.16;
pragma experimental ABIEncoderV2;

import "./LQTYStakingStrategy.sol";

contract LQTYStakingStrategyMainnet is LQTYStakingStrategy {
    address private constant lusd =
        address(0x5f98805A4E8be255a32880FDeC7F6728C6568bA0);
    address private constant lqty =
        address(0x6DEA81C8171D0bA574754EF6F8b412F2Ed88c54D);
    address private constant usdc =
        address(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    address private constant weth =
        address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);

    address private constant lqtyStaking =
        address(0x4f9Fbb3f1E99B56e0Fe2892e623Ed36A76Fc605d);
    address private constant lusd3CrvPair =
        address(0xEd279fDD11cA84bEef15AF5D39BB4d4bEE23F0cA);

    bytes32 private constant uniV3 = bytes32(uint256(keccak256("uniV3")));

    constructor() public {}

    function initializeStrategy(address _storage, address _vault)
        public
        initializer
    {
        LQTYStakingStrategy.initializeBaseStrategy(
            _storage,
            _vault,
            lusd,
            lqty,
            usdc,
            weth,
            lqtyStaking,
            lusd3CrvPair
        );

        storedLiquidationPaths[usdc][weth] = [usdc, weth];
        storedLiquidationDexes[usdc][weth] = [uniV3];
        storedLiquidationPaths[weth][lqty] = [weth, lqty];
        storedLiquidationDexes[weth][lqty] = [uniV3];
    }
}
