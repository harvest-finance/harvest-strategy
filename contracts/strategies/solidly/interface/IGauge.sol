// SPDX-License-Identifier: Unlicense
pragma solidity 0.5.16;

interface IGauge {
    function depositAll(uint tokenId) external;
    function deposit(uint amount, uint tokenId) external;
    function withdrawAll() external;
    function withdraw(uint amount) external;
    function getReward(address account, address[] calldata tokens) external;
    function balanceOf(address account) external view returns (uint);
}