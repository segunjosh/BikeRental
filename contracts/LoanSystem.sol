// SPDX-License-Identifier: MIT
pragma solidity ^0.5.4;

contract LoanSystem {
    address public owner;

  mapping (bytes32=>address[]) public ownerMap;
  mapping (address=>bytes32[]) public loanMap;

  constructor() {
      owner = msg.sender;
  }
  
  function addData(bytes32 document) public {
    address[] storage owners = ownerMap[document];
    for( uint i = 0; i < owners.length; i++){
      if(owners[i] == msg.sender)
        return;
    }
    ownerMap[document].push(msg.sender);
    uint count = loanMap[msg.sender].length;
    for( uint i = 0; i < count; i++){
      if (loanMap[msg.sender][i] == document)
        return;
    }
    loanMap[msg.sender].push(document);
  }

  function getLoanCount(address person) public view returns(uint) {
    return loanMap[person].length;
  }

  function getOwnerCount(bytes32 hash) public view returns(uint) {
    return ownerMap[hash].length;
  }
  
  function getOwnerByPosition(bytes32 hash, uint index) public view returns(address) {
    return ownerMap[hash][index];
  }
  
}