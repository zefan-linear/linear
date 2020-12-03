// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;

import "./IBEP20.sol";
import "./LnAdmin.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "./SafeDecimalMath.sol";
import "@openzeppelin/contracts/utils/Address.sol";


contract LnBep20Bridge is LnAdmin {
    using SafeMath for uint;
    using SafeDecimalMath for uint;
    using Address for address;

    uint public totalFrozen;
    mapping(address => uint) public frozenOf;

    IBEP20 private bep20;
    address private frozenHolder;


    constructor(address _admin, address _frozenHolder, address _tokenAddr, uint _totalFrozen) public LnAdmin(_admin) {
        bep20 = IBEP20(_tokenAddr);
        bep20.approve(address(this), _totalFrozen);
        totalFrozen = _totalFrozen;
        frozenHolder = _frozenHolder;
    }

    // need approve
    function freeze(uint256 _amount) external returns (bool) {
        require(_amount > 0, "freeze amount can not zero");

        address user = msg.sender;

        require(bep20.balanceOf(user) >= _amount, "insufficient balance");
        require(bep20.allowance(user, address(this)) >= _amount, "insufficient allowance, need approve more amount");

        bep20.transferFrom(user, address(this), _amount);

        totalFrozen = totalFrozen.add(_amount);
        frozenOf[user] = frozenOf[user].add(_amount);

        emit freezeLog(user, bep20.symbol(), _amount);
        return true;
    }    

    function unfreeze(uint256 _amount) external returns (bool) {
        address user = msg.sender;

        require(_amount > 0, "freeze amount can not zero");
        require(totalFrozen.sub(_amount,"unfreeze total frozen sub overflow")> 0, "totalFrozen can not zero");
        // require(frozenOf[user] > _amount, "freeze amount insufficient");

        totalFrozen = totalFrozen.sub(_amount, "unfreeze total frozen sub overflow");
        if (frozenOf[user] >= _amount ){
            frozenOf[user] = frozenOf[user].sub(_amount, "unfreeze frozenOf sub overflow");
        }

        bep20.transferFrom(frozenHolder, user, _amount);

        emit unfreezeLog(user, bep20.symbol(), _amount);
        return true;
    }  

    event freezeLog(address user, string _currency, uint256 _amount);
    event unfreezeLog(address user, string _currency, uint256 _amount);


}