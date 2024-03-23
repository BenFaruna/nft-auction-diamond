// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "../contracts/interfaces/IDiamondCut.sol";
import "../contracts/facets/DiamondCutFacet.sol";
import "../contracts/facets/DiamondLoupeFacet.sol";
import "../contracts/facets/OwnershipFacet.sol";
import "forge-std/Test.sol";
import "../contracts/Diamond.sol";

import "../contracts/libraries/LibDiamond.sol";

import "../contracts/facets/AUCFacet.sol";

contract DiamondDeployer is Test, IDiamondCut {
    //contract types of facets to be deployed
    Diamond diamond;
    DiamondCutFacet dCutFacet;
    DiamondLoupeFacet dLoupe;
    OwnershipFacet ownerF;
    AUCFacet aucF;

    address A = address(0xa);
    address B = address(0xb);
    address C = address(0xc);

    function setUp() public {
        //deploy facets
        dCutFacet = new DiamondCutFacet();
        diamond = new Diamond(address(this), address(dCutFacet));
        dLoupe = new DiamondLoupeFacet();
        ownerF = new OwnershipFacet();
        aucF = new AUCFacet();

        //upgrade diamond with facets

        //build cut struct
        FacetCut[] memory cut = new FacetCut[](3);

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
                facetAddress: address(aucF),
                action: FacetCutAction.Add,
                functionSelectors: generateSelectors("AUCFacet")
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
        assertEq(a.balanceOf(C), 120e18);
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
