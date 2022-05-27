//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "hardhat/console.sol";

contract WavePortal{
    uint256 totalWaves;
     uint256 private seed;
    event NewWave(address indexed from, uint256 timestamp, string message);
    
    struct Wave {
        address waver; // The address of the user who waved.
        string message; // The message the user sent.
        uint256 timestamp; // The timestamp when the user waved.
    }
   
    Wave[] waves;

    mapping(address => uint256) public lastWavedAt;

    constructor() payable{
        console.log("Wave! I am a smart contract to count waves") ;
        seed = (block.timestamp + block.difficulty) % 100;

    }


    function wave(string memory _message) public {

         require(lastWavedAt[msg.sender] + 30 seconds < block.timestamp,  "Wait 30s before waving again"
        );

        /*
         * Update the current timestamp we have for the user
         */
         
        lastWavedAt[msg.sender] = block.timestamp;
        totalWaves+=1;
        console.log("Person %s has waved",msg.sender);
        waves.push(Wave(msg.sender, _message, block.timestamp));
        
        /*
         * Generate a new seed for the next user that sends a wave
         */
         
        seed = (block.difficulty + block.timestamp + seed) % 100;

        console.log("Random # generated: %d", seed);

        /*
         * Give a 50% chance that the user wins the prize.
         */
        if (seed <= 50) {
            console.log("%s won!", msg.sender);

        uint256 prizeAmount = 0.0001 ether;
        
    require(prizeAmount <= address(this).balance, "Trying to withdraw more money than the contract has.  );
    (bool success, ) = (msg.sender).call{value: prizeAmount}("");
    require(success, "Failed to withdraw money from contract.");
        
    }
     emit NewWave(msg.sender, block.timestamp, _message);

    }

    function getAllWaves() public view returns (Wave[] memory) {
        return waves;
    }

    function getTotalWaves() public view returns(uint256){
        console.log("We have %d total waves",totalWaves);
        return totalWaves;
    }
}
