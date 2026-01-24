// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

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
function mulDiv(uint256 a, uint256 b, uint256 denominator) pure returns (uint256 result) {

    /*
     * Step 1: Prevent division by zero.
     */
    if (denominator == 0) {
        /*
         * Revert with panic code 0x12 (division by zero)
         * This is the standard panic code for division by zero in Solidity.
         */
        assembly ("memory-safe") {                
            mstore(0x00, 0x4e487b71) // Panic error selector
            mstore(0x04, 0x12) // Panic code 0x12
            revert(0x00, 0x24) // Revert with 36 bytes
        }
    }

    /*
     * Step 2: Calculate a 512-bit product of a and b.
     * - prod0 contains the least significant 256 bits of the product (a * b % 2**256).
     * - prod1 contains the most significant 256 bits. This is the "overflow" portion from 256-bit multiplication.
     * - Assembly is used for efficiency.
     */
    uint256 prod0;
    uint256 prod1;    
    assembly {
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
    if (prod1 >= denominator) {
        assembly {
            mstore(0x00, 0x4e487b71)  // Panic error selector
            mstore(0x04, 0x11)        // Panic code 0x11 (arithmetic overflow)
            revert(0x00, 0x24)        // Revert with 36 bytes
        }
    }

    /*
     * Step 5: Compute and subtract remainder from [prod1 prod0] to make the division exact.
     * - Calculate the remainder of (a * b) % denominator.
     * - Remove the remainder from the [prod1 prod0] 512-bit product so division will be exact.
     */    
    assembly {
        let remainder := mulmod(a, b, denominator)
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