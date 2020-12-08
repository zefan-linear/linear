// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;

import "./LnObserver.sol";

contract LnSharePool is LnObserver {

    event UpdateTotalAsset(address _asset, uint256 _oldAmount, uint256 _nowAmount);

    //========asset data=======
    struct AssetData {
        uint256 aID;
        bool isValid;
        uint256 selfSupply;
        uint256 totalSupply;
    }

    uint256 private aID_;
    mapping(address => AssetData) private assetTotalSupply_;
    address[] private assetsList_;

    //初始化observer
    constructor(address _observer) public LnObserver(_observer) {
        
    }

    /**
    判定资产是否存在，不存在则分配aID
     */
    function determineAID(address _asset) internal returns (uint256){
        
        require(_asset != address(0), "determineAID param _asset err!");

        uint256 _aID = assetTotalSupply_[_asset].aID;

        if(_aID == 0){
            aID_++;
            assetTotalSupply_[_asset].aID = aID_;
            assetTotalSupply_[_asset].isValid = true;
            assetTotalSupply_[_asset].selfSupply = 0;
            assetTotalSupply_[_asset].totalSupply = 0;
            _aID = aID_;
        }

        return(_aID);
    }

    /**
    update a kind asset's supply
     */
    function setSupply(address _asset, uint256 _totalAmount) onlyObserver public {
        
        require(_totalAmount >= 0, "updateSupply param _amount err!");
        require(_asset != address(0), "updateSupply param _asset err!");

        determineAID(_asset);
        
        uint256 _old = assetTotalSupply_[_asset].totalSupply;
        assetTotalSupply_[_asset].totalSupply = _totalAmount;

        emit UpdateTotalAsset(_asset, _old, _totalAmount);

    }

    /*

    */
    function getAID() onlyObserver external view returns(uint256) {
        return(aID_);
    }

    function getSupply(address _asset) external view returns(uint256,uint256) {
        require(_asset != address(0), "getSupply param _asset err!");

        return (assetTotalSupply_[_asset].totalSupply, assetTotalSupply_[_asset].selfSupply);
    }

}
