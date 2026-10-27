// SPDX-License-Identifer: MIT
pragma solidity ^0.8.34;

import {NFTAuction} from "../src/NFTAuction.sol";
import {Test} from "forge-std/Test.sol";
import {MyNFT} from "../src/MyNFT.sol";
import {MockERC20} from "../src/MockERC20.sol";

contract NFTAuctionTest is Test {
    NFTAuction public auction;
    address public owner;
    address public recipient;
    address public recipient2;
    function setUp() public {
        owner = makeAddr("owner");
        recipient = makeAddr("recipient");
        recipient2 = makeAddr("recipient2");
        auction = new NFTAuction();
    }
    function test_Auction() public {
        MyNFT nft = new MyNFT(address(this), "MyNFT", "NFT");
        nft.mint(owner);

        vm.prank(owner);
        // 授权 auction合约操作tokenId为0的NFT
        nft.approve(address(auction), 0);

        uint256 duration = 100;
        vm.prank(owner);
        // 创建一个NFT的拍卖
        auction.createAuction(address(nft), 0, address(0), 1 ether, duration);

        // 给出价者1 设置3个 eth
        vm.deal(recipient, 3 ether);
        //由出价者发起出价
        vm.prank(recipient);
        auction.bid{value: 2 ether}(0, 2 ether);

        // 给出价者2 设置10个 eth
        vm.deal(recipient2, 10 ether);
        //由出价者发起出价
        vm.prank(recipient2);
        auction.bid{value: 5 ether}(0, 5 ether);

        // 把事件推进制定地区
        vm.warp(block.timestamp + duration);
        // 结束拍卖为0的的AUCTION
        auction.endAuction(0);
        assertEq(nft.ownerOf(0), recipient2);

        // 取出拍卖的金额
        vm.prank(recipient);
        auction.withdrawn(address(0)); // 失败出价者取回 2 ETH

        assertEq(recipient.balance, 3 ether); // 原有 3 ETH，先出价 2 ETH，再退回 2 ETH
        assertEq(recipient2.balance, 5 ether); // 原有 10 ETH，出价 5 ETH

        assertEq(owner.balance, 5 ether); // 合约收取 5 ETH
    }
    // 无人竞价
    function test_EndAuctionWithoutBidsReturnsNFT() public {
        MyNFT nft = new MyNFT(address(this), "MyNFT", "NFT");
        nft.mint(owner);

        vm.prank(owner);
        nft.approve(address(auction), 0);

        uint256 duration = 100;
        vm.prank(owner);
        auction.createAuction(address(nft), 0, address(0), 1 ether, duration);

        vm.warp(block.timestamp + duration);
        auction.endAuction(0);

        assertEq(nft.ownerOf(0), owner);
    }
    // 竞价成功,花费的是非比特币
    function test_AuctionWithPaymentToken() public {
        // 创建一个同质化代币合约
        MockERC20 paymentToken = new MockERC20();

        // 创建一个非同质化代币合约
        MyNFT nft = new MyNFT(address(this), "MyNFT", "NFT");
        //  为 owner 发行一个 NFT
        nft.mint(owner);

        // 授权 auction合约操作tokenId为0的NFT
        vm.prank(owner);
        nft.approve(address(auction), 0);

        uint256 duration = 100;
        vm.prank(owner);
        // 创建一个NFT的拍卖
        auction.createAuction(
            address(nft),
            0,
            address(paymentToken), // 使用 paymentToken 作为拍卖的支付币种
            1 ether,
            duration
        );

        // 给出价者1 设置3个 eth
        paymentToken.mint(recipient, 3 ether);
        //由出价者发起出价
        vm.prank(recipient);
        // 竞价者1 授权 auction合约从paymentToken合约中取钱,取钱额度是 2 ether
        paymentToken.approve(address(auction), 2 ether);

        vm.prank(recipient);
        auction.bid(0, 2 ether); // ERC20 出价不附带 ETH

        // 给出价者2 设置10个 eth
        paymentToken.mint(recipient2, 10 ether);
        //由出价者发起出价
        vm.prank(recipient2);
        // 竞价者2 授权 auction合约从paymentToken合约中取钱,取钱额度是 5 ether
        paymentToken.approve(address(auction), 5 ether);

        vm.prank(recipient2);
        auction.bid(0, 5 ether); // ERC20 出价不附带 ETH

        // 把事件推进制定地区
        vm.warp(block.timestamp + duration);
        // 结束拍卖为0的的AUCTION
        auction.endAuction(0);
        // 验证tokenId为0的NFT的拥有者
        assertEq(nft.ownerOf(0), recipient2);
        // 验证 nft的owner的余额
        assertEq(paymentToken.balanceOf(owner), 5 ether);

        // 取出拍卖的金额
        vm.prank(recipient);
        auction.withdrawn(address(paymentToken)); // 失败出价者取回 2 ETH
        // 验证出价者的余额
        assertEq(paymentToken.balanceOf(recipient), 3 ether);
        // 验证出价者2的余额
        assertEq(paymentToken.balanceOf(recipient2), 5 ether);
        // 验证合约的余额
        assertEq(paymentToken.balanceOf(address(auction)), 0);
    }
}
