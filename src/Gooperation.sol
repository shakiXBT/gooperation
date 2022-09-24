// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {ArtGobblers} from "art-gobblers/ArtGobblers.sol";
import {Goo} from "art-gobblers/Goo.sol";
import {ERC721TokenReceiver} from "solmate/tokens/ERC721.sol";

contract Gooperation is ERC721TokenReceiver {

    ArtGobblers public immutable artGobblers;
    Goo public immutable goo;

    /// @dev gobblerOwnerships[userAddress][gobblerId] == true
    mapping(address => mapping(uint256 => bool)) public gobblerOwnerships;

    mapping(address => uint256) public getUserMultiplier;

    mapping(address => uint256) public gooOwnerships;

    bool public wonAuction;

    // ERRORS

    error Unauthorized();
    error DepositsDisabled();

    modifier ownsGobbler(uint256 _gobblerId) {
        if (!gobblerOwnerships[msg.sender][_gobblerId]) revert Unauthorized();

        _;
    }

    modifier onlyBeforeAuction() {
        if (wonAuction) revert DepositsDisabled();

        _;
    }

    modifier onlyBelowAuctionStartingPrice() {
        (uint128 auctionprice,) = artGobblers.legendaryGobblerAuctionData();
        if (artGobblers.balanceOf(address(this)) > auctionprice) {
            revert DepositsDisabled();
        }

        _;
    }

    /// @notice Sets the addresses of relevant contracts
    /// @param _artGobblers Address of the ArtGobblers contract
    /// @param _goo Address of the Goo contract
    constructor(ArtGobblers _artGobblers, Goo _goo) {
        artGobblers = _artGobblers;
        goo = _goo;
    }

    function withdrawGobblerTo(address to, uint256 gobblerId) public ownsGobbler(gobblerId) {
        artGobblers.safeTransferFrom(address(this), to, gobblerId);
    }

    function withdrawGobbler(uint256 gobblerId) public {
        withdrawGobblerTo(msg.sender, gobblerId);
    }

    function bidLegendaryGobbler() public {}

    function onERC721Received(address from, address, uint256 gobblerId, bytes memory) public virtual override onlyBeforeAuction() onlyBelowAuctionStartingPrice() returns (bytes4) {
        // update user ownership
        gobblerOwnerships[from][gobblerId] = true;
        // update user multiplier
        getUserMultiplier[from] += artGobblers.getGobblerEmissionMultiple(gobblerId);

        return this.onERC721Received.selector;
    }

    function getGobblerOwnership(address owner, uint256 gobblerId) public view returns (bool) {
        return gobblerOwnerships[owner][gobblerId];
    }

    /// @notice requires approval
    function depositGoo(uint256 _amount) public {
        goo.transferFrom(msg.sender, address(this), _amount);
    }

    /*
    function depositGoo() {
        // check if approved for transfer or revert? maybe dont need since it reverts by itself
     

        // burn goo erc20 to add virtual goo balance
        artgobblers.addGoo()
    }

    function withdrawGoo() {
        // burn virtual goo to withdraw goo balance
        // will need to keep track of goo belonging to a user
        artgobblers.removeGoo()
    }


    */
}