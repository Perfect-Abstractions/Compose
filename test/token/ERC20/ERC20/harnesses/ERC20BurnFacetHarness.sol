// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {ERC20BurnFacet} from "../../../../../src/token/ERC20/ERC20/ERC20BurnFacet.sol";

/**
 * @title ERC20BurnFacetHarness
 * @notice Test harness for ERC20BurnFacet that adds initialization and minting for testing
 */
contract ERC20BurnFacetHarness is ERC20BurnFacet {
    event Approval(address indexed _owner, address indexed _spender, uint256 _value);

    /**
     * @notice ERC20 view helpers so tests can call the standard API
     */
    function balanceOf(address _account) external view returns (uint256) {
        return getStorage().balanceOf[_account];
    }

    function totalSupply() external view returns (uint256) {
        return getStorage().totalSupply;
    }

    function allowance(address _owner, address _spender) external view returns (uint256) {
        return getStorage().allowance[_owner][_spender];
    }

    /**
     * @notice Minimal approve implementation for tests (writes into the same storage used by burnFrom)
     */
    function approve(address _spender, uint256 _value) external returns (bool) {
        require(_spender != address(0), "ERC20: approve to zero address");
        ERC20Storage storage s = getStorage();
        s.allowance[msg.sender][_spender] = _value;
        emit Approval(msg.sender, _spender, _value);
        return true;
    }

    /**
     * @notice Mint tokens to an address
     * @dev Only used for testing - exposes internal mint functionality
     */
    function mint(address _to, uint256 _value) external {
        ERC20Storage storage s = getStorage();
        require(_to != address(0), "ERC20: mint to zero address");
        unchecked {
            s.totalSupply += _value;
            s.balanceOf[_to] += _value;
        }
        emit Transfer(address(0), _to, _value);
    }
}
