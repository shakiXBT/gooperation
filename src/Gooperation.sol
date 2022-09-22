// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {ArtGobblers} from "art-gobblers/ArtGobblers.sol";
import {Goo} from "art-gobblers/Goo.sol";

contract Gooperation {

    ArtGobblers public immutable artGobblers;

    /// @param _artGobblers ArtGobblers contract address
    constructor(ArtGobblers _artGobblers) {
        artGobblers = _artGobblers;
    }



}