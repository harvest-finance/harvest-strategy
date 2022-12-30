//SPDX-License-Identifier: Unlicense
pragma solidity 0.5.16;
pragma experimental ABIEncoderV2;

import "./base/AuraStrategyJoinPoolUL.sol";

contract AuraStrategyMainnet_stETH is AuraStrategyJoinPoolUL {

    //Differentiator for the bytecode
    address public stETH_Stable_unused;

    constructor() public {}

    function initializeStrategy(
        address _storage, // Harvest: Storage
        address _vault // Harvest: Vault
    ) public initializer {
        address underlying = address(0x32296969Ef14EB0c6d29669C550D4a0449130230); // Balancer: Balancer stETH Stable Pool
        address rewardPool = address(0xe4683Fe8F53da14cA5DAc4251EaDFb3aa614d528); // Aura: Balancer stETH Stable Pool Aura Deposit Vault
        address wstEth = address(0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0);

        poolAssets = [wstEth, weth];
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
            29, // Aura: PoolId
            0x32296969ef14eb0c6d29669c550d4a0449130230000200000000000000000080, // Balancer: PoolId
            weth, //Balancer: Deposit Token
            1, // Balancer: Deposit Array Position
            500
        );
    }
}
