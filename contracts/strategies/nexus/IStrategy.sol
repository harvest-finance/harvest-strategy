// SPDX-License-Identifier: MIT
// solhint-disable

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";

import "../../base/interface/IController.sol";

pragma solidity ^0.5.0;

contract Initializable {
    /**
     * @dev Indicates that the contract has been initialized.
     */
    bool private initialized;

    /**
     * @dev Indicates that the contract is in the process of being initialized.
     */
    bool private initializing;

    /**
     * @dev Modifier to use in the initializer function of a contract.
     */
    modifier initializer() {
        // TODO: fix isConstructor
        // require(initializing || isConstructor() || !initialized, "Contract instance has already been initialized");
        require(
            initializing || !initialized,
            "Contract instance has already been initialized"
        );

        bool isTopLevelCall = !initializing;
        if (isTopLevelCall) {
            initializing = true;
            initialized = true;
        }

        _;

        if (isTopLevelCall) {
            initializing = false;
        }
    }

    // /// @dev Returns true if and only if the function is running in the constructor
    // function isConstructor() private view returns (bool) {
    //     // extcodesize checks the size of the code stored in an address, and
    //     // address returns the current address. Since the code is still not
    //     // deployed when running a constructor, any checks on its code size will
    //     // yield zero, making it an effective way to detect if a contract is
    //     // under construction or not.
    //     uint256 cs;
    //     assembly {
    //         cs := extcodesize(address)
    //     }
    //     return cs == 0;
    // }

    // Reserved storage space to allow for layout changes in the future.
    uint256[50] private ______gap;
}

contract ERC20Detailed is IERC20 {
    string private _name;
    string private _symbol;
    uint8 private _decimals;

    /**
     * @dev Sets the values for `name`, `symbol`, and `decimals`. All three of
     * these values are immutable: they can only be set once during
     * construction.
     */
    constructor(
        string memory name,
        string memory symbol,
        uint8 decimals
    ) public {
        _name = name;
        _symbol = symbol;
        _decimals = decimals;
    }

    /**
     * @dev Returns the name of the token.
     */
    function name() public view returns (string memory) {
        return _name;
    }

    /**
     * @dev Returns the symbol of the token, usually a shorter version of the
     * name.
     */
    function symbol() public view returns (string memory) {
        return _symbol;
    }

    /**
     * @dev Returns the number of decimals used to get its user representation.
     * For example, if `decimals` equals `2`, a balance of `505` tokens should
     * be displayed to a user as `5,05` (`505 / 10 ** 2`).
     *
     * Tokens usually opt for a value of 18, imitating the relationship between
     * Ether and Wei.
     *
     * NOTE: This information is only used for _display_ purposes: it in
     * no way affects any of the arithmetic of the contract, including
     * {IERC20-balanceOf} and {IERC20-transfer}.
     */
    function decimals() public view returns (uint8) {
        return _decimals;
    }
}

interface IStrategy {
    function unsalvagableTokens(address tokens) external view returns (bool);

    function governance() external view returns (address);

    function controller() external view returns (address);

    function underlying() external view returns (address);

    function vault() external view returns (address);

    function withdrawAllToVault() external;

    function withdrawToVault(uint256 amount) external;

    function investedUnderlyingBalance() external view returns (uint256); // itsNotMuch()

    // should only be called by controller
    function salvage(
        address recipient,
        address token,
        uint256 amount
    ) external;

    function doHardWork() external;

    function depositArbCheck() external view returns (bool);
}

