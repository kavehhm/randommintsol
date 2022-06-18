// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
contract RandomMint is ERC721Enumerable, Ownable {
    using Strings for uint256;

    string baseURI;
    string public baseExtension = ".json";
    uint256 public maxSupply = 10000;
    uint256 public maxMintAmount = 5;
    bool public paused = false;
    bool public premintStarted = false;
    bool public publicmintStarted = false;
    bool public whitelistMintStarted = false;

    address payable public wallet1;
    address payable public wallet2;
    address payable public wallet3;
    
    bool public revealed = true;
    string public notRevealedUri;

    uint256 public ethPrice;
    uint256[3] priceListUSD = [500, 550, 600];
    uint256[3] supplyList = [3300, 3350, 3350];

    bytes32 public preSaleMerkleRoot = 0x0000000000000000000000000000000000000000000000000000000000000000;

    mapping (uint256 => uint256) private currentSupply;
    mapping (uint256 => uint256) private currentIndex;
    mapping (uint256 => uint256) public priceList;

    constructor(
        string memory _name,
        string memory _symbol,
        string memory _initBaseURI,
        string memory _initNotRevealedUri
    ) ERC721(_name, _symbol) {
        for (uint8 i = 1; i < 3; i ++) {
            currentIndex[i] = currentIndex[i-1] + supplyList[i-1];
        }

        ethPrice = 1200;
        updatePrice();

        setBaseURI(_initBaseURI);
        setNotRevealedURI(_initNotRevealedUri);
    }

    function setEthPrice(uint256 _price) public onlyOwner {
        ethPrice = _price;
        updatePrice();
    }

    function setMerkleRoot(bytes32 _preSaleMerkleRoot) external onlyOwner {
        preSaleMerkleRoot = _preSaleMerkleRoot;
    }


    function setPriceListUSD (uint256[] calldata _list) public onlyOwner {
        require (_list.length == 3, "Must set the 3 prices");
        for (uint8 i = 0; i < 3; i ++) {
            priceListUSD[i] = _list[i];
        }
        updatePrice();
    }

    function updatePrice () internal {
        for (uint8 i = 0; i < 3; i++) {
            priceList[i] = priceListUSD[i] * 1 ether / ethPrice;
        }
    }
    // internal
    function _baseURI() internal view virtual override returns (string memory) {
        return baseURI;
    }

    function canMint(uint256 _tokenId) public view virtual returns (bool) {
        return (!_exists(_tokenId));
    }
    function whitelistMint (bytes32[] calldata _proof, uint256[] calldata _tokenIds) public payable {
        require (!paused);
        require (whitelistMintStarted, "Whitelist Mint not started!");
        require (_tokenIds.length <= maxMintAmount, "Can not mint over limit");
        if (msg.sender != owner()) {
            require(MerkleProof.verify(_proof, preSaleMerkleRoot, keccak256(abi.encodePacked(msg.sender))), "Address does not exist in whitelist.");
        }

        uint256 price = 0;
        uint256 tier = 0;
        for (uint256 i = 0; i < _tokenIds.length; i ++) {
            require (_tokenIds[i] > 0, "Id must start from 1");
            require (_tokenIds[i] <= 10000, "Id must be in 10000");
            require (canMint (_tokenIds[i]), "Already Minted");

            tier = getTier (_tokenIds[i]);
            currentSupply[tier] += 1;

            _safeMint (msg.sender, _tokenIds[i]);
            price += getPriceOfTokenId (_tokenIds[i]);
        }
        if (msg.sender == owner()) {
            price = 0;
        }
        require (msg.value >= price, "Insufficient Fund");
    }

    function preMint (uint256[] calldata _tokenIds) public payable {
        require (!paused);
        require (premintStarted, "Premint not started!");
        require (_tokenIds.length <= maxMintAmount, "Can not mint over limit");

        uint256 price = 0;
        uint256 tier = 0;
        for (uint256 i = 0; i < _tokenIds.length; i ++) {
            require (_tokenIds[i] > 0, "Id must start from 1");
            require (_tokenIds[i] <= 10000, "Id must be in 10000");
            require (canMint (_tokenIds[i]), "Already Minted");

            tier = getTier (_tokenIds[i]);
            currentSupply[tier] += 1;

            _safeMint (msg.sender, _tokenIds[i]);
            price += getPriceOfTokenId (_tokenIds[i]);
        }
        if (msg.sender == owner()) {
            price = 0;
        }
        require (msg.value >= price, "Insufficient Fund");
    }


    function publicMint (uint256 _tier, uint256 _amount) public payable {
        require (!paused);
        require (publicmintStarted, "Public Mint not started yet !");
        require (_tier < 3, "Tier must be smaller than 3");
        require (_amount > 0, "Amount must be at least 0");
        require (_amount <= maxMintAmount, "Can not mint over maxMintLimit");
        require (currentSupply[_tier] + _amount <= supplyList[_tier], "Supply exceed");

        uint256 price = getPriceOfTier (_tier);
        if (msg.sender == owner()) {
            price = 0;
        }
        require (msg.value >= price * _amount, "Insufficient Fund");

        for (uint256 i = 1; i <= _amount; i++) {
            while (!canMint (currentIndex[_tier] + 1)) {
                currentIndex[_tier] += 1;
            }
            _safeMint (msg.sender, currentIndex[_tier] + 1);
        }
        currentSupply[_tier] += _amount;
    }

    function getSupply (uint256 _tier) public view returns (uint256) {
        return (currentSupply[_tier]);
    }

    function getMaxSupply (uint256 _tier) public view returns (uint256) {
        return (supplyList[_tier]);
    }
    function getPriceOfTier (uint256 _tier) public view returns (uint256) {
        return priceList[_tier];
    }
    function getPriceOfTokenId (uint256 _tokenId) public view returns (uint256) {
        return (getPriceOfTier(getTier(_tokenId)));
    }

    function getTier (uint256 _tokenId) public view returns (uint256) {
        uint256 supply = 0;
        for (uint256 i = 0; i < supplyList.length; i++) {
            supply += supplyList[i];
            if (_tokenId <= supply) {
                return i;
            }
        }
        return 5;
    }

    function walletOfOwner(address _owner)
    public
    view
    returns (uint256[] memory)
    {
        uint256 ownerTokenCount = balanceOf(_owner);
        uint256[] memory tokenIds = new uint256[](ownerTokenCount);
        for (uint256 i; i < ownerTokenCount; i++) {
            tokenIds[i] = tokenOfOwnerByIndex(_owner, i);
        }
        return tokenIds;
    }

    function tokenURI(uint256 tokenId)
    public
    view
    virtual
    override
    returns (string memory)
    {
        require(
            _exists(tokenId),
            "ERC721Metadata: URI query for nonexistent token"
        );

        if(revealed == false) {
            return notRevealedUri;
        }

        string memory currentBaseURI = _baseURI();
        return bytes(currentBaseURI).length > 0
        ? string(abi.encodePacked(currentBaseURI, tokenId.toString(), baseExtension))
        : "";
    }

    //only owner
    function reveal() public onlyOwner {
        revealed = true;
    }

    function setmaxMintAmount(uint256 _newmaxMintAmount) public onlyOwner {
        maxMintAmount = _newmaxMintAmount;
    }

    function setNotRevealedURI(string memory _notRevealedURI) public onlyOwner {
        notRevealedUri = _notRevealedURI;
    }

    function setBaseURI(string memory _newBaseURI) public onlyOwner {
        baseURI = _newBaseURI;
    }

    function setBaseExtension(string memory _newBaseExtension) public onlyOwner {
        baseExtension = _newBaseExtension;
    }

    function pause(bool _state) public onlyOwner {
        paused = _state;
    }

    function setPremint (bool _state) public onlyOwner {
        premintStarted = _state;
    }

    function setWhitelistmint (bool _state) public onlyOwner {
        whitelistMintStarted = _state;
    }

    function setPublicmint (bool _state) public onlyOwner {
        publicmintStarted = _state;
    }
    function withdraw() public payable onlyOwner {
        uint256 contractBalance = address(this).balance;
        wallet1.transfer (contractBalance * 5 / 100);
        wallet2.transfer (contractBalance * 5 / 100);
        wallet3.transfer (contractBalance * 90 / 100);
    }
}