// SPDX-License-Identifier:MIT
pragma solidity ^0.8.34;

/**
@title 众筹活动合约
@dev 使用状态机模式的单个众筹合约
@notice 本合约管理单个众筹合约的完整完整生命周期,状态流转如下:
 准备中(Preparing) -> 进行中(Active) -> 成功(Success)/失败(Failed)-> 已关闭(Closed)/已退款(Refunded)

 */
contract CrowdFundingCampaign {
    /// @dev 众筹活动状态所有的可能状态
    enum Status {
        Preparing,
        Active,
        Success,
        Failed,
        Closed,
        Refunded
    }

    /// @dev 众筹活动当前状态
    Status public status;

    /// @dev 活动地址的创建者,部署后不可更改
    address public immutable owner;

    /// @dev 众筹活动名称(部署后不可更改)
    string public name;

    /// @dev 众筹活动目标金额,单位为 wei (部署后不可更改)
    uint256 public immutable goal;

    /// @dev 活动的截止日期 (部署后不可更改)
    uint256 public immutable deadline;

    /// @dev 活动已筹集的总金额
    uint256 public totalRaised;

    /// @dev 活动从贡献者手里筹集的金额
    mapping(address => uint256) public contributions;

    /// @dev 活动的贡献者列表
    address[] public contributors;

    /// @dev 事件定义
    /// @notice  状态变更事件:当前活动状态变更时触发
    event StatusChanged(Status oldStatus, Status newStatus);
    /// @notice  贡献事件:当用户贡献资金时触发
    event Contribution(address contributor, uint256 amount);
    /// @notice  提取事件:当用户提取资金时触发
    event Withdraw(address contributor, uint256 amount);
    /// @notice  退款事件:当用户退款时触发
    event Refund(address contributor, uint256 amount);

    /// @dev 修饰符定义
    /// @notice 仅所有者修饰符:确保只有活动的创建者才可以调用
    modifier onlyOwner() {
        require(owner == msg.sender, "CrowdFundingCampaign:not owner");
        _;
    }
    /// @notice 状态检查修饰符:确保活动处于指定状态
    /// @param _status 指定的状态
    modifier inStatus(Status _status) {
        require(status == _status, "CrowdFundingCampaign:Invalid status");
        _;
    }
    /// @notice 未过期修饰符:确保活动未过期
    modifier notExpired() {
        require(block.timestamp < deadline, "CrowdFundingCampaign:Expired");
        _;
    }

    /**
      @dev 构造函数
      @param _owner 活动创建者
      @param _name 活动名称
      @param _goal 目标金额 单位 wei
      @param _durationInDays 截止日期 活动持续持续时间
     */
    constructor(
        address _owner,
        string memory _name,
        uint256 _goal,
        uint256 _durationInDays
    ) {
        // 验证创建者地址不能为0
        require(_owner != address(0), "CrowdFundingCampaign:Invalid owner");
        // 验证活动名称不能为0
        require(bytes(_name).length > 0, "CrowdFundingCampaign:Invalid name");
        // 验证目标金额不能为0
        require(_goal > 0, "CrowdFundingCampaign:Invalid goal");
        // 验证持续时间必须在1-90天之间
        require(
            _durationInDays > 0 && _durationInDays <= 90,
            "CrowdFundingCampaign:Invalid duration"
        );

        owner = _owner;
        name = _name;
        goal = _goal;
        deadline = block.timestamp + (_durationInDays * 1 days);
        status = Status.Preparing;
    }

    /**
      @dev 启动众筹活动
      @notice 仅所有者修饰符:确保只有活动的创建者才可以调用
      @notice 状态检查修饰符:确保活动处于准备中状态
     */
    function start() external onlyOwner inStatus(Status.Preparing) {
        // 将活动状态设置为进行中
        status = Status.Active;
        // 触发状态变更事件
        emit StatusChanged(Status.Preparing, Status.Active);
    }

    /**
      @dev 贡献资金给众筹活动
      @notice 未过期修饰符:确保活动未过期
      @notice 状态检查修饰符:确保活动处于进行中状态
     */
    function contribute() external payable notExpired inStatus(Status.Active) {
        // 验证贡献金额必须大于0
        require(msg.value > 0, "CrowdFundingCampaign:Invalid amount");
        // 贡献者地址
        address contributor = msg.sender;
        // 追踪贡献者,如果是首次贡献,则将贡献者地址添加到贡献者列表中
        if (contributions[contributor] == 0) {
            contributors.push(contributor);
        }
        // 更新贡献者贡献金额
        contributions[contributor] += msg.value;
        // 更新活动总贡献金额
        totalRaised += msg.value;
        // 触发贡献事件
        emit Contribution(contributor, msg.value);
        // 自动转换状态:如果总金额大道目标金额则把状态更改成成功
        if (totalRaised >= goal) {
            status = Status.Success;
            emit StatusChanged(Status.Active, Status.Success);
        }
    }

    /**
      @dev 结束众筹活动
      @notice 未过期修饰符:确保活动未过期
      @notice 状态检查修饰符:确保活动处于进行中状态
   */
    function finalize() external inStatus(Status.Active) {
        // 验证当前时间必须已经超过截止日期
        require(
            block.timestamp >= deadline,
            "CrowdFundingCampaign:Not expired"
        );
        // 保存就状态用于事件
        Status previousStatus = status;
        // Active 状态下尚未达到目标,否则 contribute 已将状态设为 Success
        status = Status.Failed;
        // 触发状态变更事件
        emit StatusChanged(previousStatus, status);
    }

    /**
      @dev 取款函数
      @notice 仅所有者修饰符:确保只有活动的创建者才可以调用
      @notice 状态检查修饰符:确保活动处于成功或失败状态
     */
    function withdraw() external payable onlyOwner inStatus(Status.Success) {
        // 将活动状态设置为已关闭
        status = Status.Closed;
        // 获取当前合约的余额
        uint256 balance = address(this).balance;
        // 将余额转移给创建者
        (bool success, ) = owner.call{value: balance}("");
        // 验证转移是否成功
        require(success, "CrowdFundingCampaign:Failed to transfer funds");
        // 触发提取事件
        emit Withdraw(owner, balance);

        // 触发状态变更事件
        emit StatusChanged(Status.Success, Status.Closed);
    }
    /**
      @dev  退款函数
      @notice 状态检查修饰符:确保活动处于失败状态
     */
    function refund() external inStatus(Status.Failed) {
        // 检查调用者的余额
        uint256 balance = contributions[msg.sender];
        if (balance <= 0) {
            revert("CrowdFundingCampaign:No balance");
        }
        contributions[msg.sender] = 0;
        totalRaised -= balance;
        // 将余额转移给调用者
        (bool success, ) = msg.sender.call{value: balance}("");
        // 验证转移是否成功
        require(success, "CrowdFundingCampaign:Failed to transfer funds");
        // 触发退款事件
        emit Refund(msg.sender, balance);
    }
    /**
       @dev 获取贡献者列表
       @return 贡献者列表
     */
    function getContributors() external view returns (address[] memory) {
        return contributors;
    }
    /**
    @dev 检查活动是否正在进行中
    @return 是否正在进行中
     */
    function isActive() external view returns (bool) {
        return status == Status.Active;
    }
    /**
      @dev 获取贡献者总数
      @return 贡献者总数
     */
    function getContributorCount() external view returns (uint256) {
        return contributors.length;
    }
    /**
     @dev 获取活动的百分比
     @return 活动的百分比
     */
    function getProgress() external view returns (uint256) {
        uint256 percentage = (totalRaised * 100) / goal;

        return percentage > 100 ? 100 : percentage;
    }

    /**
       @dev 获取贡献者贡献金额
       @param contributor 贡献者地址
       @return 贡献者贡献金额
     */
    function getContributions(
        address contributor
    ) external view returns (uint256) {
        return contributions[contributor];
    }
}