contract BaseUpgradeableStrategyStorage {
    bytes32 internal constant _UNDERLYING_SLOT =
        0xa1709211eeccf8f4ad5b6700d52a1a9525b5f5ae1e9e5f9e5a0c2fc23c86e530;
    bytes32 internal constant _VAULT_SLOT =
        0xefd7c7d9ef1040fc87e7ad11fe15f86e1d11e1df03c6d7c87f7e1f4041f08d41;

    bytes32 internal constant _REWARD_TOKEN_SLOT =
        0xdae0aafd977983cb1e78d8f638900ff361dc3c48c43118ca1dd77d1af3f47bbf;
    bytes32 internal constant _REWARD_POOL_SLOT =
        0x3d9bb16e77837e25cada0cf894835418b38e8e18fbec6cfd192eb344bebfa6b8;
    bytes32 internal constant _SELL_FLOOR_SLOT =
        0xc403216a7704d160f6a3b5c3b149a1226a6080f0a5dd27b27d9ba9c022fa0afc;
    bytes32 internal constant _SELL_SLOT =
        0x656de32df98753b07482576beb0d00a6b949ebf84c066c765f54f26725221bb6;
    bytes32 internal constant _PAUSED_INVESTING_SLOT =
        0xa07a20a2d463a602c2b891eb35f244624d9068572811f63d0e094072fb54591a;

    bytes32 internal constant _PROFIT_SHARING_NUMERATOR_SLOT =
        0xe3ee74fb7893020b457d8071ed1ef76ace2bf4903abd7b24d3ce312e9c72c029;
    bytes32 internal constant _PROFIT_SHARING_DENOMINATOR_SLOT =
        0x0286fd414602b432a8c80a0125e9a25de9bba96da9d5068c832ff73f09208a3b;

    bytes32 internal constant _NEXT_IMPLEMENTATION_SLOT =
        0x29f7fcd4fe2517c1963807a1ec27b0e45e67c60a874d5eeac7a0b1ab1bb84447;
    bytes32 internal constant _NEXT_IMPLEMENTATION_TIMESTAMP_SLOT =
        0x414c5263b05428f1be1bfa98e25407cc78dd031d0d3cd2a2e3d63b488804f22e;
    bytes32 internal constant _NEXT_IMPLEMENTATION_DELAY_SLOT =
        0x82b330ca72bcd6db11a26f10ce47ebcfe574a9c646bccbc6f1cd4478eae16b31;

    constructor() public {
        assert(
            _UNDERLYING_SLOT ==
                bytes32(
                    uint256(keccak256("eip1967.strategyStorage.underlying")) - 1
                )
        );
        assert(
            _VAULT_SLOT ==
                bytes32(uint256(keccak256("eip1967.strategyStorage.vault")) - 1)
        );
        assert(
            _REWARD_TOKEN_SLOT ==
                bytes32(
                    uint256(keccak256("eip1967.strategyStorage.rewardToken")) -
                        1
                )
        );
        assert(
            _REWARD_POOL_SLOT ==
                bytes32(
                    uint256(keccak256("eip1967.strategyStorage.rewardPool")) - 1
                )
        );
        assert(
            _SELL_FLOOR_SLOT ==
                bytes32(
                    uint256(keccak256("eip1967.strategyStorage.sellFloor")) - 1
                )
        );
        assert(
            _SELL_SLOT ==
                bytes32(uint256(keccak256("eip1967.strategyStorage.sell")) - 1)
        );
        assert(
            _PAUSED_INVESTING_SLOT ==
                bytes32(
                    uint256(
                        keccak256("eip1967.strategyStorage.pausedInvesting")
                    ) - 1
                )
        );

        assert(
            _PROFIT_SHARING_NUMERATOR_SLOT ==
                bytes32(
                    uint256(
                        keccak256(
                            "eip1967.strategyStorage.profitSharingNumerator"
                        )
                    ) - 1
                )
        );
        assert(
            _PROFIT_SHARING_DENOMINATOR_SLOT ==
                bytes32(
                    uint256(
                        keccak256(
                            "eip1967.strategyStorage.profitSharingDenominator"
                        )
                    ) - 1
                )
        );

        assert(
            _NEXT_IMPLEMENTATION_SLOT ==
                bytes32(
                    uint256(
                        keccak256("eip1967.strategyStorage.nextImplementation")
                    ) - 1
                )
        );
        assert(
            _NEXT_IMPLEMENTATION_TIMESTAMP_SLOT ==
                bytes32(
                    uint256(
                        keccak256(
                            "eip1967.strategyStorage.nextImplementationTimestamp"
                        )
                    ) - 1
                )
        );
        assert(
            _NEXT_IMPLEMENTATION_DELAY_SLOT ==
                bytes32(
                    uint256(
                        keccak256(
                            "eip1967.strategyStorage.nextImplementationDelay"
                        )
                    ) - 1
                )
        );
    }

    function _setUnderlying(address _address) internal {
        setAddress(_UNDERLYING_SLOT, _address);
    }

    function underlying() public view returns (address) {
        return getAddress(_UNDERLYING_SLOT);
    }

    function _setRewardPool(address _address) internal {
        setAddress(_REWARD_POOL_SLOT, _address);
    }

    function rewardPool() public view returns (address) {
        return getAddress(_REWARD_POOL_SLOT);
    }

    function _setRewardToken(address _address) internal {
        setAddress(_REWARD_TOKEN_SLOT, _address);
    }

    function rewardToken() public view returns (address) {
        return getAddress(_REWARD_TOKEN_SLOT);
    }

    function _setVault(address _address) internal {
        setAddress(_VAULT_SLOT, _address);
    }

    function vault() public view returns (address) {
        return getAddress(_VAULT_SLOT);
    }

    // a flag for disabling selling for simplified emergency exit
    function _setSell(bool _value) internal {
        setBoolean(_SELL_SLOT, _value);
    }

    function sell() public view returns (bool) {
        return getBoolean(_SELL_SLOT);
    }

    function _setPausedInvesting(bool _value) internal {
        setBoolean(_PAUSED_INVESTING_SLOT, _value);
    }

    function pausedInvesting() public view returns (bool) {
        return getBoolean(_PAUSED_INVESTING_SLOT);
    }

    function _setSellFloor(uint256 _value) internal {
        setUint256(_SELL_FLOOR_SLOT, _value);
    }

    function sellFloor() public view returns (uint256) {
        return getUint256(_SELL_FLOOR_SLOT);
    }

    function _setProfitSharingNumerator(uint256 _value) internal {
        setUint256(_PROFIT_SHARING_NUMERATOR_SLOT, _value);
    }

    function profitSharingNumerator() public view returns (uint256) {
        return getUint256(_PROFIT_SHARING_NUMERATOR_SLOT);
    }

    function _setProfitSharingDenominator(uint256 _value) internal {
        setUint256(_PROFIT_SHARING_DENOMINATOR_SLOT, _value);
    }

    function profitSharingDenominator() public view returns (uint256) {
        return getUint256(_PROFIT_SHARING_DENOMINATOR_SLOT);
    }

    // upgradeability

    function _setNextImplementation(address _address) internal {
        setAddress(_NEXT_IMPLEMENTATION_SLOT, _address);
    }

    function nextImplementation() public view returns (address) {
        return getAddress(_NEXT_IMPLEMENTATION_SLOT);
    }

    function _setNextImplementationTimestamp(uint256 _value) internal {
        setUint256(_NEXT_IMPLEMENTATION_TIMESTAMP_SLOT, _value);
    }

    function nextImplementationTimestamp() public view returns (uint256) {
        return getUint256(_NEXT_IMPLEMENTATION_TIMESTAMP_SLOT);
    }

    function _setNextImplementationDelay(uint256 _value) internal {
        setUint256(_NEXT_IMPLEMENTATION_DELAY_SLOT, _value);
    }

    function nextImplementationDelay() public view returns (uint256) {
        return getUint256(_NEXT_IMPLEMENTATION_DELAY_SLOT);
    }

    function setBoolean(bytes32 slot, bool _value) internal {
        setUint256(slot, _value ? 1 : 0);
    }

    function getBoolean(bytes32 slot) internal view returns (bool) {
        return (getUint256(slot) == 1);
    }

    function setAddress(bytes32 slot, address _address) internal {
        // solhint-disable-next-line no-inline-assembly
        assembly {
            sstore(slot, _address)
        }
    }

    function setUint256(bytes32 slot, uint256 _value) internal {
        // solhint-disable-next-line no-inline-assembly
        assembly {
            sstore(slot, _value)
        }
    }

    function getAddress(bytes32 slot) internal view returns (address str) {
        // solhint-disable-next-line no-inline-assembly
        assembly {
            str := sload(slot)
        }
    }

    function getUint256(bytes32 slot) internal view returns (uint256 str) {
        // solhint-disable-next-line no-inline-assembly
        assembly {
            str := sload(slot)
        }
    }
}

