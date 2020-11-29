// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;

import "./LnProxyImpl.sol";
import "./IBEP20.sol";

contract LnProxyBEP20 is LnProxyBase, IBEP20 {
    constructor(address _admin) public LnProxyBase(_admin) {}

    function name() public view override returns (string memory) {
        
        return IBEP20(address(target)).name();
    }

    function getOwner() public view override returns (address) {
        
        return target.admin();
    }

    function symbol() public view override returns (string memory) {
        
        return IBEP20(address(target)).symbol();
    }

    function decimals() public view override returns (uint8) {
        
        return IBEP20(address(target)).decimals();
    }

    function totalSupply() public view override returns (uint256) {
        
        return IBEP20(address(target)).totalSupply();
    }

    function balanceOf(address account) public view override returns (uint256) {
        
        return IBEP20(address(target)).balanceOf(account);
    }

    function allowance(address owner, address spender) public view override returns (uint256) {
        
        return IBEP20(address(target)).allowance(owner, spender);
    }

    function transfer(address to, uint256 value) public override returns (bool) {
        
        target.setMessageSender(msg.sender);

        IBEP20(address(target)).transfer(to, value);

        return true;
    }

    function approve(address spender, uint256 value) public override returns (bool) {
        
        target.setMessageSender(msg.sender);

        IBEP20(address(target)).approve(spender, value);

        return true;
    }

    function transferFrom(
        address from,
        address to,
        uint256 value
    ) public override returns (bool) {
        
        target.setMessageSender(msg.sender);

        IBEP20(address(target)).transferFrom(from, to, value);

        return true;
    }

}

