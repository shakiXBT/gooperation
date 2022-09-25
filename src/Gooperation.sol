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
    error ClaimsDisabled();
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

    modifier onlyAfterAuctionWin() {
        if (!wonAuction) revert ClaimsDisabled();

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

    /// @dev Implement the ERC721TokenReceiver interface
    function onERC721Received(address from, address, uint256 gobblerId, bytes memory) public virtual override onlyBeforeAuction() onlyBelowAuctionStartingPrice() returns (bytes4) {
        // update user ownership
        gobblerOwnerships[from][gobblerId] = true;
        // update user multiplier
        getUserGooShare[from] += artGobblers.getGobblerEmissionMultiple(gobblerId);

        return this.onERC721Received.selector;
    }

    /// @notice Withdraw a Gobbler to an address
    /// @param to address to withdraw the Gobbler to
    /// @param gobblerId ID of the Gobbler to withdraw
    function withdrawGobblerTo(address to, uint256 gobblerId) external ownsGobbler(gobblerId) {
        artGobblers.safeTransferFrom(address(this), to, gobblerId);
        // update user multiplier
        getUserGooShare[msg.sender] -= artGobblers.getGobblerEmissionMultiple(gobblerId);
    }

    /// @notice Mint a legendary Gobbler through Gooperation
    /// @param gobblerIds IDs of the Gobblers that will be burned for the legendary Gobbler
    /// @dev we leave the logic to choose which gobblers to burn to the user calling this function.
    function mintLegendaryGobbler(uint256[] calldata gobblerIds) public returns (uint256) {
        // checks on auction readiness and gobbler amount are already done by the ArtGobblers contract
        mintedLegendaryId = artGobblers.mintLegendaryGobbler(gobblerIds);
        // disable new gobbler deposits
        wonAuction = true;
        return mintedLegendaryId;
    }

    // TODO
    /// @dev requires approval
    function depositGoo(uint256 _amount) public {
        require(goo.balanceOf(msg.sender) >= _amount, "you dont have enough goo");
        require(goo.allowance(msg.sender, address(this)) >= _amount, "Check the token allowance");
        goo.transferFrom(msg.sender, address(this), _amount);
        // burn goo erc20 to add virtual goo balance
        // artgobblers.addGoo()
        // re-calculate user multiplier based on goo deposit
    }
    
    // TODO
    function claimUserGooShare() public onlyAfterAuctionWin() {
        uint256 totalGoo = artGobblers.gooBalance(address(this));
        
        // uint256 userShare = totalGoo.divWadDown(artGobblers.getUserEmissionMultiple(address(this)));
        uint256 userShare = (totalGoo / artGobblers.getUserEmissionMultiple(address(this))) * (getUserGooShare[msg.sender] * 2);
        getUserGooShare[msg.sender] = 0;
        // transform virtual Goo to ERC20 for withdrawing
        artGobblers.removeGoo(userShare);
        goo.transferFrom(address(this), msg.sender, userShare);
    }

    /*
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

    function getUserTotalGooShare(address user) public view returns (uint256) {
        uint256 gooperationShare = artGobblers.gooBalance(address(this));
        return (gooperationShare / artGobblers.getUserEmissionMultiple(address(this))) * getUserGooShare[user];

    }

    function getUserTotalGooShare() public view returns (uint256) {
        return getUserTotalGooShare(msg.sender);
    }
}