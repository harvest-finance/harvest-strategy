pragma solidity 0.5.16;
pragma experimental ABIEncoderV2;

import "./NotionalStrategy.sol";

contract NotionalStrategy_ETH is NotionalStrategy {
    constructor() public {}

    function initializeStrategy(address _storage, address _vault)
        public
        initializer
    {
        address proxy = address(0x1344A36A1B56144C3Bc62E7757377D288fDE0369);

        NotionalStrategy.initializeBaseStrategy(
            _storage,
            address(0xabc07BF91469C5450D6941dD0770E6E6761B90d6), // nETH
            _vault,
            proxy, // notional proxy
            address(0xBA12222222228d8Ba445958a75a0704d566BF2C8), //balancer vault
            0x5122e01d819e58bb2e22528c0d68d310f0aa6fd7000200000000000000000163, // note2wethpid
            1 // currencyId
        );
    }
}
