pragma solidity 0.5.16;
pragma experimental ABIEncoderV2;

import "./NotionalStrategy.sol";

contract NotionalStrategyMainnet_ETH is NotionalStrategy {
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
            1 // currencyId
        );
    }
}
