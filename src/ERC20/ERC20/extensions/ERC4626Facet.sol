// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

interface IERC20 {
    /// @notice Returns the number of decimals used for token precision.
    /// @return The number of decimals.
    function decimals() external view returns (uint8);

    /// @notice Returns the balance of a specific account.
    /// @param _account The address of the account.
    /// @return The account balance.
    function balanceOf(address _account) external view returns (uint256);

    /// @notice Transfers tokens to another address.
    /// @dev Emits a {Transfer} event.
    /// @param _to The address to receive the tokens.
    /// @param _value The amount of tokens to transfer.
    /// @return True if the operation succeeded.
    function transfer(address _to, uint256 _value) external returns (bool);

    /// @notice Transfers tokens on behalf of another account, provided sufficient allowance exists.
    /// @dev Emits a {Transfer} event and decreases the spender's allowance.
    /// @param _from The address to transfer tokens from.
    /// @param _to The address to transfer tokens to.
    /// @param _value The amount of tokens to transfer.
    /// @return True if the operation succeeded.
    function transferFrom(
        address _from,
        address _to,
        uint256 _value
    ) external returns (bool);
}

/**
 * @dev Implementation of the ERC-4626 "Tokenized Vault Standard" as defined in
 * https://eips.ethereum.org/EIPS/eip-4626[ERC-4626].
 *
 * [CAUTION]
 * ====
 * In empty (or nearly empty) ERC-4626 vaults, deposits are at high risk of being stolen through frontrunning
 * with a "donation" to the vault that inflates the price of a share. This is variously known as a donation or inflation
 * attack and is essentially a problem of slippage. Vault deployers can protect against this attack by making an initial
 * deposit of a non-trivial amount of the asset, such that price manipulation becomes infeasible. Withdrawals may
 * similarly be affected by slippage. Users can protect against this attack as well as unexpected slippage in general by
 * verifying the amount received is as expected, using a wrapper that performs these checks such as
 * https://github.com/fei-protocol/ERC4626#erc4626router-and-base[ERC4626Router].
 *
 * Since v4.9, this implementation introduces configurable virtual assets and shares to help developers mitigate that risk.
 * The `_decimalsOffset()` corresponds to an offset in the decimal representation between the underlying asset's decimals
 * and the vault decimals. This offset also determines the rate of virtual shares to virtual assets in the vault, which
 * itself determines the initial exchange rate. While not fully preventing the attack, analysis shows that the default
 * offset (0) makes it non-profitable even if an attacker is able to capture value from multiple user deposits, as a result
 * of the value being captured by the virtual shares (out of the attacker's donation) matching the attacker's expected gains.
 * With a larger offset, the attack becomes orders of magnitude more expensive than it is profitable. More details about the
 * underlying math can be found xref:ROOT:erc4626.adoc#inflation-attack[here].
 *
 * The drawback of this approach is that the virtual shares do capture (a very small) part of the value being accrued
 * to the vault. Also, if the vault experiences losses, the users try to exit the vault, the virtual shares and assets
 * will cause the first user to exit to experience reduced losses in detriment to the last users that will experience
 * bigger losses. Developers willing to revert back to the pre-v4.9 behavior just need to override the
 * `_convertToShares` and `_convertToAssets` functions.
 * ====
 *
 * [NOTE]
 * ====
 * When overriding this contract, some elements must be considered:
 *
 * * When overriding the behavior of the deposit or withdraw mechanisms, it is recommended to override the internal
 * functions. Overriding {_deposit} automatically affects both {deposit} and {mint}. Similarly, overriding {_withdraw}
 * automatically affects both {withdraw} and {redeem}. Overall it is not recommended to override the public facing
 * functions since that could lead to inconsistent behaviors between the {deposit} and {mint} or between {withdraw} and
 * {redeem}, which is documented to have lead to loss of funds.
 *
 * * Overrides to the deposit or withdraw mechanism must be reflected in the preview functions as well.
 *
 * * {maxWithdraw} depends on {maxRedeem}. Therefore, overriding {maxRedeem} only is enough. On the other hand,
 * overriding {maxWithdraw} only would have no effect on {maxRedeem}, and could create an inconsistency between the two
 * functions.
 *
 * * If {previewRedeem} is overridden to revert, {maxWithdraw} must be overridden as necessary to ensure it
 * always return successfully.
 * ====
 */
