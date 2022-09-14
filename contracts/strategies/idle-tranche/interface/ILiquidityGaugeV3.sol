pragma solidity 0.5.16;

contract ILiquidityGaugeV3 {
    function deposit(uint256 _value) external;
    function deposit(uint256 _value, address _addr) external;
    function deposit(uint256 _value, address _addr, bool _claim_rewards) external;
    function withdraw(uint256 _value) external;
    function withdraw(uint256 _value, bool _claim_rewards) external;
    function claim_rewards() external;
    function approve(address _spender, uint256 _value) external;
    function balanceOf(address _addr) external view returns (uint256);
}