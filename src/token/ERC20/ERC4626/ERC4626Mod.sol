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

error ERC20InsufficientBalance(address account, uint256 balance, uint256 required);
error ERC20InsufficientAllowance(address owner, address spender, uint256 allowance, uint256 required);
error ERC20InvalidReceiver(address receiver);
error TransferFailed(address token, address from, address to, uint256 amount, bytes reason);
error ERC4626InsufficientShares(uint256 shares, uint256 required);
error ERC4626InsufficientAssets(uint256 assets, uint256 required);
error ERC4626NoBytecodeAtAddress(address contractAddress);

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
    * @dev Returns the ERC20 storage struct.
    */
function getERC20Storage() pure returns (ERC20Storage storage s) {
    bytes32 position = ERC20_STORAGE_POSITION;
    assembly {
        s.slot := position
    }
}

/**
    * @dev Returns the ERC4626 storage struct.
    */
function getStorage() pure returns (ERC4626Storage storage s) {
    bytes32 position = STORAGE_POSITION;
    assembly {
        s.slot := position
    }
}

/**
    * @notice Returns the address of the vault's underlying asset.
    * @return assetTokenAddress The ERC20 token used for deposits/withdrawals
    */
function asset() view returns (address assetTokenAddress) {
    ERC4626Storage storage s = getStorage();
    assetTokenAddress = address(s.asset);
    return assetTokenAddress;
}

/**
    * @notice Returns the total underlying assets managed by the vault.
    * @return totalManagedAssets Assets (in asset token) currently held by the vault,
    *         including virtual buffering.
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
    * @notice Performs full precision (a * b) / denominator computation.
    * @dev Inspired from - https://xn--2-umb.com/21/muldiv/
    * @dev Handles intermediate overflow using 512-bit math.
    *      - Computes 512-bit multiplication to detect and handle overflow.
    *      - If result fits in 256 bits, just divide.
    *      - Otherwise, adjust to make division exact, factor out powers of two, and compute inverse for precise division.
    * @param a First operand.
    * @param b Second operand.
    * @param denominator Denominator.
    * @return result The result of (a * b) / denominator.
    */