// abstract contract ERC4626 is ERC20, IERC4626 {
contract ERC4626Facet {
    /// @notice Thrown when an account has insufficient balance for a transfer or burn.
    /// @param _sender Address attempting the transfer.
    /// @param _balance Current balance of the sender.
    /// @param _needed Amount required to complete the operation.
    error ERC20InsufficientBalance(
        address _sender,
        uint256 _balance,
        uint256 _needed
    );

    /// @notice Thrown when the sender address is invalid (e.g., zero address).
    /// @param _sender Invalid sender address.
    error ERC20InvalidSender(address _sender);

    /// @notice Thrown when the receiver address is invalid (e.g., zero address).
    /// @param _receiver Invalid receiver address.
    error ERC20InvalidReceiver(address _receiver);

    /// @notice Thrown when a spender tries to use more than the approved allowance.
    /// @param _spender Address attempting to spend.
    /// @param _allowance Current allowance for the spender.
    /// @param _needed Amount required to complete the operation.
    error ERC20InsufficientAllowance(
        address _spender,
        uint256 _allowance,
        uint256 _needed
    );

    /// @notice Thrown when the spender address is invalid (e.g., zero address).
    /// @param _spender Invalid spender address.
    error ERC20InvalidSpender(address _spender);

    /// @notice Thrown when a permit signature is invalid or expired.
    /// @param _owner The address that signed the permit.
    /// @param _spender The address that was approved.
    /// @param _value The amount that was approved.
    /// @param _deadline The deadline for the permit.
    /// @param _v The recovery byte of the signature.
    /// @param _r The r value of the signature.
    /// @param _s The s value of the signature.
    error ERC2612InvalidSignature(
        address _owner,
        address _spender,
        uint256 _value,
        uint256 _deadline,
        uint8 _v,
        bytes32 _r,
        bytes32 _s
    );

    /// @notice Emitted when an approval is made for a spender by an owner.
    /// @param _owner The address granting the allowance.
    /// @param _spender The address receiving the allowance.
    /// @param _value The amount approved.
    event Approval(
        address indexed _owner,
        address indexed _spender,
        uint256 _value
    );

    /// @notice Emitted when tokens are transferred between two addresses.
    /// @param _from Address sending the tokens.
    /// @param _to Address receiving the tokens.
    /// @param _value Amount of tokens transferred.
    event Transfer(address indexed _from, address indexed _to, uint256 _value);

    /// @dev Attempted to deposit more assets than the max amount for `receiver`.
    error ERC4626ExceededMaxDeposit(
        address receiver,
        uint256 assets,
        uint256 max
    );

    /// @dev Attempted to mint more shares than the max amount for `receiver`.
    error ERC4626ExceededMaxMint(address receiver, uint256 shares, uint256 max);

    /// @dev Attempted to withdraw more assets than the max amount for `receiver`.
    error ERC4626ExceededMaxWithdraw(
        address owner,
        uint256 assets,
        uint256 max
    );

    /// @dev Attempted to redeem more shares than the max amount for `receiver`.
    error ERC4626ExceededMaxRedeem(address owner, uint256 shares, uint256 max);

    /// @dev Storage position determined by the keccak256 hash of the diamond storage identifier.
    bytes32 constant STORAGE_POSITION = keccak256("compose.erc4626");

    struct ERC4626Storage {
        string name;
        string symbol;
        uint8 underlyingDecimals;
        IERC20 asset;
        // uint8 underlyingDecimals;
        uint256 totalSupply;
        mapping(address owner => uint256 balance) balanceOf;
        mapping(address owner => mapping(address spender => uint256 allowance)) allowances;
        mapping(address owner => uint256) nonces;
    }

    function getStorage() internal pure returns (ERC4626Storage storage s) {
        bytes32 position = STORAGE_POSITION;
        assembly {
            s.slot := position
        }
    }

    /// @notice Returns the name of the token.
    /// @return The token name.
    function name() external view returns (string memory) {
        return getStorage().name;
    }

    /// @notice Returns the symbol of the token.
    /// @return The token symbol.
    function symbol() external view returns (string memory) {
        return getStorage().symbol;
    }

    /// @notice Returns the number of decimals used for token precision.
    /// @return The number of decimals.
    function decimals() external view returns (uint8) {
        return getStorage().underlyingDecimals + _decimalsOffset();
    }

    /// @notice Returns the total supply of tokens.
    /// @return The total token supply.
    function totalSupply() external view returns (uint256) {
        return getStorage().totalSupply;
    }

    /// @notice Returns the balance of a specific account.
    /// @param _account The address of the account.
    /// @return The account balance.
    function balanceOf(address _account) external view returns (uint256) {
        return getStorage().balanceOf[_account];
    }

    /// @notice Returns the remaining number of tokens that a spender is allowed to spend on behalf of an owner.
    /// @param _owner The address of the token owner.
    /// @param _spender The address of the spender.
    /// @return The remaining allowance.
    function allowance(
        address _owner,
        address _spender
    ) external view returns (uint256) {
        return getStorage().allowances[_owner][_spender];
    }

    /// @notice Approves a spender to transfer up to a certain amount of tokens on behalf of the caller.
    /// @dev Emits an {Approval} event.
    /// @param _spender The address approved to spend tokens.
    /// @param _value The number of tokens to approve.
    /// @return True if the approval was successful.
    function approve(address _spender, uint256 _value) external returns (bool) {
        ERC20Storage storage s = getStorage();
        if (_spender == address(0)) {
            revert ERC20InvalidSpender(address(0));
        }
        s.allowances[msg.sender][_spender] = _value;
        emit Approval(msg.sender, _spender, _value);
        return true;
    }

    /// @notice Transfers tokens to another address.
    /// @dev Emits a {Transfer} event.
    /// @param _to The address to receive the tokens.
    /// @param _value The amount of tokens to transfer.
    /// @return True if the transfer was successful.
    function transfer(address _to, uint256 _value) external returns (bool) {
        ERC20Storage storage s = getStorage();
        if (_to == address(0)) {
            revert ERC20InvalidReceiver(address(0));
        }
        uint256 fromBalance = s.balanceOf[msg.sender];
        if (fromBalance < _value) {
            revert ERC20InsufficientBalance(msg.sender, fromBalance, _value);
        }
        unchecked {
            s.balanceOf[msg.sender] = fromBalance - _value;
        }
        s.balanceOf[_to] += _value;
        emit Transfer(msg.sender, _to, _value);
        return true;
    }

    /// @notice Transfers tokens on behalf of another account, provided sufficient allowance exists.
    /// @dev Emits a {Transfer} event and decreases the spender's allowance.
    /// @param _from The address to transfer tokens from.
    /// @param _to The address to transfer tokens to.
    /// @param _value The amount of tokens to transfer.
    /// @return True if the transfer was successful.
    function transferFrom(
        address _from,
        address _to,
        uint256 _value
    ) external returns (bool) {
        ERC20Storage storage s = getStorage();
        if (_from == address(0)) {
            revert ERC20InvalidSender(address(0));
        }
        if (_to == address(0)) {
            revert ERC20InvalidReceiver(address(0));
        }
        uint256 currentAllowance = s.allowances[_from][msg.sender];
        if (currentAllowance < _value) {
            revert ERC20InsufficientAllowance(
                msg.sender,
                currentAllowance,
                _value
            );
        }
        uint256 fromBalance = s.balanceOf[_from];
        if (fromBalance < _value) {
            revert ERC20InsufficientBalance(_from, fromBalance, _value);
        }
        unchecked {
            if (currentAllowance != type(uint256).max) {
                s.allowances[_from][msg.sender] = currentAllowance - _value;
            }
            s.balanceOf[_from] = fromBalance - _value;
        }
        s.balanceOf[_to] += _value;
        emit Transfer(_from, _to, _value);
        return true;
    }

    /// @notice Burns (destroys) a specific amount of tokens from the caller's balance.
    /// @dev Emits a {Transfer} event to the zero address.
    /// @param _value The amount of tokens to burn.
    function burn(uint256 _value) external {
        ERC20Storage storage s = getStorage();
        uint256 balance = s.balanceOf[msg.sender];
        if (balance < _value) {
            revert ERC20InsufficientBalance(msg.sender, balance, _value);
        }
        unchecked {
            s.balanceOf[msg.sender] = balance - _value;
            s.totalSupply -= _value;
        }
        emit Transfer(msg.sender, address(0), _value);
    }

    /// @notice Burns tokens from another account, deducting from the caller's allowance.
    /// @dev Emits a {Transfer} event to the zero address.
    /// @param _account The address whose tokens will be burned.
    /// @param _value The amount of tokens to burn.
    function burnFrom(address _account, uint256 _value) external {
        ERC20Storage storage s = getStorage();
        uint256 currentAllowance = s.allowances[_account][msg.sender];
        if (currentAllowance < _value) {
            revert ERC20InsufficientAllowance(
                msg.sender,
                currentAllowance,
                _value
            );
        }
        uint256 balance = s.balanceOf[_account];
        if (balance < _value) {
            revert ERC20InsufficientBalance(_account, balance, _value);
        }
        unchecked {
            if (currentAllowance != type(uint256).max) {
                s.allowances[_account][msg.sender] = currentAllowance - _value;
            }
            s.balanceOf[_account] = balance - _value;
            s.totalSupply -= _value;
        }
        emit Transfer(_account, address(0), _value);
    }

    // EIP-2612 Permit Extension

    /// @notice Returns the current nonce for an owner.
    /// @dev This value changes each time a permit is used.
    /// @param _owner The address of the owner.
    /// @return The current nonce.
    function nonces(address _owner) external view returns (uint256) {
        return getStorage().nonces[_owner];
    }

    /// @notice Returns the domain separator used in the encoding of the signature for {permit}.
    /// @dev This value is unique to a contract and chain ID combination to prevent replay attacks.
    /// @return The domain separator.
    function DOMAIN_SEPARATOR() external view returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    keccak256(
                        "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
                    ),
                    keccak256(bytes(getStorage().name)),
                    keccak256("1"),
                    block.chainid,
                    address(this)
                )
            );
    }

    /// @notice Sets the allowance for a spender via a signature.
    /// @dev This function implements EIP-2612 permit functionality.
    /// @param _owner The address of the token owner.
    /// @param _spender The address of the spender.
    /// @param _value The amount of tokens to approve.
    /// @param _deadline The deadline for the permit (timestamp).
    /// @param _v The recovery byte of the signature.
    /// @param _r The r value of the signature.
    /// @param _s The s value of the signature.
    function permit(
        address _owner,
        address _spender,
        uint256 _value,
        uint256 _deadline,
        uint8 _v,
        bytes32 _r,
        bytes32 _s
    ) external {
        if (_spender == address(0)) {
            revert ERC20InvalidSpender(address(0));
        }
        if (block.timestamp > _deadline) {
            revert ERC2612InvalidSignature(
                _owner,
                _spender,
                _value,
                _deadline,
                _v,
                _r,
                _s
            );
        }

        ERC20Storage storage s = getStorage();
        uint256 currentNonce = s.nonces[_owner];
        bytes32 structHash = keccak256(
            abi.encode(
                keccak256(
                    "Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"
                ),
                _owner,
                _spender,
                _value,
                currentNonce,
                _deadline
            )
        );

        bytes32 hash = keccak256(
            abi.encodePacked(
                "\x19\x01",
                keccak256(
                    abi.encode(
                        keccak256(
                            "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
                        ),
                        keccak256(bytes(s.name)),
                        keccak256("1"),
                        block.chainid,
                        address(this)
                    )
                ),
                structHash
            )
        );

        address signer = ecrecover(hash, _v, _r, _s);
        if (signer != _owner || signer == address(0)) {
            revert ERC2612InvalidSignature(
                _owner,
                _spender,
                _value,
                _deadline,
                _v,
                _r,
                _s
            );
        }

        s.allowances[_owner][_spender] = _value;
        s.nonces[_owner] = currentNonce + 1;
        emit Approval(_owner, _spender, _value);
    }

    /// @inheritdoc IERC4626
    function asset() public view returns (address) {
        return address(getStorage().asset);
    }

    /// @notice Returns the total amount of the underlying asset that is "managed" by Vault.
    function totalAssets() public view returns (uint256) {
        return IERC20(asset()).balanceOf(address(this));
    }

    /// @notice Returns the amount of shares that the Vault would exchange for the amount of assets provided, in an ideal
    /// scenario where all the conditions are met.
    function convertToShares(uint256 assets) public view returns (uint256) {
        return _convertToShares(assets, Math.Rounding.Floor);
    }

    /// @notice Returns the amount of assets that the Vault would exchange for the amount of shares provided, in an ideal
    /// scenario where all the conditions are met.
    function convertToAssets(uint256 shares) public view returns (uint256) {
        return _convertToAssets(shares, Math.Rounding.Floor);
    }

    /// @notice Returns the maximum amount of the underlying asset that can be deposited into the Vault for the receiver,
    /// through a deposit call.
    function maxDeposit(address) public view returns (uint256) {
        return type(uint256).max;
    }

    /// @notice Returns the maximum amount of the Vault shares that can be minted for the receiver, through a mint call.
    function maxMint(address) public view returns (uint256) {
        return type(uint256).max;
    }

    /// @notice Returns the maximum amount of the underlying asset that can be withdrawn from the owner balance in the
    /// Vault, through a withdraw call.
    function maxWithdraw(address owner) public view returns (uint256) {
        return previewRedeem(maxRedeem(owner));
    }

    /// @notice Returns the maximum amount of Vault shares that can be redeemed from the owner balance in the Vault,
    /// through a redeem call.
    function maxRedeem(address owner) public view returns (uint256) {
        return balanceOf(owner);
    }

    /// @inheritdoc IERC4626
    function previewDeposit(uint256 assets) public view returns (uint256) {
        return _convertToShares(assets, Math.Rounding.Floor);
    }

    /// @notice Allows an on-chain or off-chain user to simulate the effects of their mint at the current block, given
    /// current on-chain conditions.
    function previewMint(uint256 shares) public view returns (uint256) {
        return _convertToAssets(shares, Math.Rounding.Ceil);
    }

    /// @notice Allows an on-chain or off-chain user to simulate the effects of their withdrawal at the current block,
    /// given current on-chain conditions.
    function previewWithdraw(
        uint256 assets
    ) public view virtual returns (uint256) {
        return _convertToShares(assets, Math.Rounding.Ceil);
    }

    /// @notice Allows an on-chain or off-chain user to simulate the effects of their redemption at the current block,
    /// given current on-chain conditions.
    function previewRedeem(
        uint256 shares
    ) public view virtual returns (uint256) {
        return _convertToAssets(shares, Math.Rounding.Floor);
    }

    /// @notice Mints shares Vault shares to receiver by depositing exactly amount of underlying tokens.
    function deposit(
        uint256 assets,
        address receiver
    ) public returns (uint256) {
        uint256 maxAssets = maxDeposit(receiver);
        if (assets > maxAssets) {
            revert ERC4626ExceededMaxDeposit(receiver, assets, maxAssets);
        }

        uint256 shares = previewDeposit(assets);
        _deposit(_msgSender(), receiver, assets, shares);

        return shares;
    }

    /// @notice Returns the maximum amount of the Vault shares that can be minted for the receiver, through a mint call.
    function mint(uint256 shares, address receiver) public returns (uint256) {
        uint256 maxShares = maxMint(receiver);
        if (shares > maxShares) {
            revert ERC4626ExceededMaxMint(receiver, shares, maxShares);
        }

        uint256 assets = previewMint(shares);
        _deposit(_msgSender(), receiver, assets, shares);

        return assets;
    }

    /// @notice Burns shares from owner and sends exactly assets of underlying tokens to receiver.
    function withdraw(
        uint256 assets,
        address receiver,
        address owner
    ) public returns (uint256) {
        uint256 maxAssets = maxWithdraw(owner);
        if (assets > maxAssets) {
            revert ERC4626ExceededMaxWithdraw(owner, assets, maxAssets);
        }

        uint256 shares = previewWithdraw(assets);
        _withdraw(_msgSender(), receiver, owner, assets, shares);

        return shares;
    }

    /// @notice Burns exactly shares from owner and sends assets of underlying tokens to receiver.
    function redeem(
        uint256 shares,
        address receiver,
        address owner
    ) public virtual returns (uint256) {
        uint256 maxShares = maxRedeem(owner);
        if (shares > maxShares) {
            revert ERC4626ExceededMaxRedeem(owner, shares, maxShares);
        }

        uint256 assets = previewRedeem(shares);
        _withdraw(_msgSender(), receiver, owner, assets, shares);

        return assets;
    }

    /// @dev Internal conversion function (from assets to shares) with support for direction.
    function _convertToShares(
        uint256 assets,
        Math.Rounding rounding
    ) internal view virtual returns (uint256) {
        return
            mulDiv(
                assets,
                totalSupply() + 10 ** _decimalsOffset(),
                totalAssets() + 1,
                rounding
            );
    }

    /// @dev Internal conversion function (from shares to assets) with support for rounding direction.
    function _convertToAssets(
        uint256 shares,
        Math.Rounding rounding
    ) internal view virtual returns (uint256) {
        return
            mulDiv(
                shares,
                totalAssets() + 1,
                totalSupply() + 10 ** _decimalsOffset(),
                rounding
            );
    }

    /// @dev Deposit/mint common workflow.
    function _deposit(
        address caller,
        address receiver,
        uint256 assets,
        uint256 shares
    ) internal {
        IERC20(asset()).transferFrom(caller, address(this), assets);
        ERC4626Storage storage s = getStorage();
        if (_account == address(0)) {
            revert ERC20InvalidReceiver(address(0));
        }
        s.totalSupply += _value;
        s.balanceOf[_account] += _value;

        emit Transfer(address(0), _account, _value);
        emit Deposit(caller, receiver, assets, shares);
    }

    /// @dev Withdraw/redeem common workflow.
    function _withdraw(
        address caller,
        address receiver,
        address owner,
        uint256 assets,
        uint256 shares
    ) internal virtual {
        if (caller != owner) {
            _spendAllowance(owner, caller, shares);
        }

        burn(owner, shares);
        IERC20(asset()).transfer(receiver, assets);

        emit Withdraw(caller, receiver, owner, assets, shares);
    }

    function _decimalsOffset() internal view virtual returns (uint8) {
        return 0;
    }

    /// @dev Cast a boolean (false or true) to a uint256 (0 or 1) with no jump.
    function toUint(bool b) internal pure returns (uint256 u) {
        assembly ("memory-safe") {
            u := iszero(iszero(b))
        }
    }

    /// @dev Return the 512-bit multiplication of two uint256.
    /// The result is stored in two 256 variables such that product = high * 2²⁵⁶ + low.
    function mul512(
        uint256 a,
        uint256 b
    ) internal pure returns (uint256 high, uint256 low) {
        // 512-bit multiply [high low] = x * y. Compute the product mod 2²⁵⁶ and mod 2²⁵⁶ - 1, then use
        // the Chinese Remainder Theorem to reconstruct the 512 bit result. The result is stored in two 256
        // variables such that product = high * 2²⁵⁶ + low.
        assembly ("memory-safe") {
            let mm := mulmod(a, b, not(0))
            low := mul(a, b)
            high := sub(sub(mm, low), lt(mm, low))
        }
    }

    /// @dev Calculates floor(x * y / denominator) with full precision. Throws if result overflows a uint256 or
    /// denominator == 0.
    /// Original credit to Remco Bloemen under MIT license (https://xn--2-umb.com/21/muldiv) with further edits by
    /// Uniswap Labs also under MIT license.
    function mulDiv(
        uint256 x,
        uint256 y,
        uint256 denominator
    ) internal pure returns (uint256 result) {
        unchecked {
            (uint256 high, uint256 low) = mul512(x, y);

            // Handle non-overflow cases, 256 by 256 division.
            if (high == 0) {
                // Solidity will revert if denominator == 0, unlike the div opcode on its own.
                // The surrounding unchecked block does not change this fact.
                // See https://docs.soliditylang.org/en/latest/control-structures.html#checked-or-unchecked-arithmetic.
                return low / denominator;
            }

            // Make sure the result is less than 2²⁵⁶. Also prevents denominator == 0.
            if (denominator <= high) {
                Panic.panic(
                    ternary(
                        denominator == 0,
                        Panic.DIVISION_BY_ZERO,
                        Panic.UNDER_OVERFLOW
                    )
                );
            }

            ///////////////////////////////////////////////
            // 512 by 256 division.
            ///////////////////////////////////////////////

            // Make division exact by subtracting the remainder from [high low].
            uint256 remainder;
            assembly ("memory-safe") {
                // Compute remainder using mulmod.
                remainder := mulmod(x, y, denominator)

                // Subtract 256 bit number from 512 bit number.
                high := sub(high, gt(remainder, low))
                low := sub(low, remainder)
            }

            // Factor powers of two out of denominator and compute largest power of two divisor of denominator.
            // Always >= 1. See https://cs.stackexchange.com/q/138556/92363.

            uint256 twos = denominator & (0 - denominator);
            assembly ("memory-safe") {
                // Divide denominator by twos.
                denominator := div(denominator, twos)

                // Divide [high low] by twos.
                low := div(low, twos)

                // Flip twos such that it is 2²⁵⁶ / twos. If twos is zero, then it becomes one.
                twos := add(div(sub(0, twos), twos), 1)
            }

            // Shift in bits from high into low.
            low |= high * twos;

            // Invert denominator mod 2²⁵⁶. Now that denominator is an odd number, it has an inverse modulo 2²⁵⁶ such
            // that denominator * inv ≡ 1 mod 2²⁵⁶. Compute the inverse by starting with a seed that is correct for
            // four bits. That is, denominator * inv ≡ 1 mod 2⁴.
            uint256 inverse = (3 * denominator) ^ 2;

            // Use the Newton-Raphson iteration to improve the precision. Thanks to Hensel's lifting lemma, this also
            // works in modular arithmetic, doubling the correct bits in each step.
            inverse *= 2 - denominator * inverse; // inverse mod 2⁸
            inverse *= 2 - denominator * inverse; // inverse mod 2¹⁶
            inverse *= 2 - denominator * inverse; // inverse mod 2³²
            inverse *= 2 - denominator * inverse; // inverse mod 2⁶⁴
            inverse *= 2 - denominator * inverse; // inverse mod 2¹²⁸
            inverse *= 2 - denominator * inverse; // inverse mod 2²⁵⁶

            // Because the division is now exact we can divide by multiplying with the modular inverse of denominator.
            // This will give us the correct result modulo 2²⁵⁶. Since the preconditions guarantee that the outcome is
            // less than 2²⁵⁶, this is the final result. We don't need to compute the high bits of the result and high
            // is no longer required.
            result = low * inverse;
            return result;
        }
    }

    /// @dev Calculates x * y / denominator with full precision, following the selected rounding direction.
    function mulDiv(
        uint256 x,
        uint256 y,
        uint256 denominator,
        Rounding rounding
    ) internal pure returns (uint256) {
        return
            mulDiv(x, y, denominator) +
            toUint(unsignedRoundsUp(rounding) && mulmod(x, y, denominator) > 0);
    }

    /// @dev Returns whether a provided rounding mode is considered rounding up for unsigned integers.
    function unsignedRoundsUp(Rounding rounding) internal pure returns (bool) {
        return uint8(rounding) % 2 == 1;
    }
}
