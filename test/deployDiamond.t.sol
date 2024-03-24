// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "../contracts/interfaces/IERC721.sol";

import "../contracts/interfaces/IDiamondCut.sol";
import "../contracts/facets/DiamondCutFacet.sol";
import "../contracts/facets/DiamondLoupeFacet.sol";
import "../contracts/facets/OwnershipFacet.sol";
import "forge-std/Test.sol";
import "../contracts/Diamond.sol";

import "../contracts/libraries/LibDiamond.sol";

import "../contracts/facets/AUCFacet.sol";
import "../contracts/facets/AuctionFacet.sol";

import "../contracts/NFTOnChain.sol";

import "../contracts/libraries/LibAuctionStorage.sol";

contract DiamondDeployer is Test, IDiamondCut {
    //contract types of facets to be deployed
    Diamond diamond;
    DiamondCutFacet dCutFacet;
    DiamondLoupeFacet dLoupe;
    OwnershipFacet ownerF;
    AUCFacet aucTokenF;
    AuctionFacet auctionF;

    NFTOnChain nftOnChain;

    address A = address(0xa);
    address B = address(0xb);
    address C = address(0xc);

    address DAO_ADDRESS = 0xdD2FD4581271e230360230F9337D5c0430Bf44C0;
    address TEAM_ADDRESS = 0xb2b2130b4B83Af141cFc4C5E3dEB1897eB336D79;

    function setUp() public {
        //deploy facets
        dCutFacet = new DiamondCutFacet();
        diamond = new Diamond(address(this), address(dCutFacet));
        dLoupe = new DiamondLoupeFacet();
        ownerF = new OwnershipFacet();
        aucTokenF = new AUCFacet();
        auctionF = new AuctionFacet();

        nftOnChain = new NFTOnChain();

        //upgrade diamond with facets

        //build cut struct
        FacetCut[] memory cut = new FacetCut[](4);

        cut[0] = (
            FacetCut({
                facetAddress: address(dLoupe),
                action: FacetCutAction.Add,
                functionSelectors: generateSelectors("DiamondLoupeFacet")
            })
        );

        cut[1] = (
            FacetCut({
                facetAddress: address(ownerF),
                action: FacetCutAction.Add,
                functionSelectors: generateSelectors("OwnershipFacet")
            })
        );

        cut[2] = (
            FacetCut({
                facetAddress: address(aucTokenF),
                action: FacetCutAction.Add,
                functionSelectors: generateSelectors("AUCFacet")
            })
        );

        cut[3] = (
            FacetCut({
                facetAddress: address(auctionF),
                action: FacetCutAction.Add,
                functionSelectors: generateSelectors("AuctionFacet")
            })
        );
        //upgrade diamond
        IDiamondCut(address(diamond)).diamondCut(cut, address(0x0), "");

        //call a function
        DiamondLoupeFacet(address(diamond)).facetAddresses();

        A = mkaddr("A");
        B = mkaddr("B");
        C = mkaddr("C");

        AUCFacet(address(diamond)).mint(A, 100e18);
        AUCFacet(address(diamond)).mint(B, 200e18);
        AUCFacet(address(diamond)).mint(C, 10e18);
    }

    function testAUCFacetConnection() public {
        AUCFacet a = AUCFacet(address(diamond));

        assertEq(a.name(), "AUC Token");
        assertEq(a.symbol(), "AUC");
        assertEq(a.decimal(), 18);
    }

    function testAUCMintFunction() public {
        AUCFacet a = AUCFacet(address(diamond));

        a.mint(C, 120e18);
        assertEq(a.balanceOf(C), 130e18);
    }

    function testAUCMintRevertWithNotOwnerCall() public {
        AUCFacet a = AUCFacet(address(diamond));

        switchSigner(A);
        vm.expectRevert(LibDiamond.NotDiamondOwner.selector);
        a.mint(B, 100e18);
    }

    function testAUCTransfer() public {
        AUCFacet a = AUCFacet(address(diamond));

        switchSigner(A);
        a.transfer(B, 20e18);
        assertEq(a.balanceOf(B), 220e18);
    }

    function testTransferFailWithInsufficientBalance() public {
        AUCFacet a = AUCFacet(address(diamond));

        switchSigner(C);
        vm.expectRevert("ERC20: transfer amount exceeds balance");
        a.transfer(B, 20e18);
    }

    function testApproval() public {
        AUCFacet a = AUCFacet(address(diamond));

        switchSigner(A);
        a.approve(address(diamond), 1000e18);
        assertEq(a.allowance(A, address(diamond)), 1000e18);
    }

    function testApproveValueReduceOnSpending() public {
        AUCFacet a = AUCFacet(address(diamond));

        switchSigner(A);
        a.approve(B, 1000e18);
        switchSigner(B);
        a.transferFrom(A, address(diamond), 100e18);
        assertEq(a.allowance(A, B), 900e18);
    }

    function testTransferFailsWithLessAllowance() public {
        AUCFacet a = AUCFacet(address(diamond));

        switchSigner(A);
        a.approve(B, 10e18);
        switchSigner(B);
        vm.expectRevert("Not enough allowance");
        a.transferFrom(A, address(diamond), 100e18);
    }

    function testCreate721Auction() public {
        AuctionFacet a = AuctionFacet(address(diamond));
        switchSigner(A);

        IERC721 nftContract = IERC721(address(nftOnChain));

        nftContract.mint();
        nftContract.approve(address(diamond), 0);

        assertEq(nftContract.ownerOf(0), A);

        vm.expectEmit(false, false, false, false);
        emit LibAuctionStorage.AuctionCreated(
            0,
            address(nftOnChain),
            0,
            A,
            block.timestamp + 3 days,
            0.5e18
        );
        a.create721Auction(
            LibAuctionStorage.Categories.ERC721,
            address(nftOnChain),
            0,
            block.timestamp + 3 days,
            0.5e18
        );
    }

    function testGetAuctionDetails() public {
        AuctionFacet a = AuctionFacet(address(diamond));
        switchSigner(A);

        IERC721 nftContract = IERC721(address(nftOnChain));

        nftContract.mint();
        nftContract.approve(address(diamond), 0);

        a.create721Auction(
            LibAuctionStorage.Categories.ERC721,
            address(nftOnChain),
            0,
            block.timestamp + 3 days,
            0.5e18
        );

        (
            address currentBidOwner,
            uint256 currentBidPrice,
            uint256 endAuction,
            bool isOpen
        ) = a.getAuctionDetails(0);

        assertEq(address(0), currentBidOwner);
        assertEq(0.5e18, currentBidPrice);
        assertEq(block.timestamp + 3 days, endAuction);
        assertEq(true, isOpen);
    }

    function testCreate721AuctionFailWithoutApproval() public {
        AuctionFacet a = AuctionFacet(address(diamond));
        switchSigner(A);

        IERC721 nftContract = IERC721(address(nftOnChain));

        nftContract.mint();

        vm.expectRevert("Contract not approved");
        a.create721Auction(
            LibAuctionStorage.Categories.ERC721,
            address(nftOnChain),
            0,
            block.timestamp + 3 days,
            0.5e18
        );
    }

    function testBidOnAuction() public {
        AuctionFacet a = AuctionFacet(address(diamond));
        switchSigner(A);

        IERC721 nftContract = IERC721(address(nftOnChain));

        nftContract.mint();
        nftContract.approve(address(diamond), 0);

        a.create721Auction(
            LibAuctionStorage.Categories.ERC721,
            address(nftOnChain),
            0,
            block.timestamp + 3 days,
            0.5e18
        );

        switchSigner(B);

        AUCFacet erc20 = AUCFacet(address(diamond));
        erc20.approve(address(diamond), 1e18);

        a.BidOnAuction(0, 1e18);

        (address currentBidOwner, uint256 currentBidPrice, , ) = a
            .getAuctionDetails(0);

        assertEq(B, currentBidOwner);
        assertEq(1e18, currentBidPrice);
    }

    function testBidTransfersFundsAppropriately() public {
        AuctionFacet a = AuctionFacet(address(diamond));
        switchSigner(A);

        IERC721 nftContract = IERC721(address(nftOnChain));

        nftContract.mint();
        nftContract.approve(address(diamond), 0);

        a.create721Auction(
            LibAuctionStorage.Categories.ERC721,
            address(nftOnChain),
            0,
            block.timestamp + 3 days,
            0.5e18
        );

        switchSigner(B);

        AUCFacet erc20 = AUCFacet(address(diamond));
        uint256 totalSupply = erc20.totalSupply();

        erc20.approve(address(diamond), 1e18);

        a.BidOnAuction(0, 1e18);

        switchSigner(A);
        erc20.approve(address(diamond), 2e18);

        // last interaction before bid
        switchSigner(C);
        erc20.approve(address(diamond), 10e18);

        switchSigner(A);
        a.BidOnAuction(0, 2e18);

        assertEq(erc20.balanceOf(address(0)), 2e16);
        assertEq(erc20.balanceOf(DAO_ADDRESS), 2e16);
        assertEq(erc20.balanceOf(TEAM_ADDRESS), 2e16);
        assertEq(erc20.balanceOf(B), 200.03e18);
        assertEq(erc20.balanceOf(C), 10.01e18);
    }

    function testNftClaimFailBeforeEndTime() public {
        AuctionFacet a = AuctionFacet(address(diamond));
        switchSigner(A);

        IERC721 nftContract = IERC721(address(nftOnChain));

        nftContract.mint();
        nftContract.approve(address(diamond), 0);

        a.create721Auction(
            LibAuctionStorage.Categories.ERC721,
            address(nftOnChain),
            0,
            block.timestamp + 3 days,
            0.5e18
        );

        switchSigner(B);

        AUCFacet erc20 = AUCFacet(address(diamond));
        uint256 totalSupply = erc20.totalSupply();

        erc20.approve(address(diamond), 1e18);

        a.BidOnAuction(0, 1e18);

        switchSigner(C);
        erc20.approve(address(diamond), 2e18);
        a.BidOnAuction(0, 2e18);

        vm.expectRevert("Auction ongoing");
        a.claimNFT(0);
    }

    function testNftClaimFailWhenNotWinner() public {
        AuctionFacet a = AuctionFacet(address(diamond));
        switchSigner(A);

        IERC721 nftContract = IERC721(address(nftOnChain));

        nftContract.mint();
        nftContract.approve(address(diamond), 0);

        a.create721Auction(
            LibAuctionStorage.Categories.ERC721,
            address(nftOnChain),
            0,
            block.timestamp + 3 days,
            0.5e18
        );

        switchSigner(B);

        AUCFacet erc20 = AUCFacet(address(diamond));
        uint256 totalSupply = erc20.totalSupply();

        erc20.approve(address(diamond), 1e18);

        a.BidOnAuction(0, 1e18);

        switchSigner(C);
        erc20.approve(address(diamond), 2e18);
        a.BidOnAuction(0, 2e18);

        vm.warp(4 days);

        switchSigner(B);

        vm.expectRevert("Not winner");
        a.claimNFT(0);
    }

    function testNftClaimFailOnDoubleClaim() public {
        AuctionFacet a = AuctionFacet(address(diamond));
        switchSigner(A);

        IERC721 nftContract = IERC721(address(nftOnChain));

        nftContract.mint();
        nftContract.approve(address(diamond), 0);

        a.create721Auction(
            LibAuctionStorage.Categories.ERC721,
            address(nftOnChain),
            0,
            block.timestamp + 3 days,
            0.5e18
        );

        switchSigner(B);

        AUCFacet erc20 = AUCFacet(address(diamond));
        uint256 totalSupply = erc20.totalSupply();

        erc20.approve(address(diamond), 1e18);

        a.BidOnAuction(0, 1e18);

        switchSigner(C);
        erc20.approve(address(diamond), 2e18);
        a.BidOnAuction(0, 2e18);

        vm.warp(4 days);

        a.claimNFT(0);

        vm.expectRevert("Nft Claimed");
        a.claimNFT(0);
    }

    function testNftClaimOnWin() public {
        AuctionFacet a = AuctionFacet(address(diamond));
        switchSigner(A);

        IERC721 nftContract = IERC721(address(nftOnChain));

        nftContract.mint();
        nftContract.approve(address(diamond), 0);

        a.create721Auction(
            LibAuctionStorage.Categories.ERC721,
            address(nftOnChain),
            0,
            block.timestamp + 3 days,
            0.5e18
        );

        switchSigner(B);

        AUCFacet erc20 = AUCFacet(address(diamond));
        uint256 totalSupply = erc20.totalSupply();

        erc20.approve(address(diamond), 1e18);

        a.BidOnAuction(0, 1e18);

        switchSigner(C);
        erc20.approve(address(diamond), 2e18);
        a.BidOnAuction(0, 2e18);

        vm.warp(4 days);

        vm.expectEmit(false, false, false, false);
        emit LibAuctionStorage.AuctionEnded(0, C, 2e18);
        a.claimNFT(0);
    }

    function mkaddr(string memory name) public returns (address) {
        address addr = address(
            uint160(uint256(keccak256(abi.encodePacked(name))))
        );
        vm.label(addr, name);
        return addr;
    }

    function switchSigner(address _newSigner) public {
        address foundrySigner = 0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38;
        if (msg.sender == foundrySigner) {
            vm.startPrank(_newSigner);
            vm.deal(_newSigner, 10 ether);
        } else {
            vm.stopPrank();
            vm.startPrank(_newSigner);
        }
    }

    function generateSelectors(
        string memory _facetName
    ) internal returns (bytes4[] memory selectors) {
        string[] memory cmd = new string[](3);
        cmd[0] = "node";
        cmd[1] = "scripts/genSelectors.js";
        cmd[2] = _facetName;
        bytes memory res = vm.ffi(cmd);
        selectors = abi.decode(res, (bytes4[]));
    }

    function diamondCut(
        FacetCut[] calldata _diamondCut,
        address _init,
        bytes calldata _calldata
    ) external override {}
}
