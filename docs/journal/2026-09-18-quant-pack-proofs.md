# 2026-09-18: quant-pack-proofs

## Current State

- `bend/pack_unpack/{LAWS,PROOF}.bend` proves a base-3 pair-packing round-trip
  (`digit = 3*t1 + t0`) by structural induction over `List<&2, Block2>` of any length —
  `bend bend/pack_unpack/PROOF.bend` prints `All terms check.`
- `bend/pack_unpack_5trit/{LAWS,PROOF}.bend` proves the real target: `pack_unpack_block5`
  (`unpack5(pack5(t4,t3,t2,t1,t0)) == B5{t4,t3,t2,t1,t0}` for five free trits, a 3^5=243-leaf
  exhaustive case analysis) and `pack_unpack5` (the same property generalized to
  `List<&2, Block5>` of any length, structural induction using the block lemma). Both laws:
  `bend bend/pack_unpack_5trit/PROOF.bend` prints `All terms check.`
- `bend/pack_unpack_5trit/buggy_first_attempt.bend` extracts five base-3 digits from a byte
  correctly but assembles them into `Block5` in extraction order rather than reversed to match the
  field order (`t4..t0`) — running it on a non-palindromic instance prints a mirror-reversed block.
  `buggy_first_attempt_disproved.bend` states the round-trip for that instance and `bend` rejects
  it with a named mismatch.
- `rust/src/{trit,trit5}.rs` implement both arities; `rust/tests/{roundtrip,roundtrip5}.rs` cover
  fixed instances cross-checked against the Bend demo output, arbitrary-length full-group lists,
  and the target 128-trit block (`pack_full_target_block_128`), plus a float dequantize/quantize
  tolerance round-trip (`dequant.rs`) explicitly not mirrored in Bend (`F32` is axiomatic in Bend —
  see `bend-primer/docs/limitations-and-honest-assessment.md`).
- `docs/proof-boundary.md` states which format-name and bit-width facts about PrismML's
  `PTQ1_0`/`Q1_0_G128` are independently confirmed (org, repo, PR titles, "1.75 bpw" framing) versus
  which parts of this project's byte layout are its own design "in that style," not a byte-exact
  reproduction of PrismML's actual source.

## Missing

- The 128-trit target block is packed as 25 full 5-trit groups (125 trits) plus a 3-trit remainder;
  the remainder's padding is tested in Rust (`pack_full_target_block_128`), not proven in Bend —
  `pack_unpack5`'s list proof covers only lists of *full* 5-trit groups.

## Divergence

- None found — `README.md` and `docs/round-trip-law.md` both state the arity-5 proof's actual
  scope (full groups, not the ragged 128-trit block) rather than overclaiming it.