function muldiv(uint256 a, uint256 b, uint256 denominator) view returns (uint256 result) {
    /**
        * Step 1: Safety check to prevent division by zero, which would otherwise revert
        */
    require(denominator > 0);

    uint256 prod0;
    uint256 prod1;
    /**
        * Step 2: Calculate a 512-bit product of a and b.
        * - prod0 contains the least significant 256 bits of the product (a * b % 2**256).
        * - prod1 contains the most significant 256 bits. This is the "overflow" portion from 256-bit multiplication.
        * - Assembly is used for efficiency.
        */
    assembly {
        /**
            * b) in two parts:
            * mm: full (modulo not(0)), which is 2**256 - 1
            * prod0: a * b (mod 2**256)
            * prod1: (a * b - prod0)/2**256
            */
        /**
            * Full-width mulmod for high bits
            */
        let mm := mulmod(a, b, not(0))
        /**
            * Standard multiplication for low bits
            */
        prod0 := mul(a, b)
        /**
            * Derive prod1 using differences and underflow detection (see muldiv reference).
            */
        prod1 := sub(sub(mm, prod0), lt(mm, prod0))
    }

    /**
        * Step 3: Shortcut if there is no overflow (the high 256 bits are zero).
        * - Division fits in 256-bits, so we can safely divide.
        */
    if (prod1 == 0) {
        assembly {
            result := div(prod0, denominator)
        }
        return result;
    }

    /**
        * Step 4: Now we know (a * b) didn't fit in 256 bits (prod1 != 0),
        * but it must fit into 256 *bits* after dividing by denominator.
        * Check that denominator is large enough to prevent result overflow.
        */
    require(prod1 < denominator);

    /**
        * Step 5: Compute and subtract remainder from [prod1 prod0] to make the division exact.
        * - Calculate the remainder of (a * b) % denominator.
        * - Remove the remainder from the [prod1 prod0] 512-bit product so division will be exact.
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
        * Step 6: Remove all powers of two from the denominator, shift bits from prod0 and prod1 accordingly.
        * - Find the largest power of two divisor of denominator using bitwise tricks.
        * - Divide denominator by this, and also adjust prod0 and prod1 to compensate.
        */
    uint256 twos = (~denominator + 1) & denominator;
    assembly {
        /**
            * Divide denominator by its largest power of two divisor.
            */
        denominator := div(denominator, twos)
        /**
            * Divide prod0 by the same power of two, shifting low bits right
            */
        prod0 := div(prod0, twos)
        /**
            * Compute 2^256 / twos, prepares for condensing the top bits:
            */
        twos := add(div(sub(0, twos), twos), 1)
    }

    /**
        * Step 7: Condense the 512 bit result into 256 bits.
        * - Move the high bits (prod1) down by multiplying by (2^256 / twos) and combining.
        */
    prod0 |= prod1 * twos;

    /**
        * Step 8: Compute modular inverse of denominator to enable division modulo 2**256.
        * - Newton-Raphson iterations are used to compute the inverse efficiently.
        * - The result is now: prod0 * inverse(denominator) mod 2**256 is the answer.
        * - Unrolling the iterations since denominator is odd here (twos were factored out).
        */
    uint256 inv = (3 * denominator) ^ 2;
    inv *= 2 - denominator * inv;
    /**
        * inverse mod 2^8
        */
    inv *= 2 - denominator * inv;
    /**
        * inverse mod 2^16
        */
    inv *= 2 - denominator * inv;
    /**
        * inverse mod 2^32
        */
    inv *= 2 - denominator * inv;
    /**
        * inverse mod 2^64
        */
    inv *= 2 - denominator * inv;
    /**
        * inverse mod 2^128
        */
    inv *= 2 - denominator * inv;
    /**
        * inverse mod 2^256
        */

    /**
        * Step 9: Multiply prod0 by the modular inverse of denominator to get the final division result.
        * - Since all powers of two are removed from denominator, and all high-bits are handled,
        *   this multiplication cannot overflow and yields the exact solution.
        */
    result = prod0 * inv;
    return result;
}

/**
    * @notice Same as muldiv, but rounds up if there is a remainder.
    */
function mulDivRoundingUp(uint256 a, uint256 b, uint256 denominator) view returns (uint256 result) {
    result = muldiv(a, b, denominator);
    if (mulmod(a, b, denominator) > 0) {
        result++;
    }
}

/**
    * @dev Safely calls IERC20.transferFrom accounting for non-standard ERC20s.
    * @param token Token to transfer
    * @param from Source address
    * @param to Target address
    * @param amount Value to transfer
    */
function safeTransferFrom(IERC20 token, address from, address to, uint256 amount) {
    if (address(token).code.length == 0) {
        revert ERC4626NoBytecodeAtAddress(address(token));
    }
    bytes memory data = abi.encodeWithSelector(token.transferFrom.selector, from, to, amount);
    (bool success, bytes memory returndata) = address(token).call(data);
    if (!success) {
        revert TransferFailed(address(token), from, to, amount, returndata);
    }
    if (returndata.length > 0 && !abi.decode(returndata, (bool))) {
        revert TransferFailed(address(token), from, to, amount, returndata);
    }
}

