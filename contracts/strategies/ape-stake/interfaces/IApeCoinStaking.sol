pragma solidity 0.5.16;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IApeCoinStaking {
    struct Position {
        uint256 stakedAmount;
        int256 rewardsDebt;
    }

    function depositApeCoin(uint256 _amount, address _recipient) external;

    function depositSelfApeCoin(uint256 _amount) external;

    function claimApeCoin(address _recipient) external;

    function claimSelfApeCoin() external;

    function withdrawApeCoin(uint256 _amount, address _recipient) external;

    function withdrawSelfApeCoin(uint256 _amount) external;

    function addressPosition(address _address) external view returns (Position memory);
}
