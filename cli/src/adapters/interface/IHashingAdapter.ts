import { type Hex } from "viem";

/** Interface for hashing utilities */
export interface IHashingAdapter {
  /**
   * Hashes a UTF-8 string using keccak256 and returns the hex-encoded result.
   *
   * @param value - The UTF-8 string to hash
   * @returns The keccak256 hex digest
   */
  keccak256(value: string): Hex;
}