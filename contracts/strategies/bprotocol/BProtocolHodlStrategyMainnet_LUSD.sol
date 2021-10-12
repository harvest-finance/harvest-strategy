pragma solidity 0.5.16;

import "./BProtocolHodlStrategy.sol";

contract BProtocolHodlStrategyMainnet_LUSD is BProtocolHodlStrategy {

  address public bprotocol_lusd_unused; // just a differentiator for the bytecode

  constructor() public {}

  function initializeStrategy(
    address _storage,
    address _vault
  ) public initializer {
    address underlying_lusd = address(0x5f98805A4E8be255a32880FDeC7F6728C6568bA0); // underlying is lusd single asset staking
    address lqty = address(0x6DEA81C8171D0bA574754EF6F8b412F2Ed88c54D); // reward token is lqty. LUSD is auto compounded
    address hodlVaultLqty = address(0xCf16b17A215D1728b0a36a30A57BeAaf7845F334); // hodl vault for fLQTY
    address rewardPool = address(0x0d3AbAA7E088C2c82f54B2f47613DA438ea8C598); // reward pool -> B.AMM V2

    /**
     * bProtocol should only be rewarding LQTY and LUSD in theory, but their code contains a payout for ETH too
     * in theory, there should not be any ETH there to pay out, but since they include that fail-safe we include one too
     * Thus we liquidate ETH to LQTY before hodling LQTY
     */
    address weth = address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    bytes32 uniV3Dex = bytes32(0x8f78a54cb77f4634a5bf3dd452ed6a2e33432c73821be59208661199511cd94f);

    BProtocolHodlStrategy.initializeBProtocolHodlStrategy(
      _storage,
      underlying_lusd,
      _vault,
      rewardPool, // reward pool
      lqty, // reward token
      hodlVaultLqty, // hodl vault for fLQTY
      address(0) // distribution pool / pot pool -> must be set later manually
    );

    storedLiquidationPaths[weth][lqty] = [weth, lqty];
    storedLiquidationDexes[weth][lqty] = [uniV3Dex];
  }

}
