//SPDX-License-Identifier: Unlicense
pragma solidity 0.5.16;
pragma experimental ABIEncoderV2;

import "hardhat/console.sol";
import "./base/AuraStrategyAuraBAL.sol";

contract AuraStrategyMainnet_auraBAL is AuraStrategyAuraBAL {

    //Differentiator for the bytecode
    address public auraBAL_unused;

    constructor() public {}

    function initializeStrategy(
        address _storage, // Harvest: Storage
        address _vault // Harvest: Vault
    ) public initializer {
        address underlying = address(0x616e8BfA43F920657B3497DBf40D6b1A02D4608d); // Aura: auraBAL
        address depositToken = address(0x5c6Ee304399DBdB9C8Ef030aB642B10820DB8F56); // Balancer: B-80BAL-20WETH
        address rewardPool = address(0x5e5ea2048475854a5702F5B8468A51Ba1296EFcC); // Aura: auraBAL Rewards
        address auraDeposit = address(0xeAd792B55340Aa20181A80d6a16db6A0ECd1b827); // Aura: auraBALBpt Depositor 
        bytes32 balancerDex = bytes32(0x9e73ce1e99df7d45bc513893badf42bc38069f1564ee511b0c8988f72f127b13);
        address bal = address(0xba100000625a3754423978a60c9317c58a424e3D);
        address aura = address(0xC0c293ce456fF0ED870ADd98a0828Dd4d2903DBF);
        address usdc = address(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
        address bbaUSDC = address(0x82698aeCc9E28e9Bb27608Bd52cF57f704BD1B83);
        address bbaUSD = address(0xA13a9247ea42D743238089903570127DdA72fE44);

        poolAssets = [bal, weth];
        // bb-a-USD -> bb-a-USDC -> USDC -> WETH
        swapAssets = [bbaUSD, bbaUSDC, usdc, weth];

        rewardTokens = [bal, aura, bbaUSD];
        storedLiquidationPaths[bal][weth] = [bal, weth];
        storedLiquidationDexes[bal][weth] = [balancerDex];
        storedLiquidationPaths[aura][weth] = [aura, weth];
        storedLiquidationDexes[aura][weth] = [balancerDex];

        AuraStrategyAuraBAL.initializeBaseStrategy(
            _storage,
            underlying,
            _vault,
            rewardPool,
            auraDeposit,
            0x5c6ee304399dbdb9c8ef030ab642b10820db8f56000200000000000000000014, // Balancer: PoolId
            depositToken, //Balancer: Deposit Token
            1, // Balancer: Deposit Array Position
            1000
        );

        bytes32 bbaUSD_bbaUSDC = bytes32(0xa13a9247ea42d743238089903570127dda72fe4400000000000000000000035d);
        bytes32 bbaUSDC_USDC = bytes32(0x82698aecc9e28e9bb27608bd52cf57f704bd1b83000000000000000000000336);
        bytes32 USDC_wETH = bytes32(0x96646936b91d6b9d7d0c47c496afbf3d6ec7b6f8000200000000000000000019);
        swapPoolIds = [bbaUSD_bbaUSDC, bbaUSDC_USDC, USDC_wETH];
    }
}
