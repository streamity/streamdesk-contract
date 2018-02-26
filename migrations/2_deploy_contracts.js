var StreamityEscrow = artifacts.require("./StreamityEscrow.sol");

module.exports = function(deployer) {
  deployer.deploy(StreamityEscrow);
};
