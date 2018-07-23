pragma solidity ^0.4.18;

/**
 * @title SafeMath
 * @dev Math operations with safety checks that throw on error
 */
library SafeMath {

  /**
  * @dev Multiplies two numbers, throws on overflow.
  */
  function mul(uint256 a, uint256 b) internal pure returns (uint256) {
    if (a == 0) {
      return 0;
    }
    uint256 c = a * b;
    assert(c / a == b);
    return c;
  }

  /**
  * @dev Integer division of two numbers, truncating the quotient.
  */
  function div(uint256 a, uint256 b) internal pure returns (uint256) {
    // assert(b > 0); // Solidity automatically throws when dividing by 0
    uint256 c = a / b;
    // assert(a == b * c + a % b); // There is no case in which this doesn't hold
    return c;
  }

  /**
  * @dev Substracts two numbers, throws on overflow (i.e. if subtrahend is greater than minuend).
  */
  function sub(uint256 a, uint256 b) internal pure returns (uint256) {
    assert(b <= a);
    return a - b;
  }

  /**
  * @dev Adds two numbers, throws on overflow.
  */
  function add(uint256 a, uint256 b) internal pure returns (uint256) {
    uint256 c = a + b;
    assert(c >= a);
    return c;
  }
}

/**
 * @title Ownable
 * @dev The Ownable contract has an owner address, and provides basic authorization control
 * functions, this simplifies the implementation of "user permissions".
 */
contract Ownable {
  address public owner;


  event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);


  /**
   * @dev The Ownable constructor sets the original `owner` of the contract to the sender
   * account.
   */
  function Ownable() public {
    owner = msg.sender;
  }

  /**
   * @dev Throws if called by any account other than the owner.
   */
  modifier onlyOwner() {
    require(msg.sender == owner);
    _;
  }

  /**
   * @dev Allows the current owner to transfer control of the contract to a newOwner.
   * @param newOwner The address to transfer ownership to.
   */
  function transferOwnership(address newOwner) public onlyOwner {
    require(newOwner != address(0));
    OwnershipTransferred(owner, newOwner);
    owner = newOwner;
  }

}

interface tokenRecipient
{
    function receiveApproval(address _from, uint256 _value, address _token, bytes _extraData) public;
}