contract Storage {
    address public governance;
    address public controller;

    constructor() public {
        governance = msg.sender;
    }

    modifier onlyGovernance() {
        require(isGovernance(msg.sender), "Not governance");
        _;
    }

    function setGovernance(address _governance) public onlyGovernance {
        require(_governance != address(0), "new governance shouldn't be empty");
        governance = _governance;
    }

    function setController(address _controller) public onlyGovernance {
        require(_controller != address(0), "new controller shouldn't be empty");
        controller = _controller;
    }

    function isGovernance(address account) public view returns (bool) {
        return account == governance;
    }

    function isController(address account) public view returns (bool) {
        return account == controller;
    }
}

contract Governable {
    Storage public store;

    constructor(address _store) public {
        require(_store != address(0), "new storage shouldn't be empty");
        store = Storage(_store);
    }

    modifier onlyGovernance() {
        require(store.isGovernance(msg.sender), "Not governance");
        _;
    }

    function setStorage(address _store) public onlyGovernance {
        require(_store != address(0), "new storage shouldn't be empty");
        store = Storage(_store);
    }

    function governance() public view returns (address) {
        return store.governance();
    }
}

contract GovernableInit is Initializable {
    bytes32 internal constant _STORAGE_SLOT =
        0xa7ec62784904ff31cbcc32d09932a58e7f1e4476e1d041995b37c917990b16dc;

    modifier onlyGovernance() {
        require(Storage(_storage()).isGovernance(msg.sender), "Not governance");
        _;
    }

    constructor() public {
        assert(
            _STORAGE_SLOT ==
                bytes32(
                    uint256(keccak256("eip1967.governableInit.storage")) - 1
                )
        );
    }

    function initialize(address _store) public initializer {
        _setStorage(_store);
    }

    function _setStorage(address newStorage) private {
        bytes32 slot = _STORAGE_SLOT;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            sstore(slot, newStorage)
        }
    }

    function setStorage(address _store) public onlyGovernance {
        require(_store != address(0), "new storage shouldn't be empty");
        _setStorage(_store);
    }

    function _storage() internal view returns (address str) {
        bytes32 slot = _STORAGE_SLOT;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            str := sload(slot)
        }
    }

    function governance() public view returns (address) {
        return Storage(_storage()).governance();
    }
}

