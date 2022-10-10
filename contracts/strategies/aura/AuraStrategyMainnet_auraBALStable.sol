//SPDX-License-Identifier: Unlicense
pragma solidity 0.5.16;
pragma experimental ABIEncoderV2;

import "hardhat/console.sol";
import "./base/AuraStrategyJoinPoolUL.sol";

contract AuraStrategyMainnet_auraBALStable is AuraStrategyJoinPoolUL {

    //Differentiator for the bytecode
    address public auraBAL_Stable_unused;

    constructor() public {}

    function initializeStrategy(
        address _storage, // Harvest: Storage
        address _vault // Harvest: Vault
    ) public initializer {
        address underlying = address(0x3dd0843A028C86e0b760b1A76929d1C5Ef93a2dd); // Balancer: Balancer auraBAL Stable Pool
        address rewardPool = address(0x2AEF2f950E507A23cc19a882DC9b33c03B55D3f2); // Aura: Balancer auraBAL Stable Pool Aura Deposit Vault
        bytes32 balancerDex = bytes32(0x9e73ce1e99df7d45bc513893badf42bc38069f1564ee511b0c8988f72f127b13);
        address bal = address(0xba100000625a3754423978a60c9317c58a424e3D);
        address aura = address(0xC0c293ce456fF0ED870ADd98a0828Dd4d2903DBF);
        address b80Bal20wEth = address(0x5c6Ee304399DBdB9C8Ef030aB642B10820DB8F56);
        address auraBal = address(0x616e8BfA43F920657B3497DBf40D6b1A02D4608d);

        poolAssets = [b80Bal20wEth, auraBal];
        rewardTokens = [bal, aura];
        storedLiquidationPaths[bal][weth] = [bal, weth];
        storedLiquidationDexes[bal][weth] = [balancerDex];
        storedLiquidationPaths[aura][weth] = [aura, weth];
        storedLiquidationDexes[aura][weth] = [balancerDex];
        storedLiquidationPaths[weth][auraBal] = [weth, auraBal];
        storedLiquidationDexes[weth][auraBal] = [balancerDex];

        AuraStrategyJoinPoolUL.initializeBaseStrategy(
            _storage,
            underlying,
            _vault,
            rewardPool,
            19, // Aura: PoolId
            0x3dd0843a028c86e0b760b1a76929d1c5ef93a2dd000200000000000000000249, // Balancer: PoolId
            auraBal, //Balancer: Deposit Token
            1, // Balancer: Deposit Array Position
            1000
        );
    }
}
