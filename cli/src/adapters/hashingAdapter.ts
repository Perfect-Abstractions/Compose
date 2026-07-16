import { keccak256, stringToBytes, type Hex } from "viem";
import { IHashingAdapter } from "./interface/IHashingAdapter";

/** Adapter providing keccak256 hashing over UTF-8 strings, returning a hex digest. */
export const HashingAdapter: IHashingAdapter = {
  /** @inheritdoc */
  keccak256(value: string): Hex {
    return keccak256(stringToBytes(value));
  },
};
