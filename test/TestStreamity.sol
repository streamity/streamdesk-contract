pragma solidity ^0.4.2;

import "truffle/Assert.sol";
import "truffle/DeployedAddresses.sol";
import "../contracts/Streamity.sol";

contract TestStreamity {

  function testRecover() public {
    Streamity stm = Streamity(DeployedAddresses.Streamity());
  }
}
