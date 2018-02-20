var ethers = require('ethers')
var SigningKey = ethers._SigningKey;
var secp256k1 = require('secp256k1')
var utils = require('ethers').utils;
var Wallet = require('ethers').Wallet;

var Streamity = artifacts.require("../contract/Streamity.sol");
var privateKeyOwner = "0xc87509a1c067bbde78beb793e6fa76530b6382a4c0241e5e4a9ec0a0f44dc0d3";

contract('Streamity', function(accounts) {
  it("Owner created", function() {
    return Streamity.deployed().then(function(instance) {
      stm = instance;
      return stm.owner.call();
    }).then(function(owner) {
      assert.equal(accounts[0], owner, "Owner created");
    });
  });
});

contract('Streamity', function(accounts) {
  var tradeID = "0xfec6b3564db327475a799b6eb971ad1f478bf4a1506a1ba2e2f9d9f25b6eca07";
  var buyer = accounts[2];
  var seller = accounts[1];

  var value_eth = "10.0"; // transfer value
  var value = ethers.utils.parseEther(value_eth);
  var comission = ethers.utils.parseEther("0.05"); // 5% in wei
  //var hash = utils.solidityKeccak256([ 'bytes32', 'address', 'address', 'uint256', 'uint256'], [tradeID, seller, buyer, value, comission]);
  var hash2 = utils.solidityKeccak256([ 'bytes32'], [tradeID]);
  var signature =  getSignature(privateKeyOwner, hash2);
  it("Create deal", function() {
    return Streamity.deployed().then(function(instance) {
      stm = instance;

      return stm.testRecover(tradeID, signature.v, signature.r, signature.s);
    }).then(function(result) {
      console.log("hash ------- ", hash2);
      console.log("signature ------- ", JSON.stringify(signature));
    });
  });
});

// подпись приватным ключом 
function getSignature(privateKey, message) {

  var signingKey = new SigningKey(privateKey);
  var sig = signingKey.signDigest(message);

  signature = (hexPad(sig.r, 32) + hexPad(sig.s, 32).substring(2) + (sig.recoveryParam ? '1c': '1b'));
  
  signature = ethers.utils.arrayify(signature);
  return {
      r: ethers.utils.hexlify(signature.slice(0, 32)),
      s: ethers.utils.hexlify(signature.slice(32, 64)),
      v: sig.recoveryParam + 27
  };
}

function hexPad(value, length) {
  while (value.length < 2 * length + 2) {
      value = '0x0' + value.substring(2);
  }
  return value;
}

function getSignature2(privateKey, msgHash) {
  var sig = secp256k1.sign(new Buffer(msgHash, 'hex'), new Buffer(privateKey, 'hex'))
  var ret = {}
  ret.r = sig.signature.slice(0, 32)
  ret.s = sig.signature.slice(32, 64)
  ret.v = sig.recovery + 27
}