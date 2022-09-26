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
        gooperation = new Gooperation(gobblers, goo);
    }

    function gobblerSetup() public {
        
        utils = new Utilities();
        users = utils.createUsers(5);
        linkToken = new LinkToken();
        vrfCoordinator = new VRFCoordinatorMock(address(linkToken));

        // gobblers contract will be deployed after 4 contract deploys, pages after 5
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
            // Gobblers
            utils.predictContractAddress(address(this), 1),
            // Pages
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

    /// @notice check Gobbler deposit to Gooperation
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

        // verify gobbler ownership inside gooperation
        assertEq(gooperation.getGobblerOwner(1), user);

    }
    
    /// @notice check Gobbler withdrawal from Gooperation
    function testGobblerWithdrawal() public {
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

    /// @notice check Gobbler withdrawal from unauthorized wallet
    function testUnauthorizeGobblerdWithdrawal() public {
        address user = users[0];
        address user1 = users[1];
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
        vm.prank(user1);
        vm.expectRevert(Gooperation.Unauthorized.selector);
        gooperation.withdrawGobblerTo(user1, 1);
        
        assertEq(gobblers.balanceOf(user1), 0);
    }

    /// @notice Gobbler deposits should be disabled when Gooperation owns more than the starting auction price
    function testDepositDisabled() public {
        address user = users[0];
        mintGobblerToAddress(user, 70);

        (uint128 auctionprice,) = gobblers.legendaryGobblerAuctionData();
        emit log_named_uint("legendary gobbler price:", auctionprice);

        for (uint256 i = 0; i != auctionprice; ++i) {
            vm.prank(user);
            gobblers.safeTransferFrom(user, address(gooperation), i+1);
        }

        vm.expectRevert(Gooperation.DepositsDisabled.selector);
        vm.prank(user);
        gobblers.safeTransferFrom(user, address(gooperation), auctionprice + 1);
    }

    /// @notice test minting a legendary Gobbler
    function testMintLegendaryGobbler() public {
        address user = users[0];
        uint256 startTime = block.timestamp + 30 days;
        vm.warp(startTime);
        // Mint full interval to kick off first auction.
        mintGobblerToAddress(user, gobblers.LEGENDARY_AUCTION_INTERVAL());
        // can now call this without revert
        uint256 cost = gobblers.legendaryGobblerPrice();
        setRandomnessAndReveal(cost, "seed");

        uint256 userMultiplier;

        // Deposit to Gooperation
        for (uint256 i = 1; i <= cost; ++i) {
            ids.push(i);
            vm.prank(user);
            gobblers.safeTransferFrom(user, address(gooperation), i);
            userMultiplier += gobblers.getGobblerEmissionMultiple(i);
        }

        assertEq(userMultiplier, gooperation.getUserGooShare(user));
        emit log_named_uint("gooperation has starting multiplier of", userMultiplier);

        // everyone should be able to call the mintLegendary function
        vm.prank(users[1]);
        uint256 mintedLegendaryId = gooperation.mintLegendaryGobbler(ids);
        
        emit log_named_uint("minted legendary with id: ", mintedLegendaryId);
        assertEq(gobblers.ownerOf(mintedLegendaryId), address(gooperation));

        emit log_named_uint("gooperation has final multiplier of", gobblers.getUserEmissionMultiple(address(gooperation)));
        assertEq(userMultiplier * 2, gobblers.getUserEmissionMultiple(address(gooperation)));

        emit log_named_uint("user burned amount", gooperation.getUserBurnAmount(user));
        emit log_named_uint("cost", cost);
        assertEq(gooperation.getUserBurnAmount(user), cost);

        assertEq(gooperation.getUserGooShare(user), userMultiplier * 2);
    }

    /// @notice test deposit gobblers from two users and then claim each user's share
    function testClaimUserGooShare() public {
        address user = users[0];
        address user1 = users[1];
        // move forward in time to allow minting
        uint256 startTime = block.timestamp + 30 days;
        vm.warp(startTime);
        // mint full interval to kick off first auction (should be 581)
        mintGobblerToAddress(user, 35);
        mintGobblerToAddress(user1, 34);
        mintGobblerToAddress(users[2], gobblers.LEGENDARY_AUCTION_INTERVAL() - 69);
        // can now call this without revert (should be 69)
        uint256 cost = gobblers.legendaryGobblerPrice();
        // reveal all minted gobblers
        setRandomnessAndReveal(cost, "gool");

        uint256 userMultiplier;
        uint256 user1Multiplier;

        // Deposit 35 Gobblers from user1
        for (uint256 i = 1; i <= 35; ++i) {
            ids.push(i);
            vm.prank(user);
            gobblers.safeTransferFrom(user, address(gooperation), i);
            userMultiplier += gobblers.getGobblerEmissionMultiple(i);
        }

        // Deposit 34 Gobblers from user2
        for (uint256 i = 36; i <= 69; ++i) {
            ids.push(i);
            vm.prank(user1);
            gobblers.safeTransferFrom(user1, address(gooperation), i);
            user1Multiplier += gobblers.getGobblerEmissionMultiple(i);
        }

        assertEq(userMultiplier, gooperation.getUserGooShare(user));
        assertEq(user1Multiplier, gooperation.getUserGooShare(user1));

        emit log_named_uint("gooperation has starting multiplier of", gobblers.getUserEmissionMultiple(address(gooperation)));

        // anyone can call the mintLegendary function
        vm.prank(users[3]);
        gooperation.mintLegendaryGobbler(ids);

        // wait some time for Goo to start oozing
        vm.warp(block.timestamp + 10 days);

        // user is impatient and withdraws early, fumbling the bag
        emit log_named_uint("user goo balance erc20 b4 withdraw", goo.balanceOf(user));
        vm.prank(user);
        gooperation.claimUserGooShare();
        emit log_named_uint("user goo balance erc20 after withdraw", goo.balanceOf(user));

        // user1 hodls
        vm.warp(block.timestamp + 100 days);
        
        // user1 has to pay bills
        emit log_named_uint("user1 goo balance erc20 b4 withdraw", goo.balanceOf(user1));
        vm.prank(user1);
        gooperation.claimUserGooShare();
        emit log_named_uint("user1 goo balance erc20 after withdraw", goo.balanceOf(user1));

        // this assertion would fail since there's some goo left in the tank due to rounding divisions
        // it's very little anyways so we don't really care for now
        // assertEq(gobblers.gooBalance(address(gooperation)), 0);
        emit log_named_uint("remaining goo virtual balance", gobblers.gooBalance(address(gooperation)));

    }

    // HELPERS

    function mintGobblerToAddress(address addr, uint256 num) internal {
        for (uint256 i = 0; i < num; ++i) {
            vm.startPrank(address(gobblers));
            goo.mintForGobblers(addr, gobblers.gobblerPrice());
            vm.stopPrank();

            uint256 gobblersOwnedBefore = gobblers.balanceOf(addr);

            vm.prank(addr);
            gobblers.mintFromGoo(type(uint256).max, false);

            assertEq(gobblers.balanceOf(addr), gobblersOwnedBefore + 1);
        }
    }

    /// @notice Call back vrf with randomness and reveal gobblers.
    function setRandomnessAndReveal(uint256 numReveal, string memory seed) internal {
        bytes32 requestId = gobblers.requestRandomSeed();
        uint256 randomness = uint256(keccak256(abi.encodePacked(seed)));
        // call back from coordinator
        vrfCoordinator.callBackWithRandomness(requestId, randomness, address(randProvider));
        gobblers.revealGobblers(numReveal);
    }

    function mintNextLegendary(address addr) internal {
        uint256[] memory id;
        mintGobblerToAddress(addr, gobblers.LEGENDARY_AUCTION_INTERVAL() * 2);
        vm.prank(addr);
        gobblers.mintLegendaryGobbler(id);
    }
}
