pragma solidity 0.5.16;

interface IBASPool {
    /* ================= CALLS ================= */

    function tokenOf(uint256 _pid) external view returns (address);

    function poolIdsOf(address _token) external view returns (uint256[] memory);

    function totalSupply(uint256 _pid) external view returns (uint256);

    function balanceOf(uint256 _pid, address _owner)
        external
        view
        returns (uint256);

    function rewardRatePerPool(uint256 _pid) external view returns (uint256);

    function rewardPerToken(uint256 _pid) external view returns (uint256);

    function rewardEarned(uint256 _pid, address _target)
        external
        view
        returns (uint256);

    /* ================= TXNS ================= */

    function update(uint256 _pid) external;

    function deposit(uint256 _pid, uint256 _amount) external;

    function withdraw(uint256 _pid, uint256 _amount) external;

    function claimReward(uint256 _pid) external;

    function exit(uint256 _pid) external;
}
