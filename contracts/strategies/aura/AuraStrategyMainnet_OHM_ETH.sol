//SPDX-License-Identifier: Unlicense
pragma solidity 0.5.16;
pragma experimental ABIEncoderV2;

import "./base/AuraStrategyJoinPoolUL.sol";

contract AuraStrategyMainnet_OHM_ETH is AuraStrategyJoinPoolUL {

    constructor() public {}

    function initializeStrategy(
        address _storage, // Harvest: Storage
        address _vault // Harvest: Vault
    ) public initializer {
        address underlying = address(0xD1eC5e215E8148D76F4460e4097FD3d5ae0A3558);
        address rewardPool = address(0x978653C02f2fBBDfd67CbC7f45c42262f213e0b5);
        address ohm = address(0x64aa3364F17a4D01c6f1751Fd97C2BD3D7e7f1D5);

        poolAssets = [ohm, weth];
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
            55, // Aura: PoolId
            0xd1ec5e215e8148d76f4460e4097fd3d5ae0a35580002000000000000000003d3, // Balancer: PoolId
            weth, //Balancer: Deposit Token
            1, // Balancer: Deposit Array Position
            500
        );
    }
}
