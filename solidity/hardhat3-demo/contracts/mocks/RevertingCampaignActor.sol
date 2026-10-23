// SPDX-License-Identifier: MIT
pragma solidity ^0.8.34;

import "../CrowdFundingCampaign.sol";

contract RevertingCampaignActor {
    CrowdFundingCampaign public immutable campaign;

    constructor(string memory name, uint256 goal, uint256 durationInDays) {
        campaign = new CrowdFundingCampaign(
            address(this),
            name,
            goal,
            durationInDays
        );
    }

    function startCampaign() external {
        campaign.start();
    }

    function withdrawCampaign() external {
        campaign.withdraw();
    }

    function contributeToCampaign() external payable {
        campaign.contribute{value: msg.value}();
    }

    function refundFromCampaign() external {
        campaign.refund();
    }

    receive() external payable {
        revert("RevertingCampaignActor: reject transfer");
    }
}
