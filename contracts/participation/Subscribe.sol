pragma solidity ^0.4.8;

import "./SubscribeProtocol.sol";
import "../assets/AssetProtocol.sol";
import "../dependencies/Owned.sol";
import "../dependencies/SafeMath.sol";
import "../assets/EtherToken.sol";
import "../CoreProtocol.sol";



/// @title Subscribe Contract
/// @author Melonport AG <team@melonport.com>
/// @notice Simple and static Subscribe Module.
contract Subscribe is SubscribeProtocol, SafeMath, Owned {

    // FIELDS

    // Constant fields
    uint public constant decimals = 18;
    uint public constant BASE_UNIT_OF_SHARES = 1;
    uint public constant INITIAL_SHARE_PRICE = 10 ** decimals;

    // EVENTS

    event SharesCreated(address indexed byParticipant, uint atTimestamp, uint numShares); // Participation
    event SharesAnnihilated(address indexed byParticipant, uint atTimestamp, uint numShares);
    event Refund(address to, uint value);

    // MODIFIERS

    modifier msg_value_at_least(uint x) {
        assert(msg.value >= x);
        _;
    }

    modifier msg_value_past_zero() {
        assert(msg.value > 0);
        _;
    }

    modifier past_zero(uint x) {
        assert(x > 0);
        _;
    }

    modifier this_balance_at_least(uint x) {
        assert(this.balance >= x);
        _;
    }

    modifier is_at_least(uint x, uint y) {
        assert(x >= y);
        _;
    }

    // CONSTANT METHODS

    // NON-CONSTANT METHODS

    function Subscribe() {}

    /// Pre: Investor approves spending of reference asset of core to this contract
    /// Post: Invest in a fund by creating shares
    /* Rem:
     *  This is can be seen as a none persistent all or nothing limit order, where:
     *  amount == wantedShares and price == wantedShares/offeredAmount [Shares / Reference Asset]
     */
    function createSharesWithReferenceAsset(address ofCore, uint wantedShares, uint offeredAmount)
        past_zero(wantedShares)
    {
        CoreProtocol Core = CoreProtocol(ofCore);
        uint sharePrice = Core.calcSharePrice(); // Denoted in [referenceAsset / share]
        uint offeredValue = offeredAmount; // Offered value relative to reference token
        uint actualValue = sharePrice * wantedShares / BASE_UNIT_OF_SHARES; // [referenceAsset / share] * [Base unit amount of shares] / [Base unit of shares]
        allocateEtherInvestment(ofCore, actualValue, offeredValue, wantedShares);
    }

    /// Pre: EtherToken as Asset in Universe
    /// Post: Invest in a fund by creating shares
    function allocateEtherInvestment(
        address ofCore,
        uint actualValue,
        uint offeredValue,
        uint wantedShares
    )
        internal
        is_at_least(offeredValue, actualValue)
    {
        //TODO check recipient
        address referenceAsset = Core.getReferenceAsset();
        AssetProtocol Asset = AssetProtocol(address(referenceAsset));        
        assert(Asset.transferFrom(msg.sender, this, actualValue)); // Send funds from investor to owner
        CoreProtocol Core = CoreProtocol(ofCore);
        Core.createSharesViaSubscribeModule(msg.sender, wantedShares);
        SharesCreated(msg.sender, now, wantedShares);
    }
}
