pragma solidity ^0.5.17;

import "./LnAdmin.sol";

import "./LnProxyBase.sol";


contract LnProxyBase is LnAdmin {
    LnProxyImpl public target;

    constructor(address _owner) public LnAdmin(_owner) {}

    function setTarget(LnProxyImpl _target) external onlyAdmin {
        target = _target;
        emit TargetUpdated(_target);
    }

    function _emit(
        bytes calldata callData,
        uint numTopics,
        bytes32 topic1,
        bytes32 topic2,
        bytes32 topic3,
        bytes32 topic4
    ) external onlyTarget {
        uint size = callData.length;
        bytes memory _callData = callData;

        assembly {
            
            switch numTopics
                case 0 {
                    log0(add(_callData, 32), size)
                }
                case 1 {
                    log1(add(_callData, 32), size, topic1)
                }
                case 2 {
                    log2(add(_callData, 32), size, topic1, topic2)
                }
                case 3 {
                    log3(add(_callData, 32), size, topic1, topic2, topic3)
                }
                case 4 {
                    log4(add(_callData, 32), size, topic1, topic2, topic3, topic4)
                }
        }
    }

    function() external payable {
        
        target.setMessageSender(msg.sender);

        assembly {
            let free_ptr := mload(0x40)
            calldatacopy(free_ptr, 0, calldatasize)

            let result := call(gas, sload(target_slot), callvalue, free_ptr, calldatasize, 0, 0)
            returndatacopy(free_ptr, 0, returndatasize)

            if iszero(result) {
                revert(free_ptr, returndatasize)
            }
            return(free_ptr, returndatasize)
        }
    }

    modifier onlyTarget {
        require(LnProxyImpl(msg.sender) == target, "Must be proxy target");
        _;
    }

    event TargetUpdated(LnProxyImpl newTarget);
}


contract LnProxyImpl is LnAdmin {
    
    LnProxyBase public proxy;
    LnProxyBase public integrationProxy;

    address public messageSender;

    constructor(address payable _proxy) internal {
        
        require(admin != address(0), "Admin must be set");

        proxy = LnProxyBase(_proxy);
        emit ProxyUpdated(_proxy);
    }

    function setProxy(address payable _proxy) external onlyAdmin {
        proxy = LnProxyBase(_proxy);
        emit ProxyUpdated(_proxy);
    }

    function setIntegrationProxy(address payable _integrationProxy) external onlyAdmin {
        integrationProxy = LnProxyBase(_integrationProxy);
    }

    function setMessageSender(address sender) external onlyProxy {
        messageSender = sender;
    }

    modifier onlyProxy {
        require(LnProxyBase(msg.sender) == proxy || LnProxyBase(msg.sender) == integrationProxy, "Only the proxy can call");
        _;
    }

    modifier optionalProxy {
        if (LnProxyBase(msg.sender) != proxy && LnProxyBase(msg.sender) != integrationProxy && messageSender != msg.sender) {
            messageSender = msg.sender;
        }
        _;
    }

    modifier optionalProxy_onlyAdmin {
        if (LnProxyBase(msg.sender) != proxy && LnProxyBase(msg.sender) != integrationProxy && messageSender != msg.sender) {
            messageSender = msg.sender;
        }
        require(messageSender == admin, "only for admin");
        _;
    }

    event ProxyUpdated(address proxyAddress);
}

