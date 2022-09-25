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
        assert(gooperation.getGobblerOwnership(user, 1));

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

    // TODO actual test w/ assert, for now just used to debug contracts
    function testGooIssuance() public {
        address user = users[0];
        bytes32[] memory proof;
        vm.prank(user);
        gobblers.claimGobbler(proof);

        vm.prank(address(gobblers));
        goo.mintForGobblers(user, 1000000);

        vm.prank(user);
        gobblers.addGoo(1000000);

        // warp for reveal
        vm.warp(block.timestamp + 1 days);
        setRandomnessAndReveal(1, "seed");

        emit log_named_uint("user multipler:", gobblers.getUserEmissionMultiple(user));
        emit log_named_uint("gobbler multipler:", gobblers.getGobblerEmissionMultiple(1));

        emit log_named_uint("initial goo balance erc20", goo.balanceOf(user));
        emit log_named_uint("initial goo balance virtual", gobblers.gooBalance(user));
        emit log_named_uint("initial timestamp: ", block.timestamp); 

        // warp to accrue goo
        vm.warp(block.timestamp + 100);

        emit log_named_uint("final goo balance erc20", goo.balanceOf(user));
        emit log_named_uint("final goo balance virtual", gobblers.gooBalance(user));
        emit log_named_uint("final timestamp: ", block.timestamp);
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

        assertEq(userMultiplier * 2, gobblers.getUserEmissionMultiple(address(gooperation)));
        emit log_named_uint("gooperation has final multiplier of", gobblers.getUserEmissionMultiple(address(gooperation)));
    }

    function testDepositGoo() public {
        address user = users[0];
        bytes32[] memory proof;
        vm.prank(user);
        gobblers.claimGobbler(proof);

        vm.prank(address(gobblers));
        goo.mintForGobblers(user, 1e18);
        assertEq(goo.balanceOf(user), 1e18);

        // approve
        vm.prank(user);
        goo.approve(address(gooperation), 1e18);

        // deposit goo into gooperation
        vm.prank(user);
        gooperation.depositGoo(1e18);
        // TODO check other logic
    }

    function testClaimUserGooShare() public {
        // win auction
        // try withdrawing goo
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