contract TokenERC20 is Ownable
{
    using SafeMath for uint;

    // Public variables of the token
    string public name;
    string public symbol;
    uint256 public decimals = 18;
    uint256 DEC = 10 ** uint256(decimals);
    uint256 public totalSupply;
    uint256 public avaliableSupply;
    uint256 public buyPrice = 1000000000000000000 wei;

    // This creates an array with all balances
    mapping (address => uint256) public balanceOf;
    mapping (address => mapping (address => uint256)) public allowance;

    // This generates a public event on the blockchain that will notify clients
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Burn(address indexed from, uint256 value);
    event Approval(address indexed _owner, address indexed _spender, uint256 _value);

    /**
     * Constrctor function
     *
     * Initializes contract with initial supply tokens to the creator of the contract
     */
    function TokenERC20(
        uint256 initialSupply,
        string tokenName,
        string tokenSymbol
    ) public
    {
        totalSupply = initialSupply.mul(DEC);  // Update total supply with the decimal amount
        balanceOf[this] = totalSupply;         // Give the creator all initial tokens
        avaliableSupply = balanceOf[this];     // Show how much tokens on contract
        name = tokenName;                      // Set the name for display purposes
        symbol = tokenSymbol;                  // Set the symbol for display purposes
    }

    /**
     * Internal transfer, only can be called by this contract
     *
     * @param _from - address of the contract
     * @param _to - address of the investor
     * @param _value - tokens for the investor
     */
    function _transfer(address _from, address _to, uint256 _value) internal
    {
        // Prevent transfer to 0x0 address. Use burn() instead
        require(_to != 0x0);
        // Check if the sender has enough
        require(balanceOf[_from] >= _value);
        // Check for overflows
        require(balanceOf[_to].add(_value) > balanceOf[_to]);
        // Save this for an assertion in the future
        uint previousBalances = balanceOf[_from].add(balanceOf[_to]);
        // Subtract from the sender
        balanceOf[_from] = balanceOf[_from].sub(_value);
        // Add the same to the recipient
        balanceOf[_to] = balanceOf[_to].add(_value);

        Transfer(_from, _to, _value);
        // Asserts are used to use static analysis to find bugs in your code. They should never fail
        assert(balanceOf[_from].add(balanceOf[_to]) == previousBalances);
    }

    /**
     * Transfer tokens
     *
     * Send `_value` tokens to `_to` from your account
     *
     * @param _to The address of the recipient
     * @param _value the amount to send
     */
    function transfer(address _to, uint256 _value) public
    {
        _transfer(msg.sender, _to, _value);
    }

    /**
     * Transfer tokens from other address
     *
     * Send `_value` tokens to `_to` in behalf of `_from`
     *
     * @param _from The address of the sender
     * @param _to The address of the recipient
     * @param _value the amount to send
     */
    function transferFrom(address _from, address _to, uint256 _value) public
        returns (bool success)
    {
        require(_value <= allowance[_from][msg.sender]);     // Check allowance

        allowance[_from][msg.sender] = allowance[_from][msg.sender].sub(_value);
        _transfer(_from, _to, _value);

        return true;
    }

    /**
     * Set allowance for other address
     *
     * Allows `_spender` to spend no more than `_value` tokens in your behalf
     *
     * @param _spender The address authorized to spend
     * @param _value the max amount they can spend
     */
    function approve(address _spender, uint256 _value) public
        returns (bool success)
    {
        allowance[msg.sender][_spender] = _value;

        return true;
    }

    /**
     * Set allowance for other address and notify
     *
     * Allows `_spender` to spend no more than `_value` tokens in your behalf, and then ping the contract about it
     *
     * @param _spender The address authorized to spend
     * @param _value the max amount they can spend
     * @param _extraData some extra information to send to the approved contract
     */
    function approveAndCall(address _spender, uint256 _value, bytes _extraData) public onlyOwner
        returns (bool success)
    {
        tokenRecipient spender = tokenRecipient(_spender);

        if (approve(_spender, _value)) {
            spender.receiveApproval(msg.sender, _value, this, _extraData);

            return true;
        }
    }

    /**
     * approve should be called when allowed[_spender] == 0. To increment
     * allowed value is better to use this function to avoid 2 calls (and wait until
     * the first transaction is mined)
     * From MonolithDAO Token.sol
     */
    function increaseApproval (address _spender, uint _addedValue) public
        returns (bool success)
    {
        allowance[msg.sender][_spender] = allowance[msg.sender][_spender].add(_addedValue);

        Approval(msg.sender, _spender, allowance[msg.sender][_spender]);

        return true;
    }

    function decreaseApproval (address _spender, uint _subtractedValue) public
        returns (bool success)
    {
        uint oldValue = allowance[msg.sender][_spender];

        if (_subtractedValue > oldValue) {
            allowance[msg.sender][_spender] = 0;
        } else {
            allowance[msg.sender][_spender] = oldValue.sub(_subtractedValue);
        }

        Approval(msg.sender, _spender, allowance[msg.sender][_spender]);

        return true;
    }

    /**
     * Destroy tokens
     *
     * Remove `_value` tokens from the system irreversibly
     *
     * @param _value the amount of money to burn
     */
    function burn(uint256 _value) public onlyOwner
        returns (bool success)
    {
        require(balanceOf[msg.sender] >= _value);   // Check if the sender has enough

        balanceOf[msg.sender] = balanceOf[msg.sender].sub(_value);  // Subtract from the sender
        totalSupply = totalSupply.sub(_value);                      // Updates totalSupply
        avaliableSupply = avaliableSupply.sub(_value);

        Burn(msg.sender, _value);

        return true;
    }

    /**
     * Destroy tokens from other account
     *
     * Remove `_value` tokens from the system irreversibly on behalf of `_from`.
     *
     * @param _from the address of the sender
     * @param _value the amount of money to burn
     */
    function burnFrom(address _from, uint256 _value) public onlyOwner
        returns (bool success)
    {
        require(balanceOf[_from] >= _value);                // Check if the targeted balance is enough
        require(_value <= allowance[_from][msg.sender]);    // Check allowance

        balanceOf[_from] = balanceOf[_from].sub(_value);    // Subtract from the targeted balance
        allowance[_from][msg.sender] = allowance[_from][msg.sender].sub(_value);    // Subtract from the sender's allowance
        totalSupply = totalSupply.sub(_value);              // Update totalSupply
        avaliableSupply = avaliableSupply.sub(_value);

        Burn(_from, _value);

        return true;
    }
}

