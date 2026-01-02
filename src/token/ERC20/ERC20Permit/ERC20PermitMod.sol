// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

/*
 * @title   LibERC20Permit — Library for ERC-2612 Permit Logic
 * @notice  Library for self-contained ERC-2612 permit and domain separator logic and storage
 * @dev     Does not import anything. Designed to be used by facets handling ERC20 permit functionality.
 */

/**
 * @notice Thrown when a permit signature is invalid or expired.
 * @param _owner The address that signed the permit.
 * @param _spender The address that was approved.
 * @param _value The amount that was approved.
 * @param _deadline The deadline for the permit.
 * @param _v The recovery byte of the signature.
 * @param _r The r value of the signature.
 * @param _s The s value of the signature.
 */
error ERC2612InvalidSignature(
    address _owner, address _spender, uint256 _value, uint256 _deadline, uint8 _v, bytes32 _r, bytes32 _s
);

/**
 * @notice Thrown when the spender address is invalid (e.g., zero address).
 * @param _spender Invalid spender address.
 */
error ERC20InvalidSpender(address _spender);

/**
 * @notice Emitted when an approval is made for a spender by an owner.
 * @param _owner The address granting the allowance.
 * @param _spender The address receiving the allowance.
 * @param _value The amount approved.
 */
event Approval(address indexed _owner, address indexed _spender, uint256 _value);

bytes32 constant ERC20_METADATA_STORAGE_POSITION = keccak256("compose.erc20.metadata");

/**
 * @custom:storage-location erc8042:compose.erc20.metadata
 */
struct ERC20MetadataStorage {
    string name;
}

function getERC20MetadataStorage() pure returns (ERC20MetadataStorage storage s) {
    bytes32 position = ERC20_METADATA_STORAGE_POSITION;
    assembly {
        s.slot := position
    }
}

bytes32 constant ERC20_TRANSFER_STORAGE_POSITION = keccak256("compose.erc20.transfer");

/**
 * @custom:storage-location erc8042:compose.erc20.transfer
 */
struct ERC20TransferStorage {
    mapping(address owner => uint256 balance) balanceOf;
    uint256 totalSupply;
    mapping(address owner => mapping(address spender => uint256 allowance)) allowance;
}

function getERC20TransferStorage() pure returns (ERC20TransferStorage storage s) {
    bytes32 position = ERC20_TRANSFER_STORAGE_POSITION;
    assembly {
        s.slot := position
    }
}

bytes32 constant STORAGE_POSITION = keccak256("compose.erc20.permit");

/**
 * @custom:storage-location erc8042:compose.erc20.permit
 */
struct ERC20PermitStorage {
    mapping(address owner => uint256) nonces;
}

function getPermitStorage() pure returns (ERC20PermitStorage storage s) {
    bytes32 position = STORAGE_POSITION;
    assembly {
        s.slot := position
    }
}

/**
 * @notice Returns the domain separator used in the encoding of the signature for {permit}.
 * @dev This value is unique to a contract and chain ID combination to prevent replay attacks.
 * @return The domain separator.
 */
function DOMAIN_SEPARATOR() view returns (bytes32) {
    address thisAddress;
    assembly {
        thisAddress := address()
    }
    return keccak256(
        abi.encode(
            keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
            keccak256(bytes(getERC20MetadataStorage().name)),
            keccak256("1"),
            block.chainid,
            thisAddress
        )
    );
}

/**
 * @notice         Validates a permit signature and sets allowance.
 * @dev            Emits Approval event; must be emitted by the calling facet/contract.
 * @param _owner   Token owner.
 * @param _spender Token spender.
 * @param _value   Allowance value.
 * @param _deadline Permit's time deadline.
 * @param _v, _r, _s   Signature fields.
 */
function permit(address _owner, address _spender, uint256 _value, uint256 _deadline, uint8 _v, bytes32 _r, bytes32 _s) {
    if (_spender == address(0)) {
        revert ERC20InvalidSpender(address(0));
    }
    if (block.timestamp > _deadline) {
        revert ERC2612InvalidSignature(_owner, _spender, _value, _deadline, _v, _r, _s);
    }

    ERC20PermitStorage storage s = getPermitStorage();
    ERC20TransferStorage storage erc20Transfer = getERC20TransferStorage();
    uint256 currentNonce = s.nonces[_owner];
    bytes32 structHash = keccak256(
        abi.encode(
            keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"),
            _owner,
            _spender,
            _value,
            currentNonce,
            _deadline
        )
    );
    address thisAddress;
    assembly {
        thisAddress := address()
    }
    bytes32 hash = keccak256(
        abi.encodePacked(
            "\x19\x01",
            keccak256(
                abi.encode(
                    keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                    keccak256(bytes(getERC20MetadataStorage().name)),
                    keccak256("1"),
                    block.chainid,
                    thisAddress
                )
            ),
            structHash
        )
    );

    address signer = ecrecover(hash, _v, _r, _s);
    if (signer != _owner || signer == address(0)) {
        revert ERC2612InvalidSignature(_owner, _spender, _value, _deadline, _v, _r, _s);
    }

    erc20Transfer.allowance[_owner][_spender] = _value;
    s.nonces[_owner] = currentNonce + 1;
    emit Approval(_owner, _spender, _value);
}
