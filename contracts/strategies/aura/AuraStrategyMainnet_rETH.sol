//SPDX-License-Identifier: Unlicense
pragma solidity 0.5.16;
pragma experimental ABIEncoderV2;

import "hardhat/console.sol";
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
        address rewardPool = address(0x6eBDC53B2C07378662940A7593Ad39Fb67778457); // Aura: Balancer rETH Stable Pool Aura Deposit Vault
        bytes32 balancerDex = bytes32(0x9e73ce1e99df7d45bc513893badf42bc38069f1564ee511b0c8988f72f127b13);
        address bal = address(0xba100000625a3754423978a60c9317c58a424e3D);
        address aura = address(0xC0c293ce456fF0ED870ADd98a0828Dd4d2903DBF);
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
            21, // Aura: PoolId
            0x1e19cf2d73a72ef1332c882f20534b6519be0276000200000000000000000112, // Balancer: PoolId
            weth, //Balancer: Deposit Token
            1, // Balancer: Deposit Array Position
            1000
        );
    }
}
