var ethers = require('ethers')
var SigningKey = ethers._SigningKey;
var secp256k1 = require('secp256k1')
var utils = require('ethers').utils;
var Wallet = require('ethers').Wallet;
var Web3Utils = require('web3-utils');
var StreamityEscrow = artifacts.require("../contract/StreamityEscrow.sol");
var StreamityContract = artifacts.require("../contract/Streamity/StreamityContract.sol");
var privateKeyOwner = "0xc87509a1c067bbde78beb793e6fa76530b6382a4c0241e5e4a9ec0a0f44dc0d3";

var STATUS_NO_DEAL = 0x0;
var STATUS_DEAL_WAIT_CONFIRMATION = 0x01;
var STATUS_DEAL_APPROVE = 0x02;
var STATUS_DEAL_RELEASE = 0x03;
var STATUS_DEAL_DISPUT = 0x04;

contract('2th stage tests', async (accounts) => {
	var tradeID = Web3Utils.randomHex(32);
	var ownerContract = accounts[0];
	var buyer = accounts[2];
	var seller = accounts[1];

	var value = 1000;
	var commission = 1;
	var hash = utils.solidityKeccak256(['bytes32', 'address', 'address', 'uint256', 'uint256'], [tradeID, seller, buyer, value, commission]);
	var signature = getSignatureSig(privateKeyOwner, hash);

	it("Alt coin transfer test", async () => {
	  var UNIX_TIMESTAMP = Math.round(new Date().getTime() / 1000);
	  let instance_stm = await StreamityContract.deployed();
	  let instance_escrow = await StreamityEscrow.deployed();
	  
	  await instance_stm.startCrowd(5000, UNIX_TIMESTAMP, 5, 0, 0);
	  await instance_stm.transferWeb3js(seller, 2000, {from: ownerContract});
	  await instance_stm.approve(instance_escrow.address, 1000, {from: seller});
	   
	  await instance_escrow.payAltCoin(tradeID, seller, buyer, value, commission, signature, {
                from: seller
            }); 
			
	  let status = await instance_escrow.getStatusDeal(hash);

	  await instance_escrow.approveDeal(hash, {from: ownerContract});
	  
	  let balance_contract = await instance_stm.balanceOf.call(instance_escrow.address);
	  
	 
	  await instance_escrow.releaseTokens(hash, 0, {from: buyer});
	  let balance_buyer = await instance_stm.balanceOf.call(buyer);
	  
	  assert(value-commission, balance_buyer.toNumber(), "Stm coin not transfer to buyer");
	});

});

function getSignature(privateKey, message) {

    var signingKey = new SigningKey(privateKey);
    var sig = signingKey.signDigest(message);

    signature = (hexPad(sig.r, 32) + hexPad(sig.s, 32).substring(2) + (sig.recoveryParam ? '1c' : '1b'));

    signature = ethers.utils.arrayify(signature);
    return {
        r: ethers.utils.hexlify(signature.slice(0, 32)),
        s: ethers.utils.hexlify(signature.slice(32, 64)),
        v: sig.recoveryParam + 27
    };
}

// sign
function getSignatureSig(privateKey, message) {
    
        var signingKey = new SigningKey(privateKey);
        var sig = signingKey.signDigest(message);
    
        signature = (hexPad(sig.r, 32) + hexPad(sig.s, 32).substring(2) + (sig.recoveryParam ? '1c' : '1b'));
    
        return signature;
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
/*
var ownerContract = accounts[0];
    it("StreamityContract start", function () {
        StreamityContract.deployed().then(function (instance) {
            streamityToken = instance; 
            var UNIX_TIMESTAMP = Math.round(new Date().getTime() / 1000);
            return streamityToken.startCrowd(1000, UNIX_TIMESTAMP, 5, 0, 0);
        }).then(function(result){
            return 
        }).then(function(result){
           return streamityToken.balanceOf.call(accounts[1]);
        }).then(function(result){
            assert.equal(5, result.toString(), "Can't transfer token to account");
            return streamityToken.approve(StreamityEscrow.address, 4, {from: accounts[1]}); // approve for Escrow smart contract 
        }).then(function(result){
            return streamityToken.allowance.call(accounts[1], StreamityEscrow.address);
        }).then(function(result){
            assert.equal(4, result.toString(), "Status deal is not wait");
        });
    });
*/