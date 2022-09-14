pragma solidity 0.5.16;

contract IIdleCDO {
    function depositAA(uint256 _amount) external returns (uint256);
    function depositBB(uint256 _amount) external returns (uint256);
    function withdrawAA(uint256 _amount ) external returns (uint256);
    function withdrawBB(uint256 _amount) external returns (uint256);
    function token() external view returns (address);
    function strategyToken() external view returns (address);
    function AATranche() external view returns (address);
    function BBTranche() external view returns (address); 
    function tranchePrice(address tranche) external view returns (uint256);
}