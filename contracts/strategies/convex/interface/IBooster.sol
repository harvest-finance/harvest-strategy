pragma solidity 0.5.16;

interface IBooster {
    function deposit(uint256 _pid, uint256 _amount, bool _stake) external;
    function depositAll(uint256 _pid, bool _stake) external;
    function withdraw(uint256 _pid, uint256 _amount) external;
    function withdrawAll(uint256 _pid) external;
    function poolInfo(uint256 _pid) external view returns (address lpToken, address, address, address, address, bool);
    function earmarkRewards(uint256 _pid) external;
}