contract Controllable is Governable {
    constructor(address _storage) public Governable(_storage) {}

    modifier onlyController() {
        require(store.isController(msg.sender), "Not a controller");
        _;
    }

    modifier onlyControllerOrGovernance() {
        require(
            (store.isController(msg.sender) || store.isGovernance(msg.sender)),
            "The caller must be controller or governance"
        );
        _;
    }

    function controller() public view returns (address) {
        return store.controller();
    }
}

contract ControllableInit is GovernableInit {
    constructor() public {}

    function initialize(address _storage) public initializer {
        GovernableInit.initialize(_storage);
    }

    modifier onlyController() {
        require(
            Storage(_storage()).isController(msg.sender),
            "Not a controller"
        );
        _;
    }

    modifier onlyControllerOrGovernance() {
        require(
            (Storage(_storage()).isController(msg.sender) ||
                Storage(_storage()).isGovernance(msg.sender)),
            "The caller must be controller or governance"
        );
        _;
    }

    function controller() public view returns (address) {
        return Storage(_storage()).controller();
    }
}

contract BaseUpgradeableStrategy is
    Initializable,
    ControllableInit,
    BaseUpgradeableStrategyStorage
{
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    event ProfitsNotCollected(bool sell, bool floor);
    event ProfitLogInReward(
        uint256 profitAmount,
        uint256 feeAmount,
        uint256 timestamp
    );

    modifier restricted() {
        require(
            msg.sender == vault() ||
                msg.sender == controller() ||
                msg.sender == governance(),
            "The sender has to be the controller, governance, or vault"
        );
        _;
    }

    // This is only used in `investAllUnderlying()`
    // The user can still freely withdraw from the strategy
    modifier onlyNotPausedInvesting() {
        require(
            !pausedInvesting(),
            "Action blocked as the strategy is in emergency state"
        );
        _;
    }

    constructor() public BaseUpgradeableStrategyStorage() {}

    function initialize(
        address _storage,
        address _underlying,
        address _vault,
        address _rewardPool,
        address _rewardToken,
        uint256 _profitSharingNumerator,
        uint256 _profitSharingDenominator,
        bool _sell,
        uint256 _sellFloor,
        uint256 _implementationChangeDelay
    ) public initializer {
        ControllableInit.initialize(_storage);
        _setUnderlying(_underlying);
        _setVault(_vault);
        _setRewardPool(_rewardPool);
        _setRewardToken(_rewardToken);
        _setProfitSharingNumerator(_profitSharingNumerator);
        _setProfitSharingDenominator(_profitSharingDenominator);

        _setSell(_sell);
        _setSellFloor(_sellFloor);
        _setNextImplementationDelay(_implementationChangeDelay);
        _setPausedInvesting(false);
    }

    /**
     * Schedules an upgrade for this vault's proxy.
     */
    function scheduleUpgrade(address impl) public onlyGovernance {
        _setNextImplementation(impl);
        _setNextImplementationTimestamp(
            block.timestamp.add(nextImplementationDelay())
        );
    }

    function _finalizeUpgrade() internal {
        _setNextImplementation(address(0));
        _setNextImplementationTimestamp(0);
    }

    function shouldUpgrade() external view returns (bool, address) {
        return (
            nextImplementationTimestamp() != 0 &&
                block.timestamp > nextImplementationTimestamp() &&
                nextImplementation() != address(0),
            nextImplementation()
        );
    }

    // reward notification

    function notifyProfitInRewardToken(uint256 _rewardBalance) internal {
        if (_rewardBalance > 0) {
            uint256 feeAmount =
                _rewardBalance.mul(profitSharingNumerator()).div(
                    profitSharingDenominator()
                );
            emit ProfitLogInReward(_rewardBalance, feeAmount, block.timestamp);
            IERC20(rewardToken()).safeApprove(controller(), 0);
            IERC20(rewardToken()).safeApprove(controller(), feeAmount);

            IController(controller()).notifyFee(rewardToken(), feeAmount);
        } else {
            emit ProfitLogInReward(0, 0, block.timestamp);
        }
    }
}

interface IMasterChef {
    function deposit(uint256 _pid, uint256 _amount) external;

    function withdraw(uint256 _pid, uint256 _amount) external;

    function userInfo(uint256 _pid, address _user)
        external
        view
        returns (uint256 amount, uint256 rewardDebt);

    function poolInfo(uint256 _pid)
        external
        view
        returns (
            address lpToken,
            uint256,
            uint256,
            uint256
        );

    function massUpdatePools() external;

    function pendingSushi(uint256 _pid, address _user)
        external
        view
        returns (uint256 amount);

    // interface reused for pickle
    function pendingPickle(uint256 _pid, address _user)
        external
        view
        returns (uint256 amount);
}
