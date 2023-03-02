//SPDX-License-Identifier: Unlicense
pragma solidity 0.5.16;
pragma experimental ABIEncoderV2;

import "./base/AuraStrategyBatchSwapUL.sol";

contract AuraStrategyMainnet_bbiUSD is AuraStrategyBatchSwapUL {

    //Differentiator for the bytecode
    address public bbiUSD_unused;

    constructor() public {}

    function initializeStrategy(
        address _storage, // Harvest: Storage
        address _vault // Harvest: Vault
    ) public initializer {
        address underlying = address(0x60683B05e9a39E3509D8fdb9C959f23170f8A0fa); // Balancer: Balancer Idle Boosted StablePool
        address rewardPool = address(0x4d585a29dF0a8E18c26f662C6586ded6703062a8); // Aura: Balancer Idle Boosted StablePool Aura Deposit Vault
        bytes32 wETH_USDC = bytes32(0x96646936b91d6b9d7d0c47c496afbf3d6ec7b6f8000200000000000000000019);
        bytes32 USDC_bbiUSDC = bytes32(0xbc0f2372008005471874e426e86ccfae7b4de79d000000000000000000000485);
        bytes32 bbiUSDC_bbiUSD = bytes32(0x60683b05e9a39e3509d8fdb9c959f23170f8a0fa000000000000000000000489);
        address usdc = address(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
        address bbiUSDC = address(0xbc0F2372008005471874e426e86CCFae7B4De79d);

        // WETH -> USDC -> bb-i-USDC -> bb-i-USD
        swapAssets = [weth, usdc, bbiUSDC, underlying];
        swapPoolIds = [wETH_USDC, USDC_bbiUSDC, bbiUSDC_bbiUSD];

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
            72, // Aura: PoolId
            weth, //Balancer: Deposit Token
            500
        );
    }
}
