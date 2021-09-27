pragma solidity 0.5.16;

import "./AlkemiStrategy.sol";

contract AlkemiStrategyMainnet_WETH is AlkemiStrategy {

  address public weth_unused; // just a differentiator for the bytecode

  constructor() public {}

  function initializeStrategy(
    address _storage,
    address _vault
  ) public initializer {
    address underlying = address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    address rewardPool = address(0x14716C982Fd8b7F1E8F0b4dbb496dCe438a29D93);
    address supplyContract = address(0x4822D9172e5b76b9Db37B75f5552F9988F98a888);
    address alkemiToken = address(0x8125afd067094cD573255f82795339b9fe2A40ab);
    address alk = address(0x6C16119B20fa52600230F074b349dA3cb861a7e3);
    bytes32 uniV3Dex = bytes32(0x8f78a54cb77f4634a5bf3dd452ed6a2e33432c73821be59208661199511cd94f);
    AlkemiStrategy.initializeBaseStrategy(
      _storage,
      underlying,
      _vault,
      rewardPool,
      alk,
      alkemiToken,
      supplyContract,
      10000 //100%
    );
    storedLiquidationPaths[alk][underlying] = [alk, underlying];
    storedLiquidationDexes[alk][underlying] = [uniV3Dex];
  }
}
