pragma solidity 0.5.16;

contract IMooniswap {
    function token0() external view returns (address);
    function token1() external view returns (address);

    function getTokens() external view returns(address[] memory tokens);
    function tokens(uint256 i) external view returns(address);
    function deposit(uint256[2] calldata maxAmounts, uint256[2] calldata minAmounts) external payable returns(uint256 fairSupply, uint256[2] memory receivedAmounts);
    function swap(address src, address dst, uint256 amount, uint256 minReturn, address referral) external payable returns(uint256 result);
    function withdraw(uint256 amount, uint256[] memory minReturns) public returns(uint256[2] memory withdrawnAmounts);
}
