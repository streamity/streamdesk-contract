pragma solidity ^0.4.2;

import "truffle/Assert.sol";
import "truffle/DeployedAddresses.sol";
import "../contracts/StreamityEscrow.sol";
import "../contracts/Streamity/StreamityContract.sol";

contract TestStreamity {

  function TestEscrow() public {
    StreamityContract stm = StreamityContract(DeployedAddresses.StreamityContract());
    StreamityEscrow escrow = StreamityEscrow(DeployedAddresses.StreamityEscrow());
  }
}
