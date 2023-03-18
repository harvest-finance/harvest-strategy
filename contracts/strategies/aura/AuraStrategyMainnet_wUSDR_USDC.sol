//SPDX-License-Identifier: Unlicense
pragma solidity 0.5.16;
pragma experimental ABIEncoderV2;

import "./base/AuraStrategyJoinPoolUL.sol";

contract AuraStrategyMainnet_wUSDR_USDC is AuraStrategyJoinPoolUL {

    constructor() public {}

    function initializeStrategy(
        address _storage, // Harvest: Storage
        address _vault // Harvest: Vault
    ) public initializer {
        address underlying = address(0x831261f44931B7dA8ba0DcC547223c60BB75B47F);
        address rewardPool = address(0x2a596E721A9F1824F36c484e71f5bE80675Cca2b);
        address wusdr = address(0xD5a14081a34d256711B02BbEf17E567da48E80b5);
        address usdc = address(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
        bytes32 uniV3Dex = bytes32(0x8f78a54cb77f4634a5bf3dd452ed6a2e33432c73821be59208661199511cd94f);

        poolAssets = [usdc, wusdr];
        rewardTokens = [bal, aura];
        storedLiquidationPaths[bal][weth] = [bal, weth];
        storedLiquidationDexes[bal][weth] = [balancerDex];
        storedLiquidationPaths[aura][weth] = [aura, weth];
        storedLiquidationDexes[aura][weth] = [balancerDex];
        storedLiquidationPaths[weth][usdc] = [weth, usdc];
        storedLiquidationDexes[weth][usdc] = [uniV3Dex];

        AuraStrategyJoinPoolUL.initializeBaseStrategy(
            _storage,
            underlying,
            _vault,
            rewardPool,
            65, // Aura: PoolId
            0x831261f44931b7da8ba0dcc547223c60bb75b47f000200000000000000000460, // Balancer: PoolId
            usdc, //Balancer: Deposit Token
            0, // Balancer: Deposit Array Position
            500
        );
    }
}