/**
 * @title Helps contracts guard agains reentrancy attacks.
 * @author Remco Bloemen <remco@2π.com>
 * @notice If you mark a function `nonReentrant`, you should also
 * mark it `external`.
 */
contract ReentrancyGuard {

  /**
   * @dev We use a single lock for the whole contract.
   */
  bool private reentrancy_lock = false;

  /**
   * @dev Prevents a contract from calling itself, directly or indirectly.
   * @notice If you mark a function `nonReentrant`, you should also
   * mark it `external`. Calling one nonReentrant function from
   * another is not supported. Instead, you can implement a
   * `private` function doing the actual work, and a `external`
   * wrapper marked as `nonReentrant`.
   */
  modifier nonReentrant() {
    require(!reentrancy_lock);
    reentrancy_lock = true;
    _;
    reentrancy_lock = false;
  }

}

/**
 * @title Eliptic curve signature operations
 *
 * @dev Based on https://gist.github.com/axic/5b33912c6f61ae6fd96d6c4a47afde6d
 */

library ECRecovery {

  /**
   * @dev Recover signer address from a message by using his signature
   * @param hash bytes32 message, the hash is the signed message. What is recovered is the signer address.
   * @param sig bytes signature, the signature is generated using web3.eth.sign()
   */
  function recover(bytes32 hash, bytes sig) public pure returns (address) {
    bytes32 r;
    bytes32 s;
    uint8 v;

    //Check the signature length
    if (sig.length != 65) {
      return (address(0));
    }

    // Divide the signature in r, s and v variables
    assembly {
      r := mload(add(sig, 32))
      s := mload(add(sig, 64))
      v := byte(0, mload(add(sig, 96)))
    }

    // Version of signature should be 27 or 28, but 0 and 1 are also possible versions
    if (v < 27) {
      v += 27;
    }

    // If the version is correct return the signer address
    if (v != 27 && v != 28) {
      return (address(0));
    } else {
      return ecrecover(hash, v, r, s);
    }
  }

}

