//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "./NFT.sol";
import "hardhat/console.sol";

contract FactoryNFT {

    NFT[] public tokens;

    event ChildContractCreated(address owner, address tokenContract,string name); //emitted when ERC1155 token is deployed
    event TokenCreated(address owner, address tokenContract); //emitted when ERC1155 token is deployed
    event NFTMinted(address owner, address tokenContract,uint tokenID,address to); //emmited when ERC1155 token is minted
    event NFTMintedBatch(address owner, address tokenContract,uint tokenID,address[] to); //emmited when ERC1155 token is minted to batch


    // Deployment function for child contract
    function deployContract(string memory _contractName, string memory _symbol ,string memory _uri) public returns (address) {
        NFT tokenContract = new NFT(_contractName, _symbol,_uri);
        tokens.push(tokenContract);
        emit ChildContractCreated(msg.sender,address(tokenContract),_contractName);
        return address(tokenContract);
    }

    // Create token with details
    function createToken(uint _indexOfContract,string memory _name, bool _limited, uint128 _limit,bool _allowed, bool _allowedList,string memory _uri) public {
        tokens[_indexOfContract].createToken(_name,_limited,_limit,_allowed,_allowedList,false,_uri);
        emit TokenCreated(tokens[_indexOfContract].owner(), address(tokens[_indexOfContract]));
    }

    // Mint functions for single and baatch tokens by owner and other user
    function mintNFT(uint _indexOfContract,address to,uint tokenId) public {

        // mint function
        tokens[_indexOfContract].mintTokenItem(to,tokenId);
        emit NFTMinted(tokens[_indexOfContract].owner(), address(tokens[_indexOfContract]),tokenId,to);
    }

    function mintNFTOther(uint _indexOfContract,address to,uint tokenId) public {

        // mint function
        tokens[_indexOfContract].mintTokenItemOther(to,tokenId);
        emit NFTMinted(tokens[_indexOfContract].owner(), address(tokens[_indexOfContract]),tokenId,to);
    }

    function batchmintNFT(uint _indexOfContract,address[] memory to,uint tokenId) public {

        // mint function
        tokens[_indexOfContract].batchMintTokenItem(to,tokenId);
        emit NFTMintedBatch(tokens[_indexOfContract].owner(), address(tokens[_indexOfContract]),tokenId,to);
    }

    function batchmintNFTOther(uint _indexOfContract,address[] memory to,uint tokenId) public {

        // mint function
        tokens[_indexOfContract].batchMintTokenItemOther(to,tokenId);
        emit NFTMintedBatch(tokens[_indexOfContract].owner(), address(tokens[_indexOfContract]),tokenId,to);
    }
   /*
    Helper functions below retrieve contract data index in the tokens array.
    */
    function getTokenName(uint256 _index, uint256 _tokenId) public view returns (string memory) {
        return tokens[_index].getTokenName(_tokenId);
       
    }

    function getTokenLimit(uint256 _index, uint256 _tokenId) public view returns (uint128) {
        return tokens[_index].getTokenLimit(_tokenId);
    }

    function getTokenLimited(uint256 _index,uint256 _tokenId) public view returns (bool) {
        return tokens[_index].getTokenLimited(_tokenId);
    }
     
    function getTokenMinted(uint256 _index,uint256 _tokenId) public view returns (uint128) {
        return tokens[_index].getTokenMinted(_tokenId);
    }

     function isAllowed(uint256 _index,uint256 _tokenId) public view returns (bool) {
        return tokens[_index].isAllowed(_tokenId);
    } 

    function isAllowedList(uint256 _index,uint256 _tokenId) public view returns (bool) {
        return tokens[_index].isAllowedList(_tokenId);
    }

    function isExists(uint256 _index,uint256 _tokenId) public view returns (bool) {
        return tokens[_index].isExists(_tokenId);
    }

    function isAllowedTransfer(uint256 _index,uint256 _tokenId) public view returns (bool) {
        return tokens[_index].isAllowedTransfer(_tokenId);
    }

    function getAllowedList(uint256 _index,uint256 _tokenId,address user) public view returns (bool) {
        return tokens[_index].getAllowedList(_tokenId,user);
    }

    // Setter functions for Child contract
    
    function setTokenUri(uint256 _index,string memory _uri,uint256 id) public  {
        tokens[_index].setTokenUri(_uri,id);
    }

    function setTokenisLimited(uint256 _index,uint tokenID,bool _isLimited) public  {
       tokens[_index].setTokenisLimited(tokenID,_isLimited);
    }

    function setTokenLimit(uint256 _index,uint tokenID,uint128 limit) public   {
        tokens[_index].setTokenLimit(tokenID,limit);
    }

      
    function setTokenisAllowed(uint256 _index,uint tokenID,bool _isAllowed) public   {
        tokens[_index].setTokenisAllowed(tokenID,_isAllowed);
    }

    
    function setTokenisAllowedList(uint256 _index,uint tokenID,bool _isAllowedList) public{
        tokens[_index].setTokenisAllowedList(tokenID,_isAllowedList);
    }

    
    function setTokenAllowedList(uint256 _index,uint tokenID,address[] memory _allowedList,bool allow) public   {
        tokens[_index].setTokenAllowedList(tokenID,_allowedList,allow);
    }

    function setTokenAllowTransfer(uint256 _index,uint tokenID,bool allow) public  {
       tokens[_index].setTokenAllowTransfer(tokenID,allow);
    } 

}

