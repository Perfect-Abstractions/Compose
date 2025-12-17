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
 * @dev Fires on deposits (assets in, shares out).
 */
event Deposit(address indexed sender, address indexed owner, uint256 assets, uint256 shares);

/**
 * @dev Fires on withdrawals (assets out, shares burned).
 */
event Withdraw(address indexed sender, address indexed receiver, address indexed owner, uint256 assets, uint256 shares);

bytes32 constant ERC20_STORAGE_POSITION = keccak256("compose.erc20");
bytes32 constant STORAGE_POSITION = keccak256("compose.erc4626");

uint256 constant VIRTUAL_ASSET = 1;
uint256 constant VIRTUAL_SHARE = 1;

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
    address vaultAddress;
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
 * @dev Get the address of the asset used by the vault.
 */
function asset() view returns (address) {
    ERC4626Storage storage s = getStorage();
    return address(s.asset);
}

/**
 * @dev Get the current total assets in the vault contract.
 */
function totalAssets() view returns (uint256) {
    ERC4626Storage storage s = getStorage();
    return s.asset.balanceOf(s.vaultAddress) + VIRTUAL_ASSET;
}

/**
 * @dev Compute (a * b) / denominator, using full precision and safe for overflow.
 *      Reference: https://xn--2-umb.com/21/muldiv/
 */
