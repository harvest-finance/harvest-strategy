//SPDX-License-Identifier: Unlicense
pragma solidity 0.5.16;
pragma experimental ABIEncoderV2;

import "./base/AuraStrategyJoinPoolUL.sol";

contract AuraStrategyMainnet_rETH_BADGER is AuraStrategyJoinPoolUL {

    constructor() public {}

    function initializeStrategy(
        address _storage, // Harvest: Storage
        address _vault // Harvest: Vault
    ) public initializer {
        address underlying = address(0x1ee442b5326009Bb18F2F472d3e0061513d1A0fF);
        address rewardPool = address(0xAAd4eE162Dbc9C25cCa26bA4340B36E3eF7C1A80);
        address reth = address(0xae78736Cd615f374D3085123A210448E74Fc6393);
        address badger = address(0x3472A5A71965499acd81997a54BBA8D852C6E53d);
        bytes32 uniV3Dex = bytes32(0x8f78a54cb77f4634a5bf3dd452ed6a2e33432c73821be59208661199511cd94f);

        poolAssets = [badger, reth];
        rewardTokens = [bal, aura];
        storedLiquidationPaths[bal][weth] = [bal, weth];
        storedLiquidationDexes[bal][weth] = [balancerDex];
        storedLiquidationPaths[aura][weth] = [aura, weth];
        storedLiquidationDexes[aura][weth] = [balancerDex];
        storedLiquidationPaths[weth][reth] = [weth, reth];
        storedLiquidationDexes[weth][reth] = [uniV3Dex];

        AuraStrategyJoinPoolUL.initializeBaseStrategy(
            _storage,
            underlying,
            _vault,
            rewardPool,
            67, // Aura: PoolId
            0x1ee442b5326009bb18f2f472d3e0061513d1a0ff000200000000000000000464, // Balancer: PoolId
            reth, //Balancer: Deposit Token
            1, // Balancer: Deposit Array Position
            500
        );
    }
}
