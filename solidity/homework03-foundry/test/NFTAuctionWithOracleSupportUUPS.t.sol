// SPDX-License-Identifier: MIT
pragma solidity ^0.8.34;

import {NFTAuctionWithOracleSupportUUPS} from "../src/NFTAuctionWithOracleSupportUUPS.sol";
import {Test} from "forge-std/Test.sol";
import {MyNFT} from "../src/MyNFT.sol";
import {MockERC20} from "../src/MockERC20.sol";
import {AggregatorV3Interface} from "@chainlink-evm/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
contract NFTAuctionWithOracleSupportUUPSTest is Test {
    address owner;
    address seller;
    address bidder;
    address bidder2;
    address feedAddress;
    uint256 nextTokenId;
    MyNFT public nft;
    MockERC20 public paymentToken;

    AggregatorV3Interface public mockAggregator;
    NFTAuctionWithOracleSupportUUPS public auction;
    function setUp() public {
        owner = makeAddr("owner");
        seller = makeAddr("seller");
        bidder = makeAddr("bidder");
        bidder2 = makeAddr("bidder2");
        nft = new MyNFT(address(this), "MyNFT", "NFT");
        paymentToken = new MockERC20();

        feedAddress = makeAddr("mock-feed");
        mockAggregator = AggregatorV3Interface(feedAddress);

        vm.mockCall(
            feedAddress,
            abi.encodeWithSelector(AggregatorV3Interface.decimals.selector),
            abi.encode(uint8(8))
        );

        vm.mockCall(
            feedAddress,
            abi.encodeWithSelector(
                AggregatorV3Interface.latestRoundData.selector
            ),
            abi.encode(
                uint80(1),
                int256(300_000_000_000),
                uint256(1),
                uint256(1),
                uint80(1)
            )
        );
        NFTAuctionWithOracleSupportUUPS implementation = new NFTAuctionWithOracleSupportUUPS();

        bytes memory initData = abi.encodeCall(
            NFTAuctionWithOracleSupportUUPS.initialize,
            (owner, feedAddress)
        );
        ERC1967Proxy proxy = new ERC1967Proxy(
            address(implementation),
            initData
        );
        auction = NFTAuctionWithOracleSupportUUPS(address(proxy));
    }
    function _createAuction(
        address token,
        uint256 startPrice,
        uint256 duration
    ) internal returns (uint256 auctionId) {
        uint256 tokenId = nextTokenId++;
        nft.mint(seller);

        vm.prank(seller);
        nft.approve(address(auction), tokenId);

        vm.prank(seller);
        auctionId = auction.createAuction(
            address(nft),
            tokenId,
            token,
            startPrice,
            duration
        );
    }
    function test_test_InitializationAndInitialEthFeed() public view {
        assertEq(auction.owner(), owner);
        AggregatorV3Interface feed = auction.priceFeeds(address(0));
        assertEq(address(feed), feedAddress);
    }
    function test_ImplementationCannotBeInitialized() public {
        NFTAuctionWithOracleSupportUUPS implementation = new NFTAuctionWithOracleSupportUUPS();
        vm.expectRevert();
        implementation.initialize(owner, feedAddress);
    }
    function test_GetLastPrice() public view {
        (uint256 price, uint8 decimals) = auction.getLastPrice(address(0));
        assertEq(price, 300_000_000_000);
        assertEq(decimals, 8);
    }
    function test_GetLastPriceRevertsForUnsetFeed() public {
        vm.expectRevert(bytes("Price feed not set"));
        auction.getLastPrice(address(paymentToken));
    }
    function test_GetLastPriceRevertsForNonPositiveAnswer() public {
        vm.mockCall(
            feedAddress,
            abi.encodeWithSelector(
                AggregatorV3Interface.latestRoundData.selector
            ),
            abi.encode(uint80(1), int256(0), uint256(1), uint256(1), uint80(1))
        );
        vm.expectRevert(bytes("Invalid price"));
        auction.getLastPrice(address(0));
    }
    function test_SetPriceFeedRejectsZeroAddress() public {
        vm.prank(owner);
        vm.expectRevert(bytes("Feed cannot be 0 address"));
        auction.setPriceFeed(address(paymentToken), address(0));
    }

    function test_SetPriceFeedRejectsNonOwner() public {
        vm.prank(bidder);
        vm.expectRevert();
        auction.setPriceFeed(address(paymentToken), feedAddress);
    }

    function test_GetBidValueReturnsZeroForUnknownAuction() public {
        assertEq(auction.getBidValueInUSD(123), 0);
    }

    function test_GetBidValueUsesStartPrice() public {
        uint256 auctionId = _createAuction(address(0), 1 ether, 1 days);
        assertEq(auction.getBidValueInUSD(auctionId), 3000 ether);
    }
    function test_CreateAuctionRejectsZeroDuration() public {
        vm.expectRevert(bytes("Duration must be >0"));
        auction.createAuction(address(nft), 0, address(0), 1 ether, 0);
    }
    function test_BidRejectsInvalidInputs() public {
        uint256 auctionId = _createAuction(address(0), 1 ether, 1 days);
        vm.deal(bidder, 5 ether);

        vm.expectRevert(bytes("Bid amount must be > 0"));
        vm.prank(bidder);
        auction.bid(auctionId, 0);

        vm.expectRevert(bytes("Auction does not exist"));
        vm.prank(bidder);
        auction.bid(999, 2 ether);
        
        vm.deal(seller, 2 ether);
        vm.expectRevert(bytes("Seller cannot bid"));
        vm.prank(seller);
        auction.bid{value: 2 ether}(auctionId, 2 ether);

        vm.expectRevert(bytes("Bid too low"));
        vm.prank(bidder);
        auction.bid{value: 1 ether}(auctionId, 1 ether);

        vm.expectRevert(bytes("Not enough ETH"));
        vm.prank(bidder);
        auction.bid{value: 1 ether}(auctionId, 2 ether);
    }
    function test_BidRejectsAfterAuctionExpires() public {
        uint256 auctionId = _createAuction(address(0), 1 ether, 1 days);
        vm.warp(block.timestamp + 1 days);

        vm.expectRevert(bytes("Auction is over"));
        vm.deal(bidder, 2 ether);
        vm.prank(bidder);
        auction.bid{value: 2 ether}(auctionId, 2 ether);
    }
    function test_EndAuctionRejectsBeforeDeadline() public {
        uint256 auctionId = _createAuction(address(0), 1 ether, 1 days);

        vm.expectRevert(bytes("Auction not ended"));
        auction.endAuction(auctionId);
    }

    function test_EndAuctionWithoutBidsReturnsNft() public {
        uint256 auctionId = _createAuction(address(0), 1 ether, 1 days);
        vm.warp(block.timestamp + 1 days);

        auction.endAuction(auctionId);
        assertEq(nft.ownerOf(0), seller);
    }

    function test_EthAuctionOutbidRefundAndSettlement() public {
        uint256 auctionId = _createAuction(address(0), 1 ether, 1 days);
        vm.deal(bidder, 2 ether);
        vm.deal(bidder2, 3 ether);

        vm.prank(bidder);
        auction.bid{value: 1.5 ether}(auctionId, 1.5 ether);

        vm.prank(bidder2);
        auction.bid{value: 2.5 ether}(auctionId, 2.5 ether);

        vm.warp(block.timestamp + 1 days);
        auction.endAuction(auctionId);

        assertEq(nft.ownerOf(0), bidder2);
        assertEq(seller.balance, 2.5 ether);

        vm.prank(bidder);
        auction.withdrawn(address(0));
        assertEq(bidder.balance, 2 ether);
    }
    function test_Erc20AuctionSettlementAndRefund() public {
        uint256 auctionId = _createAuction(
            address(paymentToken),
            1 ether,
            1 days
        );

        paymentToken.mint(bidder, 2 ether);
        paymentToken.mint(bidder2, 3 ether);

        vm.prank(bidder);
        paymentToken.approve(address(auction), type(uint256).max);
        vm.prank(bidder);
        auction.bid(auctionId, 1.5 ether);

        vm.prank(bidder2);
        paymentToken.approve(address(auction), type(uint256).max);
        vm.prank(bidder2);
        auction.bid(auctionId, 2.5 ether);

        vm.warp(block.timestamp + 1 days);
        auction.endAuction(auctionId);

        assertEq(nft.ownerOf(0), bidder2);
        assertEq(paymentToken.balanceOf(seller), 2.5 ether);

        vm.prank(bidder);
        assertEq(nft.ownerOf(0), bidder2);
        assertEq(paymentToken.balanceOf(seller), 2.5 ether);

        vm.prank(bidder);
        auction.withdrawn(address(paymentToken));
        assertEq(paymentToken.balanceOf(bidder), 2 ether);
    }
    function test_WithdrawRejectsWhenNoRefundIsAvailable() public {
        vm.expectRevert(bytes("Nothing to withdrawn"));
        auction.withdrawn(address(0));
    }
}
