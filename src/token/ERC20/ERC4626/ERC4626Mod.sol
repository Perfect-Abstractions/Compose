// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/**
 * @dev Simplified ERC20 interface.
 */
interface IERC20 {
    function totalSupply() external view returns (uint256);

    function balanceOf(address account) external view returns (uint256);

    function transfer(address to, uint256 amount) external returns (bool);

    function allowance(address owner, address spender) external view returns (uint256);

    function approve(address spender, uint256 amount) external returns (bool);

    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

error ERC4626InvalidAmount();
error ERC4626InvalidAddress();
error ERC4626TransferFailed();
error ERC4626InsufficientShares();
error ERC4626InsufficientAssets();

/**
 * @dev Emitted when assets are deposited and shares are minted.
 * @param sender The address that initiated the deposit.
 * @param owner The address receiving the shares.
 * @param assets Amount of assets deposited.
 * @param shares Amount of shares minted.
 */
event Deposit(address indexed sender, address indexed owner, uint256 assets, uint256 shares);

/**
 * @dev Emitted when assets are withdrawn and shares are burned.
 * @param sender The address that initiated the withdrawal.
 * @param receiver The address receiving the withdrawn assets.
 * @param owner The address whose shares are burnt.
 * @param assets Amount of assets withdrawn.
 * @param shares Amount of shares burned.
 */
event Withdraw(address indexed sender, address indexed receiver, address indexed owner, uint256 assets, uint256 shares);

bytes32 constant ERC20_STORAGE_POSITION = keccak256("compose.erc20");
bytes32 constant STORAGE_POSITION = keccak256("compose.erc4626");

uint256 constant VIRTUAL_ASSET = 1;
uint256 constant VIRTUAL_SHARE = 1e1;

/**
 * @dev Storage for ERC20 logic.
 */
struct ERC20Storage {
    mapping(address => uint256) balanceOf;
    uint256 totalSupply;
    mapping(address => mapping(address => uint256)) allowances;
    uint8 decimals;
    string name;
    string symbol;
}

/**
 * @dev Storage for ERC4626-specific data.
 */
struct ERC4626Storage {
    IERC20 asset;
}

/**
 * @dev Access ERC20Storage struct instance.
 */
function getERC20Storage() pure returns (ERC20Storage storage s) {
    bytes32 position = ERC20_STORAGE_POSITION;
    assembly {
        s.slot := position
    }
}

/**
 * @dev Access ERC4626Storage struct instance.
 */
function getStorage() pure returns (ERC4626Storage storage s) {
    bytes32 position = STORAGE_POSITION;
    assembly {
        s.slot := position
    }
}

/**
 * @notice Returns the address of the underlying ERC20 asset token.
 * @return assetTokenAddress The asset's contract address.
 */
function asset() view returns (address assetTokenAddress) {
    ERC4626Storage storage s = getStorage();
    assetTokenAddress = address(s.asset);
    return assetTokenAddress;
}

/**
 * @notice Returns the total amount of the underlying asset managed by the vault.
 * @return totalManagedAssets The total managed assets, including virtual assets.
 */
function totalAssets() view returns (uint256 totalManagedAssets) {
    ERC4626Storage storage s = getStorage();
    address diamondAddress;
    assembly {
        diamondAddress := address()
    }
    totalManagedAssets = s.asset.balanceOf(diamondAddress) + VIRTUAL_ASSET;
    return totalManagedAssets;
}

/**
 * @dev Compute (a * b) / denominator, using full precision and safe for overflow.
 *      Reference: https://xn--2-umb.com/21/muldiv/
 */
function muldiv(uint256 a, uint256 b, uint256 denominator) pure returns (uint256 result) {
    /**
     * Guard: denominator can't be zero
     */
    require(denominator > 0);

    uint256 prod0;
    uint256 prod1;

    assembly {
        let mm := mulmod(a, b, not(0))
        prod0 := mul(a, b)
        prod1 := sub(sub(mm, prod0), lt(mm, prod0))
    }

    /**
     * If high 256 bits are zero, use simple division
     */
    if (prod1 == 0) {
        assembly {
            result := div(prod0, denominator)
        }
        return result;
    }

    /**
     * Ensure denominator exceeds high bits for exact division after reduction
     */
    require(prod1 < denominator);

    /**
     * Subtract the modulus to enable exact division
     */
    uint256 remainder;
    assembly {
        remainder := mulmod(a, b, denominator)
    }
    assembly {
        prod1 := sub(prod1, gt(remainder, prod0))
        prod0 := sub(prod0, remainder)
    }

    /**
     * Remove factors of two from denominator and product
     */
    uint256 twos = (~denominator + 1) & denominator;
    assembly {
        denominator := div(denominator, twos)
        prod0 := div(prod0, twos)
        twos := add(div(sub(0, twos), twos), 1)
    }

    /**
     * Move high bits into low using bit shifts
     */
    prod0 |= prod1 * twos;

    /**
     * Compute modular inverse for denominator using Newton-Raphson
     */
    uint256 inv = (3 * denominator) ^ 2;
    inv *= 2 - denominator * inv;
    inv *= 2 - denominator * inv;
    inv *= 2 - denominator * inv;
    inv *= 2 - denominator * inv;
    inv *= 2 - denominator * inv;
    inv *= 2 - denominator * inv;

    /**
     * Complete division
     */
    result = prod0 * inv;
    return result;
}

/**
 * @dev Compute muldiv and round up the result if remainder exists.
 */
function mulDivRoundingUp(uint256 a, uint256 b, uint256 denominator) pure returns (uint256 result) {
    result = muldiv(a, b, denominator);
    if (mulmod(a, b, denominator) > 0) {
        require(result < type(uint256).max);
        result++;
    }
}

/**
 * @dev Convert an asset amount to shares using the vault's accountings.
 * @param assets The number of assets to convert to shares.
 */
function convertToShares(uint256 assets) view returns (uint256 shares) {
    ERC20Storage storage erc20s = getERC20Storage();
    uint256 totalShares_ = erc20s.totalSupply + VIRTUAL_SHARE;
    ERC4626Storage storage s = getStorage();
    address diamondAddress;
    assembly {
        diamondAddress := address()
    }
    uint256 totalAssets_ = s.asset.balanceOf(diamondAddress) + VIRTUAL_ASSET;
    shares = muldiv(totalShares_, assets, totalAssets_);
    return shares;
}

/**
 * @dev Convert shares to the corresponding asset amount.
 * @param shares The number of shares to convert.
 * @return assets The equivalent asset amount.
 */
function convertToAssets(uint256 shares) view returns (uint256 assets) {
    ERC20Storage storage erc20s = getERC20Storage();
    uint256 totalShares_ = erc20s.totalSupply + VIRTUAL_SHARE;
    ERC4626Storage storage s = getStorage();
    address diamondAddress;
    assembly {
        diamondAddress := address()
    }
    uint256 totalAssets_ = s.asset.balanceOf(diamondAddress) + VIRTUAL_ASSET;
    assets = muldiv(totalAssets_, shares, totalShares_);
    return assets;
}

/**
 * @notice Returns the maximum assets allowed for deposit by a receiver.
 * @dev Always returns the maximum possible uint256 value.
 * @return maxAssets The max depositable asset amount.
 */
function maxDeposit(
    /**
     * address receiver
     */
)
    view
    returns (uint256 maxAssets)
{
    maxAssets = type(uint256).max;
    return maxAssets;
}

/**
 * @notice Preview the number of shares that would be minted by depositing a given amount of assets.
 * @param assets Asset quantity to preview.
 * @return shares Estimated shares that would be minted.
 */
function previewDeposit(uint256 assets) view returns (uint256 shares) {
    ERC20Storage storage erc20s = getERC20Storage();
    uint256 totalShares_ = erc20s.totalSupply + VIRTUAL_SHARE;
    ERC4626Storage storage s = getStorage();
    address diamondAddress;
    assembly {
        diamondAddress := address()
    }
    uint256 totalAssets_ = s.asset.balanceOf(diamondAddress) + VIRTUAL_ASSET;
    shares = muldiv(totalShares_, assets, totalAssets_);
    return shares;
}

/**
 * @notice Executes a safe ERC20 transferFrom, supporting tokens that do not return a value.
 * @dev Returns true if the call succeeded, false otherwise.
 * @param token The ERC20 token contract.
 * @param from Source address.
 * @param to Destination address.
 * @param amount Value to transfer.
 * @return True if the operation succeeded, false otherwise.
 */
function _safeTransferFrom(IERC20 token, address from, address to, uint256 amount) returns (bool) {
    if (address(token).code.length == 0) return false;
    bytes memory data = abi.encodeWithSelector(token.transferFrom.selector, from, to, amount);
    (bool success, bytes memory returndata) = address(token).call(data);
    if (!success) return false;
    if (returndata.length == 0) {
        return true;
    } else if (returndata.length == 32) {
        return abi.decode(returndata, (bool));
    } else {
        return false;
    }
}

/**
 * @notice Executes a safe ERC20 transfer, supporting tokens that do not return a value.
 * @dev Returns true if the call succeeded, false otherwise.
 * @param token The ERC20 token contract.
 * @param to Destination address.
 * @param amount Value to transfer.
 * @return True if the operation succeeded, false otherwise.
 */
function _safeTransfer(IERC20 token, address to, uint256 amount) returns (bool) {
    if (address(token).code.length == 0) return false;
    bytes memory data = abi.encodeWithSelector(token.transfer.selector, to, amount);
    (bool success, bytes memory returndata) = address(token).call(data);
    if (!success) return false;
    if (returndata.length == 0) {
        return true;
    } else if (returndata.length == 32) {
        return abi.decode(returndata, (bool));
    } else {
        return false;
    }
}

/**
 * @notice Deposit assets into the vault and mint shares for a receiver.
 * @dev Transfers assets from msg.sender and mints shares for receiver.
 * @param assets Amount of underlying assets to deposit.
 * @param receiver Account to receive shares.
 * @return shares Number of shares minted for the deposit.
 */
function deposit(uint256 assets, address receiver) returns (uint256 shares) {
    if (receiver == address(0)) revert ERC4626InvalidAddress();

    ERC20Storage storage erc20s = getERC20Storage();
    uint256 totalShares_ = erc20s.totalSupply + VIRTUAL_SHARE;
    ERC4626Storage storage s = getStorage();
    address diamondAddress;
    assembly {
        diamondAddress := address()
    }
    uint256 totalAssets_ = s.asset.balanceOf(diamondAddress) + VIRTUAL_ASSET;
    shares = muldiv(totalShares_, assets, totalAssets_);

    if (shares == 0) revert ERC4626InsufficientShares();
    bool success = _safeTransferFrom(s.asset, msg.sender, diamondAddress, assets);
    if (!success) revert ERC4626TransferFailed();

    erc20s.totalSupply += shares;
    erc20s.balanceOf[receiver] += shares;

    emit Deposit(msg.sender, receiver, assets, shares);
    return shares;
}

/**
 * @notice Returns the maximum number of shares that can be minted to a receiver.
 * @dev Always returns the maximum possible uint256 value.
 * @return maxShares The maximum shares that may be minted.
 */
function maxMint(
    /**
     * address receiver
     */
)
    view
    returns (uint256 maxShares)
{
    maxShares = type(uint256).max;
    return maxShares;
}

/**
 * @notice Preview the required asset amount to mint a specific number of shares.
 * @param shares Number of shares to mint.
 * @return assets Assets needed to mint the given shares (rounded up).
 */
function previewMint(uint256 shares) view returns (uint256 assets) {
    ERC20Storage storage erc20s = getERC20Storage();
    uint256 totalShares_ = erc20s.totalSupply + VIRTUAL_SHARE;
    ERC4626Storage storage s = getStorage();
    address diamondAddress;
    assembly {
        diamondAddress := address()
    }
    uint256 totalAssets_ = s.asset.balanceOf(diamondAddress) + VIRTUAL_ASSET;
    assets = mulDivRoundingUp(totalAssets_, shares, totalShares_);
    return assets;
}

/**
 * @dev Mint exact shares in exchange for assets, assigning to receiver.
 * @param shares Number of shares to mint.
 * @param receiver Account to receive minted shares.
 * @return assets Amount of assets provided for minting.
 */
function mint(uint256 shares, address receiver) returns (uint256 assets) {
    if (receiver == address(0)) revert ERC4626InvalidAddress();

    ERC20Storage storage erc20s = getERC20Storage();
    uint256 totalShares_ = erc20s.totalSupply + VIRTUAL_SHARE;
    ERC4626Storage storage s = getStorage();
    address diamondAddress;
    assembly {
        diamondAddress := address()
    }
    uint256 totalAssets_ = s.asset.balanceOf(diamondAddress) + VIRTUAL_ASSET;
    assets = mulDivRoundingUp(totalAssets_, shares, totalShares_);

    if (assets == 0) revert ERC4626InsufficientAssets();
    bool success = _safeTransferFrom(s.asset, msg.sender, diamondAddress, assets);
    if (!success) revert ERC4626TransferFailed();

    erc20s.totalSupply += shares;
    erc20s.balanceOf[receiver] += shares;

    emit Deposit(msg.sender, receiver, assets, shares);
    return assets;
}

/**
 * @notice Returns the maximum amount of assets that an owner can withdraw.
 * @param owner Address for which the maximum withdrawal is calculated.
 * @return maxAssets Maximum withdrawable assets for the given owner.
 */
function maxWithdraw(address owner) view returns (uint256 maxAssets) {
    ERC20Storage storage erc20s = getERC20Storage();
    uint256 balance = erc20s.balanceOf[owner];
    ERC4626Storage storage s = getStorage();
    address diamondAddress;
    assembly {
        diamondAddress := address()
    }
    uint256 totalAssets_ = s.asset.balanceOf(diamondAddress) + VIRTUAL_ASSET;
    uint256 totalShares_ = erc20s.totalSupply + VIRTUAL_SHARE;
    maxAssets = muldiv(totalAssets_, balance, totalShares_);
    return maxAssets;
}

/**
 * @notice Preview the number of shares required to withdraw a given asset amount.
 * @param assets Amount of underlying assets to withdraw.
 * @return shares Number of shares that would be burned for the withdrawal (rounded up).
 */
function previewWithdraw(uint256 assets) view returns (uint256 shares) {
    ERC20Storage storage erc20s = getERC20Storage();
    uint256 totalShares_ = erc20s.totalSupply + VIRTUAL_SHARE;
    ERC4626Storage storage s = getStorage();
    address diamondAddress;
    assembly {
        diamondAddress := address()
    }
    uint256 totalAssets_ = s.asset.balanceOf(diamondAddress) + VIRTUAL_ASSET;
    shares = mulDivRoundingUp(totalShares_, assets, totalAssets_);
    return shares;
}

/**
 * @notice Withdraws a given amount of assets to receiver, burning appropriate shares from owner.
 * @dev Transfers assets and burns shares; handles allowances if needed.
 * @param assets Amount of assets to withdraw.
 * @param receiver Address to receive withdrawn assets.
 * @param owner Address whose shares will be burned.
 * @return shares Number of shares burned as a result of withdrawal.
 */
function withdraw(uint256 assets, address receiver, address owner) returns (uint256 shares) {
    if (receiver == address(0) || owner == address(0)) {
        revert ERC4626InvalidAddress();
    }

    ERC20Storage storage erc20s = getERC20Storage();
    uint256 balance = erc20s.balanceOf[owner];
    ERC4626Storage storage s = getStorage();
    address diamondAddress;
    assembly {
        diamondAddress := address()
    }
    uint256 totalAssets_ = s.asset.balanceOf(diamondAddress) + VIRTUAL_ASSET;
    uint256 totalShares_ = erc20s.totalSupply + VIRTUAL_SHARE;
    uint256 maxWithdrawVal = muldiv(totalAssets_, balance, totalShares_);
    if (assets > maxWithdrawVal) revert ERC4626InvalidAmount();

    shares = mulDivRoundingUp(totalShares_, assets, totalAssets_);
    if (shares == 0) revert ERC4626InsufficientShares();
    bool success = _safeTransfer(s.asset, receiver, assets);
    if (!success) revert ERC4626TransferFailed();

    if (msg.sender != owner) {
        uint256 allowed = erc20s.allowances[owner][msg.sender];
        if (allowed < shares) revert ERC4626InvalidAmount();
        erc20s.allowances[owner][msg.sender] = allowed - shares;
    }
    erc20s.balanceOf[owner] -= shares;
    erc20s.totalSupply -= shares;

    emit Withdraw(msg.sender, receiver, owner, assets, shares);
    return shares;
}

/**
 * @notice Returns the maximum number of shares an owner can redeem at the current time.
 * @param owner The address to query.
 * @return maxShares Current share balance of the owner.
 */
function maxRedeem(address owner) view returns (uint256 maxShares) {
    ERC20Storage storage erc20s = getERC20Storage();
    maxShares = erc20s.balanceOf[owner];
    return maxShares;
}

/**
 * @notice Preview assets that would be returned for redeeming a given number of shares.
 * @param shares Amount of shares to redeem.
 * @return assets Amount of assets to be returned for given shares.
 */
function previewRedeem(uint256 shares) view returns (uint256 assets) {
    ERC20Storage storage erc20s = getERC20Storage();
    uint256 totalShares_ = erc20s.totalSupply + VIRTUAL_SHARE;
    ERC4626Storage storage s = getStorage();
    address diamondAddress;
    assembly {
        diamondAddress := address()
    }
    uint256 totalAssets_ = s.asset.balanceOf(diamondAddress) + VIRTUAL_ASSET;
    assets = muldiv(totalAssets_, shares, totalShares_);
    return assets;
}

/**
 * @notice Redeems shares from an owner and sends the corresponding assets to a receiver.
 * @dev Transfers assets and burns shares; handles allowances if needed.
 * @param shares Amount of shares to redeem.
 * @param receiver Address to receive redeemed assets.
 * @param owner Shares owner's address to burn from.
 * @return assets Amount of assets received for redemption.
 */
function redeem(uint256 shares, address receiver, address owner) returns (uint256 assets) {
    if (receiver == address(0) || owner == address(0)) {
        revert ERC4626InvalidAddress();
    }
    ERC20Storage storage erc20s = getERC20Storage();
    if (shares > erc20s.balanceOf[owner]) revert ERC4626InvalidAmount();

    ERC4626Storage storage s = getStorage();
    uint256 totalShares_ = erc20s.totalSupply + VIRTUAL_SHARE;
    address diamondAddress;
    assembly {
        diamondAddress := address()
    }
    uint256 totalAssets_ = s.asset.balanceOf(diamondAddress) + VIRTUAL_ASSET;
    assets = muldiv(totalAssets_, shares, totalShares_);

    if (assets == 0) revert ERC4626InsufficientAssets();
    bool success = _safeTransfer(s.asset, receiver, assets);
    if (!success) revert ERC4626TransferFailed();

    if (msg.sender != owner) {
        uint256 allowed = erc20s.allowances[owner][msg.sender];
        if (allowed < shares) revert ERC4626InvalidAmount();
        erc20s.allowances[owner][msg.sender] = allowed - shares;
    }
    erc20s.totalSupply -= shares;
    erc20s.balanceOf[owner] -= shares;

    emit Withdraw(msg.sender, receiver, owner, assets, shares);
    return assets;
}
