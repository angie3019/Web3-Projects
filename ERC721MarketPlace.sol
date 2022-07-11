// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts-upgradeable/token/ERC721/utils/ERC721HolderUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "./IERC721Mintable.sol";

contract ERC721MarketPlaceV2 is
    Initializable,
    UUPSUpgradeable,
    ERC721HolderUpgradeable,
    OwnableUpgradeable,
    ReentrancyGuardUpgradeable
{
    // Storage

    //auction type :
    // 1 : only direct buy
    // 2 : only bid

    struct auction {
        address payable seller;
        uint256 currentBid;
        address payable highestBidder;
        uint256 auctionType;
        uint256 startingPrice;
        uint256 startingTime;
        uint256 closingTime;
        address erc20Token;
    }

    struct _brokerage {
        uint256 seller;
        uint256 buyer;
    }

    // Mapping to store auction details
    mapping(address => mapping(uint256 => auction)) _auctions;

    // Mapping to store list of allowed tokens
    mapping(address => bool) public tokenAllowed;

    // Mapping to store the brokerage
    mapping(address => _brokerage) public brokerage;

    // address to transfer brokerage
    address payable public broker;

    // Decimal precesion for brokeage calculation
    uint256 public constant decimalPrecision = 100;

    // Mapping to manage nonce for lazy mint
    mapping(address => mapping(uint256 => bool)) public isNonceProcessed;

    // Platform's signer address
    address _signer;

    // mintingCharges in wei, Will be controlled by owner
    uint256 public mintingCharge;

    // WETH address
    address public WETH;

    struct sellerVoucher {
        address to;
        uint96 royalty;
        string tokenURI;
        uint256 nonce;
        address erc721;
        uint256 startingPrice;
        uint256 startingTime;
        uint256 endingTime;
        address erc20Token;
    }

    struct buyerVoucher {
        address buyer;
        uint256 amount;
        uint256 time;
    }

    // Events
    event Bid(
        address indexed collection,
        uint256 indexed tokenId,
        address indexed seller,
        address bidder,
        uint256 amouont,
        uint256 time,
        address ERC20Address
    );
    event Sold(
        address indexed collection,
        uint256 indexed tokenId,
        address indexed seller,
        address buyer,
        uint256 amount,
        address collector,
        uint256 auctionType,
        uint256 time,
        address ERC20Address
    );
    event OnSale(
        address indexed collection,
        uint256 indexed tokenId,
        address indexed seller,
        uint256 auctionType,
        uint256 amount,
        uint256 time,
        address ERC20Address
    );
    event PriceUpdated(
        address indexed collection,
        uint256 indexed tokenId,
        address indexed seller,
        uint256 auctionType,
        uint256 oldAmount,
        uint256 amount,
        uint256 time,
        address ERC20Address
    );
    event OffSale(
        address indexed collection,
        uint256 indexed tokenId,
        address indexed seller,
        uint256 time,
        address ERC20Address
    );
    event LazyAuction(
        address seller,
        address buyer,
        address collection,
        address ERC20Address,
        uint256 price,
        uint256 time
    );

    // Modifiers
    modifier erc20Allowed(address _erc20Token) {
        require(
            tokenAllowed[_erc20Token],
            "ERC721Marketplace: ERC20 not allowed"
        );
        _;
    }

    modifier onSaleOnly(uint256 _tokenId, address _erc721) {
        require(
            auctions(_erc721, _tokenId).seller != address(0),
            "ERC721Marketplace: Token Not For Sale"
        );
        _;
    }

    modifier activeAuction(uint256 _tokenId, address _erc721) {
        require(
            block.timestamp < auctions(_erc721, _tokenId).closingTime,
            "ERC721Marketplace: Auction Time Over!"
        );
        _;
    }

    modifier auctionOnly(uint256 _tokenId, address _erc721) {
        require(
            auctions(_erc721, _tokenId).auctionType == 2,
            "ERC721Marketplace: Auction Not For Bid"
        );
        _;
    }

    modifier flatSaleOnly(uint256 _tokenId, address _erc721) {
        require(
            auctions(_erc721, _tokenId).auctionType == 1,
            "ERC721Marketplace: Auction for Bid only!"
        );
        _;
    }

    modifier tokenOwnerOnly(uint256 _tokenId, address _erc721) {
        // Sender will be owner only if no have bidded on auction.
        require(
            IERC721Mintable(_erc721).ownerOf(_tokenId) == msg.sender,
            "ERC721Marketplace: You must be owner and Token should not have any bid"
        );
        _;
    }

    // Getters
    function auctions(address _erc721, uint256 _tokenId)
        public
        view
        returns (auction memory)
    {
        address _owner = IERC721Mintable(_erc721).ownerOf(_tokenId);
        if (
            _owner == _auctions[_erc721][_tokenId].seller ||
            _owner == address(this)
        ) {
            return _auctions[_erc721][_tokenId];
        }
    }

    function addERC20TokenPayment(
        address _erc20Token,
        _brokerage calldata brokerage_
    ) external onlyOwner {
        tokenAllowed[_erc20Token] = true;
        brokerage[_erc20Token] = brokerage_;
    }

    function updateBroker(address payable _broker) external onlyOwner {
        broker = _broker;
    }

    function removeERC20TokenPayment(address _erc20Token)
        external
        erc20Allowed(_erc20Token)
        onlyOwner
    {
        tokenAllowed[_erc20Token] = false;
        delete brokerage[_erc20Token];
    }

    function setSigner(address signer_) external onlyOwner {
        require(
            signer_ != address(0),
            "ERC721MarketPlace: Signer can't be null address"
        );
        _signer = signer_;
    }

    function setWETH(address _WETH) external onlyOwner {
        require(
            _WETH != address(0),
            "ERC721MarketPlace: Signer can't be null address"
        );
        WETH = _WETH;
    }

    function signer() external view onlyOwner returns (address) {
        return _signer;
    }

    // Method to set minting charges per NFT
    function setMintingCharge(uint256 _mintingCharge) external onlyOwner {
        mintingCharge = _mintingCharge;
    }

    function bid(
        uint256 _tokenId,
        address _erc721,
        uint256 amount
    )
        external
        payable
        onSaleOnly(_tokenId, _erc721)
        activeAuction(_tokenId, _erc721)
        nonReentrant
    {
        IERC721Mintable Token = IERC721Mintable(_erc721);

        auction memory _auction = _auctions[_erc721][_tokenId];

        if (_auction.erc20Token == address(0)) {
            require(
                msg.value > _auction.currentBid,
                "ERC721Marketplace: Insufficient bidding amount."
            );

            if (_auction.highestBidder != address(0)) {
                _auction.highestBidder.transfer(_auction.currentBid);
            }
        } else {
            IERC20Upgradeable erc20Token = IERC20Upgradeable(
                _auction.erc20Token
            );
            require(
                erc20Token.allowance(msg.sender, address(this)) >= amount,
                "ERC721Marketplace: Allowance is less than amount sent for bidding."
            );
            require(
                amount > _auction.currentBid,
                "ERC721Marketplace: Insufficient bidding amount."
            );
            erc20Token.transferFrom(msg.sender, address(this), amount);

            if (_auction.highestBidder != address(0)) {
                erc20Token.transfer(
                    _auction.highestBidder,
                    _auction.currentBid
                );
            }
        }

        _auction.currentBid = _auction.erc20Token == address(0)
            ? msg.value
            : amount;

        Token.safeTransferFrom(
            Token.ownerOf(_tokenId),
            address(this),
            _tokenId
        );
        _auction.highestBidder = payable(msg.sender);

        _auctions[_erc721][_tokenId] = _auction;

        // Bid event
        emit Bid(
            _erc721,
            _tokenId,
            _auction.seller,
            _auction.highestBidder,
            _auction.currentBid,
            block.timestamp,
            _auction.erc20Token
        );
    }

    function _getCreatorAndRoyalty(
        address _erc721,
        uint256 _tokenId,
        uint256 amount
    ) private view returns (address payable, uint256) {
        address creator;
        uint256 royalty;

        IERC721Mintable collection = IERC721Mintable(_erc721);

        try collection.royaltyInfo(_tokenId, amount) returns (
            address receiver,
            uint256 royaltyAmount
        ) {
            creator = receiver;
            royalty = royaltyAmount;
        } catch {
            //  =
            try collection.royalities(_tokenId) returns (uint256 royalities) {
                try collection.creators(_tokenId) returns (
                    address payable receiver
                ) {
                    creator = receiver;
                    royalty = (royalities * amount) / (100 * 100);
                } catch {}
            } catch {}
        }
        return (payable(creator), royalty);
    }

    // Collect Function are use to collect funds and NFT from Broker
    function collect(uint256 _tokenId, address _erc721)
        external
        onSaleOnly(_tokenId, _erc721)
        auctionOnly(_tokenId, _erc721)
        nonReentrant
    {
        IERC721Mintable Token = IERC721Mintable(_erc721);
        auction memory _auction = _auctions[_erc721][_tokenId];

        // Only allow collect without finishing the auction only if admin collects it.
        if (msg.sender != _auction.seller) {
            require(
                block.timestamp > _auction.closingTime,
                "ERC721Marketplace: Auction Not Over!"
            );
        }

        if (_auction.highestBidder != address(0)) {
            // Get royality and seller
            (address payable creator, uint256 royalty) = _getCreatorAndRoyalty(
                _erc721,
                _tokenId,
                _auction.currentBid
            );

            _brokerage memory brokerage_;

            brokerage_.seller =
                (brokerage[_auction.erc20Token].seller * _auction.currentBid) /
                (100 * decimalPrecision);

            // Calculate Brokerage
            brokerage_.buyer =
                (brokerage[_auction.erc20Token].buyer * _auction.currentBid) /
                (100 * decimalPrecision);

            // Calculate seller fund
            uint256 sellerFund = _auction.currentBid -
                royalty -
                brokerage_.seller -
                brokerage_.buyer;

            // Transfer funds for native currency
            if (_auction.erc20Token == address(0)) {
                creator.transfer(royalty);
                _auction.seller.transfer(sellerFund);
                broker.transfer(brokerage_.seller + brokerage_.buyer);
            }
            // Transfer funds for ERC20 token
            else {
                IERC20Upgradeable erc20Token = IERC20Upgradeable(
                    _auction.erc20Token
                );
                erc20Token.transfer(creator, royalty);
                erc20Token.transfer(_auction.seller, sellerFund);
                erc20Token.transfer(
                    broker,
                    brokerage_.seller + brokerage_.buyer
                );
            }
            // Transfer the NFT to Buyer
            Token.safeTransferFrom(
                Token.ownerOf(_tokenId),
                _auction.highestBidder,
                _tokenId
            );

            // Sold event
            emit Sold(
                _erc721,
                _tokenId,
                _auction.seller,
                _auction.highestBidder,
                _auction.currentBid - brokerage_.buyer,
                msg.sender,
                _auction.auctionType,
                block.timestamp,
                _auction.erc20Token
            );
        }
        // Delete the auction
        delete _auctions[_erc721][_tokenId];
    }

    function buy(uint256 _tokenId, address _erc721)
        external
        payable
        onSaleOnly(_tokenId, _erc721)
        flatSaleOnly(_tokenId, _erc721)
        nonReentrant
    {
        IERC721Mintable Token = IERC721Mintable(_erc721);
        auction memory _auction = _auctions[_erc721][_tokenId];

        // Get royality and creator
        (address payable creator, uint256 royalty) = _getCreatorAndRoyalty(
            _erc721,
            _tokenId,
            _auction.startingPrice
        );

        _brokerage memory brokerage_;

        brokerage_.seller =
            (brokerage[_auction.erc20Token].seller * _auction.startingPrice) /
            (100 * decimalPrecision);

        // Calculate Brokerage
        brokerage_.buyer =
            (brokerage[_auction.erc20Token].buyer * _auction.startingPrice) /
            (100 * decimalPrecision);

        // Calculate seller fund
        uint256 sellerFund = _auction.startingPrice -
            royalty -
            brokerage_.seller;

        // Transfer funds for natice currency
        if (_auction.erc20Token == address(0)) {
            require(
                msg.value >= _auction.startingPrice + brokerage_.buyer,
                "ERC721Marketplace: Insufficient Payment"
            );
            creator.transfer(royalty);
            _auction.seller.transfer(sellerFund);
            broker.transfer(msg.value - royalty - sellerFund);
        }
        // Transfer the funds for ERC20 token
        else {
            IERC20Upgradeable erc20Token = IERC20Upgradeable(
                _auction.erc20Token
            );
            require(
                erc20Token.allowance(msg.sender, address(this)) >=
                    _auction.startingPrice + brokerage_.buyer,
                "ERC721Marketplace: Insufficient spent allowance "
            );
            // transfer royalitiy to creator
            erc20Token.transferFrom(msg.sender, creator, royalty);
            // transfer brokerage amount to broker
            erc20Token.transferFrom(
                msg.sender,
                broker,
                brokerage_.seller + brokerage_.buyer
            );
            // transfer remaining  amount to Seller
            erc20Token.transferFrom(msg.sender, _auction.seller, sellerFund);
        }

        Token.safeTransferFrom(Token.ownerOf(_tokenId), msg.sender, _tokenId);

        // Sold event
        emit Sold(
            _erc721,
            _tokenId,
            _auction.seller,
            msg.sender,
            _auction.startingPrice,
            msg.sender,
            _auction.auctionType,
            block.timestamp,
            _auction.erc20Token
        );

        // Delete the auction
        delete _auctions[_erc721][_tokenId];
    }

    function withdraw(uint256 amount) external onlyOwner {
        payable(msg.sender).transfer(amount);
    }

    function withdrawERC20(address _erc20Token, uint256 amount)
        external
        onlyOwner
    {
        IERC20Upgradeable erc20Token = IERC20Upgradeable(_erc20Token);
        erc20Token.transfer(msg.sender, amount);
    }

    function putOnSale(
        uint256 _tokenId,
        uint256 _startingPrice,
        uint256 _auctionType,
        uint256 _startingTime,
        uint256 _endindTime,
        address _erc721,
        address _erc20Token
    ) external erc20Allowed(_erc20Token) tokenOwnerOnly(_tokenId, _erc721) {
        // Scope to overcome "Stack too deep error"
        {
            IERC721Mintable Token = IERC721Mintable(_erc721);

            require(
                Token.getApproved(_tokenId) == address(this) ||
                    Token.isApprovedForAll(msg.sender, address(this)),
                "ERC721Marketplace: Broker Not approved"
            );
            require(
                _startingTime < _endindTime,
                "ERC721Marketplace: Ending time must be grater than Starting time"
            );
        }
        auction memory _auction = _auctions[_erc721][_tokenId];

        // Allow to put on sale to already on sale NFT \
        // only if it was on auction and have 0 bids and auction is over
        if (_auction.seller != address(0) && _auction.auctionType == 2) {
            require(
                _auction.highestBidder == address(0) &&
                    block.timestamp > _auction.closingTime,
                "ERC721Marketplace: This NFT is already on sale."
            );
        }

        auction memory newAuction = auction(
            payable(msg.sender),
            _startingPrice +
                (brokerage[_erc20Token].buyer * _startingPrice) /
                (100 * decimalPrecision),
            payable(address(0)),
            _auctionType,
            _startingPrice,
            _startingTime,
            _endindTime,
            _erc20Token
        );

        _auctions[_erc721][_tokenId] = newAuction;

        // OnSale event
        emit OnSale(
            _erc721,
            _tokenId,
            msg.sender,
            _auctionType,
            _startingPrice,
            block.timestamp,
            _erc20Token
        );
    }

    function updatePrice(
        uint256 _tokenId,
        address _erc721,
        uint256 _newPrice,
        address _erc20Token
    )
        external
        onSaleOnly(_tokenId, _erc721)
        erc20Allowed(_erc20Token)
        tokenOwnerOnly(_tokenId, _erc721)
    {
        auction memory _auction = _auctions[_erc721][_tokenId];

        if (_auction.auctionType == 2) {
            require(
                block.timestamp < _auction.closingTime,
                "ERC721Marketplace: Auction Time Over!"
            );
        }
        emit PriceUpdated(
            _erc721,
            _tokenId,
            _auction.seller,
            _auction.auctionType,
            _auction.startingPrice,
            _newPrice,
            block.timestamp,
            _auction.erc20Token
        );
        // Update Price
        _auction.startingPrice = _newPrice;
        if (_auction.auctionType == 2) {
            _auction.currentBid =
                _newPrice +
                (brokerage[_erc20Token].buyer * _newPrice) /
                (100 * decimalPrecision);
        }
        _auction.erc20Token = _erc20Token;
        _auctions[_erc721][_tokenId] = _auction;
    }

    function putSaleOff(uint256 _tokenId, address _erc721)
        external
        tokenOwnerOnly(_tokenId, _erc721)
    {
        auction memory _auction = _auctions[_erc721][_tokenId];

        // OffSale event
        emit OffSale(
            _erc721,
            _tokenId,
            msg.sender,
            block.timestamp,
            _auction.erc20Token
        );
        delete _auctions[_erc721][_tokenId];
    }

    function initialize() public initializer {
        __Ownable_init();
        __UUPSUpgradeable_init();
    }

    function lazyMintAuction(
        sellerVoucher memory _sellerVoucher,
        buyerVoucher memory _buyerVoucher,
        bytes memory globalSign
    ) external erc20Allowed(_sellerVoucher.erc20Token) {
        // globalSignValidation
        {
            require(
                _sellerVoucher.erc20Token != address(0),
                "ERC721Marketplace: Must be ERC20 token address"
            );

            require(
                !isNonceProcessed[_sellerVoucher.erc721][_sellerVoucher.nonce],
                "ERC721Marketplace: Nonce already processed"
            );

            bytes32 messageHash = keccak256(
                abi.encodePacked(
                    address(this),
                    _sellerVoucher.to,
                    _sellerVoucher.royalty,
                    _sellerVoucher.tokenURI,
                    _sellerVoucher.nonce,
                    _sellerVoucher.erc721,
                    _sellerVoucher.startingPrice,
                    _sellerVoucher.startingTime,
                    _sellerVoucher.endingTime,
                    _sellerVoucher.erc20Token,
                    _buyerVoucher.buyer,
                    _buyerVoucher.time,
                    _buyerVoucher.amount
                )
            );

            bytes32 signedMessageHash = keccak256(
                abi.encodePacked(
                    "\x19Ethereum Signed Message:\n32",
                    messageHash
                )
            );
            (bytes32 r, bytes32 s, uint8 v) = splitSignature(globalSign);

            address signer_ = ecrecover(signedMessageHash, v, r, s);

            require(
                _signer == signer_,
                "ERC721Marketplace: Signature not verfied."
            );

            require(
                _sellerVoucher.endingTime <= block.timestamp ||
                    msg.sender == _sellerVoucher.to,
                "ERC721Marketplace: Auction not over yet."
            );
        }

        // Calculating brokerage and validation
        _brokerage memory brokerage_ = brokerage[_sellerVoucher.erc20Token];

        uint256 buyingBrokerage = (brokerage_.buyer *
            _sellerVoucher.startingPrice) / (100 * decimalPrecision);

        require(
            _sellerVoucher.startingPrice + buyingBrokerage <=
                _buyerVoucher.amount,
            "ERC721Marketplace: Amount must include Buying Brokerage"
        );

        buyingBrokerage =
            (brokerage_.buyer * _buyerVoucher.amount) /
            (100 * decimalPrecision);

        uint256 sellingBrokerage = (brokerage_.buyer * _buyerVoucher.amount) /
            (100 * decimalPrecision);

        // Transfer the funds.
        IERC20Upgradeable erc20Token = IERC20Upgradeable(
            _sellerVoucher.erc20Token
        );

        if (WETH == _sellerVoucher.erc20Token) {
            require(
                erc20Token.allowance(_buyerVoucher.buyer, address(this)) >=
                    _buyerVoucher.amount + mintingCharge,
                "Allowance is less than amount sent for bidding."
            );

            erc20Token.transferFrom(
                _buyerVoucher.buyer,
                broker,
                sellingBrokerage + buyingBrokerage + mintingCharge
            );
        } else {
            require(
                erc20Token.allowance(_buyerVoucher.buyer, address(this)) >=
                    _buyerVoucher.amount,
                "Allowance is less than amount sent for bidding."
            );

            IERC20Upgradeable weth = IERC20Upgradeable(WETH);

            require(
                weth.allowance(_buyerVoucher.buyer, address(this)) >=
                    mintingCharge,
                "Allowance is less than minting charges"
            );

            erc20Token.transferFrom(
                _buyerVoucher.buyer,
                broker,
                sellingBrokerage + buyingBrokerage
            );

            weth.transferFrom(_buyerVoucher.buyer, broker, mintingCharge);
        }

        erc20Token.transferFrom(
            _buyerVoucher.buyer,
            _sellerVoucher.to,
            _buyerVoucher.amount - (sellingBrokerage + buyingBrokerage)
        );
        

        IERC721Mintable(_sellerVoucher.erc721).delegatedMint(
            _sellerVoucher.tokenURI,
            _sellerVoucher.royalty,
            _sellerVoucher.to,
            _buyerVoucher.buyer
        );

        isNonceProcessed[_sellerVoucher.erc721][_sellerVoucher.nonce] = true;

        emit LazyAuction(
            _sellerVoucher.to,
            _buyerVoucher.buyer,
            _sellerVoucher.erc721,
            _sellerVoucher.erc20Token,
            _buyerVoucher.amount,
            block.timestamp
        );
    }

    function splitSignature(bytes memory sig)
        internal
        pure
        returns (
            bytes32 r,
            bytes32 s,
            uint8 v
        )
    {
        require(
            sig.length == 65,
            "ERC721Marketplace: invalid signature length"
        );

        assembly {
            /*
            First 32 bytes stores the length of the signature

            add(sig, 32) = pointer of sig + 32
            effectively, skips first 32 bytes of signature

            mload(p) loads next 32 bytes starting at the memory address p into memory
            */

            // first 32 bytes, after the length prefix
            r := mload(add(sig, 32))
            // second 32 bytes
            s := mload(add(sig, 64))
            // final byte (first byte of the next 32 bytes)
            v := byte(0, mload(add(sig, 96)))
        }

        // implicitly return (r, s, v)
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() initializer {}

    function _authorizeUpgrade(address) internal override onlyOwner {}
}
