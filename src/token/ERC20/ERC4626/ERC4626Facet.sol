// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/**
 * @dev Implementation of the ERC-4626
 */
contract ERC4626Facet {
    event Deposit(address indexed caller, address indexed owner, uint256 assets, uint256 shares);
    event Withdraw(address indexed caller, address indexed receiver, address indexed owner, uint256 assets, uint256 shares);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event Transfer(address indexed from, address indexed to, uint256 value);

    error ERC4626ExceededMaxDeposit(address receiver, uint256 assets, uint256 max);
    error ERC4626ExceededMaxMint(address receiver, uint256 shares, uint256 max);
    error ERC4626ExceededMaxWithdraw(address owner, uint256 assets, uint256 max);
    error ERC4626ExceededMaxRedeem(address owner, uint256 shares, uint256 max);
    error ERC4626ZeroBalance();

    bytes32 constant STORAGE_POSITION = keccak256("compose.erc4626");
    bytes32 constant ERC20_STORAGE_POSITION = keccak256("compose.erc20");

    struct ERC20Storage {
        mapping(address owner => uint256 balance) balanceOf;
        uint256 totalSupply;
        mapping(address owner => mapping(address spender => uint256 allowance)) allowances;
        uint8 decimals;
        string name;
        string symbol;
    }

    struct ERC4626Storage {
        IERC20 asset;
    }

    function getStorage() internal pure returns (ERC4626Storage storage s) {
        bytes32 position = STORAGE_POSITION;
        assembly {
            s.slot := position
        }
    }

    function getERC20Storage() internal pure returns (ERC20Storage storage s) {
        bytes32 position = ERC20_STORAGE_POSITION;
        assembly {
            s.slot := position
        }
    }

    function asset() public view returns (address) {
        return address(getStorage().asset);
    }

    function totalAssets() public view returns (uint256) {
        return getStorage().asset.balanceOf(address(this));
    }

    function decimals() public view returns (uint8) {
        ERC20Storage storage erc20s = getERC20Storage();
        return erc20s.decimals;
    }

    function balanceOf(address account) public view returns (uint256) {
        ERC20Storage storage erc20s = getERC20Storage();
        return erc20s.balanceOf[account];
    }

    function totalSupply() public view returns (uint256) {
        ERC20Storage storage s = getERC20Storage();
        return s.totalSupply;
    }

    function convertToShares(uint256 assets) public view returns (uint256) {
        uint256 supply = totalSupply();
        if (supply == 0) {
            revert ERC4626ZeroBalance();
        }
        return assets * supply / totalAssets();
    }

    function convertToAssets(uint256 shares) public view returns (uint256) {
        uint256 supply = totalSupply();
        if (supply == 0) {
            return shares;
        }
        return shares * totalAssets() / supply;
    }


    function previewDeposit(uint256 assets) public view returns (uint256) {
        return convertToShares(assets);
    }

    function previewMint(uint256 shares) public view returns (uint256) {
        uint256 supply = totalSupply();
        uint256 assets = totalAssets();
        if (supply == 0) {
            return shares;
        }
        return (shares * assets + supply - 1) / supply;
    }

    function previewWithdraw(uint256 assets) public view returns (uint256) {
        uint256 supply = totalSupply();
        uint256 total = totalAssets();
        if (supply == 0) {
            return assets;
        }
        return (assets * supply + total - 1) / total;
    }

    function previewRedeem(uint256 shares) public view returns (uint256) {
        return convertToAssets(shares);
    }

    function maxDeposit(address) public view returns (uint256) {
        return type(uint256).max;
    }

    function maxMint(address) public view returns (uint256) {
        return type(uint256).max;
    }

    function maxWithdraw(address owner) public view returns (uint256) {
        return previewRedeem(maxRedeem(owner));
    }

    function maxRedeem(address owner) public view returns (uint256) {
        return balanceOf(owner);
    }


    function deposit(uint256 assets, address receiver) public returns (uint256) {
        uint256 maxAssets = maxDeposit(receiver);
        if (assets > maxAssets) {
            revert ERC4626ExceededMaxDeposit(receiver, assets, maxAssets);
        }
        uint256 shares = previewDeposit(assets);
        require(shares != 0, "ZERO_SHARES");

        _deposit(_msgSender(), receiver, assets, shares);
        return shares;
    }

    function mint(uint256 shares, address receiver) public returns (uint256) {
        uint256 maxShares = maxMint(receiver);
        if (shares > maxShares) {
            revert ERC4626ExceededMaxMint(receiver, shares, maxShares);
        }
        uint256 assets = previewMint(shares);
        require(assets != 0, "ZERO_ASSETS");

        _deposit(_msgSender(), receiver, assets, shares);
        return assets;
    }

    // ========== Withdraw/Redeem ==========

    function withdraw(uint256 assets, address receiver, address owner) public returns (uint256) {
        uint256 maxAssets = maxWithdraw(owner);
        if (assets > maxAssets) {
            revert ERC4626ExceededMaxWithdraw(owner, assets, maxAssets);
        }
        uint256 shares = previewWithdraw(assets);
        require(shares != 0, "ZERO_SHARES");

        _withdraw(_msgSender(), receiver, owner, assets, shares);
        return shares;
    }

    function redeem(uint256 shares, address receiver, address owner) public returns (uint256) {
        uint256 maxShares = maxRedeem(owner);
        if (shares > maxShares) {
            revert ERC4626ExceededMaxRedeem(owner, shares, maxShares);
        }
        uint256 assets = previewRedeem(shares);
        require(assets != 0, "ZERO_ASSETS");

        _withdraw(_msgSender(), receiver, owner, assets, shares);
        return assets;
    }


    // ========== Internal Deposit ==========

    function _deposit(address caller, address receiver, uint256 assets, uint256 shares) internal {
        require(receiver != address(0), "RECEIVER_ZERO");
        ERC20Storage storage erc20s = getERC20Storage();
        getStorage().asset.transferFrom(caller, address(this), assets);

        erc20s.totalSupply += shares;
        erc20s.balanceOf[receiver] += shares;

        emit Transfer(address(0), receiver, shares);
        emit Deposit(caller, receiver, assets, shares);
    }

    // ========== Internal Withdraw ==========

    function _withdraw(
        address caller,
        address receiver,
        address owner,
        uint256 assets,
        uint256 shares
    ) internal {
        ERC20Storage storage erc20s = getERC20Storage();

        if (caller != owner) {
            uint256 allowed = erc20s.allowances[owner][caller];
            require(allowed >= shares, "INSUFFICIENT_ALLOWANCE");
            if (allowed != type(uint256).max) {
                erc20s.allowances[owner][caller] = allowed - shares;
            }
        }
        require(receiver != address(0), "RECEIVER_ZERO");

        erc20s.balanceOf[owner] -= shares;
        erc20s.totalSupply -= shares;

        emit Transfer(owner, address(0), shares);

        getStorage().asset.transfer(receiver, assets);

        emit Withdraw(caller, receiver, owner, assets, shares);
    }

    // ========== Utility Functions ==========

    function _msgSender() internal view returns (address) {
        return msg.sender;
    }
}