/**
    * @notice Converts a specified amount of assets to the corresponding amount of shares,
    *         using current total assets and shares.
    * @param assets The amount of asset tokens to convert
    * @return shares Amount of vault shares representing the supplied assets
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
    * @notice Converts a specified amount of shares to the corresponding amount of underlying assets,
    *         using current total assets and shares.
    * @param shares Amount of vault shares to convert
    * @return assets Amount of asset tokens represented by the shares
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
    * @notice Returns the maximum amount of assets that may be deposited for an account.
    * @dev Per ERC4626, this may be unlimited. No per-account logic here.
    * @return maxAssets The maximum deposit amount (uint256 max)
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
    * @notice Returns the number of shares that would be minted by depositing the given `assets`.
    * @param assets Amount of asset tokens to deposit
    * @return shares Amount of vault shares that would be minted
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
    * @notice Deposits assets and mints shares to receiver.
    * @param assets Amount of assets to deposit.
    * @param receiver Address to receive shares.
    * @return shares Amount of shares minted.
    */
function deposit(uint256 assets, address receiver) returns (uint256 shares) {
    if (receiver == address(0)) {
        revert ERC20InvalidReceiver(receiver);
    }

    ERC20Storage storage erc20s = getERC20Storage();
    ERC4626Storage storage s = getStorage();
    uint256 totalShares_ = erc20s.totalSupply + VIRTUAL_SHARE;
    address diamondAddress;
    assembly {
        diamondAddress := address()
    }
    uint256 totalAssets_ = s.asset.balanceOf(diamondAddress) + VIRTUAL_ASSET;

    shares = muldiv(totalShares_, assets, totalAssets_);
    if (shares == 0) {
        revert ERC4626InsufficientShares(0, 1);
    }

    erc20s.totalSupply += shares;
    erc20s.balanceOf[receiver] += shares;

    safeTransferFrom(s.asset, msg.sender, diamondAddress, assets);

    emit Deposit(msg.sender, receiver, assets, shares);
    return shares;
}

/**
    * @notice Returns the maximum number of shares that may be minted for an account.
    * @dev Per ERC4626, this may be unlimited. No per-account logic here.
    * @return maxShares The maximum mintable shares (uint256 max)
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
    * @notice Returns the amount of assets required to mint `shares` shares, rounded up if necessary.
    * @param shares Amount of shares to mint
    * @return assets Asset tokens that must be deposited to mint the given shares
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
    * @notice Mints shares to receiver by depositing assets.
    * @param shares Amount of shares to mint.
    * @param receiver Address to receive shares.
    * @return assets Amount of assets deposited.
    */
function mint(uint256 shares, address receiver) returns (uint256 assets) {
    if (receiver == address(0)) {
        revert ERC20InvalidReceiver(receiver);
    }

    ERC20Storage storage erc20s = getERC20Storage();
    ERC4626Storage storage s = getStorage();
    uint256 totalShares_ = erc20s.totalSupply + VIRTUAL_SHARE;
    address diamondAddress;
    assembly {
        diamondAddress := address()
    }
    uint256 totalAssets_ = s.asset.balanceOf(diamondAddress) + VIRTUAL_ASSET;
    assets = mulDivRoundingUp(totalAssets_, shares, totalShares_);
    if (assets == 0) {
        revert ERC4626InsufficientAssets(0, 1);
    }

    erc20s.totalSupply += shares;
    erc20s.balanceOf[receiver] += shares;

    safeTransferFrom(s.asset, msg.sender, diamondAddress, assets);

    emit Deposit(msg.sender, receiver, assets, shares);
    return assets;
}

/**
    * @notice Returns the maximum amount of assets that can be withdrawn for the given owner.
    * @param owner The address to check withdrawable assets for
    * @return maxAssets Max withdrawable amount in asset tokens for the owner
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
    * @notice Returns the number of shares that must be burned to withdraw `assets`, rounded up.
    * @param assets Amount of asset tokens to be withdrawn
    * @return shares Shares required to burn for withdrawal
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
    * @notice Burns shares from owner to withdraw assets to receiver.
    * @param assets Amount of assets to withdraw.
    * @param receiver Address to receive assets.
    * @param owner Address whose shares are burned.
    * @return shares Amount of shares burned.
    */
