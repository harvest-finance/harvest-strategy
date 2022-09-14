//SPDX-License-Identifier: Unlicense
pragma solidity 0.5.16;
pragma experimental ABIEncoderV2;

import "./base/AuraStrategyUL.sol";

contract AuraStrategystETH is AuraStrategyUL {

    //Differentiator for the bytecode
    address public bstETHStable_unused;

    constructor() public {}

    function initializeStrategy(
        address _storage, // Harvest: Storage
        address _underlyingToken, // Aura: Target Pool, Deposit Balancer Pool Token(BPT)
        address _vault, // Harvest: Vault
        address _rewardPool, // Aura: Target Pool, Base Reward Pool
        uint256 _auraPoolID, // Aura: Target Pool ID
        bytes32 _balancerPoolID, // Balancer: Target Pool ID
        address _depositToken, // Balancer: Underlying Token for Deposit Pool
        uint256 _depositArrayPosition, // Balancer: Index of the Deposit Token in the Pool Assets Parameter
        address _balancerDepositPool, // Balancer: Address to Deposit for Balancer Pool Token(BPT)
        address[] memory _poolAssets,
        uint256 _hodlRatio // Harvest: Profit Sharing Default Hold Ratio(1000, 10%) 
    ) public initializer {
        bytes32 balancerDex = bytes32(0x9e73ce1e99df7d45bc513893badf42bc38069f1564ee511b0c8988f72f127b13);
        address bal = address(0xba100000625a3754423978a60c9317c58a424e3D);
        address aura = address(0xC0c293ce456fF0ED870ADd98a0828Dd4d2903DBF);

        AuraStrategyUL.initializeBaseStrategy(
            _storage,
            _underlyingToken,
            _vault,
            _rewardPool,
            _auraPoolID,
            _balancerPoolID,
            _depositToken,
            _depositArrayPosition,
            _balancerDepositPool,
            _poolAssets,
            _hodlRatio
        );

        rewardTokens = [bal, aura];

        storedLiquidationPaths[bal][weth] = [bal, weth];
        storedLiquidationDexes[bal][weth] = [balancerDex];
        storedLiquidationPaths[aura][weth] = [aura, weth];
        storedLiquidationDexes[aura][weth] = [balancerDex];
    }
}
