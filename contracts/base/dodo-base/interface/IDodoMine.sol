pragma solidity 0.5.16;

interface IDodoMine {
    function claim(address _lpToken) external;

    function deposit(address _lpToken, uint256 _amount) external;

    function withdraw(address _lpToken, uint256 _amount) external;

    function emergencyWithdraw(address _lpToken) external;

    function massUpdatePools() external;

    function getPid(address _lpToken) external view returns (uint256);

    function userInfo(uint256 _pid, address _user)
        external
        view
        returns (uint256 amount, uint256 rewardDebt);
}
