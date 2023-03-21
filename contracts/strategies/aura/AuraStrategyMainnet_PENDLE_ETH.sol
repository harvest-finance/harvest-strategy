//SPDX-License-Identifier: Unlicense
pragma solidity 0.5.16;
pragma experimental ABIEncoderV2;

import "./base/AuraStrategyJoinPoolUL.sol";

contract AuraStrategyMainnet_PENDLE_ETH is AuraStrategyJoinPoolUL {

    constructor() public {}

    function initializeStrategy(
        address _storage, // Harvest: Storage
        address _vault // Harvest: Vault
    ) public initializer {
        address underlying = address(0xFD1Cf6FD41F229Ca86ada0584c63C49C3d66BbC9);
        address rewardPool = address(0x08129a472dfb92A1596Bbe31f27c53914a990563);
        address pendle = address(0x808507121B80c02388fAd14726482e061B8da827);

        poolAssets = [pendle, weth];
        rewardTokens = [bal, aura];
        storedLiquidationPaths[bal][weth] = [bal, weth];
        storedLiquidationDexes[bal][weth] = [balancerDex];
        storedLiquidationPaths[aura][weth] = [aura, weth];
        storedLiquidationDexes[aura][weth] = [balancerDex];

        AuraStrategyJoinPoolUL.initializeBaseStrategy(
            _storage,
            underlying,
            _vault,
            rewardPool,
            61, // Aura: PoolId
            0xfd1cf6fd41f229ca86ada0584c63c49c3d66bbc9000200000000000000000438, // Balancer: PoolId
            weth, //Balancer: Deposit Token
            1, // Balancer: Deposit Array Position
            500
        );
    }
}
