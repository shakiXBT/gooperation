// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {ArtGobblers} from "art-gobblers/ArtGobblers.sol";
import {Goo} from "art-gobblers/Goo.sol";
import {ERC721TokenReceiver} from "solmate/tokens/ERC721.sol";

contract Gooperation is ERC721TokenReceiver {

    ArtGobblers public immutable artGobblers;

    /// @param _artGobblers ArtGobblers contract address
    constructor(ArtGobblers _artGobblers) {
        artGobblers = _artGobblers;
    }

    /// @dev requires approval
    function depositGobbler() public {}

    function withdrawGobbler() public {}

    function bidLegendaryGobbler() public {}

    function onERC721Received(address, address, uint256, bytes memory) public virtual override returns (bytes4) {
        // TODO add logic for receiving gobbler
        return this.onERC721Received.selector;
    }

}