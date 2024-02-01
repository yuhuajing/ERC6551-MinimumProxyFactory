// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract MinimalProxyFactory {
    address[] public proxies;

    function deployClone(address _implementationContract, bytes memory salt)
        external
        payable
        returns (address)
    {
        //address to assign cloned proxy
        address proxy;
        address owner;
        bytes memory createCode = _createCode(_implementationContract);
        assembly {
            owner := mload(add(salt, 20))
            /*
            |                 20 bytes                  |          20 bytes          |           15 bytes          |
            0x3d602d80600a3d3981f3363d3d373d3d3d363d73b<implementationContractInBytes>5af43d82803e903d91602b57fd5bf3 == 45 bytes in total
            */
            // create a new contract
            // send 0 Ether
            // code starts at the pointer stored in "clone"
            // code size == 0x37 (55 bytes)

           // proxy := create2(0, add(createCode, 0x20), mload(createCode), salt)
            proxy := create(0, createCode, 0x37)
        }


        ImplementationContract(proxy).initializer(owner);
        proxies.push(proxy);
        return proxy;
    }

    function _createCode(address _implementationContract)
        internal
        pure
        returns (bytes memory clone)
    {
        // convert the address to 20 bytes
        bytes20 implementationContractInBytes = bytes20(
            _implementationContract
        );

        // as stated earlier, the minimal proxy has this bytecode
        // <3d602d80600a3d3981f3363d3d373d3d3d363d73><address of implementation contract><5af43d82803e903d91602b57fd5bf3>
        // <3d602d80600a3d3981f3> == creation code which copy runtime code into memory and deploy it
        // <363d3d373d3d3d363d73> <address of implementation contract> <5af43d82803e903d91602b57fd5bf3> == runtime code that makes a delegatecall to the implentation contract
        assembly {
            /*
            reads the 32 bytes of memory starting at pointer stored in 0x40
            In solidity, the 0x40 slot in memory is special: it contains the "free memory pointer"
            which points to the end of the currently allocated memory.
            */
            clone := mload(0x40)
            // store 32 bytes to memory starting at "clone"
            mstore(
                clone,
                0x3d602d80600a3d3981f3363d3d373d3d3d363d73000000000000000000000000
            )
            /*
              |              20 bytes                |
            0x3d602d80600a3d3981f3363d3d373d3d3d363d73000000000000000000000000
                                                      ^
                                                      pointer
            */
            // store 32 bytes to memory starting at "clone" + 20 bytes
            // 0x14 = 20
            mstore(add(clone, 0x14), implementationContractInBytes)

            /*
              |               20 bytes               |                 20 bytes              |
            0x3d602d80600a3d3981f3363d3d373d3d3d363d73bebebebebebebebebebebebebebebebebebebebe
                                                                                              ^
                                                                                              pointer
            */
            // store 32 bytes to memory starting at "clone" + 40 bytes
            // 0x28 = 40
            mstore(
                add(clone, 0x28),
                0x5af43d82803e903d91602b57fd5bf30000000000000000000000000000000000
            )

            /*
            |                 20 bytes                  |          20 bytes          |           15 bytes          |
            0x3d602d80600a3d3981f3363d3d373d3d3d363d73b<implementationContractInBytes>5af43d82803e903d91602b57fd5bf3 == 45 bytes in total
            */
        }
    }
}

contract ImplementationContract {
    address public owner;
    bool public isInitialized;

    //initializer function that will be called once, during deployment.
    function initializer(address _owner) external {
        require(!isInitialized);
        isInitialized = true;
        owner = _owner;
    }

    function resByte(address addr, uint256 num)
        public
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(addr, num);
    }
}
