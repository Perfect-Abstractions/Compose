// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/// @notice Minimal IERC20 interface
interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

/**
 * @dev Implementation of the ERC-4626
 */
contract ERC4626Facet {
    event Deposit(address indexed caller, address indexed owner, uint256 assets, uint256 shares);
    event Withdraw(
        address indexed caller, address indexed receiver, address indexed owner, uint256 assets, uint256 shares
    );
    event Transfer(address indexed from, address indexed to, uint256 value);

    error ERC4626ExceededMaxDeposit(address receiver, uint256 assets, uint256 max);
    error ERC4626ExceededMaxMint(address receiver, uint256 shares, uint256 max);
    error ERC4626ExceededMaxWithdraw(address owner, uint256 assets, uint256 max);
    error ERC4626ExceededMaxRedeem(address owner, uint256 shares, uint256 max);
    error ERC4626InsufficientAllowance(address owner, address caller, uint256 allowed, uint256 required);
    error ERC4626TransferFailed(address from, address to, uint256 amount);
    error ERC4626ZeroAmount(uint256 amount);
    error ERC4626ZeroAddress(address addr);

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

    function totalShares() public view returns (uint256) {
        ERC20Storage storage s = getERC20Storage();
        return s.totalSupply;
    }

    function convertToShares(uint256 assets) public view returns (uint256) {
        uint256 totalShare = totalShares();
        /**
         * This is the state when the vault was used for the first time.
         * The ratio between the assets and the shares is 1:1 when the vault is in initial state.
         */
        if (totalShare == 0) {
            return assets;
        }
        return assets * totalShare / totalAssets();
    }

    function convertToAssets(uint256 shares) public view returns (uint256) {
        uint256 totalShare = totalShares();
        /**
         * This is the state when the vault was used for the first time.
         * The ratio between the assets and the shares is 1:1 when the vault is in initial state.
         */
        if (totalShare == 0) {
            return shares;
        }
        return shares * totalAssets() / totalShare;
    }

    function previewDeposit(uint256 assets) public view returns (uint256) {
        return convertToShares(assets);
    }

    function previewMint(uint256 shares) public view returns (uint256) {
        uint256 totalShare = totalShares();
        uint256 totalAsset = totalAssets();
        if (totalShare == 0) {
            return shares;
        }

        // rounded up
        return (shares * totalAsset + totalShare - 1) / totalShare;
    }

    function previewWithdraw(uint256 assets) public view returns (uint256) {
        uint256 totalShare = totalShares();
        uint256 totalAsset = totalAssets();
        if (totalShare == 0) {
            return assets;
        }
        return (assets * totalShare + totalAsset - 1) / totalAsset;
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
        if (shares == 0) {
            revert ERC4626ZeroAmount(shares);
        }

        if (receiver == address(0)) {
            revert ERC4626ZeroAddress(receiver);
        }
        ERC20Storage storage erc20s = getERC20Storage();
        if (!getStorage().asset.transferFrom(msg.sender, address(this), assets)) {
            revert ERC4626TransferFailed(msg.sender, address(this), assets);
        }
        erc20s.totalSupply += shares;
        erc20s.balanceOf[receiver] += shares;
        emit Deposit(msg.sender, receiver, assets, shares);

        return shares;
    }

    function mint(uint256 shares, address receiver) public returns (uint256) {
        uint256 maxShares = maxMint(receiver);
        if (shares > maxShares) {
            revert ERC4626ExceededMaxMint(receiver, shares, maxShares);
        }
        uint256 assets = previewMint(shares);
        if (assets == 0) {
            revert ERC4626ZeroAmount(assets);
        }

        if (receiver == address(0)) {
            revert ERC4626ZeroAddress(receiver);
        }
        ERC20Storage storage erc20s = getERC20Storage();
        if (!getStorage().asset.transferFrom(msg.sender, address(this), assets)) {
            revert ERC4626TransferFailed(msg.sender, address(this), assets);
        }
        erc20s.totalSupply += shares;
        erc20s.balanceOf[receiver] += shares;
        emit Deposit(msg.sender, receiver, assets, shares);

        return assets;
    }

    function withdraw(uint256 assets, address receiver, address owner) public returns (uint256) {
        uint256 maxAssets = maxWithdraw(owner);
        if (assets > maxAssets) {
            revert ERC4626ExceededMaxWithdraw(owner, assets, maxAssets);
        }
        uint256 shares = previewWithdraw(assets);
        if (shares == 0) {
            revert ERC4626ZeroAmount(shares);
        }

        ERC20Storage storage erc20s = getERC20Storage();

        if (msg.sender != owner) {
            uint256 allowed = erc20s.allowances[owner][msg.sender];
            if (allowed < shares) {
                revert ERC4626InsufficientAllowance(owner, msg.sender, allowed, shares);
            }
            if (allowed != type(uint256).max) {
                erc20s.allowances[owner][msg.sender] = allowed - shares;
            }
        }
        if (receiver == address(0)) {
            revert ERC4626ZeroAddress(receiver);
        }

        erc20s.balanceOf[owner] -= shares;
        erc20s.totalSupply -= shares;

        emit Transfer(owner, address(0), shares);

        if (!getStorage().asset.transfer(receiver, assets)) {
            revert ERC4626TransferFailed(address(this), receiver, assets);
        }

        emit Withdraw(msg.sender, receiver, owner, assets, shares);

        return shares;
    }

    function redeem(uint256 shares, address receiver, address owner) public returns (uint256) {
        uint256 maxShares = maxRedeem(owner);
        if (shares > maxShares) {
            revert ERC4626ExceededMaxRedeem(owner, shares, maxShares);
        }
        uint256 assets = previewRedeem(shares);
        if (assets == 0) {
            revert ERC4626ZeroAmount(assets);
        }

        ERC20Storage storage erc20s = getERC20Storage();

        if (msg.sender != owner) {
            uint256 allowed = erc20s.allowances[owner][msg.sender];
            if (allowed < shares) {
                revert ERC4626InsufficientAllowance(owner, msg.sender, allowed, shares);
            }
            if (allowed != type(uint256).max) {
                erc20s.allowances[owner][msg.sender] = allowed - shares;
            }
        }
        if (receiver == address(0)) {
            revert ERC4626ZeroAddress(receiver);
        }

        erc20s.balanceOf[owner] -= shares;
        erc20s.totalSupply -= shares;

        emit Transfer(owner, address(0), shares);

        if (!getStorage().asset.transfer(receiver, assets)) {
            revert ERC4626TransferFailed(address(this), receiver, assets);
        }

        emit Withdraw(msg.sender, receiver, owner, assets, shares);

        return assets;
    }
}
