import { keccak256, stringToBytes, type Hex } from "viem";

export interface HashingAdapterInterface {
  keccak256(value: string): Hex;
}

export const HashingAdapter: HashingAdapterInterface = {
  // Hash a UTF-8 string using keccak256 and return the hex digest.
  keccak256(value: string): Hex {
    return keccak256(stringToBytes(value));
  },
};
