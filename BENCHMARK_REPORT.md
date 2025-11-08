# Diamond Loupe Gas Benchmark Report

Generated from comprehensive benchmark tests.

**Compiler Settings:**
- Optimizer Runs: 20,000
- viaIR: Disabled

---

---

## Implementations Covered

- [Original (Mudgen, 2018)](https://github.com/Perfect-Abstractions/Compose/blob/bea3dfb6d2e48d88bed1b9f1c34104a16b7ebc84/src/diamond/DiamondLoupeFacet.sol) `(Original)`
- [Compose Reference (Mudgen, 2025)](https://github.com/Perfect-Abstractions/Compose/blob/main/src/diamond/DiamondLoupeFacet.sol) `(ComposeReference)`
- [Two-Pass Benchmark (Compose)](test/benchmark/implementations/TwoPassDiamondLoupeFacet.sol) `(TwoPassBaseline)`
- [Collision Map Benchmark (Compose)](test/benchmark/implementations/CollisionMapDiamondLoupeFacet.sol) `(CollisionMap)`
- [Jackie Xu Optimised Loupe](https://github.com/JackieXu/Compose/blob/fa4103dc76a73fbab4e9c3cebcd98dcac1783295/src/diamond/DiamondLoupeFacet.sol) `(JackieXu)`
- [0xkitetsu-dinesh Bucketed Loupe](https://github.com/mudgen/diamond-2/pull/155) `(KitetsuDinesh)`
- [Dawid919 Registry Loupe](https://github.com/mudgen/diamond-2/pull/155) `(Dawid919)`

---

## facets() Function Gas Costs

| Selectors/Facets | Original | ComposeReference | TwoPassBaseline | CollisionMap | JackieXu | KitetsuDinesh | Dawid919 |
|------------------|----------|----------|----------|----------|----------|----------|----------|
| 0/0 | 2,326 | 15,175 | 2,138 | 2,142 | 1,493 | 2,060 | 3,520 |
| 2/1 | 7,804 | 18,791 | 7,314 | 7,383 | 4,382 | 13,383 | 11,642 |
| 4/2 | 12,185 | 21,006 | 11,521 | 11,740 | 5,860 | 19,068 | 16,051 |
| 6/3 | 18,147 | 24,550 | 17,233 | 17,390 | 7,995 | 33,958 | 29,884 |
| 40/10 | 149,290 | 75,351 | 145,409 | 142,153 | 44,814 | 502,505 | 498,684 |
| 40/20 | 200,336 | 86,688 | 196,135 | 178,496 | FAIL | 880,400 | 896,457 |
| 64/16 | 289,753 | 113,756 | 284,191 | 273,145 | 88,886 | 1,175,016 | 1,192,983 |
| 64/32 | 433,837 | 145,385 | 428,073 | 377,962 | FAIL | 2,164,359 | 2,238,047 |
| 64/64 | 690,603 | 179,235 | 684,929 | 483,197 | FAIL | 4,112,898 | 4,298,844 |
| 504/42 | 4,018,529 | 740,761 | 4,023,165 | 3,979,912 | 611,405 | 22,269,336 | 23,228,175 |

---

## facetAddresses() Function Gas Costs

| Selectors/Facets | Original | ComposeReference | TwoPassBaseline | CollisionMap | JackieXu | KitetsuDinesh | Dawid919 |
|------------------|----------|----------|----------|----------|----------|----------|----------|
| 0/0 | 1,917 | 14,926 | 1,785 | 1,789 | 1,471 | 1,825 | 1,825 |
| 2/1 | 3,907 | 17,209 | 3,558 | 3,606 | 2,935 | 7,495 | 3,999 |
| 4/2 | 5,533 | 18,851 | 5,202 | 5,358 | 3,473 | 10,263 | 5,551 |
| 6/3 | 7,821 | 21,144 | 7,321 | 7,398 | 4,427 | 13,791 | 7,730 |
| 40/10 | 60,860 | 53,991 | 59,166 | 55,026 | 18,765 | 66,856 | 59,297 |
| 40/20 | 84,320 | 58,782 | 80,972 | 62,489 | FAIL | 73,325 | 82,491 |
| 64/16 | 120,783 | 77,562 | 118,274 | 105,584 | 36,692 | 105,360 | 118,387 |
| 64/32 | 185,031 | 87,995 | 179,896 | 127,977 | FAIL | 118,805 | 182,382 |
| 64/64 | 307,525 | 102,598 | 297,002 | 93,189 | FAIL | 139,283 | 304,886 |
| 504/42 | 1,783,312 | 464,415 | 1,782,803 | 1,705,304 | 186,853 | 802,044 | 1,775,237 |

---

## Extended Configurations (Large Diamonds)

### facets() Function

| Selectors/Facets | Original | ComposeReference | TwoPassBaseline | CollisionMap | JackieXu | KitetsuDinesh | Dawid919 |
|------------------|----------|----------|----------|----------|----------|----------|----------|
| 1000/84 | 12,439,310 | 1,402,326 | 12,530,186 | 12,305,224 | 1,265,698 | 78,633,632 | 82,734,609 |
| 10000/834 | SKIP | 27,339,081 | SKIP | SKIP | 26,167,483 | SKIP | SKIP |
| 12000/1200 | SKIP | 44,144,604 | SKIP | SKIP | 42,523,056 | SKIP | SKIP |

### facetAddresses() Function

| Selectors/Facets | Original | ComposeReference | TwoPassBaseline | CollisionMap | JackieXu | KitetsuDinesh | Dawid919 |
|------------------|----------|----------|----------|----------|----------|----------|----------|
| 1000/84 | 5,729,838 | 854,502 | 5,733,674 | 5,407,003 | 353,528 | 1,582,859 | 5,734,966 |
| 10000/834 | SKIP | 11,284,550 | SKIP | SKIP | 4,460,376 | SKIP | SKIP |
| 12000/1200 | SKIP | 16,694,359 | SKIP | SKIP | 6,468,613 | SKIP | SKIP |

---

## Additional Configurations (Issue #155 follow-up)

### facets() Function

| Selectors/Facets | Original | ComposeReference | TwoPassBaseline | CollisionMap | JackieXu | KitetsuDinesh | Dawid919 |
|------------------|----------|----------|----------|----------|----------|----------|----------|
| 20/7 | 47,342 | 38,987 | 45,561 | 44,267 | FAIL | 132,497 | 126,733 |
| 50/17 | 157,044 | 75,516 | 153,333 | 139,651 | FAIL | 648,955 | 656,413 |
| 100/34 | 464,724 | 139,924 | 458,762 | 400,938 | FAIL | 2,416,285 | 2,503,113 |
| 500/167 | 8,134,386 | 742,436 | 8,155,373 | 7,180,931 | FAIL | 54,877,515 | 58,073,007 |
| 1000/334 | 30,980,765 | 1,742,359 | 31,147,698 | 28,098,077 | FAIL | 217,864,429 | 231,237,056 |

### facetAddresses() Function

| Selectors/Facets | Original | ComposeReference | TwoPassBaseline | CollisionMap | JackieXu | KitetsuDinesh | Dawid919 |
|------------------|----------|----------|----------|----------|----------|----------|----------|
| 20/7 | 19,168 | 29,964 | 17,978 | 16,466 | FAIL | 27,560 | 18,609 |
| 50/17 | 65,433 | 52,110 | 62,571 | 48,236 | FAIL | 62,453 | 63,861 |
| 100/34 | 202,537 | 90,052 | 197,008 | 137,296 | FAIL | 123,586 | 199,790 |
| 500/167 | 3,813,301 | 399,113 | 3,794,601 | 2,788,947 | FAIL | 665,334 | 3,825,220 |
| 1000/334 | 14,721,250 | 820,750 | 14,705,092 | 11,537,984 | FAIL | 1,483,802 | 14,811,547 |
