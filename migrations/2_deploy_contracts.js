var StreamityEscrow = artifacts.require("./StreamityEscrow.sol");
var ECRecovery = artifacts.require("./ECRecovery.sol");

module.exports = function(deployer) {
  deployer.deploy(ECRecovery);
  deployer.link(ECRecovery, StreamityEscrow);
  deployer.deploy(StreamityEscrow);

};
