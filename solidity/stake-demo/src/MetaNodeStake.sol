// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
// 质押合约升级合约
contract MetaNodeStake is
    Initializable,
    UUPSUpgradeable,
    PausableUpgradeable,
    AccessControlUpgradeable
{
    using SafeERC20 for IERC20;
    using Address for address;
    using Math for uint256;

    // ************************************** INVARIANT ************************
    bytes32 public constant ADMIN_ROLE = keccak256("admin_role");
    bytes32 public constant UPGRADE_ROLE = keccak256("upgrade_role");
    uint256 public constant ETH_PID = 0;

    // ************************************** DATA  ************************
    struct Pool {
        // 质押代币的地址
        address stTokenAddress;
        // 不同资金池所占的权重
        uint256 poolWeight;
        // 最后一次发放奖励的区块
        uint256 lastRewardBlock;
        // 质押 1个ETH 经过 1个区块高度,能拿到 n 个 MetaNode
        uint256 accMetaNodePerST;
        // 质押的代币的数量
        uint256 stTokenAmount;
        // 最小质押的代币数量
        uint256 minDepositAmount;
        // 解质押锁定的区块高度
        uint256 unstakeLockedBlocks;
    }
    struct UnstakeRequest {
        // 用户取消质押的代币数量,要去出多少个token
        uint256 amount;
        // 解质押的区块高度
        uint256 unlockBlocks;
    }
    // 记录用户相对每个资金池的质押记录
    struct User {
        // 用户在当前自己池,质押的代币数量
        uint256 stAmount;
        //  用户在当前资金池,已领取的 MetaNode 数量
        uint256 finishedMetaNode;
        // 用户在当前资金池,未领取的 MetaNode 数量
        uint256 pendingMetaNode;
        // 用户在当前自己池.取消质押的记录
        UnstakeRequest[] requests;
    }
    // ****************** STATE VARIABLES ***********************
    // 质押开始的区块高度
    uint256 public startBlock;

    // 质押结束的区块高度
    uint256 public endBlock;

    // 每个区块高度 MetaNode 奖励数量
    uint256 public MetaNodePerBlock;
    // 是否暂停提现
    bool public withdrawPaused;
    // 是否暂定领取
    bool public claimPaused;
    // MetaNode 的代币地址
    IERC20 public MetaNode;
    //所有资金池 的权重综合
    uint256 public totalPoolWeight;
    // 资金池列表
    Pool[] public pools;

    // 资金池ID => 用户地址=>用户信息
    mapping(uint256 => mapping(address => User)) public user;
    //******************* EVENTS *******************
    event SetMetaNode(IERC20 indexed MetaNode);

    event PauseEithdraw();

    event UnpausedWithdraw();

    event PauseClaim();

    event UnpausedClaim();

    event SetStartBlock(uint256 indexed startBlock);

    event SetEndBlock(uint256 indexed endBlock);

    event SetMetaNodePerBlock(uint256 indexed MetaNodePerBlock);

    event AddPool(
        address indexed stTokenAddress,
        uint256 indexed poolWeight,
        uint256 indexed lastRewardBlock,
        uint256 minDepositAmount,
        uint256 unstakeLockedBlocks
    );
    event UpdatePoolInfo(
        uint256 indexed poolId,
        uint256 indexed minDepositAmount,
        uint256 indexed unstakeLockedBlocks
    );

    event SetPoolWeight(
        uint256 indexed poolId,
        uint256 indexed poolWeight,
        uint256 totalPoolWeight
    );
    event UpdatePool(
        uint256 indexed poolId,
        uint256 indexed lastRewardBlock,
        uint256 totalMetaNode
    );

    event Deposit(address indexed user, uint256 indexed poolId, uint256 amount);

    event RequestUnstake(
        address indexed user,
        uint256 indexed poolId,
        uint256 amount
    );

    event WithDraw(
        address indexed user,
        int256 indexed poolId,
        uint256 amount,
        uint256 indexed blockNumber
    );
    event Claim(
        address indexed user,
        uint256 indexed poolId,
        uint256 MetaNodeReward
    );
    //******************************** MODIFIED FUNCTIONS ************************
    modifier checkPid(uint256 _pid) {
        require(_pid < pools.length, "invalid pool id");
        _;
    }
    modifier whenNotClaimPaused() {
        require(!claimPaused, "claim paused");
        _;
    }
    modifier whenNotWithdrawPaused() {
        require(!withdrawPaused, "withdraw paused");
        _;
    }
    function innitialize(
        IERC20 _MetaNode,
        uint256 _startBlock,
        uint256 _endBlock,
        uint256 _MetaNodePerBlock
    ) public initializer {
        require(
            _startBlock < _endBlock && _MetaNodePerBlock > 0,
            "invalid params"
        );
        __AccessControl_init();

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(UPGRADE_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
        setMetaNode(_MetaNode);
        startBlock = _startBlock;
        endBlock = _endBlock;
        MetaNodePerBlock = _MetaNodePerBlock;
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyRole(UPGRADE_ROLE) {}

    function setMetaNode(IERC20 _MetaNode) public onlyRole(ADMIN_ROLE) {
        MetaNode = _MetaNode;
        emit SetMetaNode(MetaNode);
    }
    function pauseWithdraw() public onlyRole(ADMIN_ROLE) {
        require(!withdrawPaused, "withdraw paused");
        withdrawPaused = true;
        emit PauseEithdraw();
    }

    function unpauseWithdraw() public onlyRole(ADMIN_ROLE) {
        require(withdrawPaused, "withdraw not paused");
        withdrawPaused = false;
        emit UnpausedWithdraw();
    }

    function pauseClaim() public onlyRole(ADMIN_ROLE) {
        require(!claimPaused, "claim paused");
        claimPaused = true;
        emit PauseClaim();
    }

    function unpauseClaim() public onlyRole(ADMIN_ROLE) {
        require(claimPaused, "claim not paused");
        claimPaused = false;
        emit UnpausedClaim();
    }

    function setStartBlock(uint256 _startBlock) public onlyRole(ADMIN_ROLE) {
        require(_startBlock < endBlock, "invalid start block");
        startBlock = _startBlock;
        emit SetStartBlock(startBlock);
    }
    function setEndBlock(uint256 _endBlock) public onlyRole(ADMIN_ROLE) {
        require(startBlock < _endBlock, "invalid end block");
        endBlock = _endBlock;
    }
    function setMetaNodePerBlock(
        uint256 _MetaNodePerBlock
    ) public onlyRole(ADMIN_ROLE) {
        require(_MetaNodePerBlock > 0, "invalid MetaNodePerBlock");
        MetaNodePerBlock = _MetaNodePerBlock;
        emit SetMetaNodePerBlock(MetaNodePerBlock);
    }
    function addPool(
        address _stTokenAddress,
        uint256 _poolWeight,
        uint256 _minDepositAmount,
        uint256 _unstakeLockedBlocks,
        bool _withUpdate
    ) public onlyRole(ADMIN_ROLE) {
        if (pools.length > 0) {
            require(
                _stTokenAddress != address(0x0),
                "invalid staking token address"
            );
        } else {
            require(
                _stTokenAddress == address(0x0),
                "invalid staking token address"
            );
        }
        require(_unstakeLockedBlocks > 0, "invalid withdraw locked blocks");
        require(block.number < endBlock, "Already ended");
        if (_withUpdate) {
            massUpdatePools();
        }
        uint256 lastRewardBlock = block.number > startBlock
            ? block.number
            : startBlock;
        totalPoolWeight = totalPoolWeight + _poolWeight;
        pools.push(
            Pool({
                stTokenAddress: _stTokenAddress,
                poolWeight: _poolWeight,
                lastRewardBlock: lastRewardBlock,
                accMetaNodePerST: 0,
                stTokenAmount: 0,
                minDepositAmount: _minDepositAmount,
                unstakeLockedBlocks: _unstakeLockedBlocks
            })
        );
        emit AddPool(
            _stTokenAddress,
            _poolWeight,
            lastRewardBlock,
            _minDepositAmount,
            _unstakeLockedBlocks
        );
    }
    function updatePool(
        uint256 _pid,
        uint256 _minDepositAmount,
        uint256 _unstakeLockedBlocks
    ) public onlyRole(ADMIN_ROLE) checkPid(_pid) {
        pools[_pid].minDepositAmount = _minDepositAmount;
        pools[_pid].unstakeLockedBlocks = _unstakeLockedBlocks;
        emit UpdatePoolInfo(_pid, _minDepositAmount, _unstakeLockedBlocks);
    }
    function setPoolWeight(
        uint256 _pid,
        uint256 _poolWeight,
        bool _withUpdate
    ) public onlyRole(ADMIN_ROLE) checkPid(_pid) {
        require(_poolWeight > 0, "invalid pool weight");
        if (_withUpdate) {
            massUpdatePools();
        }
        totalPoolWeight =
            totalPoolWeight -
            pools[_pid].poolWeight +
            _poolWeight;
        pools[_pid].poolWeight = _poolWeight;

        emit SetPoolWeight(_pid, _poolWeight, totalPoolWeight);
    }
    function poolLength() external view returns (uint256) {
        return pools.length;
    }

    function massUpdatePools() public {
        uint256 length = pools.length;
        for (uint pid = 0; pid < length; pid++) {
            updatePool(pid);
        }
    }
    function depositETH() public payable whenNotPaused {
        Pool storage pool_ = pools[ETH_PID];
        require(
            pool_.stTokenAddress == address(0x0),
            "invalid staking token address"
        );
        uint256 _amount = msg.value;
        require(
            _amount >= pool_.minDepositAmount,
            "deposit amount is too small"
        );
        _deposit(ETH_PID, _amount);
    }
    function _deposit(uint256 _pid, uint256 _amount) internal {
        Pool storage pool_ = pools[_pid];
        User storage user_ = user[_pid][msg.sender];
        updatePool(_pid);
        if (user_.stAmount > 0) {
            (bool success1, uint256 accST) = user_.stAmount.tryMul(
                pool_.accMetaNodePerST
            );
            require(success1, "user stAmount mul accMetaNodePerST overflow");
            (success1, accST) = accST.tryDiv(1 ether);
            require(success1, "accST div 1 ether overflow");
            (bool success2, uint256 pendingMetaNode_) = accST.trySub(
                user_.finishedMetaNode
            );
            require(success2, "accST sub finishedMetaNode overFlow");
            if (pendingMetaNode_ > 0) {
                (bool sucess3, uint256 _pendingMetaNode) = user_
                    .pendingMetaNode
                    .tryAdd(pendingMetaNode_);
                require(sucess3, "user pendingMetaNode overflow");
                user_.pendingMetaNode = _pendingMetaNode;
            }
        }
        if (_amount > 0) {
            (bool success4, uint256 stAmount) = user_.stAmount.tryAdd(_amount);
            require(success4, "user stAmount overflow");
            user_.stAmount = stAmount;
        }
        (bool success5, uint256 stTokenAmount) = pool_.stTokenAmount.tryAdd(
            _amount
        );
        require(success5, "pool stTokenAmount overflow");
        pool_.stTokenAmount = stTokenAmount;

        (bool success6, uint256 finishedMetaNode) = user_.stAmount.tryMul(
            pool_.accMetaNodePerST
        );
        require(success6, "uuser stAmount mul accMetaNodePerST overflow");
        (success6, finishedMetaNode) = finishedMetaNode.tryDiv(1 ether);
        require(success6, "finishedMetaNode div 1 ether overflow");
        user_.finishedMetaNode = finishedMetaNode;

        emit Deposit(msg.sender, _pid, _amount);
    }

    function _safeMetaNodeTransfer(address _to, uint256 _amount) internal {
        uint256 MetaNodeBal = MetaNode.balanceOf(address(this));
        if (_amount > MetaNodeBal) {
            MetaNode.transfer(_to, MetaNodeBal);
        } else {
            MetaNode.transfer(_to, _amount);
        }
    }
    function _safeETHTransfer(address _to, uint256 _amount) internal {
        (bool success, bytes memory data) = address(_to).call{value: _amount}(
            ""
        );
        require(success, "ETH transfer call failed");
        if (data.length > 0) {
            require(
                abi.decode(data, (bool)),
                "ETH  transfer operation did not succeed"
            );
        }
    }
    function updatePool(uint256 _pid) public checkPid(_pid) {
        Pool storage pool_ = pools[_pid];
        if (block.number <= pool_.lastRewardBlock) {
            return;
        }
        (bool success1, uint256 totalMetaNode) = getMultiplier(
            pool_.lastRewardBlock,
            block.number
        ).tryMul(pool_.poolWeight);
        require(success1, "overflow");
        (success1, totalMetaNode) = totalMetaNode.tryDiv(totalPoolWeight);
        require(success1, "overflow");
        uint256 stSupply = pool_.stTokenAmount;
        if (stSupply > 0) {
            (bool success2, uint256 totalMetaNode_) = totalMetaNode.tryMul(
                1 ether
            );
            require(success2, "overflow");
            (success2, totalMetaNode_) = totalMetaNode_.tryDiv(stSupply);
            require(success2, "overflow");
            (bool success3, uint256 accMetaNodePerST) = pool_
                .accMetaNodePerST
                .tryAdd(totalMetaNode_);
            require(success3, "overflow");
            pool_.accMetaNodePerST = accMetaNodePerST;
        }
        pool_.lastRewardBlock = block.number;
        emit UpdatePool(_pid, pool_.lastRewardBlock, totalMetaNode);
    }

    function getMultiplier(
        uint256 _from,
        uint256 _to
    ) public view returns (uint256 multiplier) {
        require(_from <= _to, "invalid block");
        if (_from < startBlock) {
            _from = startBlock;
        }
        if (_to > endBlock) {
            _to = endBlock;
        }
        require(_from <= _to, "end block must be greater than start block");
        bool success;
        (success, multiplier) = (_to - _from).tryMul(MetaNodePerBlock);
        require(success, "multiplier overflow");
    }
    function pendingMetaNode(
        uint256 _pid,
        address _user
    ) external view checkPid(_pid) returns (uint256) {
        return pendingMetaNodeByBlockNumber(_pid, _user, block.number);
    }

    function pendingMetaNodeByBlockNumber(
        uint256 _pid,
        address _user,
        uint256 _blockNumber
    ) public view checkPid(_pid) returns (uint256) {
        Pool storage pool_ = pools[_pid];
        User storage user_ = user[_pid][_user];
        uint256 accMetaNodePerST = pool_.accMetaNodePerST;
        uint256 stSupply = pool_.stTokenAmount;

        if (_blockNumber > pool_.lastRewardBlock && stSupply != 0) {
            uint256 multiplier = getMultiplier(
                pool_.lastRewardBlock,
                _blockNumber
            );
            uint256 MetaNodeForPool = (multiplier * pool_.poolWeight) /
                totalPoolWeight;
            accMetaNodePerST =
                accMetaNodePerST +
                (MetaNodeForPool * (1 ether)) /
                stSupply;

            return
                (user_.stAmount * accMetaNodePerST) /
                (1 ether) -
                user_.finishedMetaNode +
                user_.pendingMetaNode;
        }
    }

    function stakingBalance(
        uint256 _pid,
        address _user
    ) external view checkPid(_pid) returns (uint256) {
        return user[_pid][_user].stAmount;
    }
    function withdrawAmount(
        uint256 _pid,
        address _user
    )
        public
        view
        checkPid(_pid)
        returns (uint256 requestAmount, uint256 pendingWithdrawAmount)
    {
        User storage user_ = user[_pid][_user];
        for (uint i = 0; i < user_.requests.length; i++) {
            if (user_.requests[i].unlockBlocks <= block.number) {
                pendingWithdrawAmount =
                    pendingWithdrawAmount +
                    user_.requests[i].amount;
            }
            requestAmount = requestAmount + user_.requests[i].amount;
        }
    }
    // **************************888
}
