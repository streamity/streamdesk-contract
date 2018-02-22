pragma solidity ^0.4.18;

import './Ownable.sol';
import './SafeMath.sol';

contract Streamity is Ownable {
    using SafeMath for uint256;

    uint8 constant STATUS_NO_DEAL = 0x0;
    uint8 constant STATUS_DEAL_WAIT_CONFIRMATION = 0x01;
    uint8 constant STATUS_DEAL_APPROVE = 0x02;
    uint8 constant STATUS_DEAL_RELEASE = 0x03;
    uint8 constant STATUS_DEAL_DISPUT = 0x04;
    
    uint256 public availableForWithdrawal; 

    uint32 public requestCancellationTime;
    
    function Streamity() public {
        owner = msg.sender; 
        requestCancellationTime = 2 hours;
    }

    struct Deal {
        uint256 value;
        uint256 cancelTime;
        address seller;
        address buyer;
        uint8 status;
        uint256 commission;
    }

    mapping(bytes32 => Deal) public streamityTransfers;

    event StartDealEvent(bytes32 _hashDeal, address _seller, address _buyer);
    event ApproveDealEvent(bytes32 _hashDeal, address _seller, address _buyer);
    event ReleasedEvent(bytes32 _hashDeal, address _seller, address _buyer);
    event SellerCancellEvent(bytes32 _hashDeal, address _seller, address _buyer);
    
    function pay(bytes32 _tradeID, address _seller, address _buyer, uint256 _value, uint256 _commission, uint8 _v, bytes32 _r, bytes32 _s) 
    external 
    payable 
    {
        require(msg.value > 0);
        require(msg.value == _value);
        bytes32 _hashDeal = keccak256(_tradeID, _seller, _buyer, msg.value, _commission);
        require(ecrecover(_hashDeal, _v, _r, _s) == owner); // validate sign from server
        require(streamityTransfers[_hashDeal].status == STATUS_NO_DEAL); 
        startDealForUser(_hashDeal, _seller, _buyer, _commission, msg.value);
    }

    function startDealForUser(bytes32 _hashDeal, address _seller, address _buyer, uint256 _commission, uint256 _value) 
    private returns(bytes32) 
    {
        Deal storage userDeals = streamityTransfers[_hashDeal];
        userDeals.seller = _seller;
        userDeals.buyer = _buyer;
        userDeals.value = _value; 
        userDeals.commission = _commission; 
        userDeals.cancelTime = block.timestamp + requestCancellationTime; 
        userDeals.status = STATUS_DEAL_WAIT_CONFIRMATION;
        
        StartDealEvent(_hashDeal, _seller, _buyer);
        
        return _hashDeal;
    }

    function withdrawCommisionToAddress(address _to, uint256 _amount) external onlyOwner {
        require(_amount <= availableForWithdrawal); 
        availableForWithdrawal -= _amount;
        _to.transfer(_amount);
    }

    function getStatusDeal(bytes32 _hashDeal) public constant returns (uint8) {
        return streamityTransfers[_hashDeal].status;
    }
    
    // _additionalComission is wei
    uint16 constant GAS_releaseTokens = 22300;
    function releaseTokens(bytes32 _hashDeal, uint256 _additionalGas) 
    external returns(bool) 
    {
        Deal storage deal = streamityTransfers[_hashDeal];
        
        if (deal.status == STATUS_DEAL_APPROVE) {
            deal.status = STATUS_DEAL_RELEASE; 
            bool result = transferMinusComission(deal.buyer, deal.value, deal.commission + (msg.sender == owner ? (GAS_releaseTokens + _additionalGas) * tx.gasprice : 0));

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

    uint16 constant GAS_cancelSeller= 23000;
    function cancelSeller(bytes32 _hashDeal, uint256 _additionalGas) 
    external onlyOwner returns(bool)  
    {

        Deal storage deal = streamityTransfers[_hashDeal];
        
        if (deal.cancelTime > block.timestamp)
            return false;

        if (deal.status == STATUS_DEAL_WAIT_CONFIRMATION) {
            deal.status = STATUS_DEAL_RELEASE; 
            bool result = transferMinusComission(deal.buyer, deal.value, (msg.sender == owner ? (GAS_cancelSeller + _additionalGas) * tx.gasprice : 0));

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
    public onlyOwner returns(bool) 
    {
        Deal storage deal = streamityTransfers[_hashDeal];
        
        if (deal.status == STATUS_DEAL_WAIT_CONFIRMATION) {
            deal.status = STATUS_DEAL_APPROVE;
            ApproveDealEvent(_hashDeal, deal.seller, deal.buyer);
            return true;
        }
        
        return false;
    }

    function transferMinusComission(address _to, uint256 _value, uint256 commission) 
    private returns(bool) 
    {
        uint256 _totalComission = commission; 
        if (_value - _totalComission > _value) 
            return false; 
        
        availableForWithdrawal += _totalComission; 

        _to.transfer(_value - _totalComission);
        return true;
    }
}


