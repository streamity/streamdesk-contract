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


contract('StreamityContract', function (accounts) {
    var ownerContract = accounts[0];
    it("StreamityContract start", function () {
        StreamityContract.deployed().then(function (instance) {
            streamityToken = instance; 
            var UNIX_TIMESTAMP = Math.round(new Date().getTime() / 1000);
            return streamityToken.startCrowd(1000, UNIX_TIMESTAMP, 5, 0, 0);
        }).then(function(result){
            return streamityToken.transferWeb3js(accounts[1], 5, {from: ownerContract});
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
});

contract('StreamityEscrow', function (accounts) {
    var tradeID = Web3Utils.randomHex(32); // sample "0x1ec6b3564db327475a799b6eb971ad11478bf4a1506a1ba2e2f9d9f25b6eca00"
    var ownerContract = accounts[0];
    var buyer = accounts[2];
    var seller = accounts[1];

    var value_eth = "0.5"; // transfer value
    var value = Web3Utils.toWei(value_eth, 'ether'); // 0.5 eth
    var commission = Web3Utils.toWei((value_eth * 5 / 100).toString(), 'ether'); // 5 %
    var hash = utils.solidityKeccak256(['bytes32', 'address', 'address', 'uint256', 'uint256'], [tradeID, seller, buyer, value, commission]);
    var signature = getSignatureSig(privateKeyOwner, hash);
	
    it("Create deal", function () {
		
        return StreamityEscrow.deployed().then(function (instance) {
            stm = instance;
			
            return stm.pay(tradeID, seller, buyer, value, commission, signature, {
                value: value,
                from: seller
            });
        }).then(function (result) {
            for (var i = 0; i < result.logs.length; i++) {
                var log = result.logs[i];

                if (log.event == "StartDealEvent") {
                    assert.equal(hash, log.args._hashDeal, "args._hashDeal must be equal our hash deal");
                    assert.equal(seller, log.args._seller, "args._seller must be equal our seller");
                    assert.equal(buyer, log.args._buyer, "args._buyer must be equal our buyer");
                    break;
                }
            }

            if (result.tx === undefined)
                throw "result.tx is undefined";

            return stm.getStatusDeal(hash);
        }).then(function (result) {
            assert.equal(STATUS_DEAL_WAIT_CONFIRMATION, result, "Status deal is not wait");
        });
    });

    it("Try cancel deal before 2 hours", function () {
        return StreamityEscrow.deployed().then(function (instance) {
            stm = instance;
            return stm.cancelSeller.call(hash, 0, {from : ownerContract});
        }).then(function (result) {
            assert.equal(false, result, "Status deal is not wait");
        });
    });

    it("Try Release unprove tokens", function () {
      return StreamityEscrow.deployed().then(function (instance) {
          stm = instance;

          return stm.releaseTokens(hash, 0, {from: buyer});
      }).then(function (result) {
         return stm.releaseTokens(hash, 0, {from: seller});
      }).then(function (result) {
         return stm.releaseTokens(hash, 0, {from: ownerContract});
      }).then(function (result) {
        return stm.getStatusDeal(hash);
      }).then(function (result) {
        assert.equal(STATUS_DEAL_WAIT_CONFIRMATION, parseInt(result, 16), "Deal must has status wait confirmation");
      });
    });

    it("Approve deal", function () {
        return StreamityEscrow.deployed().then(function (instance) {
            stm = instance;

            return stm.approveDeal(hash, {from: ownerContract});
        }).then(function (result) {
            if (result.tx === undefined)
                throw "result.tx is undefined";
            return stm.getStatusDeal(hash);
        }).then(function (result) {
            assert.equal(STATUS_DEAL_APPROVE, parseInt(result, 16), "Status deal is not approve");
        });
    });

    it("Release tokens", function () {
      return StreamityEscrow.deployed().then(function (instance) {
          stm = instance;

          return stm.releaseTokens.call(hash, 0, {from: buyer});
      }).then(function (result) {
         assert.equal(true, result, "Problem with deal");
         return stm.releaseTokens(hash, 0, {from: buyer});
      }).then(function (result) {
        return stm.releaseTokens.call(hash, 0, {from: buyer});
     }).then(function (result) {
        assert.equal(false, result, "You can't relese twice");
        return stm.getStatusDeal(hash);
      }).then(function (result) {
        assert.equal(STATUS_NO_DEAL, parseInt(result, 16), "Deal must has been deleted");
      });
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