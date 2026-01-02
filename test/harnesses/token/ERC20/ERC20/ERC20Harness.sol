// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import "src/token/ERC20/ERC20/ERC20Mod.sol" as ERC20Mod;

/**
 * @title ERC20Harness
 * @notice Test harness that exposes LibERC20's internal functions as external
 * @dev Required for testing since LibERC20 only has internal functions
 */
contract ERC20Harness {
    /**
     * @notice Initialize the ERC20 token storage
     * @dev Only used for testing
     */
    function initialize(string memory _name, string memory _symbol, uint8 _decimals) external {
        ERC20Mod.ERC20Storage storage s = ERC20Mod.getStorage();
        s.name = _name;
        s.symbol = _symbol;
        s.decimals = _decimals;
    }

    /**
     * @notice Exposes ERC20Mod.mint as an external function
     */
    function mint(address _account, uint256 _value) external {
        ERC20Mod.mint(_account, _value);
    }

    /**
     * @notice Exposes ERC20Mod.burn as an external function
     */
    function burn(address _account, uint256 _value) external {
        ERC20Mod.burn(_account, _value);
    }

    /**
     * @notice Exposes ERC20Mod.transferFrom as an external function
     */
    function transferFrom(address _from, address _to, uint256 _value) external {
        ERC20Mod.transferFrom(_from, _to, _value);
    }

    /**
     * @notice Exposes ERC20Mod.transfer as an external function
     */
    function transfer(address _to, uint256 _value) external {
        ERC20Mod.transfer(_to, _value);
    }

    /**
     * @notice Exposes ERC20Mod.approve as an external function
     */
    function approve(address _spender, uint256 _value) external {
        ERC20Mod.approve(_spender, _value);
    }

    /**
     * @notice Get storage values for testing
     */
    function name() external view returns (string memory) {
        return ERC20Mod.getStorage().name;
    }

    function symbol() external view returns (string memory) {
        return ERC20Mod.getStorage().symbol;
    }

    function decimals() external view returns (uint8) {
        return ERC20Mod.getStorage().decimals;
    }

    function totalSupply() external view returns (uint256) {
        return ERC20Mod.getStorage().totalSupply;
    }

    function balanceOf(address _account) external view returns (uint256) {
        return ERC20Mod.getStorage().balanceOf[_account];
    }

    function allowance(address _owner, address _spender) external view returns (uint256) {
        return ERC20Mod.getStorage().allowance[_owner][_spender];
    }
}
