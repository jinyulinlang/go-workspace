// SPDX-License-Identifier: MIT
pragma solidity ^0.8.34;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract NFTAuction is ReentrancyGuard {
    using SafeERC20 for IERC20;

    // 定义一个拍卖合约的结构体
    struct Auction {
        address seller; // 拍卖的卖家
        address nftContract; // 拍卖的NFT合约
        uint256 tokenId; // 拍卖的NFT的ID
        address paymentToken; // 拍卖的支付币种
        uint256 startPrice; // 拍卖的起始价格
        uint256 endTime; // 拍卖的结束时间
        address highestBidder; // 最高出价的用户
        uint256 highestBid; // 最高出价
        bool settled; // 是否结算
    }
    // 定义一个拍卖的ID
    uint public _nextAuctionId;
    // 定义一个拍卖的映射
    mapping(uint256 => Auction) public auctions;

    mapping(address => mapping(address => uint256)) peddingReturns;

    /// 定义一个拍卖创建事件
    event AuctionCreated(
        uint256 indexed auctionId, // 拍卖的ID
        address indexed seller, // 拍卖的卖家
        address nftContract, // 拍卖的NFT合约
        uint256 tokenId, // 拍卖的NFT的ID
        address paymentToken, // 拍卖的支付币种
        uint256 startPrice, // 拍卖的起始价格
        uint256 endTime // 拍卖的结束时间
    );
    /// 定义一个出价事件
    event BidPlaced(
        uint256 indexed auctionId, // 拍卖的ID
        address indexed bidder, // 出价的用户
        uint256 bidAmount // 出价的金额
    );
    /// 定义一个拍卖结算事件
    event AuctionSettled(
        uint256 indexed auctionId, // 拍卖的ID
        address winner, // 赢得拍卖的用户
        uint256 amount // 赢得拍卖的金额
    );
    /// 定义一个提款事件
    event Withdrawn(
        address indexed user, // 提款的用户
        address indexed token, // 提款的代币
        uint256 amount // 提款的金额
    );

    /// 创建拍卖:卖家需要先approve 本合约操作其NFT
    function createAuction(
        address nftContract, // 拍卖的NFT合约
        uint256 tokenId, // 拍卖的NFT的ID
        address paymentToken, // 拍卖的支付币种
        uint256 startPrice, // 拍卖的起始价格
        uint256 duration // 拍卖的持续时间
    ) external returns (uint256) {
        require(duration > 0, "Duration must be >0");
        require(startPrice > 0, "Start price must be > 0");
        require(startPrice > 0, "Start price must be > 0");
        // 将NFT 转入合约托管
        IERC721(nftContract).safeTransferFrom(
            msg.sender,
            address(this),
            tokenId
        );
        // 创建拍卖
        uint256 nextAuctionId = _nextAuctionId++;
        uint256 endTime = block.timestamp + duration;
        auctions[nextAuctionId] = Auction({
            seller: msg.sender,
            nftContract: nftContract,
            tokenId: tokenId,
            paymentToken: paymentToken,
            startPrice: startPrice,
            endTime: endTime,
            highestBidder: address(0),
            highestBid: 0,
            settled: false
        });
        // 发送拍卖创建事件
        emit AuctionCreated(
            nextAuctionId,
            msg.sender,
            nftContract,
            tokenId,
            paymentToken,
            startPrice,
            endTime
        );
        // 返回拍卖的ID
        return nextAuctionId;
    }

    /// 出价
    function bid(
        uint256 auctionId,
        uint256 bidAmount
    ) external payable nonReentrant {
        require(bidAmount > 0, "Bid amount must be > 0");
        // 获取拍卖
        Auction storage auction = auctions[auctionId];
        // 如果 auction 不存在，抛出异常
        require(auction.seller != address(0), "Auction does not exist");
        // 检查拍卖是否已结束
        require(block.timestamp < auction.endTime, "Auction is over");
        // 检查拍卖是否已结算
        require(!auction.settled, "Auction is settled");
        // 售卖方不能出价
        require(msg.sender != auction.seller, "Seller cannot bid");
        // 最新出价不能低于之前的出价
        uint256 minBid = auction.highestBid == 0
            ? auction.startPrice
            : auction.highestBid;
        require(bidAmount > minBid, "Bid too low");
        // 如果本次出价者是上一个出价者
        uint256 requiredPayment;
        if (auction.highestBidder == msg.sender) {
            // 同一出价者追加出价:直部差额,不产生退款记账
            requiredPayment = bidAmount - auction.highestBid;
        } else {
            requiredPayment = bidAmount;
            // 到这里 说明前一个出价者不是本次出价者,记录退款信息,待其自取
            if (auction.highestBidder != address(0)) {
                peddingReturns[auction.highestBidder][
                    auction.paymentToken
                ] += auction.highestBid;
            }
        }

        // 收取本次应付金额
        if (auction.paymentToken != address(0)) {
            require(msg.value == 0, "Do not send ETH for ERC20 auction");
            IERC20(auction.paymentToken).safeTransferFrom(
                msg.sender,
                address(this),
                requiredPayment
            );
        } else {
            require(msg.value == requiredPayment, "Not enough ETH");
        }

        // 更新最高出价
        auction.highestBidder = msg.sender;
        auction.highestBid = bidAmount;
        // 发送出价事件
        emit BidPlaced(auctionId, msg.sender, bidAmount);
    }
    /// 结束拍卖
    function endAuction(uint256 auctionId) external nonReentrant {
        // 获取拍卖
        Auction storage auction = auctions[auctionId];
        // 检查拍卖是否已结算
        require(!auction.settled, "Auction is settled");
        // 检查拍卖是否已结束
        require(block.timestamp >= auction.endTime, "Auction not ended");
        auction.settled = true;

        if (auction.highestBidder != address(0)) {
            // 将NFT 转入拍卖者
            IERC721(auction.nftContract).safeTransferFrom(
                address(this),
                auction.highestBidder,
                auction.tokenId
            );
            // 同时 把拍卖的金额转给 nft的售卖者
            // 如果拍卖的支付币种不是ETH
            if (auction.paymentToken != address(0)) {
                IERC20(auction.paymentToken).safeTransfer(
                    auction.seller,
                    auction.highestBid
                );
            } else {
                // 如果拍卖的支付币种是ETH
                (bool ok, ) = payable(auction.seller).call{
                    value: auction.highestBid
                }("");
                require(ok, "Transfer failed");
            }
            // 发送拍卖结束事件
            emit AuctionSettled(
                auctionId,
                auction.highestBidder,
                auction.highestBid
            );
        } else {
            // 意味着拍卖失败,没有任何人参与竞拍,则把 nft 返还给 nft拥有者
            IERC721(auction.nftContract).safeTransferFrom(
                address(this),
                auction.seller,
                auction.tokenId
            );
        }
    }
    /// 竞拍者取回被超越的金额
    function withdrawn(address tokenId) external nonReentrant {
        uint256 amount = peddingReturns[msg.sender][tokenId];
        require(amount > 0, "Nothing to withdrawn");
        peddingReturns[msg.sender][tokenId] = 0;
        // 校验  token的币种
        if (tokenId != address(0)) {
            IERC20(tokenId).safeTransfer(msg.sender, amount);
        } else {
            (bool ok, ) = payable(msg.sender).call{value: amount}("");
            require(ok, "Transfer failed");
        }

        emit Withdrawn(msg.sender, tokenId, amount);
    }
    /// 接收NFT: 我是拍卖合约，我能正确处理转入的 NFT
    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external pure returns (bytes4) {
        return this.onERC721Received.selector;
    }
}
