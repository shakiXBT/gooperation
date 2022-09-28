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
    mapping(uint256 => address) gobblerOwnerships;

    /// @notice The user shares of Goo produced by the legendary gobbler owned by this contract
    /// @dev An user's goo share is equal to the total multiplier of the gobblers they deposited
    mapping(address => uint256) public getUserGooShare;

    uint256 public claimedMultiplier;

    /// @notice Data regarding the legendary auction
    LegendaryAuctionData public legendaryAuctionData;

    struct LegendaryAuctionData {
        bool wonAuction;
        uint256 legendaryId;
        uint256 legendaryPrice;
        mapping(address => uint256) gobblersBurnedByUser;
    }

    // EVENTS

    event GobblerDeposit(address indexed user, uint256 indexed gobblerId);
    event GobblerWithdraw(address indexed from, address indexed to, uint256 indexed gobblerId);
    event GooShareClaim(address indexed user, uint256 indexed gooAmount);
    event LegendaryAuctionWon(uint256 indexed legendaryId, uint256[] burnedGobblerIds);

    // ERRORS

    error Unauthorized();
    error DepositsDisabled();
    error ClaimsDisabled();
    error UserDidNotPartecipateInAuction();
    error InsufficientGobblerAmount(uint256 cost);

    // MODIFIERS

    modifier ownsGobbler(uint256 _gobblerId) {
        if (gobblerOwnerships[_gobblerId] != msg.sender) revert Unauthorized();

        _;
    }

    modifier onlyBeforeAuction() {
        if (legendaryAuctionData.wonAuction) revert DepositsDisabled();

        _;
    }

    modifier onlyAfterAuctionWin() {
        if (!legendaryAuctionData.wonAuction) revert ClaimsDisabled();

        _;
    }

    modifier onlyBelowAuctionStartingPrice() {
        (uint128 auctionprice,) = artGobblers.legendaryGobblerAuctionData();
        if (artGobblers.balanceOf(address(this)) > auctionprice) {
            revert DepositsDisabled();
        }

        _;
    }

    modifier ownsLegendaryFraction(address _user) {
        if (legendaryAuctionData.gobblersBurnedByUser[_user] == 0) {
            revert UserDidNotPartecipateInAuction();
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
    function onERC721Received(address _from, address, uint256 _gobblerId, bytes memory) public virtual override onlyBeforeAuction() onlyBelowAuctionStartingPrice() returns (bytes4) {
        // update user ownership
        gobblerOwnerships[_gobblerId] = _from;
        // update user multiplier
        getUserGooShare[_from] += artGobblers.getGobblerEmissionMultiple(_gobblerId);

        emit GobblerDeposit(_from, _gobblerId);
        return this.onERC721Received.selector;
    }

    /// @notice Withdraw a Gobbler to an address
    /// @param _to address to withdraw the Gobbler to
    /// @param _gobblerId ID of the Gobbler to withdraw
    function withdrawGobblerTo(address _to, uint256 _gobblerId) external ownsGobbler(_gobblerId) {
        // update user multiplier
        getUserGooShare[msg.sender] -= artGobblers.getGobblerEmissionMultiple(_gobblerId);
        artGobblers.safeTransferFrom(address(this), _to, _gobblerId);
        
        emit GobblerWithdraw(msg.sender, _to, _gobblerId);
    }

    /// @notice Mint a legendary Gobbler through Gooperation
    /// @param _gobblerIds IDs of the Gobblers that will be burned for the legendary Gobbler
    /// @dev we leave the logic to choose which gobblers to burn to the user calling this function.
    function mintLegendaryGobbler(uint256[] calldata _gobblerIds) public returns (uint256) {
        // checks on auction readiness and gobbler amount are already done by the ArtGobblers contract
        uint256 cost = artGobblers.legendaryGobblerPrice();
        uint256 mintedLegendaryId = artGobblers.mintLegendaryGobbler(_gobblerIds);
        emit LegendaryAuctionWon(mintedLegendaryId, _gobblerIds);
        
        uint256 gobblerId;
        for (uint256 i = 0; i < cost; ++i) {
            gobblerId = _gobblerIds[i];
            // save which gobblers have been burned for the legendary
            ++legendaryAuctionData.gobblersBurnedByUser[gobblerOwnerships[gobblerId]]; 
            // adjust user multipliers
            unchecked {
                getUserGooShare[gobblerOwnerships[gobblerId]] += artGobblers.getGobblerEmissionMultiple(gobblerId);
            }
        }
        // disable new gobbler deposits
        legendaryAuctionData.wonAuction = true;
        legendaryAuctionData.legendaryId = mintedLegendaryId;
        return mintedLegendaryId;
    }

    function depositGoo() public ownsLegendaryFraction(msg.sender) {

    }
    
    /// @notice withdraw all your Goo
    /// @dev can only be called once
    function claimUserGooShare() public onlyAfterAuctionWin() ownsLegendaryFraction(msg.sender) {
        uint256 totalMultiplier = artGobblers.getUserEmissionMultiple(address(this)) - claimedMultiplier;
        uint256 totalGoo = artGobblers.gooBalance(address(this));
        uint256 userMultiplier = getUserGooShare[msg.sender];
        uint256 userShare = (totalGoo / totalMultiplier) * (userMultiplier);

        // reset user share
        getUserGooShare[msg.sender] = 0;
        // keep count of the withdrawn multiplier
        claimedMultiplier += userMultiplier;

        // transform virtual Goo to ERC20 for withdrawing
        artGobblers.removeGoo(userShare);
        goo.transfer(msg.sender, userShare);
        emit GooShareClaim(msg.sender, userShare);
    }

    // VIEW FUNCTIONS

    function getGobblerOwner(uint256 _gobblerId) public view returns (address) {
        return gobblerOwnerships[_gobblerId];
    }

    function getUserBurnAmount(address _user) external view returns (uint256) {
        return legendaryAuctionData.gobblersBurnedByUser[_user];
    }

}