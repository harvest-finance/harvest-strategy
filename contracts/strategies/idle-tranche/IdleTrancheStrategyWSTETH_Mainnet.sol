pragma solidity 0.5.16;

import "./IdleFinanceTrancheStrategy.sol";

contract IdleTrancheStrategyWSTETH_Mainnet is IdleFinanceTrancheStrategy {
    constructor() public {}

    function initializeStrategy(address _storage, address _vault)
        public
        initializer
    {
        address weth = address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
        address wsteth = address(0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0);
        address idle = address(0x875773784Af8135eA0ef43b5a374AaD105c5D39e);
        address ldo = address(0x5A98FcBEA516Cf06857215779Fd812CA3beF1B32);

        bytes32 uniV3Dex = 0x8f78a54cb77f4634a5bf3dd452ed6a2e33432c73821be59208661199511cd94f;
        bytes32 sushiDex = 0xcb2d20206d906069351c89a2cb7cdbd96c71998717cd5a82e724d955b654f67a;

        IdleFinanceTrancheStrategy.initializeBaseStrategy(
            _storage,
            wsteth, // wstETH
            _vault,
            address(0x34dCd573C5dE4672C8248cd12A99f875Ca112Ad8), // Lido stETH AA/BB Perp Tranche
            address(0x074306BC6a6Fc1bD02B425dd41D742ADf36Ca9C6), // Distributor
            address(0x675eC042325535F6e176638Dd2d4994F645502B9), // AATranche_lido gague
            ldo // LDO
        );

        storedLiquidationDexes[idle][weth] = [sushiDex];
        storedLiquidationPaths[idle][weth] = [idle, weth];
        storedLiquidationDexes[ldo][weth] = [uniV3Dex];
        storedLiquidationPaths[ldo][weth] = [ldo, weth];
        storedLiquidationDexes[weth][wsteth] = [uniV3Dex];
        storedLiquidationPaths[weth][wsteth] = [weth, wsteth];
    }
}