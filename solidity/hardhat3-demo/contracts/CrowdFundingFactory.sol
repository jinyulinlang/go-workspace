// SPDX-License-Identifier:MIT
pragma solidity ^0.8.34;
import {CrowdFundingCampaign} from "./CrowdFundingCampaign.sol";
/**
@title 众筹合约工厂合约
@dev 用于创建众筹合约
 @notice 本合约管理多个众筹合约的创建
 */
contract CrowdFundingFactory {
    /// @dev 用于存储创建的众筹合约的数组
    CrowdFundingCampaign[] public campaigns;
    /// @dev 映射: 用户地址 => 该用户创建的所有活动索引数组
    mapping(address => uint256[]) public userCampaigns;

    /// @dev 事件定义
    /// @notice 活动创建事件,当新活动创建时触发
    /// @param creator 活动创建者
    /// @param campaign 活动地址
    /// @param name 活动名称
    /// @param goal 活动目标金额
    /// @param deadline 活动截止日期
    event CampaignCreated(
        address indexed creator,
        address indexed campaign,
        string name,
        uint256 goal,
        uint256 deadline
    );

    /**
     @dev 创建众筹合约
     @param _name 活动名称
     @param _goal 目标金额
     @param _durationInDays 活动持续时间
     */
    function createCampaign(
        string memory _name,
        uint256 _goal,
        uint256 _durationInDays
    ) external returns (address) {
        CrowdFundingCampaign campaign = new CrowdFundingCampaign(
            msg.sender,
            _name,
            _goal,
            _durationInDays
        );
        uint256 index = campaigns.length;
        campaigns.push(campaign);
        userCampaigns[msg.sender].push(index);

        emit CampaignCreated(
            msg.sender,
            address(campaign),
            _name,
            _goal,
            block.timestamp + (_durationInDays * 1 days)
        );
        return address(campaign);
    }

    /**
     @dev 获取所有活动的地址
     @return 所有活动
     */
    function getAllCampaigns() external view returns (address[] memory) {
        if (campaigns.length == 0) {
            return new address[](0);
        }
        address[] memory result = new address[](campaigns.length);
        for (uint256 i = 0; i < campaigns.length; i++) {
            result[i] = address(campaigns[i]);
        }
        return result;
    }
    /**
   @dev 获取用户创建的所有活动
   @notice 获取用户创建的所有活动
   @param _user 用户地址
   @return 用户创建的所有活动
   */
    function getUserCampaigns(
        address _user
    ) external view returns (address[] memory) {
        // 交验地址是否有效
        require(_user != address(0), "Invalid address");
        uint256[] memory campaignIndexes = userCampaigns[_user];
        if (campaignIndexes.length == 0) {
            return new address[](0);
        }
        address[] memory result = new address[](campaignIndexes.length);
        for (uint256 i = 0; i < campaignIndexes.length; i++) {
            result[i] = address(campaigns[campaignIndexes[i]]);
        }
        return result;
    }

    /**
       获取活动总数
     */
    function getCampaignCount() external view returns (uint256) {
        return campaigns.length;
    }
}
