// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {DSTestPlus} from "solmate/test/utils/DSTestPlus.sol";
import {stdError} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {Gooperation} from "../src/Gooperation.sol";
import {Utilities} from "./utils/Utilities.sol";
import {ArtGobblers} from "art-gobblers/ArtGobblers.sol";
import {Pages} from "art-gobblers/Pages.sol";
import {Goo} from "art-gobblers/Goo.sol";
import {GobblerReserve} from "art-gobblers/utils/GobblerReserve.sol";
import {RandProvider} from "art-gobblers/utils/rand/RandProvider.sol";
import {ChainlinkV1RandProvider} from "art-gobblers/utils/rand/ChainlinkV1RandProvider.sol";
import {LinkToken} from "./utils/mocks/LinkToken.sol";
import {VRFCoordinatorMock} from "chainlink/v0.8/mocks/VRFCoordinatorMock.sol";

contract GooperationTest is DSTestPlus {

    // GOOPERATION VARS

    
    Gooperation public gooperation;

    // ART GOBBLERS VARS

    Vm internal immutable vm = Vm(HEVM_ADDRESS);

    Utilities internal utils;
    address payable[] internal users;

    ArtGobblers internal gobblers;
    VRFCoordinatorMock internal vrfCoordinator;
    LinkToken internal linkToken;
    Goo internal goo;
    Pages internal pages;
    GobblerReserve internal team;
    GobblerReserve internal community;
    RandProvider internal randProvider;

    bytes32 private keyHash;
    uint256 private fee;

    uint256[] ids;
    
    function setUp() public {

        gobblerSetup();
        gooperation = new Gooperation(gobblers);
    }

    function gobblerSetup() public {
        
        utils = new Utilities();
        users = utils.createUsers(5);
        linkToken = new LinkToken();
        vrfCoordinator = new VRFCoordinatorMock(address(linkToken));

        //gobblers contract will be deployed after 4 contract deploys, and pages after 5
        address gobblerAddress = utils.predictContractAddress(address(this), 4);
        address pagesAddress = utils.predictContractAddress(address(this), 5);

        team = new GobblerReserve(ArtGobblers(gobblerAddress), address(this));
        community = new GobblerReserve(ArtGobblers(gobblerAddress), address(this));
        randProvider = new ChainlinkV1RandProvider(
            ArtGobblers(gobblerAddress),
            address(vrfCoordinator),
            address(linkToken),
            keyHash,
            fee
        );

        goo = new Goo(
            // Gobblers:
            utils.predictContractAddress(address(this), 1),
            // Pages:
            utils.predictContractAddress(address(this), 2)
        );

        gobblers = new ArtGobblers(
            keccak256(abi.encodePacked(users[0])),
            block.timestamp,
            goo,
            Pages(pagesAddress),
            address(team),
            address(community),
            randProvider,
            "base",
            ""
        );

        pages = new Pages(block.timestamp, goo, address(0xBEEF), gobblers, "");
    }

    // GOOPERATION TESTS

    /// @dev check Gobbler deposit to Gooperation
    function testGobblerDeposit() public {
        address user = users[0];
        bytes32[] memory proof;
        vm.prank(user);
        gobblers.claimGobbler(proof);
        // verify gobbler ownership
        assertEq(gobblers.ownerOf(1), user);
        assertEq(gobblers.balanceOf(user), 1);

        // deposit
        vm.prank(user);
        gobblers.safeTransferFrom(user, address(gooperation), 1);

        // verify gooperation ownership
        assertEq(gobblers.ownerOf(1), address(gooperation));
        assertEq(gobblers.balanceOf(address(gooperation)), 1);
    }
    
    /// @dev check Gobbler withdrawal from Gooperation
    function testSendToGooperation() public {
        address user = users[0];
        bytes32[] memory proof;
        vm.prank(user);
        gobblers.claimGobbler(proof);
        // verify gobbler ownership
        assertEq(gobblers.ownerOf(1), user);
        assertEq(gobblers.balanceOf(user), 1);

        // deposit
        vm.prank(user);
        gobblers.safeTransferFrom(user, address(gooperation), 1);

        // withdraw
        vm.prank(user);
        gooperation.withdrawGobblerTo(user, 1);

        assertEq(gobblers.ownerOf(1), user);
        assertEq(gobblers.balanceOf(user), 1);
    }
}
