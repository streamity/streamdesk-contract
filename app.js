const ethers = require('ethers');

const wallet = ethers.Wallet.createRandom();
console.log(wallet.address);
const msg = "This message's length: 32 bytes."

const sig = wallet.signMessage(msg).slice(2);
console.log({
  r: '0x' + sig.slice(0, 64),
  s: '0x' + sig.slice(64, 128),
  v: parseInt(sig.slice(128), 16),
});