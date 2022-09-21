//SPDX-License-Identifier: Unlicense
pragma solidity 0.5.16;
pragma experimental ABIEncoderV2;

import "hardhat/console.sol";
import "./base/AuraStrategyUL.sol";

contract AuraStrategyMainnet_stETH is AuraStrategyUL {

    //Differentiator for the bytecode
    address public bstETHStable_unused;

    constructor() public {}

    function initializeStrategy(
        address _storage, // Harvest: Storage
        address _vault // Harvest: Vault
    ) public initializer {
        address underlying = address(0x32296969Ef14EB0c6d29669C550D4a0449130230);
        address rewardPool = address(0xDCee1C640cC270121faF145f231fd8fF1d8d5CD4);
        address bVault = address(0xBA12222222228d8Ba445958a75a0704d566BF2C8);
        bytes32 balancerDex = bytes32(0x9e73ce1e99df7d45bc513893badf42bc38069f1564ee511b0c8988f72f127b13);
        address bal = address(0xba100000625a3754423978a60c9317c58a424e3D);
        address aura = address(0xC0c293ce456fF0ED870ADd98a0828Dd4d2903DBF);
        address wstEth = address(0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0);

        poolAssets = [wstEth, weth];
        rewardTokens = [bal, aura];
        storedLiquidationPaths[bal][weth] = [bal, weth];
        storedLiquidationDexes[bal][weth] = [balancerDex];
        storedLiquidationPaths[aura][weth] = [aura, weth];
        storedLiquidationDexes[aura][weth] = [balancerDex];

        AuraStrategyUL.initializeBaseStrategy(
            _storage,
            underlying,
            _vault,
            rewardPool,
            3,
            0x32296969ef14eb0c6d29669c550d4a0449130230000200000000000000000080,
            weth,
            1,
            bVault,
            1000
        );
    }
}
