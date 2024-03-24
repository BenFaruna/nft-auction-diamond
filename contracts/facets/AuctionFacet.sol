// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../libraries/LibAppStorage.sol";
import "../libraries/LibAuctionStorage.sol";

import "../interfaces/IERC721.sol";
import "../interfaces/IERC20.sol";

contract AuctionFacet {
    address constant DAO_ADDRESS = 0xdD2FD4581271e230360230F9337D5c0430Bf44C0;
    address constant TEAM_ADDRESS = 0xb2b2130b4B83Af141cFc4C5E3dEB1897eB336D79;

    function getAuctionDetails(
        uint256 _auctionId
    ) public view returns (address, uint256, uint256, bool) {
        LibAuctionStorage.AuctionStorage storage s = LibAuctionStorage
            .getStorage();
        require(_auctionId < s.index, "Invalid auction id");
        LibAuctionStorage.Auction memory auction = s.auctions[_auctionId];

        return (
            auction.currentBidOwner,
            auction.currentBidPrice,
            auction.endAuction,
            auction.isOpen
        );
    }

    function create721Auction(
        LibAuctionStorage.Categories _category,
        address _addressNFTCollection,
        uint256 _nftTokenId,
        uint256 _endAuction,
        uint256 _minBid
    ) public {
        IERC721 nftContract = IERC721(_addressNFTCollection);
        require(nftContract.ownerOf(_nftTokenId) == msg.sender, "not owner");
        require(
            nftContract.getApproved(_nftTokenId) == address(this),
            "Contract not approved"
        );
        LibAuctionStorage.AuctionStorage storage s = LibAuctionStorage
            .getStorage();
        s.auctions[s.index].category = _category;
        s.auctions[s.index].addressNFTCollection = _addressNFTCollection;
        s.auctions[s.index].nftTokenIds = _nftTokenId;
        s.auctions[s.index].seller = msg.sender;
        s.auctions[s.index].endAuction = _endAuction;
        s.auctions[s.index].currentBidPrice = _minBid;
        s.auctions[s.index].isOpen = true;
        s.index++;
        emit LibAuctionStorage.AuctionCreated(
            s.index,
            _addressNFTCollection,
            _nftTokenId,
            msg.sender,
            _endAuction,
            _minBid
        );
    }

    function BidOnAuction(uint256 _auctionId, uint256 _amount) public {
        LibAuctionStorage.AuctionStorage storage s = LibAuctionStorage
            .getStorage();

        require(_auctionId < s.index, "Invalid auction id");

        LibAppStorage.AppStorage storage a = LibAppStorage.getStorage();
        LibAuctionStorage.Auction storage auction = s.auctions[_auctionId];

        require(auction.isOpen, "Auction is closed");
        require(auction.endAuction > block.timestamp, "Auction has ended");
        require(_amount > auction.currentBidPrice, "Cannot bid lower");
        IERC20 erc20 = IERC20(address(this));

        if (auction.currentBidOwner != address(0)) {
            address lastInteraction = a.lastInteraction;
            uint256 fee = LibAuctionStorage.calculatePercentDeduction(
                auction.currentBidPrice,
                1e17
            );

            require(
                erc20.transferFrom(msg.sender, address(this), _amount),
                "Insufficient balance or allowance"
            );
            uint256 prevBidPrice = auction.currentBidPrice;
            //calculations for deductions
            uint256 twoPercentDeduction = LibAuctionStorage
                .calculatePercentDeduction(prevBidPrice, 2e16);
            uint256 threePercentDeduction = LibAuctionStorage
                .calculatePercentDeduction(prevBidPrice, 3e16);
            uint256 onePercentDeduction = LibAuctionStorage
                .calculatePercentDeduction(prevBidPrice, 1e16);

            require(
                erc20.transfer(address(0), twoPercentDeduction),
                "burn failed"
            );
            require(
                erc20.transfer(lastInteraction, onePercentDeduction),
                "Last interaction Transfer failed"
            );
            require(
                erc20.transfer(DAO_ADDRESS, twoPercentDeduction),
                "DAO Transfer failed"
            );
            require(
                erc20.transfer(TEAM_ADDRESS, twoPercentDeduction),
                "TEAM Transfer failed"
            );
            require(
                erc20.transfer(
                    auction.currentBidOwner,
                    prevBidPrice + threePercentDeduction
                ),
                "Outbid refund failed"
            );
        } else {
            require(
                erc20.transferFrom(msg.sender, address(this), _amount),
                "Insufficient balance or allowance"
            );
        }

        s.auctions[_auctionId].currentBidOwner = msg.sender;
        s.auctions[_auctionId].currentBidPrice = _amount;

        emit LibAuctionStorage.BidPlaced(_auctionId, msg.sender, _amount);
    }

    function claimNFT(uint256 _auctionId) public {
        LibAuctionStorage.AuctionStorage storage s = LibAuctionStorage
            .getStorage();

        require(_auctionId < s.index, "Invalid auction id");

        LibAppStorage.AppStorage storage a = LibAppStorage.getStorage();
        LibAuctionStorage.Auction storage auction = s.auctions[_auctionId];

        require(auction.endAuction > block.timestamp, "Auction ongoing");
        require(auction.isOpen, "Not winner");
        require(msg.sender == auction.currentBidOwner, "Not winner");

        IERC721 nftContract = IERC721(auction.addressNFTCollection);

        address approval = nftContract.getApproved(auction.nftTokenIds);
        if (approval != address(this)) {
            revert("Cannot send nft");
        }

        auction.isOpen = false;
        nftContract.transferFrom(
            auction.seller,
            msg.sender,
            auction.nftTokenIds
        );

        IERC20 erc20 = IERC20(address(this));

        uint256 fee = LibAuctionStorage.calculatePercentDeduction(
            auction.currentBidPrice,
            1e17
        );
        uint256 payment = auction.currentBidPrice - fee;

        erc20.transfer(auction.seller, payment);

        emit LibAuctionStorage.NFTClaimed(
            _auctionId,
            msg.sender,
            auction.nftTokenIds
        );
        emit LibAuctionStorage.BidClaimed(_auctionId, auction.seller, payment);
        emit LibAuctionStorage.AuctionEnded(
            _auctionId,
            msg.sender,
            auction.currentBidPrice
        );
    }
}
