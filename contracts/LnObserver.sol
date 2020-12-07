// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;

contract LnObserver {
    address public observer_;
    address public candidate_;

    constructor(address _observer) public {
        require(_observer != address(0), "observer address cannot be 0");
        observer_ = _observer;
        emit ObserverChanged(address(0), _observer);
    }

    //设置候选人
    function setCandidate(address _candidate) external onlyObserver {
        address _old = candidate_;
        candidate_ = _candidate;
        emit candidateChanged( _old, candidate_);
    }

    function becomeObserver() external {
        require( msg.sender == candidate_, "Only candidate can become Observer");
        address _old = observer_;
        observer_ = candidate_;
        emit ObserverChanged( _old, observer_ ); 
    }

    modifier onlyObserver {
        require( (msg.sender == observer_), "Only the contract observer can perform this action");
        _;
    }
    
    //更改候选人
    event candidateChanged(address _oldCandidate, address _newCandidate );
    //更改观察者
    event ObserverChanged(address _oldObserver, address newObserver);
}

