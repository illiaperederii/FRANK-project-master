// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract FRANK is ERC721Enumerable, Ownable, ERC721Burnable {
    using SafeMath for uint256;
    using Counters for Counters.Counter;

    Counters.Counter private _tokenIdTracker;

    uint256 public constant MAX_ELEMENTS = 40;
    uint256 public constant MAX_BY_MINT = 20;
    uint256 constant public MAX_MINT_WHITELIST = 20;
    uint256 constant public REVEAL_TIMESTAMP = 0;

    string public baseTokenURI;
    uint256 public mintPrice = 0.08 ether;
    uint256 public startingIndex;
    uint256 public startingIndexBlock;
    

    struct Whitelist {
        address addr;
        uint claimAmount;
        uint hasMinted;
    }
    mapping(address => Whitelist) public whitelist;
    
    address[] whitelistAddr;

    bool public saleIsActive = false;
    bool public privateSaleIsActive = true;

    constructor(address[] memory addrs, uint[] memory claimAmounts) ERC721("Frank and Beans", "FRANK") {
        whitelistAddr = addrs;
        for(uint i = 0; i < whitelistAddr.length; i++) {
            addAddressToWhitelist(whitelistAddr[i], claimAmounts[i]);
        }
    }

    function _totalSupply() internal view returns (uint) {
        return _tokenIdTracker.current();
    }
    function totalMint() public view returns (uint256) {
        return _totalSupply();
    }

    function mint(uint256 _count) public payable {
        uint256 total = _totalSupply();
        require(saleIsActive, "Sale must be active to mint");
        require(total.add(_count) <= MAX_ELEMENTS, "Max limit");
        require(total <= MAX_ELEMENTS, "Sale end");
        require(_count <= MAX_BY_MINT, "Exceeds maximum number of mintable tokens at a time");
        require(msg.value >= price(_count), "Value below price");

        if(privateSaleIsActive) {
            require(_count <= MAX_MINT_WHITELIST, "Above max tx count");
            require(isWhitelisted(msg.sender), "Is not whitelisted");
            require(whitelist[msg.sender].hasMinted.add(_count) <= MAX_MINT_WHITELIST, "Can only mint 20 while whitelisted");
            require(whitelist[msg.sender].hasMinted <= MAX_MINT_WHITELIST, "Can only mint 20 while whitelisted");
            whitelist[msg.sender].hasMinted = whitelist[msg.sender].hasMinted.add(_count);
        } else {
            require(_count <= MAX_BY_MINT, "Above max tx count");
        }

        for (uint256 i = 0; i < _count; i++) {
            _mintAnElement(msg.sender);
        }

        // If we haven't set the starting index and this is either
        // 1) the last saleable token or
        // 2) the first token to be sold after the end of pre-sale, set the starting index block
        if (startingIndexBlock == 0 && (_totalSupply() == MAX_ELEMENTS || block.timestamp >= REVEAL_TIMESTAMP)) {
            startingIndexBlock = block.number;
        }
    }

    function freeMint(uint _count) public {
        require(isWhitelisted(msg.sender), "Is not whitelisted");
        require(privateSaleIsActive, "Presale must be active to mint");
        require(_totalSupply().add(_count) <= MAX_ELEMENTS, "Exceeds max supply");
        require(whitelist[msg.sender].claimAmount > 0, "You have no amount to claim");
        require(_count <= whitelist[msg.sender].claimAmount, "You claim amount exceeded");

        for(uint i = 0; i < _count; i++) {
            _mintAnElement(msg.sender);
        }
        whitelist[msg.sender].claimAmount = whitelist[msg.sender].claimAmount.sub(_count);
        
        // If we haven't set the starting index and this is either
        // 1) the last saleable token or
        // 2) the first token to be sold after the end of pre-sale, set the starting index block
        if (startingIndexBlock == 0 && (_totalSupply() == MAX_ELEMENTS || block.timestamp >= REVEAL_TIMESTAMP)) {
            startingIndexBlock = block.number;
        }
    }

    /**
    * Set the starting index for the collection
    */
    function setStartingIndex() public onlyOwner {
        require(startingIndex == 0, "Starting index is already set");
        require(startingIndexBlock != 0, "Starting index block must be set");
        startingIndex = uint(blockhash(startingIndexBlock)) % MAX_ELEMENTS;
        // Just a sanity case in the worst case if this function is called late (EVM only stores last 256 block hashes)
        if (block.number.sub(startingIndexBlock) > 255) {
            startingIndex = uint(blockhash(block.number - 1)) % MAX_ELEMENTS;
        }
        // Prevent default sequence
        if (startingIndex == 0) {
            startingIndex = startingIndex + 1;
        }
    }
    /**
     * Set the starting index block for the collection, essentially unblocking
     * setting starting index
     */

    function emergencySetStartingIndexBlock() public onlyOwner {
        require(startingIndex == 0, "Starting index is already set");
        
        startingIndexBlock = block.number;
    }

    function withdraw() public onlyOwner {
        uint256 balance = address(this).balance;
        (bool success, ) = msg.sender.call{value: balance}("");
        require(success);
    }

    function partialWithdraw(uint256 _amount, address payable _to) external onlyOwner {
        require(_amount > 0, "Withdraw must be greater than 0");
        require(_amount <= address(this).balance, "Amount too high");
        (bool success, ) = _to.call{value: _amount}("");
        require(success);
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        if (startingIndex == 0) {
            return super.tokenURI(0);
        }
        uint256 moddedId = (tokenId + startingIndex) % MAX_ELEMENTS;
        return super.tokenURI(moddedId);
    }

    function _mintAnElement(address _to) private {
        uint id = _totalSupply();
        _tokenIdTracker.increment();
        _safeMint(_to, id);
    }

    function price(uint256 _count) public view returns (uint256) {
        return mintPrice.mul(_count);
    }

    function setMintPrice(uint256 _price) external onlyOwner {
        mintPrice = _price;
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return baseTokenURI;
    }

    function setBaseURI(string memory baseURI) public onlyOwner {
        baseTokenURI = baseURI;
    }

    function flipSaleState() public onlyOwner {
        saleIsActive = !saleIsActive;
    }

    function flipPrivateSaleState() public onlyOwner {
        privateSaleIsActive = !privateSaleIsActive;
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual override(ERC721, ERC721Enumerable) {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721, ERC721Enumerable) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    function reserve(uint256 _count) public onlyOwner {
        uint256 total = _totalSupply();
        require(total + _count <= 100, "Exceeded");
        for (uint256 i = 0; i < _count; i++) {
            _mintAnElement(msg.sender);
        }
    }
    
    function addAddressToWhitelist(address addr, uint claimAmount) onlyOwner public returns(bool success) {
        require(!isWhitelisted(addr), "Already whitelisted");
        whitelist[addr].addr = addr;
        whitelist[addr].claimAmount = claimAmount;
        whitelist[addr].hasMinted = 0;
        success = true;
    }

    function isWhitelisted(address addr) public view returns (bool isWhiteListed) {
        return whitelist[addr].addr == addr;
    }

}