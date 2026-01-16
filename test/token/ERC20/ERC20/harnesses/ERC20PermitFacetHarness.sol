// // SPDX-License-Identifier: MIT
// pragma solidity >=0.8.30;
//
// /* Compose
//  * https://compose.diamonds
//  */
//
// import {ERC20PermitFacet} from "src/token/ERC20/ERC20Permit/ERC20PermitFacet.sol";
//
// /**
//  * @title ERC20PermitFacetHarness
//  * @notice Test harness for ERC20PermitFacet that adds initialization and minting for testing
//  */
// contract ERC20PermitFacetHarness is ERC20PermitFacet {
//     event Transfer(address indexed _from, address indexed _to, uint256 _value);
//
//     /**
//      * @notice Initialize the ERC20 token storage
//      * @dev Only used for testing - production diamonds should initialize in constructor
//      */
//     function initialize(string memory _name) external {
//         ERC20MetadataStorage storage s = getERC20MetadataStorage();
//         s.name = _name;
//     }
//
//     /**
//      * @notice Mint tokens to an address
//      * @dev Only used for testing - exposes internal mint functionality
//      */
//     function mint(address _to, uint256 _value) external {
//         ERC20TransferStorage storage s = getERC20TransferStorage();
//         require(_to != address(0), "ERC20: mint to zero address");
//         unchecked {
//             s.totalSupply += _value;
//             s.balanceOf[_to] += _value;
//         }
//         emit Transfer(address(0), _to, _value);
//     }
//
//     /**
//      * @notice ERC20 view helpers so tests can call the standard API
//      */
//     function balanceOf(address _account) external view returns (uint256) {
//         return getERC20TransferStorage().balanceOf[_account];
//     }
//
//     function totalSupply() external view returns (uint256) {
//         return getERC20TransferStorage().totalSupply;
//     }
//
//     function allowance(address _owner, address _spender) external view returns (uint256) {
//         return getERC20TransferStorage().allowance[_owner][_spender];
//     }
//
//     /**
//      * @notice Minimal approve implementation for tests
//      */
//     function approve(address _spender, uint256 _value) external returns (bool) {
//         require(_spender != address(0), "ERC20: approve to zero address");
//         ERC20TransferStorage storage s = getERC20TransferStorage();
//         s.allowance[msg.sender][_spender] = _value;
//         emit Approval(msg.sender, _spender, _value);
//         return true;
//     }
//
//     /**
//      * @notice TransferFrom implementation for tests (needed by test_Permit_ThenTransferFrom)
//      */
//     function transferFrom(address _from, address _to, uint256 _value) external returns (bool) {
//         ERC20TransferStorage storage s = getERC20TransferStorage();
//         require(_to != address(0), "ERC20: transfer to zero address");
//         require(s.balanceOf[_from] >= _value, "ERC20: insufficient balance");
//
//         uint256 currentAllowance = s.allowance[_from][msg.sender];
//         require(currentAllowance >= _value, "ERC20: insufficient allowance");
//
//         unchecked {
//             s.allowance[_from][msg.sender] = currentAllowance - _value;
//             s.balanceOf[_from] -= _value;
//         }
//         s.balanceOf[_to] += _value;
//         emit Transfer(_from, _to, _value);
//         return true;
//     }
// }
