// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library LibAuctionStorage {
    bytes32 constant AUCTION_STORAGE_POSITION = keccak256("auction.storage");

    struct Auction {
        Categories category;
        address addressNFTCollection;
        address seller;
        uint256 nftTokenIds;
        address currentBidOwner;
        uint256 currentBidPrice;
        uint256 endAuction;
        bool isOpen;
    }

    struct AuctionStorage {
        mapping(uint256 => Auction) auctions;
        uint256[] auctionIds;
        uint256 index;
    }

    event Transfer(
        address indexed _from,
        address indexed _to,
        uint256 indexed _tokenId
    );

    enum Categories {
        ERC721,
        ERC1155
    }

    // event to notify when a new auction is created
    event AuctionCreated(
        uint256 index,
        address addressNFTCollection,
        uint256 nftTokenId,
        address auctionCreator,
        uint256 endAuction,
        uint256 minBid
    );

    // event to notify when a new bid is placed
    event BidPlaced(uint256 index, address bidder, uint256 bidAmount);

    // event to notify when an auction is ended
    event AuctionEnded(uint256 index, address winner, uint256 bidAmount);

    // event when winner claims the NFT
    event NFTClaimed(uint256 index, address winner, uint256 nftTokenId);
    event BidClaimed(uint256 index, address seller, uint256 amount);

    // event when auction creator claims the the token
    event TokenClaimed(
        uint256 index,
        address auctionCreator,
        uint256 nftTokenId
    );

    // event where NFT is transferred to the creator
    event NFTRefund(uint256 index, address auctionCreator, uint256 nftTokenId);

    function updateAuctionBid(
        uint256 _auctionId,
        address _bidder,
        uint256 _bidAmount
    ) internal {
        AuctionStorage storage s = LibAuctionStorage.getStorage();
        Auction storage auction = s.auctions[_auctionId];

        s.auctions[_auctionId].currentBidOwner = _bidder;
        s.auctions[_auctionId].currentBidPrice = _bidAmount;
    }

    function calculatePercentDeduction(
        uint256 _amount,
        uint256 _percent
    ) internal view returns (uint256) {
        uint256 ONE_HUNDRED_PERCENT = 1e18;
        require(
            _percent <= ONE_HUNDRED_PERCENT,
            "Percentage must be between 0 and 100"
        );

        // Multiply amount by percentage (fixed-point math)
        uint256 product = _amount * _percent;

        // Divide by ONE_HUNDRED_PERCENT to get the result with 18 decimal places
        return product / ONE_HUNDRED_PERCENT;
    }

    function getStorage() internal pure returns (AuctionStorage storage s) {
        bytes32 position = AUCTION_STORAGE_POSITION;
        assembly {
            s.slot := position
        }
    }
}
