//SPDX-License-Identifier: Unlicense
pragma solidity 0.5.16;
pragma experimental ABIEncoderV2;

import "./base/AuraStrategyJoinPoolUL.sol";

contract AuraStrategyMainnet_rETH is AuraStrategyJoinPoolUL {

    //Differentiator for the bytecode
    address public rETH_Stable_unused;

    constructor() public {}

    function initializeStrategy(
        address _storage, // Harvest: Storage
        address _vault // Harvest: Vault
    ) public initializer {
        address underlying = address(0x1E19CF2D73a72Ef1332C882F20534B6519Be0276); // Balancer: Balancer rETH Stable Pool
        address rewardPool = address(0x001B78CEC62DcFdc660E06A91Eb1bC966541d758); // Aura: Balancer rETH Stable Pool Aura Deposit Vault
        address rEth = address(0xae78736Cd615f374D3085123A210448E74Fc6393);

        poolAssets = [rEth, weth];
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
            15, // Aura: PoolId
            0x1e19cf2d73a72ef1332c882f20534b6519be0276000200000000000000000112, // Balancer: PoolId
            weth, //Balancer: Deposit Token
            1, // Balancer: Deposit Array Position
            500
        );
    }
}
