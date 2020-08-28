
pragma solidity ^0.5.17;


import "./LnAdmin.sol";

contract LnAddressStorage is LnAdmin {

    mapping(bytes32 => address) public mStorage;

    constructor(address _admin ) public LnAdmin(_admin ) {}


    function updateAll(bytes32[] calldata names, address[] calldata destinations) external onlyAdmin {
        require(names.length == destinations.length, "Input lengths must match");

        for (uint i = 0; i < names.length; i++) {
            mStorage[names[i]] = destinations[i];
        }
    }

    function update(bytes32 name, address dest ) external onlyAdmin {
        require( name != "", "name can not be empty");
        require( dest != address(0), "address cannot be 0");
        mStorage[name] = dest;
    }

    function getAddress(bytes32 name) external view returns (address) {
        return mStorage[name];
    }

    function getAddressWithRequire(bytes32 name, string calldata reason) external view returns (address) {
        address _foundAddress = mStorage[name];
        require(_foundAddress != address(0), reason);
        return _foundAddress;
    }
}


interface LnAddressCache  {
    function updateAddressCache( address _addressStorage )  external ;

}

contract testAddressCache  is LnAddressCache, LnAdmin {
    address public addr1;
    address public addr2;
    
    constructor(address _admin ) public LnAdmin(_admin ) {}


    function updateAddressCache( address _addressStorage ) onlyAdmin public
    {
        addr1 = LnAddressStorage(_addressStorage).getAddressWithRequire("a", "");
        addr2 = LnAddressStorage(_addressStorage).getAddressWithRequire("b", "" );
        
    }


}