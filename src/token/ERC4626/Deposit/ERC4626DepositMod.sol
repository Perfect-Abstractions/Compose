// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

/**
 * @dev Minimal ERC20 interface.
 */
interface IERC20 {
    function balanceOf(address account) external view returns (uint256);

    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

/*
 * @title ERC4626DepositMod
 * @notice Provides internal ERC-4626 deposit functions.
 */

/**
 * @notice Thrown when the denominator is zero in a mulDiv operation.
 */
error MulDivDivisionByZero();

/**
 * @notice Thrown when the result of a mulDiv operation exceeds uint256.
 */
error MulDivOverflow();

/**
 * @notice Thrown when the receiver address is invalid (e.g., zero address).
 * @param _receiver The invalid receiver address.
 */
error ERC20InvalidReceiver(address _receiver);

/**
 * @notice Thrown when the number of shares is insufficient for an ERC-4626 operation.
 * @param _shares The available or calculated number of shares.
 * @param _required The minimum number of shares required.
 */
error ERC4626InsufficientShares(uint256 _shares, uint256 _required);

/**
 * @notice Thrown when the specified address contains no contract bytecode.
 * @param _contractAddress The address without contract bytecode.
 */
error ERC4626NoBytecodeAtAddress(address _contractAddress);

/**
 * @notice Thrown when an ERC-20 token transfer fails.
 * @param _token The address of the token being transferred.
 * @param _from The address sending the tokens.
 * @param _to The address receiving the tokens.
 * @param _amount The amount of tokens being transferred.
 * @param _reason The revert data or return data indicating the failure.
 */
error TransferFailed(address _token, address _from, address _to, uint256 _amount, bytes _reason);

/**
 * @notice Emitted when vault shares are transferred or minted.
 * @param _from The address shares are transferred from, or the zero address for a mint.
 * @param _to The address receiving the shares.
 * @param _value The amount of shares transferred or minted.
 */
event Transfer(address indexed _from, address indexed _to, uint256 _value);

/**
 * @notice Emitted when assets are deposited into the vault and corresponding shares issued.
 * @param sender The address initiating the deposit (msg.sender)
 * @param owner The account that will receive the shares
 * @param assets The amount of asset tokens deposited
 * @param shares The amount of vault shares minted
 */
event Deposit(address indexed sender, address indexed owner, uint256 assets, uint256 shares);

/**
 * @dev Virtual Assets and Virtual Shares
 *
 * VIRTUAL_ASSET and VIRTUAL_SHARE constants are used to prevent certain edge cases in the vault's math logic,
 * especially when the vault is empty. They ensure the asset-to-share conversion
 * calculations always have a minimum non-zero denominator and numerator, preventing division-by-zero errors and
 * other undesirable rounding artifacts.
 *
 * `VIRTUAL_ASSET` is a small integer, so the vault always considers itself to hold at least 1 asset.
 * `VIRTUAL_SHARE` is also a small, but higher value, so the vault always considers itself to have at least 10 shares.
 *
 * These values are added to `totalAssets` and `totalShares` in all conversion logic throughout the vault.
 */
uint256 constant VIRTUAL_ASSET = 1;
uint256 constant VIRTUAL_SHARE = 1e1;

/**
 * @dev Storage position determined by the keccak256 hash of the diamond storage identifier.
 */
bytes32 constant ERC20_STORAGE_POSITION = keccak256("erc20");

/**
 * @dev ERC-8042 compliant storage struct for ERC20 token data.
 * @custom:storage-location erc8042:erc20
 */
struct ERC20Storage {
    mapping(address owner => uint256 balance) balanceOf;
    uint256 totalSupply;
}

/**
 * @notice Returns the ERC20 storage struct from the predefined diamond storage slot.
 * @dev Uses inline assembly to set the storage slot reference.
 * @return s The ERC20 storage struct reference.
 */
function getERC20Storage() pure returns (ERC20Storage storage s) {
    bytes32 position = ERC20_STORAGE_POSITION;
    assembly {
        s.slot := position
    }
}

/**
 * @dev Storage position determined by the keccak256 hash of the diamond storage identifier.
 */
bytes32 constant ERC4626_STORAGE_POSITION = keccak256("erc4626");

/**
 * @dev ERC4626-specific storage layout.
 */
struct ERC4626Storage {
    IERC20 asset;
}

/**
 * @notice Returns the ERC4626 storage struct from the predefined diamond storage slot.
 * @dev Uses inline assembly to set the storage slot reference.
 * @return s The ERC4626 storage struct reference.
 */
function getERC4626Storage() pure returns (ERC4626Storage storage s) {
    bytes32 position = ERC4626_STORAGE_POSITION;
    assembly {
        s.slot := position
    }
}

/**
 * @notice Returns the address of the vault executing this module.
 * @return vault The address of the current contract.
 */
function getVaultAddress() view returns (address vault) {
    assembly ("memory-safe") {
        vault := address()
    }
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
function muldiv(uint256 a, uint256 b, uint256 denominator) pure returns (uint256 result) {
    unchecked {
        /**
         * Step 1: Safety check to prevent division by zero, which would otherwise revert
         */
        if (denominator == 0) {
            revert MulDivDivisionByZero();
        }

        uint256 prod0;
        uint256 prod1;

        /*
         * Step 2: Compute the 512-bit product of a and b.
         * prod0 contains the lower 256 bits, and prod1 contains the upper 256 bits.
         */
        assembly ("memory-safe") {
            let mm := mulmod(a, b, not(0))
            prod0 := mul(a, b)
            prod1 := sub(sub(mm, prod0), lt(mm, prod0))
        }

        /**
         * Step 3: Shortcut if there is no overflow (the high 256 bits are zero).
         * - Division fits in 256-bits, so we can safely divide.
         */
        if (prod1 == 0) {
            assembly ("memory-safe") {
                result := div(prod0, denominator)
            }
            return result;
        }

        /**
         * Step 4: Ensure the result fits within 256 bits.
         * The denominator must be greater than prod1 to prevent overflow.
         */
        if (prod1 >= denominator) {
            revert MulDivOverflow();
        }

        /*
         * Step 5: Compute and subtract remainder from [prod1 prod0] to make the division exact.
         * - Calculate the remainder of (a * b) % denominator.
         * - Remove the remainder from the [prod1 prod0] 512-bit product so division will be exact.
         */
        assembly ("memory-safe") {
            let remainder := mulmod(a, b, denominator)
            prod1 := sub(prod1, gt(remainder, prod0))
            prod0 := sub(prod0, remainder)
        }

        /**
         * Step 6: Factor out powers of two from the denominator.
         * Adjust prod0 and prepare to combine it with prod1.
         */
        uint256 twos = (~denominator + 1) & denominator;

        assembly ("memory-safe") {
            denominator := div(denominator, twos)
            prod0 := div(prod0, twos)
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
 * @notice Returns the maximum amount of assets that may be deposited for an account.
 * @dev Per ERC4626, this may be unlimited. No per-account logic here.
 * @return maxAssets The maximum deposit amount (uint256 max)
 */
function maxDeposit(address) pure returns (uint256) {
    return type(uint256).max;
}

/**
 * @notice Returns the number of shares that would be minted by depositing the given `assets`.
 * @param assets Amount of asset tokens to deposit
 * @return shares Amount of vault shares that would be minted
 */
function previewDeposit(uint256 assets) view returns (uint256 shares) {
    ERC20Storage storage erc20s = getERC20Storage();
    uint256 totalShares = erc20s.totalSupply + VIRTUAL_SHARE;
    ERC4626Storage storage erc4626s = getERC4626Storage();
    uint256 totalAssets = erc4626s.asset.balanceOf(getVaultAddress()) + VIRTUAL_ASSET;
    shares = muldiv(totalShares, assets, totalAssets);
    return shares;
}

/**
 * @notice Deposits assets and mints shares to receiver.
 * @dev Pulls assets before minting so pre-transfer hooks see the pre-deposit state.
 * @param assets Amount of assets to deposit.
 * @param receiver Address to receive shares.
 * @return shares Amount of shares minted.
 */
function deposit(uint256 assets, address receiver) returns (uint256 shares) {
    if (receiver == address(0)) {
        revert ERC20InvalidReceiver(receiver);
    }

    ERC20Storage storage erc20s = getERC20Storage();
    ERC4626Storage storage erc4626s = getERC4626Storage();
    uint256 totalShares_ = erc20s.totalSupply + VIRTUAL_SHARE;
    address vault = getVaultAddress();
    uint256 totalAssets_ = erc4626s.asset.balanceOf(vault) + VIRTUAL_ASSET;

    shares = muldiv(totalShares_, assets, totalAssets_);
    if (shares == 0) {
        revert ERC4626InsufficientShares(0, 1);
    }

    safeTransferFrom(erc4626s.asset, msg.sender, vault, assets);

    erc20s.totalSupply += shares;
    erc20s.balanceOf[receiver] += shares;
    emit Transfer(address(0), receiver, shares);

    emit Deposit(msg.sender, receiver, assets, shares);

    return shares;
}
