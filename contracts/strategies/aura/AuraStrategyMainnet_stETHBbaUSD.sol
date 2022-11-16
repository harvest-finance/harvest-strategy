//SPDX-License-Identifier: Unlicense
pragma solidity 0.5.16;
pragma experimental ABIEncoderV2;

import "./base/AuraStrategyBatchSwapJoinPoolUL.sol";

contract AuraStrategyMainnet_stETHBbaUSD is AuraStrategyBatchSwapJoinPoolUL {

    //Differentiator for the bytecode
    address public bbaUSD_unused;

    constructor() public {}

    // Swap all reward tokens into WETH
    // Swap WETH into bbaUSD
    // Deposit bbaUSD for 50wstETH-50bb-a-USD
    // Deposit 50wstETH-50bb-a-USD into Aura

    function initializeStrategy(
        address _storage, // Harvest: Storage
        address _vault // Harvest: Vault
    ) public initializer {
        address underlying = address(0x25Accb7943Fd73Dda5E23bA6329085a3C24bfb6a); // Balancer: Balancer 50wstETH-50bb-a-USD Pool
        address rewardPool = address(0xe5d920029556a49a9cA4DD808CD62a1876C10eBA); // Aura: Balancer 50wstETH-50bb-a-USD Aura Deposit Vault
        bytes32 wETH_USDC = bytes32(0x96646936b91d6b9d7d0c47c496afbf3d6ec7b6f8000200000000000000000019);
        bytes32 USDC_bbaUSDC = bytes32(0x82698aecc9e28e9bb27608bd52cf57f704bd1b83000000000000000000000336);
        bytes32 bbaUSDC_bbaUSD = bytes32(0xa13a9247ea42d743238089903570127dda72fe4400000000000000000000035d);
        address usdc = address(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
        address bbaUSDC = address(0x82698aeCc9E28e9Bb27608Bd52cF57f704BD1B83);
        address bbaUSD = address(0xA13a9247ea42D743238089903570127DdA72fE44);
        address wstEth = address(0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0);

        poolAssets = [wstEth, bbaUSD];
        // WETH -> USDC -> bb-a-USDC -> bb-a-USD
        swapAssets = [weth, usdc, bbaUSDC, bbaUSD];
        swapPoolIds = [wETH_USDC, USDC_bbaUSDC, bbaUSDC_bbaUSD];

        rewardTokens = [bal, aura];
        storedLiquidationPaths[bal][weth] = [bal, weth];
        storedLiquidationDexes[bal][weth] = [balancerDex];
        storedLiquidationPaths[aura][weth] = [aura, weth];
        storedLiquidationDexes[aura][weth] = [balancerDex];
        AuraStrategyBatchSwapJoinPoolUL.initializeBaseStrategy(
            _storage,
            underlying,
            _vault,
            rewardPool,
            51, // Aura: PoolId
            0x25accb7943fd73dda5e23ba6329085a3c24bfb6a000200000000000000000387, // Balancer: PoolId
            bbaUSD, //Balancer: Deposit Token
            1,
            1000
        );
    }
}
