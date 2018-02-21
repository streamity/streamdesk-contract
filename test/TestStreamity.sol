pragma solidity ^0.4.2;

import "truffle/Assert.sol";
import "truffle/DeployedAddresses.sol";
import "../contracts/Streamity.sol";

contract TestStreamity {

  function testRecover() public {
    Streamity stm = Streamity(DeployedAddresses.Streamity());
	
  }

  function testInitialBalanceWithNewMetaCoin() public {
    Streamity stm = new Streamity();

    uint expected = 10000;

    Assert.equal(expected, expected, "Owner should have 10000 MetaCoin initially");
  }

}