function withdraw(uint256 assets, address receiver, address owner) returns (uint256 shares) {
    if (receiver == address(0)) {
        revert ERC20InvalidReceiver(receiver);
    }
    if (owner == address(0)) {
        revert ERC20InvalidReceiver(owner);
    }

    ERC20Storage storage erc20s = getERC20Storage();
    ERC4626Storage storage s = getStorage();

    uint256 balance = erc20s.balanceOf[owner];
    address diamondAddress;
    assembly {
        diamondAddress := address()
    }
    uint256 totalAssets_ = s.asset.balanceOf(diamondAddress) + VIRTUAL_ASSET;
    uint256 totalShares_ = erc20s.totalSupply + VIRTUAL_SHARE;
    uint256 maxWithdrawVal = muldiv(totalAssets_, balance, totalShares_);
    if (assets > maxWithdrawVal) {
        revert ERC4626InsufficientAssets(maxWithdrawVal, assets);
    }

    shares = mulDivRoundingUp(totalShares_, assets, totalAssets_);
    if (shares == 0) {
        revert ERC4626InsufficientShares(0, 1);
    }

    if (msg.sender != owner) {
        uint256 allowed = erc20s.allowances[owner][msg.sender];
        if (allowed < shares) {
            revert ERC20InsufficientAllowance(owner, msg.sender, allowed, shares);
        }
        erc20s.allowances[owner][msg.sender] = allowed - shares;
    }
    erc20s.balanceOf[owner] -= shares;
    erc20s.totalSupply -= shares;

    safeTransferFrom(s.asset, diamondAddress, receiver, assets);

    emit Withdraw(msg.sender, receiver, owner, assets, shares);
    return shares;
}

/**
    * @notice Returns the maximum number of shares that an owner may redeem from the vault.
    * @param owner The address to check redeemable shares for
    * @return maxShares Number of redeemable shares for the owner
    */
function maxRedeem(address owner) view returns (uint256 maxShares) {
    ERC20Storage storage erc20s = getERC20Storage();
    maxShares = erc20s.balanceOf[owner];
    return maxShares;
}

/**
    * @notice Returns the amount of assets that would be received for redeeming the given `shares`.
    * @param shares Amount of shares to redeem
    * @return assets Asset tokens returned by redeeming the shares
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
    * @notice Redeems shares from owner for assets to receiver.
    * @param shares Amount of shares to redeem.
    * @param receiver Address to receive assets.
    * @param owner Address whose shares are redeemed.
    * @return assets Amount of assets withdrawn.
    */
function redeem(uint256 shares, address receiver, address owner) returns (uint256 assets) {
    if (receiver == address(0)) {
        revert ERC20InvalidReceiver(receiver);
    }
    if (owner == address(0)) {
        revert ERC20InvalidReceiver(owner);
    }

    ERC20Storage storage erc20s = getERC20Storage();

    if (shares > erc20s.balanceOf[owner]) {
        revert ERC20InsufficientBalance(owner, erc20s.balanceOf[owner], shares);
    }

    ERC4626Storage storage s = getStorage();
    uint256 totalShares_ = erc20s.totalSupply + VIRTUAL_SHARE;
    address diamondAddress;
    assembly {
        diamondAddress := address()
    }
    uint256 totalAssets_ = s.asset.balanceOf(diamondAddress) + VIRTUAL_ASSET;
    assets = muldiv(totalAssets_, shares, totalShares_);
    if (assets == 0) {
        revert ERC4626InsufficientAssets(0, 1);
    }

    if (msg.sender != owner) {
        uint256 allowed = erc20s.allowances[owner][msg.sender];
        if (allowed < shares) {
            revert ERC20InsufficientAllowance(owner, msg.sender, allowed, shares);
        }
        erc20s.allowances[owner][msg.sender] = allowed - shares;
    }
    erc20s.totalSupply -= shares;
    erc20s.balanceOf[owner] -= shares;

    safeTransferFrom(s.asset, diamondAddress, receiver, assets);

    emit Withdraw(msg.sender, receiver, owner, assets, shares);
    return assets;
}