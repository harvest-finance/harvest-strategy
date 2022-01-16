pragma solidity 0.5.16;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IMasterChefV2 {
    function deposit(
        uint256 _pid,
        uint256 _amount,
        address _to
    ) external;

    function withdraw(
        uint256 _pid,
        uint256 _amount,
        address _to
    ) external;

    function withdrawAndHarvest(
        uint256 _pid,
        uint256 _amount,
        address _to
    ) external;

    function harvest(uint256 _pid, address _to) external;

    function emergencyWithdraw(uint256 _pid, address _to) external;

    function userInfo(uint256 _pid, address _user)
        external
        view
        returns (uint256 amount, uint256 rewardDebt);

    function poolInfo(uint256 _pid)
        external
        view
        returns (
            uint128 accSushiPerShare,
            uint64 lastRewardBlock,
            uint64 allocPoint
        );

    function lpToken(uint256 _pid) external view returns (IERC20);

    function rewarder(uint256 _pid) external view returns (address);
}
