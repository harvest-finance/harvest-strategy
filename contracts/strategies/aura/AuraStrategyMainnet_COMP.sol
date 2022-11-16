//SPDX-License-Identifier: Unlicense
pragma solidity 0.5.16;
pragma experimental ABIEncoderV2;

import "./base/AuraStrategyJoinPoolUL.sol";

contract AuraStrategyMainnet_COMP is AuraStrategyJoinPoolUL {

    //Differentiator for the bytecode
    address public COMP50_WETH50_unused;

    constructor() public {}

    function initializeStrategy(
        address _storage, // Harvest: Storage
        address _vault // Harvest: Vault
    ) public initializer {
        address underlying = address(0xEFAa1604e82e1B3AF8430b90192c1B9e8197e377); // Balancer: Balancer 50 COMP 50 WETH
        address rewardPool = address(0x724C6D29f23F6Bd671B0d9305AAB6e7d9d8b8bE0); // Aura: Balancer 50 COMP 50 WETH Aura Deposit Vault
        address comp = address(0xc00e94Cb662C3520282E6f5717214004A7f26888);

        poolAssets = [comp, weth];
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
            32, // Aura: PoolId
            0xefaa1604e82e1b3af8430b90192c1b9e8197e377000200000000000000000021, // Balancer: PoolId
            weth, //Balancer: Deposit Token
            1, // Balancer: Deposit Array Position
            1000
        );
    }
}
