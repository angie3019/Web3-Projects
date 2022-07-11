//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
contract ReviewProject is ERC1155, Ownable {
    
    string public name;
    string public symbol;
    string public baseURI;
    
    using Counters for Counters.Counter;  // using counter for auto-incrementing the token id's
   Counters.Counter private reviewId;

    
    struct Review {
        uint id;
        string project;
        string title;
        string comment;
        uint   like;
     }

    struct ProjectReviews{
        Review[] reviewArray;
    }
    
    mapping(string=>ProjectReviews)  projReviews;
    mapping(address=> mapping(string=>Review)) userReviews;
    mapping (uint256 => string) private _tokenUris;

    constructor(string memory _name, string memory _symbol,string memory _baseURI) ERC1155('') {
        name = _name;
        symbol = _symbol;
        baseURI = _baseURI;
        
    }
    
    modifier checkReview(address user,string memory project){
     require(userReviews[user][project].id==0,"Review already exists");
    _;
    }

    function createReview(string memory project,string memory title,string memory comment,uint like) public checkReview(msg.sender,project){
        reviewId.increment();
        Review memory  review = Review(reviewId.current(),project,title,comment,like);
        userReviews[msg.sender][project] = review;
        projReviews[project].reviewArray.push(review);
    }

    function mintReviewNFT(address to,uint id,string memory _uri) public onlyOwner  {       
        setTokenUri(_uri, id);
        _mint(to, id, 1, '');
        
    }

    //Get reviews by user for a given project
    function getReviewsForUser(address reviewer,string memory project)public view returns(Review memory){
        return userReviews[reviewer][project];
    }
    
    //Get all reviews of a project
    function getReviewsForProject(string memory project)public view returns(Review[] memory){
       // return projReviews[project].reviewArray;
       return projReviews[project].reviewArray;
    }
    
    function updateReview(address reviewer,uint reviewID,string memory project,string memory title,string memory comment,uint like)public {
        Review memory  review = Review(reviewID,project,title,comment,like);
        userReviews[reviewer][project]=review;
        Review[] memory reviews = projReviews[project].reviewArray;
        for(uint i=0;i<reviews.length;i++){
            if(reviews[i].id==reviewID)
                reviews[i] = review;
        }
    }
   
    function uri(uint256 id) override public view returns (string memory) {
        return(_tokenUris[id]);
    }
    

    function setTokenUri(string memory _uri,uint256 id) public onlyOwner {
        _tokenUris[id] = _uri; 
    }
 
    function safeTransferFrom(address from,address to,uint256 id,uint256 amount,bytes memory data) public   override {
        require(false,"Transfer not allowed");
        
    }
    function safeBatchTransferFrom(address from,address to,uint256[] memory ids,uint256[] memory amounts,bytes memory data) public  override {
        require(false,"Transfer not allowed");

    }

}
