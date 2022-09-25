// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {ArtGobblers} from "art-gobblers/ArtGobblers.sol";
import {Goo} from "art-gobblers/Goo.sol";
import {ERC721TokenReceiver} from "solmate/tokens/ERC721.sol";

/// @title Gooperation
/// @author shakiXBT
/// @notice A contract for Gobblers to cooperate towards buying legendary Gobblers
contract Gooperation is ERC721TokenReceiver {

    /// @notice The address of the Art Gobblers contract
    ArtGobblers public immutable artGobblers;
    
    /// @notice The address of the Goo ERC20 token contract
    Goo public immutable goo;

    /// @notice The user ownerships of Gobblers deposited in this contract
    /// @dev gobblerOwnerships[userAddress][gobblerId] == true
    mapping(address => mapping(uint256 => bool)) public gobblerOwnerships;

    /// @notice The user shares of Goo produced by the legendary gobbler owned by this contract
    /// @dev An user's goo share is equal to the total multiplier of the gobblers they deposited
    mapping(address => uint256) public getUserGooShare;

    /// @notice The Gobbler ID of the legendary Gobbler minted through this contract
    uint256 public mintedLegendaryId;

    /// @notice Flag for knowing if the contract has already won a legendary Gobbler auction
    bool public wonAuction;

    // ERRORS

    error Unauthorized();
    error DepositsDisabled();
    error InsufficientGobblerAmount(uint256 cost);

    // MODIFIERS

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

    // CONSTRUCTOR

    /// @notice Sets the addresses of relevant contracts
    /// @param _artGobblers Address of the ArtGobblers contract
    /// @param _goo Address of the Goo contract
    constructor(ArtGobblers _artGobblers, Goo _goo) {
        artGobblers = _artGobblers;
        goo = _goo;
    }

    // FUNCTIONS

    function onERC721Received(address from, address, uint256 gobblerId, bytes memory) public virtual override onlyBeforeAuction() onlyBelowAuctionStartingPrice() returns (bytes4) {
        // update user ownership
        gobblerOwnerships[from][gobblerId] = true;
        // update user multiplier
        getUserGooShare[from] += artGobblers.getGobblerEmissionMultiple(gobblerId);

        return this.onERC721Received.selector;
    }

    function withdrawGobblerTo(address to, uint256 gobblerId) external ownsGobbler(gobblerId) {
        artGobblers.safeTransferFrom(address(this), to, gobblerId);
        // update user multiplier
        getUserGooShare[msg.sender] -= artGobblers.getGobblerEmissionMultiple(gobblerId);
    }

    /// @dev we leave the logic to choose which gobblers to burn to the user calling this function.
    function mintLegendaryGobbler(uint256[] calldata gobblerIds) public returns (uint256) {
        // checks on auction readiness and gobbler amount are already done by the ArtGobblers contract
        mintedLegendaryId = artGobblers.mintLegendaryGobbler(gobblerIds);
        // disable new gobbler deposits
        wonAuction = true;
        return mintedLegendaryId;
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

    // VIEW FUNCTIONS

    function getGobblerOwnership(address owner, uint256 gobblerId) public view returns (bool) {
        return gobblerOwnerships[owner][gobblerId];
    }
}