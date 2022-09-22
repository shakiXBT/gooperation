// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {ArtGobblers} from "art-gobblers/ArtGobblers.sol";
import {Goo} from "art-gobblers/Goo.sol";
import {ERC721TokenReceiver} from "solmate/tokens/ERC721.sol";

contract Gooperation is ERC721TokenReceiver {

    ArtGobblers public immutable artGobblers;

    /// @dev gobblerOwnerships[userAddress][gobblerId] == true
    mapping(address => mapping(uint256 => bool)) public gobblerOwnerships;

    /// @param _artGobblers ArtGobblers contract address
    constructor(ArtGobblers _artGobblers) {
        artGobblers = _artGobblers;
    }

    function withdrawGobblerTo(address to, uint256 gobblerId) public {
        require(gobblerOwnerships[msg.sender][gobblerId], "UNAUTHORIZED WITHDRAWAL");
        artGobblers.safeTransferFrom(address(this), to, gobblerId);
    }

    function withdrawGobbler(uint256 gobblerId) public {
        withdrawGobblerTo(msg.sender, gobblerId);
    }

    function bidLegendaryGobbler() public {}

    function onERC721Received(address, address to, uint256 gobblerId, bytes memory) public virtual override returns (bytes4) {
        gobblerOwnerships[to][gobblerId] = true;
        return this.onERC721Received.selector;
    }

    function getGobblerOwnership(address owner, uint256 gobblerId) public view returns (bool) {
        return gobblerOwnerships[owner][gobblerId];
    }
}