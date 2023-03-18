//SPDX-License-Identifier: Unlicense
pragma solidity 0.5.16;
pragma experimental ABIEncoderV2;

import "./base/AuraStrategyBatchSwapUL.sol";

contract AuraStrategyMainnet_wstETH_rETH_sfrxETH is AuraStrategyBatchSwapUL {

    constructor() public {}

    function initializeStrategy(
        address _storage, // Harvest: Storage
        address _vault // Harvest: Vault
    ) public initializer {
        address underlying = address(0x5aEe1e99fE86960377DE9f88689616916D5DcaBe);
        address rewardPool = address(0xd26948E7a0223700e3C3cdEA21cA2471abCb8d47);
        bytes32 wETH_wstETH = bytes32(0x32296969ef14eb0c6d29669c550d4a0449130230000200000000000000000080);
        bytes32 wstETH_underlying = bytes32(0x5aee1e99fe86960377de9f88689616916d5dcabe000000000000000000000467);
        address wsteth = address(0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0);

        // WETH -> wstETH -> underlying
        swapAssets = [weth, wsteth, underlying];
        swapPoolIds = [wETH_wstETH, wstETH_underlying];

        rewardTokens = [bal, aura];
        storedLiquidationPaths[bal][weth] = [bal, weth];
        storedLiquidationDexes[bal][weth] = [balancerDex];
        storedLiquidationPaths[aura][weth] = [aura, weth];
        storedLiquidationDexes[aura][weth] = [balancerDex];
        AuraStrategyBatchSwapUL.initializeBaseStrategy(
            _storage,
            underlying,
            _vault,
            rewardPool,
            50, // Aura: PoolId
            weth, //Balancer: Deposit Token
            500
        );
    }
}
