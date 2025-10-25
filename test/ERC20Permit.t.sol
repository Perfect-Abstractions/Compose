// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {ERC20Facet} from "../src/ERC20/ERC20/ERC20Facet.sol";

/// @title MockERC20Facet
/// @notice Mock contract that properly initializes ERC20 storage for testing
contract MockERC20Facet is ERC20Facet {
    constructor() {
        // Initialize storage directly
        ERC20Storage storage s = getStorage();
        s.name = "TestToken";
        s.symbol = "TEST";
        s.decimals = 18;
        s.totalSupply = 1000000 * 10**18;
    }
    
    function mint(address to, uint256 amount) external {
        ERC20Storage storage s = getStorage();
        s.balanceOf[to] += amount;
        s.totalSupply += amount;
        emit Transfer(address(0), to, amount);
    }
}

/// @title ERC20PermitTest
/// @notice Comprehensive tests for ERC-20 Permit extension (EIP-2612)
contract ERC20PermitTest is Test {
    MockERC20Facet public erc20;
    
    // Test accounts
    address public owner;
    address public spender;
    address public other;
    
    // Test values
    uint256 public constant INITIAL_SUPPLY = 1000000 * 10**18;
    uint256 public constant PERMIT_AMOUNT = 1000 * 10**18;
    uint256 public constant DEADLINE = 1000000000; // Far future timestamp
    
    // EIP-712 constants
    bytes32 public constant PERMIT_TYPEHASH = keccak256(
        "Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"
    );
    bytes32 public constant EIP712_DOMAIN_TYPEHASH = keccak256(
        "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
    );

    function setUp() public {
        // Create test accounts
        owner = makeAddr("owner");
        spender = makeAddr("spender");
        other = makeAddr("other");
        
        // Deploy MockERC20Facet
        erc20 = new MockERC20Facet();
        
        // Give owner some tokens
        erc20.mint(owner, INITIAL_SUPPLY);
    }

    // Helper function to create EIP-712 signature
    function _createPermitSignature(
        address _owner,
        address _spender,
        uint256 _value,
        uint256 _nonce,
        uint256 _deadline,
        uint256 _privateKey
    ) internal view returns (uint8 v, bytes32 r, bytes32 s) {
        bytes32 domainSeparator = erc20.DOMAIN_SEPARATOR();
        
        bytes32 structHash = keccak256(
            abi.encode(
                PERMIT_TYPEHASH,
                _owner,
                _spender,
                _value,
                _nonce,
                _deadline
            )
        );
        
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                domainSeparator,
                structHash
            )
        );
        
        return vm.sign(_privateKey, digest);
    }


    // ============ SUCCESS PATH TESTS ============

    function test_Permit_ValidSignature_SetsAllowance() public {
        uint256 privateKey = 0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef;
        address signer = vm.addr(privateKey);
        
        // Give signer some tokens
        erc20.mint(signer, INITIAL_SUPPLY);
        
        uint256 nonce = 0;
        (uint8 v, bytes32 r, bytes32 s) = _createPermitSignature(
            signer,
            spender,
            PERMIT_AMOUNT,
            nonce,
            DEADLINE,
            privateKey
        );
        
        // Expect Approval event
        vm.expectEmit(true, true, false, true);
        emit ERC20Facet.Approval(signer, spender, PERMIT_AMOUNT);
        
        // Execute permit
        erc20.permit(signer, spender, PERMIT_AMOUNT, DEADLINE, v, r, s);
        
        // Verify allowance was set
        assertEq(erc20.allowance(signer, spender), PERMIT_AMOUNT);
    }

    function test_Permit_ValidSignature_IncrementsNonce() public {
        uint256 privateKey = 0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef;
        address signer = vm.addr(privateKey);
        
        // Give signer some tokens
        erc20.mint(signer, INITIAL_SUPPLY);
        
        uint256 initialNonce = erc20.nonces(signer);
        (uint8 v, bytes32 r, bytes32 s) = _createPermitSignature(
            signer,
            spender,
            PERMIT_AMOUNT,
            initialNonce,
            DEADLINE,
            privateKey
        );
        
        // Execute permit
        erc20.permit(signer, spender, PERMIT_AMOUNT, DEADLINE, v, r, s);
        
        // Verify nonce was incremented
        assertEq(erc20.nonces(signer), initialNonce + 1);
    }

    function test_Permit_MultiplePermits_SequentialNonces() public {
        uint256 privateKey = 0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef;
        address signer = vm.addr(privateKey);
        
        // Give signer some tokens
        erc20.mint(signer, INITIAL_SUPPLY);
        
        // First permit
        uint256 nonce1 = 0;
        (uint8 v1, bytes32 r1, bytes32 s1) = _createPermitSignature(
            signer,
            spender,
            PERMIT_AMOUNT,
            nonce1,
            DEADLINE,
            privateKey
        );
        erc20.permit(signer, spender, PERMIT_AMOUNT, DEADLINE, v1, r1, s1);
        
        // Second permit with incremented nonce
        uint256 nonce2 = 1;
        (uint8 v2, bytes32 r2, bytes32 s2) = _createPermitSignature(
            signer,
            spender,
            PERMIT_AMOUNT * 2,
            nonce2,
            DEADLINE,
            privateKey
        );
        erc20.permit(signer, spender, PERMIT_AMOUNT * 2, DEADLINE, v2, r2, s2);
        
        // Verify final allowance and nonce
        assertEq(erc20.allowance(signer, spender), PERMIT_AMOUNT * 2);
        assertEq(erc20.nonces(signer), 2);
    }

    function test_Permit_ZeroValueApproval() public {
        uint256 privateKey = 0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef;
        address signer = vm.addr(privateKey);
        
        // Give signer some tokens
        erc20.mint(signer, INITIAL_SUPPLY);
        
        uint256 nonce = 0;
        (uint8 v, bytes32 r, bytes32 s) = _createPermitSignature(
            signer,
            spender,
            0, // Zero value
            nonce,
            DEADLINE,
            privateKey
        );
        
        // Expect Approval event with zero value
        vm.expectEmit(true, true, false, true);
        emit ERC20Facet.Approval(signer, spender, 0);
        
        // Execute permit
        erc20.permit(signer, spender, 0, DEADLINE, v, r, s);
        
        // Verify allowance was set to zero
        assertEq(erc20.allowance(signer, spender), 0);
    }

    function test_DOMAIN_SEPARATOR_Consistent() public view {
        bytes32 domainSeparator1 = erc20.DOMAIN_SEPARATOR();
        bytes32 domainSeparator2 = erc20.DOMAIN_SEPARATOR();
        
        assertEq(domainSeparator1, domainSeparator2);
    }

    // ============ FAILURE PATH TESTS ============

    function test_Permit_ExpiredDeadline_Reverts() public {
        uint256 privateKey = 0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef;
        address signer = vm.addr(privateKey);
        
        // Give signer some tokens
        erc20.mint(signer, INITIAL_SUPPLY);
        
        uint256 expiredDeadline = block.timestamp - 1; // Expired deadline
        uint256 nonce = 0;
        (uint8 v, bytes32 r, bytes32 s) = _createPermitSignature(
            signer,
            spender,
            PERMIT_AMOUNT,
            nonce,
            expiredDeadline,
            privateKey
        );
        
        // Expect revert with ERC2612InvalidSignature
        vm.expectRevert(
            abi.encodeWithSelector(
                ERC20Facet.ERC2612InvalidSignature.selector,
                signer,
                spender,
                PERMIT_AMOUNT,
                expiredDeadline,
                v,
                r,
                s
            )
        );
        
        erc20.permit(signer, spender, PERMIT_AMOUNT, expiredDeadline, v, r, s);
    }

    function test_Permit_ReusedSignature_Reverts() public {
        uint256 privateKey = 0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef;
        address signer = vm.addr(privateKey);
        
        // Give signer some tokens
        erc20.mint(signer, INITIAL_SUPPLY);
        
        uint256 nonce = 0;
        (uint8 v, bytes32 r, bytes32 s) = _createPermitSignature(
            signer,
            spender,
            PERMIT_AMOUNT,
            nonce,
            DEADLINE,
            privateKey
        );
        
        // First permit succeeds
        erc20.permit(signer, spender, PERMIT_AMOUNT, DEADLINE, v, r, s);
        
        // Second permit with same signature should fail
        vm.expectRevert(
            abi.encodeWithSelector(
                ERC20Facet.ERC2612InvalidSignature.selector,
                signer,
                spender,
                PERMIT_AMOUNT,
                DEADLINE,
                v,
                r,
                s
            )
        );
        
        erc20.permit(signer, spender, PERMIT_AMOUNT, DEADLINE, v, r, s);
    }

    function test_Permit_WrongSigner_Reverts() public {
        uint256 privateKey1 = 0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef;
        uint256 privateKey2 = 0xabcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890;
        address signer1 = vm.addr(privateKey1);
        
        // Give signer1 some tokens
        erc20.mint(signer1, INITIAL_SUPPLY);
        
        uint256 nonce = 0;
        (uint8 v, bytes32 r, bytes32 s) = _createPermitSignature(
            signer1, // Owner in signature
            spender,
            PERMIT_AMOUNT,
            nonce,
            DEADLINE,
            privateKey2 // But signed with different private key
        );
        
        // Expect revert with ERC2612InvalidSignature
        vm.expectRevert(
            abi.encodeWithSelector(
                ERC20Facet.ERC2612InvalidSignature.selector,
                signer1,
                spender,
                PERMIT_AMOUNT,
                DEADLINE,
                v,
                r,
                s
            )
        );
        
        erc20.permit(signer1, spender, PERMIT_AMOUNT, DEADLINE, v, r, s);
    }

    function test_Permit_InvalidSignature_Reverts() public {
        uint256 privateKey = 0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef;
        address signer = vm.addr(privateKey);
        
        // Give signer some tokens
        erc20.mint(signer, INITIAL_SUPPLY);
        
        uint256 nonce = 0;
        (uint8 v, bytes32 r, bytes32 s) = _createPermitSignature(
            signer,
            spender,
            PERMIT_AMOUNT,
            nonce,
            DEADLINE,
            privateKey
        );
        
        // Corrupt the signature
        bytes32 corruptedR = bytes32(uint256(r) ^ 1);
        
        // Expect revert with ERC2612InvalidSignature
        vm.expectRevert(
            abi.encodeWithSelector(
                ERC20Facet.ERC2612InvalidSignature.selector,
                signer,
                spender,
                PERMIT_AMOUNT,
                DEADLINE,
                v,
                corruptedR,
                s
            )
        );
        
        erc20.permit(signer, spender, PERMIT_AMOUNT, DEADLINE, v, corruptedR, s);
    }

    // ============ EDGE CASE TESTS ============

    function test_Permit_MaxUint256Value() public {
        uint256 privateKey = 0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef;
        address signer = vm.addr(privateKey);
        
        // Give signer some tokens
        erc20.mint(signer, INITIAL_SUPPLY);
        
        uint256 maxValue = type(uint256).max;
        uint256 nonce = 0;
        (uint8 v, bytes32 r, bytes32 s) = _createPermitSignature(
            signer,
            spender,
            maxValue,
            nonce,
            DEADLINE,
            privateKey
        );
        
        // Expect Approval event with max value
        vm.expectEmit(true, true, false, true);
        emit ERC20Facet.Approval(signer, spender, maxValue);
        
        // Execute permit
        erc20.permit(signer, spender, maxValue, DEADLINE, v, r, s);
        
        // Verify allowance was set to max value
        assertEq(erc20.allowance(signer, spender), maxValue);
    }

    function test_Permit_NonceReadout_MatchesExpected() public {
        uint256 privateKey = 0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef;
        address signer = vm.addr(privateKey);
        
        // Give signer some tokens
        erc20.mint(signer, INITIAL_SUPPLY);
        
        // Execute multiple permits
        for (uint256 i = 0; i < 5; i++) {
            uint256 nonce = i;
            (uint8 v, bytes32 r, bytes32 s) = _createPermitSignature(
                signer,
                spender,
                PERMIT_AMOUNT,
                nonce,
                DEADLINE,
                privateKey
            );
            
            erc20.permit(signer, spender, PERMIT_AMOUNT, DEADLINE, v, r, s);
            
            // Verify nonce matches expected value
            assertEq(erc20.nonces(signer), i + 1);
        }
    }
}
