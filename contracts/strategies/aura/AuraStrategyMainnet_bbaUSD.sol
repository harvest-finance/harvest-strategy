//SPDX-License-Identifier: Unlicense
pragma solidity 0.5.16;
pragma experimental ABIEncoderV2;

import "hardhat/console.sol";
import "./base/AuraStrategyBatchSwapUL.sol";

contract AuraStrategyMainnet_bbaUSD is AuraStrategyBatchSwapUL {

    //Differentiator for the bytecode
    address public bbaUSD_unused;

    constructor() public {}

    function initializeStrategy(
        address _storage, // Harvest: Storage
        address _vault // Harvest: Vault
    ) public initializer {
        address underlying = address(0xA13a9247ea42D743238089903570127DdA72fE44); // Balancer: Balancer Aave Boosted StablePool
        address rewardPool = address(0x1e9F147241dA9009417811ad5858f22Ed1F9F9fd); // Aura: Balancer Aave Boosted StablePool Aura Deposit Vault
        bytes32 balancerDex = bytes32(0x9e73ce1e99df7d45bc513893badf42bc38069f1564ee511b0c8988f72f127b13);
        bytes32 wETH_USDC = bytes32(0x96646936b91d6b9d7d0c47c496afbf3d6ec7b6f8000200000000000000000019);
        bytes32 USDC_bbaUSDC = bytes32(0x82698aecc9e28e9bb27608bd52cf57f704bd1b83000000000000000000000336);
        bytes32 bbaUSDC_bbaUSD = bytes32(0xa13a9247ea42d743238089903570127dda72fe4400000000000000000000035d);
        address bal = address(0xba100000625a3754423978a60c9317c58a424e3D);
        address aura = address(0xC0c293ce456fF0ED870ADd98a0828Dd4d2903DBF);
        address usdc = address(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
        address bbaUSDC = address(0x82698aeCc9E28e9Bb27608Bd52cF57f704BD1B83);
        address bbaUSD = address(0xA13a9247ea42D743238089903570127DdA72fE44);

        // WETH -> USDC -> bb-a-USDC -> bb-a-USD
        swapAssets = [weth, usdc, bbaUSDC, bbaUSD];
        swapPoolIds = [wETH_USDC, USDC_bbaUSDC, bbaUSDC_bbaUSD];

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
            41, // Aura: PoolId
            weth, //Balancer: Deposit Token
            1000
        );
    }
}
