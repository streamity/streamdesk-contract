var StreamityEscrow = artifacts.require("./StreamityEscrow.sol");
var ECRecovery = artifacts.require("./ECRecovery.sol");
var Stm = artifacts.require("./Streamity/StreamityContract.sol");

module.exports = function(deployer) {
  deployer.deploy(ECRecovery);
  deployer.link(ECRecovery, StreamityEscrow);
	deployer.deploy(Stm).then(function() {
	  return deployer.deploy(StreamityEscrow, Stm.address);
	});
};
