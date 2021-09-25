//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract Ethernauts is ERC721Enumerable, Ownable {
    using Address for address payable;

    // Can be set only once on deploy
    uint public immutable maxTokens;
    uint public immutable maxGiftable;

    // Can be changed by owner
    string public baseTokenURI;
    uint public mintPrice;
    uint public earlyMintPrice;

    // private
    uint private _tokensGifted;
    mapping(bytes32 => bool) _couponUsed;

    // Three different sale stages:
    enum SaleState {
        Paused, // No one can mint, except the owner via gifting (default)
        Early, // Only community can mint, at a discount using signed messages
        Open // Anyone can mint
    }
    SaleState public saleState;

    constructor(
        uint maxGiftable_,
        uint maxTokens_,
        uint mintPrice_,
        uint earlyMintPrice_
    ) ERC721("Ethernauts", "NAUTS") {
        require(maxGiftable_ <= 100, "Max giftable supply too large");
        require(maxTokens_ <= 10000, "Max token supply too large");

        maxGiftable = maxGiftable_;
        maxTokens = maxTokens_;
        mintPrice = mintPrice_;
        earlyMintPrice = earlyMintPrice_;

        saleState = SaleState.Paused;
    }

    // ----------
    // Modifiers
    // ----------

    modifier notOnState(SaleState state_) {
        require(saleState != state_, "Not allowed in current state");
        _;
    }

    // --------------------
    // Public external ABI
    // --------------------

    function mint() external payable notOnState(SaleState.Paused) notOnState(SaleState.Early) {
        require(msg.value >= mintPrice, "bad msg.value");
        require(availableToMint() > 0, "No available supply");

        _mintNext(msg.sender);
    }

    function mintEarly(bytes memory signedCoupon) external payable notOnState(SaleState.Paused) {
        require(msg.value >= earlyMintPrice, "bad msg.value");
        require(availableToMint() > 0, "No available supply");

        _verifyCoupon(msg.sender, signedCoupon);
        _mintNext(msg.sender);
    }

    function tokensGifted() public view returns (uint) {
        return _tokensGifted;
    }

    function availableSupply() public view returns (uint) {
        return maxTokens - totalSupply();
    }

    function availableToMint() public view returns (uint) {
        return availableSupply() - availableToGift();
    }

    function availableToGift() public view returns (uint) {
        return maxGiftable - _tokensGifted;
    }

    function exists(uint tokenId) public view returns (bool) {
        return _exists(tokenId);
    }

    // -----------------------
    // Protected external ABI
    // -----------------------

    function gift(address to) external onlyOwner {
        require(_tokensGifted < maxGiftable, "No more Ethernauts can be gifted");

        _mintNext(to);

        _tokensGifted += 1;
    }

    function setMintPrice(uint newMintPrice) external onlyOwner {
        mintPrice = newMintPrice;
    }

    function setEarlyMintPrice(uint newEarlyMintPrice) external onlyOwner {
        earlyMintPrice = newEarlyMintPrice;
    }

    function setBaseURI(string memory baseTokenURI_) public onlyOwner {
        baseTokenURI = baseTokenURI_;
    }

    function setSaleState(SaleState newState_) public onlyOwner {
        require(newState_ != saleState, "Invalid new state");

        saleState = newState_;
    }

    function withdraw(address payable beneficiary) external onlyOwner {
        beneficiary.sendValue(address(this).balance);
    }

    // -------------------
    // Private functions
    // -------------------

    function _verifyCoupon(address sender, bytes memory signedCoupon) private {
        bytes32 messageHash = ECDSA.toEthSignedMessageHash(sender);
        require(!_couponUsed[messageHash], "Coupon already used");

        address retrievedSigner = ECDSA.recover(messageHash, signedCoupon);
        require(couponSigner == retrievedSigner, "Fake coupon");

        _couponUsed[messageHash] = true;
    }

    function _baseURI() private view virtual override returns (string memory) {
        return baseTokenURI;
    }

    function _mintNext(address to) private {
        uint tokenId = totalSupply();

        _mint(to, tokenId);
    }

    function _mint(address to, uint tokenId) private virtual override {
        require(totalSupply() < maxTokens, "No available supply");

        super._mint(to, tokenId);
    }
}