contract StreamityEscrow is Ownable, ReentrancyGuard {
    using SafeMath for uint256;
    using ECRecovery for bytes32;

    uint8 constant public STATUS_NO_DEAL = 0x0;
    uint8 constant public STATUS_DEAL_WAIT_CONFIRMATION = 0x01;
    uint8 constant public STATUS_DEAL_APPROVE = 0x02;
    uint8 constant public STATUS_DEAL_RELEASE = 0x03;

    TokenERC20 public streamityContractAddress;
    
    uint256 public availableForWithdrawal;
    uint256 public availableForWithdrawalSTM;

    uint32 public requestCancelationTime;

    mapping(bytes32 => Deal) public streamityTransfers;

    function StreamityEscrow(address streamityContract) public {
        require(streamityContract != 0x0); 
        requestCancelationTime = 2 hours;
        streamityContractAddress = TokenERC20(streamityContract);
    }

    struct Deal {
        uint256 value;
        uint256 cancelTime;
        address seller;
        address buyer;
        uint8 status;
        uint256 commission;
        bool isAltCoin;
    }

    event StartDealEvent(bytes32 indexed _hashDeal, address indexed _seller, address indexed _buyer);
    event ApproveDealEvent(bytes32 indexed _hashDeal, address indexed _seller, address indexed _buyer);
    event ReleasedEvent(bytes32 indexed _hashDeal, address indexed _seller, address indexed _buyer);
    event SellerCancelEvent(bytes32 indexed _hashDeal, address indexed _seller, address indexed _buyer);
    
    function pay(bytes32 _tradeID, address _seller, address _buyer, uint256 _value, uint256 _commission, bytes _sign) 
    external 
    payable 
    {
        require(msg.value > 0);
        require(msg.value == _value);
        require(msg.value > _commission);
        bytes32 _hashDeal = keccak256(_tradeID, _seller, _buyer, msg.value, _commission);
        verifyDeal(_hashDeal, _sign);
        startDealForUser(_hashDeal, _seller, _buyer, _commission, msg.value, false);
    }

    function () public payable {
        availableForWithdrawal = availableForWithdrawal.add(msg.value);
    }

    function payAltCoin(bytes32 _tradeID, address _seller, address _buyer, uint256 _value, uint256 _commission, bytes _sign) 
    external 
    {
        bytes32 _hashDeal = keccak256(_tradeID, _seller, _buyer, _value, _commission);
        verifyDeal(_hashDeal, _sign);
        bool result = streamityContractAddress.transferFrom(msg.sender, address(this), _value);
        require(result == true);
        startDealForUser(_hashDeal, _seller, _buyer, _commission, _value, true);
    }

    function verifyDeal(bytes32 _hashDeal, bytes _sign) private view {
        require(_hashDeal.recover(_sign) == owner);
        require(streamityTransfers[_hashDeal].status == STATUS_NO_DEAL); 
    }

    function startDealForUser(bytes32 _hashDeal, address _seller, address _buyer, uint256 _commission, uint256 _value, bool isAltCoin) 
    private returns(bytes32) 
    {
        Deal storage userDeals = streamityTransfers[_hashDeal];
        userDeals.seller = _seller;
        userDeals.buyer = _buyer;
        userDeals.value = _value; 
        userDeals.commission = _commission; 
        userDeals.cancelTime = block.timestamp.add(requestCancelationTime); 
        userDeals.status = STATUS_DEAL_WAIT_CONFIRMATION;
        userDeals.isAltCoin = isAltCoin;
        emit StartDealEvent(_hashDeal, _seller, _buyer);
        
        return _hashDeal;
    }

    function withdrawCommisionToAddress(address _to, uint256 _amount) external onlyOwner {
        require(_amount <= availableForWithdrawal); 
        availableForWithdrawal = availableForWithdrawal.sub(_amount);
        _to.transfer(_amount);
    }

    function withdrawCommisionToAddressAltCoin(address _to, uint256 _amount) external onlyOwner {
        require(_amount <= availableForWithdrawalSTM); 
        availableForWithdrawalSTM = availableForWithdrawalSTM.sub(_amount);
        streamityContractAddress.transfer(_to, _amount);
    }

    function getStatusDeal(bytes32 _hashDeal) external view returns (uint8) {
        return streamityTransfers[_hashDeal].status;
    }
    
    // _additionalComission is wei
    uint256 constant GAS_releaseTokens = 60000;
    function releaseTokens(bytes32 _hashDeal, uint256 _additionalGas) 
    external 
    nonReentrant
    returns(bool) 
    {
        Deal storage deal = streamityTransfers[_hashDeal];

        if (deal.status == STATUS_DEAL_APPROVE) {
            deal.status = STATUS_DEAL_RELEASE; 
            bool result = false;

            if (deal.isAltCoin == false)
                result = transferMinusComission(deal.buyer, deal.value, deal.commission.add((msg.sender == owner ? (GAS_releaseTokens.add(_additionalGas)).mul(tx.gasprice) : 0)));
            else 
                result = transferMinusComissionAltCoin(streamityContractAddress, deal.buyer, deal.value, deal.commission);

            if (result == false) {
                deal.status = STATUS_DEAL_APPROVE; 
                return false;   
            }

            emit ReleasedEvent(_hashDeal, deal.seller, deal.buyer);
            delete streamityTransfers[_hashDeal];
            return true;
        }
        
        return false;
    }

    function releaseTokensForce(bytes32 _hashDeal) 
    external onlyOwner
    nonReentrant
    returns(bool) 
    {
        Deal storage deal = streamityTransfers[_hashDeal];
        uint8 prevStatus = deal.status; 
        if (deal.status != STATUS_NO_DEAL) {
            deal.status = STATUS_DEAL_RELEASE; 
            bool result = false;

            if (deal.isAltCoin == false)
                result = transferMinusComission(deal.buyer, deal.value, deal.commission);
            else 
                result = transferMinusComissionAltCoin(streamityContractAddress, deal.buyer, deal.value, deal.commission);

            if (result == false) {
                deal.status = prevStatus; 
                return false;   
            }

            emit ReleasedEvent(_hashDeal, deal.seller, deal.buyer);
            delete streamityTransfers[_hashDeal];
            return true;
        }
        
        return false;
    }

    uint256 constant GAS_cancelSeller = 30000;
    function cancelSeller(bytes32 _hashDeal, uint256 _additionalGas) 
    external onlyOwner
    nonReentrant	
    returns(bool)   
    {
        Deal storage deal = streamityTransfers[_hashDeal];

        if (deal.status == STATUS_DEAL_WAIT_CONFIRMATION) {
            deal.status = STATUS_DEAL_RELEASE; 

            bool result = false;
            if (deal.isAltCoin == false)
                result = transferMinusComission(deal.seller, deal.value, GAS_cancelSeller.add(_additionalGas).mul(tx.gasprice));
            else 
                result = transferMinusComissionAltCoin(streamityContractAddress, deal.seller, deal.value, _additionalGas);

            if (result == false) {
                deal.status = STATUS_DEAL_WAIT_CONFIRMATION; 
                return false;   
            }

            emit SellerCancelEvent(_hashDeal, deal.seller, deal.buyer);
            delete streamityTransfers[_hashDeal];
            return true;
        }
        
        return false;
    }

    function approveDeal(bytes32 _hashDeal) 
    external 
    onlyOwner 
    nonReentrant	
    returns(bool) 
    {
        Deal storage deal = streamityTransfers[_hashDeal];
        
        if (deal.status == STATUS_DEAL_WAIT_CONFIRMATION) {
            deal.status = STATUS_DEAL_APPROVE;
            emit ApproveDealEvent(_hashDeal, deal.seller, deal.buyer);
            return true;
        }
        
        return false;
    }

    function transferMinusComission(address _to, uint256 _value, uint256 _commission) 
    private returns(bool) 
    {
        uint256 _totalComission = _commission; 
		
        require(_value >= _totalComission);
        
        require(availableForWithdrawal.add(_totalComission) >= availableForWithdrawal); // Check for overflows

        availableForWithdrawal = availableForWithdrawal.add(_totalComission); 

        _to.transfer(_value.sub(_totalComission));
        return true;
    }

    function transferMinusComissionAltCoin(TokenERC20 _contract, address _to, uint256 _value, uint256 _commission) 
    private returns(bool) 
    {
        uint256 _totalComission = _commission; 
		
        require(_value >= _totalComission);
		
        require(availableForWithdrawalSTM.add(_totalComission) >= availableForWithdrawalSTM); // Check for overflows

        availableForWithdrawalSTM = availableForWithdrawalSTM.add(_totalComission); 
		
        _contract.transfer(_to, _value.sub(_totalComission));
        return true;
    }

    function setStreamityContractAddress(address newAddress) 
    external onlyOwner 
    {
        streamityContractAddress = TokenERC20(newAddress);
    }

    // For other Tokens
    function transferToken(TokenERC20 _tokenContract, address _transferTo, uint256 _value) onlyOwner external {
        _tokenContract.transfer(_transferTo, _value);
    }
    function transferTokenFrom(TokenERC20 _tokenContract, address _transferTo, address _transferFrom, uint256 _value) onlyOwner external {
        _tokenContract.transferFrom(_transferTo, _transferFrom, _value);
    }
    function approveToken(TokenERC20 _tokenContract, address _spender, uint256 _value) onlyOwner external {
        _tokenContract.approve(_spender, _value);
    }
}