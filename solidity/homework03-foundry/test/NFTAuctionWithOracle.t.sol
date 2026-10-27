// SPDX-License-Identifier: MIT
pragma solidity ^0.8.34;

import {NFTAuctionWithOracle} from "../src/NFTAuctionWithOracle.sol";
import {Test} from "forge-std/Test.sol";
import {MyNFT} from "../src/MyNFT.sol";
import {AggregatorV3Interface} from "@chainlink-evm/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
contract NFTAuctionWithOracleTest is Test {
    NFTAuctionWithOracle public vault;
    address public owner;
    address public recipient;
    address public recipient2;
    MockPriceFeed public feed;
    function setUp() public {
        owner = makeAddr("owner");
        recipient = makeAddr("recipient");
        recipient2 = makeAddr("recipient2");
        feed = new MockPriceFeed(8, 300_000_000_000); // $3000，8 位小数
        vault = new NFTAuctionWithOracle(owner, address(feed));
    }
    // 测试获取价格,如果没有设置价格，返回 起拍价计算 USD 估值
    function test_GetLastPrice() public view {
        (uint256 price, uint8 decimals) = vault.getLastPrice(address(0));
        assertEq(price, 300_000_000_000);
        assertEq(decimals, 8);
    }

    function test_GetBidValueInUSD_UsesStartPrice() public {
        MyNFT nft = new MyNFT(address(this), "MyNFT", "NFT");
        nft.mint(owner);

        vm.prank(owner);
        // 授权 auction合约操作tokenId为0的NFT
        nft.approve(address(vault), 0);

        vm.prank(owner);
        // 创建一个NFT的拍卖
        vault.createAuction(address(nft), 0, address(0), 1 ether, 1 days);
        uint256 usd = vault.getBidValueInUSD(0);
        assertEq(usd, 3000 ether);
    }

    // 测试获没有设置价格
    function test_GetLastPriceRevertsWhenFeedIsNotSet() public {
        vm.expectRevert(bytes("Price feed not set"));
        vault.getLastPrice(recipient);
    }
    // 测试 设置无效价格
    function test_GetLastPriceRevertsWhenAnswerIsNotPositive() public {
        feed.setAnswer(0);
        vm.expectRevert(bytes("Invalid price"));
        vault.getLastPrice(address(0));
    }
    // 测试设置价格
    function test_SetPriceFeed() public {
        address token = makeAddr("payment-token");
        MockPriceFeed newFeed = new MockPriceFeed(8, 250_000_000_000);
        vm.prank(owner);
        vault.setPriceFeed(token, address(newFeed));
        AggregatorV3Interface v3 = vault.priceFeeds(token);
        assertEq(address(v3), address(newFeed));

        (uint256 price, uint8 decimals) = vault.getLastPrice(token);
        assertEq(price, 250_000_000_000);
        assertEq(decimals, 8);
    }
    // 测试非owner 回滚
    function test_SetPriceFeedRevertsForNonOwner() public {
        vm.expectRevert(bytes("Feed cannot be 0 address"));
        vm.prank(owner);
        vault.setPriceFeed(recipient, address(0));
    }

    // 测试 为未初始化的拍卖通过ID获取USD估值
    function test_GetBidValueInUSDReturnsZeroForUninitializedAuction()
        public
        view
    {
        uint256 usd = vault.getBidValueInUSD(999);
        assertEq(usd, 0);
    }

    // 测试使用最高出价
    function test_GetBidValueInUSDUsesHighestBid() public {
        MyNFT nft = new MyNFT(address(this), "MyNFT", "NFT");
        nft.mint(owner);

        vm.prank(owner);
        // 授权 auction合约操作tokenId为0的NFT
        nft.approve(address(vault), 0);

        vm.prank(owner);
        // 创建一个NFT的拍卖
        vault.createAuction(address(nft), 0, address(0), 1 ether, 1 days);

        // 给出价者1 设置3个 eth
        vm.deal(recipient, 3 ether);
        //由出价者发起出价
        vm.prank(recipient);
        vault.bid{value: 2 ether}(0, 2 ether);

        // 给出价者2 设置10个 eth
        vm.deal(recipient2, 10 ether);
        //由出价者发起出价
        vm.prank(recipient2);
        vault.bid{value: 5 ether}(0, 5 ether);

        uint256 usd = vault.getBidValueInUSD(0);
        assertEq(usd, 15_000 ether);
    }
}

contract MockPriceFeed {
    uint8 public immutable decimals;
    int256 public answer;

    constructor(uint8 decimals_, int256 answer_) {
        decimals = decimals_;
        answer = answer_;
    }

    function setAnswer(int256 answer_) external {
        answer = answer_;
    }

    function latestRoundData()
        external
        view
        returns (
            uint80 roundId,
            int256 answer_,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        )
    {
        return (1, answer, block.timestamp, block.timestamp, 1);
    }
}