function muldiv(uint256 a, uint256 b, uint256 denominator) view returns (uint256 result) {
    /**
     * Guard: denominator can't be zero
     */
    require(denominator > 0);

    uint256 prod0;
    uint256 prod1;
    /**
     * b
     */
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
function mulDivRoundingUp(uint256 a, uint256 b, uint256 denominator) view returns (uint256 result) {
    result = muldiv(a, b, denominator);
    if (mulmod(a, b, denominator) > 0) {
        require(result < type(uint256).max);
        result++;
    }
}

/**
 * @dev Return the sum of true shares and the virtual share value.
 */
function totalShares() view returns (uint256) {
    ERC20Storage storage erc20s = getERC20Storage();
    return erc20s.totalSupply + VIRTUAL_SHARE;
}

/**
 * @dev Convert an asset amount to shares using the vault's accountings.
 * @param assets The number of assets to convert to shares.
 */
function convertToShares(uint256 assets) view returns (uint256) {
    ERC20Storage storage erc20s = getERC20Storage();
    uint256 totalShares_ = erc20s.totalSupply + VIRTUAL_SHARE;
    ERC4626Storage storage s = getStorage();
    uint256 totalAssets_ = s.asset.balanceOf(s.vaultAddress) + VIRTUAL_ASSET;
    return muldiv(totalShares_, assets, totalAssets_);
}

/**
 * @dev Convert shares to the corresponding asset amount.
 * @param shares The number of shares to convert.
 */
function convertToAssets(uint256 shares) view returns (uint256) {
    ERC20Storage storage erc20s = getERC20Storage();
    uint256 totalShares_ = erc20s.totalSupply + VIRTUAL_SHARE;
    ERC4626Storage storage s = getStorage();
    uint256 totalAssets_ = s.asset.balanceOf(s.vaultAddress) + VIRTUAL_ASSET;
    return muldiv(totalAssets_, shares, totalShares_);
}

/**
 * @dev Maximum possible deposit allowed for this vault.
 */
function maxDeposit() pure returns (uint256) {
    return type(uint256).max;
}

/**
 * @dev Calculate shares to issue for a potential deposit of given assets.
 * @param assets Assets input for previewing shares minted.
 */
function previewDeposit(uint256 assets) view returns (uint256) {
    ERC20Storage storage erc20s = getERC20Storage();
    uint256 totalShares_ = erc20s.totalSupply + VIRTUAL_SHARE;
    ERC4626Storage storage s = getStorage();
    uint256 totalAssets_ = s.asset.balanceOf(s.vaultAddress) + VIRTUAL_ASSET;
    return muldiv(totalShares_, assets, totalAssets_);
}

/**
 * @dev Safe ERC20 transferFrom wrapper supporting non-standard tokens.
 */
function _safeTransferFrom(IERC20 token, address from, address to, uint256 amount) returns (bool) {
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
 * @dev Safe ERC20 transfer wrapper supporting non-standard tokens.
 */
function _safeTransfer(IERC20 token, address to, uint256 amount) returns (bool) {
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
 * @dev Effect actual deposit, minting shares for the receiver.
 * @param assets Asset amount sent in.
 * @param receiver Address to receive the minted shares.
 * @return shares The number of shares minted as a result.
 */
function deposit(uint256 assets, address receiver) returns (uint256) {
    if (receiver == address(0)) revert ERC4626InvalidAddress();
    if (assets > type(uint256).max) revert ERC4626InvalidAmount();

    ERC20Storage storage erc20s = getERC20Storage();
    uint256 totalShares_ = erc20s.totalSupply + VIRTUAL_SHARE;
    ERC4626Storage storage s = getStorage();
    uint256 totalAssets_ = s.asset.balanceOf(s.vaultAddress) + VIRTUAL_ASSET;
    uint256 shares = muldiv(totalShares_, assets, totalAssets_);

    if (shares == 0) revert ERC4626InsufficientShares();
    bool success = _safeTransferFrom(s.asset, msg.sender, s.vaultAddress, assets);
    if (!success) revert ERC4626TransferFailed();

    erc20s.totalSupply += shares;
    erc20s.balanceOf[receiver] += shares;

    emit Deposit(msg.sender, receiver, assets, shares);
    return shares;
}

/**
 * @dev Return the max number of shares that can be minted.
 */
function maxMint() pure returns (uint256) {
    return type(uint256).max;
}

/**
 * @dev Preview the asset amount required for minting a number of shares.
 * @param shares The desired number of shares to mint.
 */
function previewMint(uint256 shares) view returns (uint256) {
    ERC20Storage storage erc20s = getERC20Storage();
    uint256 totalShares_ = erc20s.totalSupply + VIRTUAL_SHARE;
    ERC4626Storage storage s = getStorage();
    uint256 totalAssets_ = s.asset.balanceOf(s.vaultAddress) + VIRTUAL_ASSET;
    return mulDivRoundingUp(totalAssets_, shares, totalShares_);
}

/**
 * @dev Mint exact shares in exchange for assets, assigning to receiver.
 * @param shares Number of shares to mint.
 * @param receiver Who receives these shares.
 * @return assets Asset quantity paid for minting.
 */
function mint(uint256 shares, address receiver) returns (uint256) {
    if (receiver == address(0)) revert ERC4626InvalidAddress();
    if (shares > type(uint256).max) revert ERC4626InvalidAmount();

    ERC20Storage storage erc20s = getERC20Storage();
    uint256 totalShares_ = erc20s.totalSupply + VIRTUAL_SHARE;
    ERC4626Storage storage s = getStorage();
    uint256 totalAssets_ = s.asset.balanceOf(s.vaultAddress) + VIRTUAL_ASSET;
    uint256 assets = mulDivRoundingUp(totalAssets_, shares, totalShares_);

    if (assets == 0) revert ERC4626InsufficientAssets();
    bool success = _safeTransferFrom(s.asset, msg.sender, s.vaultAddress, assets);
    if (!success) revert ERC4626TransferFailed();

    erc20s.totalSupply += shares;
    erc20s.balanceOf[receiver] += shares;

    emit Deposit(msg.sender, receiver, assets, shares);
    return assets;
}

/**
 * @dev Get the max asset withdrawal allowed for the given owner.
 * @param owner Account address to check.
 */
function maxWithdraw(address owner) view returns (uint256) {
    ERC20Storage storage erc20s = getERC20Storage();
    uint256 balance = erc20s.balanceOf[owner];
    ERC4626Storage storage s = getStorage();
    uint256 totalAssets_ = s.asset.balanceOf(s.vaultAddress) + VIRTUAL_ASSET;
    uint256 totalShares_ = erc20s.totalSupply + VIRTUAL_SHARE;
    return muldiv(totalAssets_, balance, totalShares_);
}

/**
 * @dev Preview required shares for a withdrawal of the given asset amount.
 * @param assets Desired withdrawal quantity.
 */
function previewWithdraw(uint256 assets) view returns (uint256) {
    ERC20Storage storage erc20s = getERC20Storage();
    uint256 totalShares_ = erc20s.totalSupply + VIRTUAL_SHARE;
    ERC4626Storage storage s = getStorage();
    uint256 totalAssets_ = s.asset.balanceOf(s.vaultAddress) + VIRTUAL_ASSET;
    return mulDivRoundingUp(totalShares_, assets, totalAssets_);
}

/**
 * @dev Burn owner's shares to release assets to the given receiver address.
 * @param assets Number of assets to withdraw.
 * @param receiver Address to receive assets.
 * @param owner The address whose shares are spent.
 * @return shares Amount of shares burned.
 */
function withdraw(uint256 assets, address receiver, address owner) returns (uint256) {
    if (receiver == address(0) || owner == address(0)) {
        revert ERC4626InvalidAddress();
    }

    ERC20Storage storage erc20s = getERC20Storage();
    uint256 balance = erc20s.balanceOf[owner];
    ERC4626Storage storage s = getStorage();
    uint256 totalAssets_ = s.asset.balanceOf(s.vaultAddress) + VIRTUAL_ASSET;
    uint256 totalShares_ = erc20s.totalSupply + VIRTUAL_SHARE;
    uint256 maxWithdrawVal = muldiv(totalAssets_, balance, totalShares_);
    if (assets > maxWithdrawVal) revert ERC4626InvalidAmount();

    uint256 shares = mulDivRoundingUp(totalShares_, assets, totalAssets_);
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
 * @dev Find how many shares can currently be redeemed by the owner.
 * @param owner Whose shares are inquired.
 */
function maxRedeem(address owner) view returns (uint256) {
    ERC20Storage storage erc20s = getERC20Storage();
    return erc20s.balanceOf[owner];
}

/**
 * @dev Show the resulting assets for redeeming the given share count.
 * @param shares Share count to be redeemed.
 */
function previewRedeem(uint256 shares) view returns (uint256) {
    ERC20Storage storage erc20s = getERC20Storage();
    uint256 totalShares_ = erc20s.totalSupply + VIRTUAL_SHARE;
    ERC4626Storage storage s = getStorage();
    uint256 totalAssets_ = s.asset.balanceOf(s.vaultAddress) + VIRTUAL_ASSET;
    return muldiv(totalAssets_, shares, totalShares_);
}

/**
 * @dev Redeem shares from given owner, transferring assets to receiver.
 * @param shares Number of shares to redeem.
 * @param receiver Destination address for asset withdrawal.
 * @param owner User whose shares are spent in redemption.
 * @return assets Amount of assets delivered to receiver.
 */
function redeem(uint256 shares, address receiver, address owner) returns (uint256) {
    if (receiver == address(0) || owner == address(0)) {
        revert ERC4626InvalidAddress();
    }
    ERC20Storage storage erc20s = getERC20Storage();
    if (shares > erc20s.balanceOf[owner]) revert ERC4626InvalidAmount();

    ERC4626Storage storage s = getStorage();
    uint256 totalShares_ = erc20s.totalSupply + VIRTUAL_SHARE;
    uint256 totalAssets_ = s.asset.balanceOf(s.vaultAddress) + VIRTUAL_ASSET;
    uint256 assets = muldiv(totalAssets_, shares, totalShares_);

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
