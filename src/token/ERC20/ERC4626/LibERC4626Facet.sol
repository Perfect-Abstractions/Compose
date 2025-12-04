



// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/** 
 * @title Minimal IERC20 interface
 * @notice Minimal interface to interact with ERC20 tokens
 */
interface IERC20 {
    /** 
     * @notice Returns the total supply of the token.
     */
    function totalSupply() external view returns (uint256);

    /** 
     * @notice Returns the balance of a given account.
     * @param account The account address to query.
     */
    function balanceOf(address account) external view returns (uint256);

    /** 
     * @notice Transfers tokens to a specified address.
     * @param to The recipient address.
     * @param amount The amount of tokens to transfer.
     * @return success True if transfer succeeded, false otherwise.
     */
    function transfer(address to, uint256 amount) external returns (bool);

    /** 
     * @notice Returns the allowance granted to a spender by the owner.
     * @param owner The owner's address.
     * @param spender The spender's address.
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /** 
     * @notice Approves a spender to spend a given amount.
     * @param spender The spender address.
     * @param amount The allowance amount.
     * @return success True if approval succeeded, false otherwise.
     */
    function approve(address spender, uint256 amount) external returns (bool);

    /** 
     * @notice Transfers tokens from one address to another using allowance.
     * @param from The sender address.
     * @param to The recipient address.
     * @param amount The amount to transfer.
     * @return success True if transfer succeeded, false otherwise.
     */
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

/** 
 * @title ERC4626Facet
 * @notice Implementation of the ERC-4626 Tokenized Vault standard
 */
contract ERC4626Facet {
    /** 
     * @notice Emitted after a deposit of `assets` and minting of `shares`
     * @param caller Address making the deposit call
     * @param owner Receives the minted shares
     * @param assets Amount of asset tokens deposited
     * @param shares Amount of vault shares minted
     */
    event Deposit(address indexed caller, address indexed owner, uint256 assets, uint256 shares);

    /** 
     * @notice Emitted after a withdrawal or redemption of `assets` and burning of `shares`
     * @param caller Address making the withdrawal call
     * @param receiver Receives the withdrawn assets
     * @param owner Owner of the withdrawn assets and burned shares
     * @param assets Amount of asset tokens withdrawn
     * @param shares Amount of vault shares burned
     */
    event Withdraw(
        address indexed caller, address indexed receiver, address indexed owner, uint256 assets, uint256 shares
    );

    /** 
     * @notice Emitted when vault shares are transferred (including minting/burning)
     * @param from Sender address
     * @param to Recipient address (zero address means burn)
     * @param value Amount of shares transferred
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /** 
     * @notice Reverts when the deposit exceeds maximum allowed assets for receiver
     */
    error ERC4626ExceededMaxDeposit(address receiver, uint256 assets, uint256 max);

    /** 
     * @notice Reverts when the mint exceeds maximum allowed shares for receiver
     */
    error ERC4626ExceededMaxMint(address receiver, uint256 shares, uint256 max);

    /** 
     * @notice Reverts when the withdraw exceeds maximum allowed assets for owner
     */
    error ERC4626ExceededMaxWithdraw(address owner, uint256 assets, uint256 max);

    /** 
     * @notice Reverts when the redeem exceeds maximum allowed shares for owner
     */
    error ERC4626ExceededMaxRedeem(address owner, uint256 shares, uint256 max);

    /** 
     * @notice Reverts when allowance is insufficient for withdraw/redeem
     */
    error ERC4626InsufficientAllowance(address owner, address caller, uint256 allowed, uint256 required);

    /** 
     * @notice Reverts when an asset transfer fails
     */
    error ERC4626TransferFailed(address from, address to, uint256 amount);

    /** 
     * @notice Reverts when zero amount is involved where not valid
     */
    error ERC4626ZeroAmount(uint256 amount);

    /** 
     * @notice Reverts on zero address input where not valid
     */
    error ERC4626ZeroAddress(address addr);

    /** 
     * @notice Storage slot used for ERC4626 data
     */
    bytes32 constant STORAGE_POSITION = keccak256("compose.erc4626");

    /** 
     * @notice Storage slot used for ERC20 data (shares)
     */
    bytes32 constant ERC20_STORAGE_POSITION = keccak256("compose.erc20");

    /** 
     * @notice ERC20 share vault storage
     */
    struct ERC20Storage {
        mapping(address owner => uint256 balance) balanceOf;
        uint256 totalSupply;
        mapping(address owner => mapping(address spender => uint256 allowance)) allowances;
        uint8 decimals;
        string name;
        string symbol;
    }

    /** 
     * @notice Storage containing vault's asset
     */
    struct ERC4626Storage {
        IERC20 asset;
    }

    /** 
     * @notice Returns storage struct for the ERC4626 position
     * @return s The storage reference for ERC4626Storage
     */
    function getStorage() internal pure returns (ERC4626Storage storage s) {
        bytes32 position = STORAGE_POSITION;
        assembly {
            s.slot := position
        }
    }

    /** 
     * @notice Returns storage struct for ERC20 shares
     * @return s The storage reference for ERC20Storage
     */
    function getERC20Storage() internal pure returns (ERC20Storage storage s) {
        bytes32 position = ERC20_STORAGE_POSITION;
        assembly {
            s.slot := position
        }
    }

    /** 
     * @notice The address of the asset managed by the vault.
     * @return The asset token address.
     */
    function asset() public view returns (address) {
        return address(getStorage().asset);
    }

    /** 
     * @notice Returns the total amount of the underlying asset managed by the vault.
     * @return The total assets held by the vault.
     */
    function totalAssets() public view returns (uint256) {
        return getStorage().asset.balanceOf(address(this));
    }

    /** 
     * @notice Returns the number of decimals of the vault share token.
     * @return Number of decimals.
     */
    function decimals() public view returns (uint8) {
        ERC20Storage storage erc20s = getERC20Storage();
        return erc20s.decimals;
    }

    /** 
     * @notice Returns the share balance of an account.
     * @param account The address to query.
     * @return The balance of shares owned by `account`.
     */
    function balanceOf(address account) public view returns (uint256) {
        ERC20Storage storage erc20s = getERC20Storage();
        return erc20s.balanceOf[account];
    }

    /** 
     * @notice Returns the total supply of vault shares.
     * @return The total shares (ERC20 tokens) in existence.
     */
    function totalShares() public view returns (uint256) {
        ERC20Storage storage s = getERC20Storage();
        return s.totalSupply;
    }

    /** 
     * @notice Converts an amount of assets to the equivalent amount of shares.
     * @param assets Amount of asset tokens.
     * @return The computed amount of shares for `assets`.
     */
    function convertToShares(uint256 assets) public view returns (uint256) {
        uint256 totalShare = totalShares();
        /** 
         * If no shares exist, 1:1 ratio between asset and shares
         */
        if (totalShare == 0) {
            return assets;
        }
        return assets * totalShare / totalAssets();
    }

    /** 
     * @notice Converts an amount of shares to the equivalent amount of assets.
     * @param shares Amount of vault shares.
     * @return Amount of asset tokens equivalent to `shares`.
     */
    function convertToAssets(uint256 shares) public view returns (uint256) {
        uint256 totalShare = totalShares();
        /** 
         * If no shares exist, 1:1 ratio between asset and shares
         */
        if (totalShare == 0) {
            return shares;
        }
        return shares * totalAssets() / totalShare;
    }

    /** 
     * @notice Returns the amount of shares that would be minted for a deposit of `assets`.
     * @param assets Amount of assets to deposit.
     * @return shares Amount of shares previewed.
     */
    function previewDeposit(uint256 assets) public view returns (uint256) {
        return convertToShares(assets);
    }

    /** 
     * @notice Returns the amount of assets required for a mint of `shares`.
     * @param shares Amount of shares to mint.
     * @return assets Amount of assets previewed.
     */
    function previewMint(uint256 shares) public view returns (uint256) {
        uint256 totalShare = totalShares();
        uint256 totalAsset = totalAssets();
        if (totalShare == 0) {
            return shares;
        }

        /** 
         * Rounds up the result
         */
        return (shares * totalAsset + totalShare - 1) / totalShare;
    }

    /** 
     * @notice Returns the number of shares needed to withdraw `assets` assets.
     * @param assets Amount of assets to withdraw.
     * @return shares Number of shares required.
     */
    function previewWithdraw(uint256 assets) public view returns (uint256) {
        uint256 totalShare = totalShares();
        uint256 totalAsset = totalAssets();
        if (totalShare == 0) {
            return assets;
        }
        /** 
         * Rounds up the result
         */
        return (assets * totalShare + totalAsset - 1) / totalAsset;
    }

    /** 
     * @notice Returns the amount of assets redeemed for a given amount of shares.
     * @param shares Amount of shares to redeem.
     * @return assets Amount of assets previewed.
     */
    function previewRedeem(uint256 shares) public view returns (uint256) {
        return convertToAssets(shares);
    }

    /** 
     * @notice Returns the maximum amount of assets that can be deposited for `receiver`.
     * @param receiver Address of the receiver (ignored, always max).
     * @return max Maximum deposit amount allowed.
     */
    function maxDeposit(address receiver) public view returns (uint256) {
        return type(uint256).max;
    }

    /** 
     * @notice Returns the maximum number of shares that can be minted for `receiver`.
     * @param receiver Address of the receiver (ignored, always max).
     * @return max Maximum mint amount allowed.
     */
    function maxMint(address receiver) public view returns (uint256) {
        return type(uint256).max;
    }

    /** 
     * @notice Returns the maximum amount of assets that can be withdrawn for `owner`.
     * @param owner The address to query.
     * @return max Maximum amount of assets withdrawable.
     */
    function maxWithdraw(address owner) public view returns (uint256) {
        return previewRedeem(maxRedeem(owner));
    }

    /** 
     * @notice Returns the maximum number of shares that can be redeemed for `owner`.
     * @param owner The address to query.
     * @return max Maximum shares redeemable (equal to owner's balance).
     */
    function maxRedeem(address owner) public view returns (uint256) {
        return balanceOf(owner);
    }

    /** 
     * @notice Deposits asset tokens and mints corresponding shares to `receiver`.
     * @param assets Amount of asset tokens to deposit.
     * @param receiver Address to receive minted shares.
     * @return shares Amount of shares minted.
     */
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

    /** 
     * @notice Mints `shares` vault shares to `receiver` by transferring corresponding asset amount from caller.
     * @param shares Amount of shares to mint.
     * @param receiver Address to receive minted shares.
     * @return assets Amount of assets transferred from caller.
     */
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

    /** 
     * @notice Burns shares from `owner` and transfers corresponding assets to `receiver`.
     * @param assets Amount of assets to withdraw.
     * @param receiver Address receiving the withdrawn assets.
     * @param owner The address whose shares are burned.
     * @return shares Amount of shares burned.
     */
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

    /** 
     * @notice Redeems `shares` from `owner` and transfers corresponding assets to `receiver`.
     * @param shares Amount of shares to redeem.
     * @param receiver Address to receive redeemed assets.
     * @param owner Address whose shares are redeemed.
     * @return assets Amount of assets transferred to receiver.
     */
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
