pragma solidity ^0.4.18;

import "./Streamity/StreamityContract.sol";
import "./Zeppelin/ReentrancyGuard.sol";
import "./Zeppelin/ECRecovery.sol";
import "./ContractToken.sol";

contract StreamityEscrow is Ownable, ReentrancyGuard {
    using SafeMath for uint256;
    using ECRecovery for bytes32;

    uint8 constant public STATUS_NO_DEAL = 0x0;
    uint8 constant public STATUS_DEAL_WAIT_CONFIRMATION = 0x01;
    uint8 constant public STATUS_DEAL_APPROVE = 0x02;
    uint8 constant public STATUS_DEAL_RELEASE = 0x03;

    TokenERC20 public streamityContractAddress;
    
    uint256 public availableForWithdrawal;

    uint32 public requestCancellationTime;

    mapping(bytes32 => Deal) public streamityTransfers;

    function StreamityEscrow(address streamityContract) public {
        owner = msg.sender; 
        requestCancellationTime = 2 hours;
        streamityContractAddress = TokenERC20(streamityContract); // TODO Stm contract adrress
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

    event StartDealEvent(bytes32 _hashDeal, address _seller, address _buyer);
    event ApproveDealEvent(bytes32 _hashDeal, address _seller, address _buyer);
    event ReleasedEvent(bytes32 _hashDeal, address _seller, address _buyer);
    event SellerCancellEvent(bytes32 _hashDeal, address _seller, address _buyer);
    
    function pay(bytes32 _tradeID, address _seller, address _buyer, uint256 _value, uint256 _commission, bytes _sign) 
    external 
    payable 
    {
        require(msg.value > 0);
        require(msg.value == _value);
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
        userDeals.cancelTime = block.timestamp.add(requestCancellationTime); 
        userDeals.status = STATUS_DEAL_WAIT_CONFIRMATION;
        userDeals.isAltCoin = isAltCoin;
        
        StartDealEvent(_hashDeal, _seller, _buyer);
        
        return _hashDeal;
    }

    function withdrawCommisionToAddress(address _to, uint256 _amount) external onlyOwner {
        require(_amount <= availableForWithdrawal); 
        availableForWithdrawal = availableForWithdrawal.sub(_amount);
        _to.transfer(_amount);
    }

    function withdrawCommisionToAddressAltCoin(address _to, uint256 _amount) external onlyOwner {
        
    }

    function getStatusDeal(bytes32 _hashDeal) external view returns (uint8) {
        return streamityTransfers[_hashDeal].status;
    }
    
    // _additionalComission is wei
    uint256 constant GAS_releaseTokens = 22300;
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

            ReleasedEvent(_hashDeal, deal.seller, deal.buyer);
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

            ReleasedEvent(_hashDeal, deal.seller, deal.buyer);
            delete streamityTransfers[_hashDeal];
            return true;
        }
        
        return false;
    }

    uint256 constant GAS_cancelSeller= 23000;
    function cancelSeller(bytes32 _hashDeal, uint256 _additionalGas) 
    external onlyOwner
    nonReentrant	
    returns(bool)   
    {
        Deal storage deal = streamityTransfers[_hashDeal];

        if (deal.cancelTime > block.timestamp)
            return false;

        if (deal.status == STATUS_DEAL_WAIT_CONFIRMATION) {
            deal.status = STATUS_DEAL_RELEASE; 

            bool result = false;
            if (deal.isAltCoin == false)
                result = transferMinusComission(deal.buyer, deal.value, deal.commission.add((msg.sender == owner ? (GAS_releaseTokens.add(_additionalGas)).mul(tx.gasprice) : 0)));
            else 
                result = transferMinusComissionAltCoin(streamityContractAddress, deal.buyer, deal.value, deal.commission);

            if (result == false) {
                deal.status = STATUS_DEAL_WAIT_CONFIRMATION; 
                return false;   
            }

            SellerCancellEvent(_hashDeal, deal.seller, deal.buyer);
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
            ApproveDealEvent(_hashDeal, deal.seller, deal.buyer);
            return true;
        }
        
        return false;
    }

    function transferMinusComission(address _to, uint256 _value, uint256 _commission) 
    private returns(bool) 
    {
        uint256 _totalComission = _commission; 
        
        require(availableForWithdrawal.add(_totalComission) > availableForWithdrawal); // Check for overflows

        availableForWithdrawal = availableForWithdrawal.add(_totalComission); 

        _to.transfer(_value.sub(_totalComission));
        return true;
    }

    function transferMinusComissionAltCoin(TokenERC20 _contract, address _to, uint256 _value, uint256 _commission) 
    private returns(bool) 
    {
        uint256 _totalComission = _commission; 
        _contract.transfer(_to, _value.sub(_totalComission));
        return true;
    }

    function setStreamityContractAddress(address newAddress) 
    external onlyOwner 
    {
        streamityContractAddress = TokenERC20(newAddress);
    }

    // For other Tokens
    function transferToken(ContractToken _tokenContract, address _transferTo, uint256 _value) onlyOwner external {
         _tokenContract.transfer(_transferTo, _value);
    }
    function transferTokenFrom(ContractToken _tokenContract, address _transferTo, address _transferFrom, uint256 _value) onlyOwner external {
         _tokenContract.transferFrom(_transferTo, _transferFrom, _value);
    }
    function approveToken(ContractToken _tokenContract, address _spender, uint256 _value) onlyOwner external {
         _tokenContract.approve(_spender, _value);
    }
}


