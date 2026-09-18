# Packing arithmetic, derived

Two schemes are worked out here: the **target** scheme (5 trits/byte, the
arity that matters for an actual deployment) and the **proven** scheme (2
trits/digit, the deliberately simplified stand-in that is actually checked
by `bend` in this project). Both use the same offset-encoded alphabet and
the same technique (base-3 digit packing, inverted by Euclidean div/mod);
only the arity differs.

## The alphabet

A ternary weight is one of three values, `{-1, 0, +1}`. Storing signed
values directly in a packed integer code invites off-by-one sign bugs (is
`-1` stored as `0xFF`? as the top bit set? two's complement of what width?),
so instead each trit is **offset-encoded** as a value in `{0, 1, 2}`:

| trit | packed code |
|:---:|:---:|
| -1 | 0 |
|  0 | 1 |
| +1 | 2 |

This is a standard technique (the same idea as storing a signed exponent
with a bias, or a centered index with an offset) and needs no external
citation - it is just "shift the domain so it starts at 0, so packing code
is unsigned-only arithmetic," derived and justified here, not asserted.

## Target scheme: 5 trits per byte

**How many trits fit losslessly in one byte?** A byte has `2^8 = 256`
distinct values. Packing `k` independent base-3 digits into one byte needs
`3^k <= 256`:

```
3^1 =     3
3^2 =     9
3^3 =    27
3^4 =    81
3^5 =   243   <= 256   (fits, 13 codepoints unused: 256 - 243 = 13)
3^6 =   729   >  256   (does not fit)
```

So `k = 5` is the largest arity that packs losslessly into a byte: `3^5 =
243 <= 256 < 3^6 = 729`. The packing map for a byte holding 5 trits
`t4, t3, t2, t1, t0` (each in `{0,1,2}`) is the base-3 place-value sum

```
byte = t4*3^4 + t3*3^3 + t2*3^2 + t1*3^1 + t0*3^0
     = 81*t4 + 27*t3 + 9*t2 + 3*t1 + t0
```

which ranges over `0..=242`, leaving byte values `243..=255` (13 of them)
unused - exactly the `256 - 243 = 13` slack from the inequality above.
Unpacking is repeated Euclidean division by 3: `t0 = byte % 3`, then
`byte /= 3`, `t1 = byte % 3`, and so on for 5 steps.

**Bytes needed for a block of 128 trits:**

```
ceil(128 / 5) = ceil(25.6) = 26 bytes
```

25 of those bytes are fully packed (5 trits each, `25 * 5 = 125` trits);
the 26th byte carries the remaining `128 - 125 = 3` trits, using only
`3^3 = 27` of its 256 possible values (a deliberately simple, if wasteful,
choice - a bit-interleaved packing across the block boundary could reclaim
that waste, at the cost of a messier proof and implementation; not
attempted here).

**Bits per weight, codes only** (no scale yet):

```
26 bytes * 8 bits/byte / 128 weights = 208 / 128 = 1.625 bits/weight
```

**Adding a per-block scale factor.** PrismML's PTQ1_0 and BitNet b1.58 both
share one scale across a group of weights (128, in PTQ1_0's case - both
facts independently confirmed, see `../README.md`); this project makes the
same design choice for its own scheme. The scale's storage width changes
the total:

| scale width | total bytes/block | bits/weight |
|---|---|---|
| `f16` (2 bytes) | 26 + 2 = 28 | `(208+16)/128 = 224/128 = 1.75` |
| `f32` (4 bytes) | 26 + 4 = 30 | `(208+32)/128 = 240/128 = 1.875` |

The `f16` row lands on exactly the same `1.75` bits/weight figure quoted
for PTQ1_0 in the independently-confirmed "1.75 bpw, lossless vs PQ2_0"
framing (see the README). That is a consequence of the arithmetic above
(26-byte codes + a 2-byte scale, over 128 weights), not a claim that this
project's byte *layout* matches PTQ1_0's - we did not verify PTQ1_0's actual
byte layout against its source (see `../README.md` and
`../../bend-primer/docs/verification-notes.md`), only the bits/weight
figure, and only as an arithmetic coincidence worth flagging honestly
rather than hiding.

This project's Rust dequantizer (`rust/src/dequant.rs`) uses `f32` for the
scale, for implementation simplicity (`f16` needs either a dependency or
hand-rolled bit manipulation, and the round-trip *law* this project proves
doesn't touch the scale's width at all - see `proof-boundary.md`). That is
a stated simplification, not a claim about what any upstream format uses.

## Proven scheme: 2 trits per digit

Proving the 5-trits/byte scheme's round trip in Bend means a case analysis
over `3^5 = 243` combinations (or an equivalent inductive argument over a
5-step div/mod chain) - judged too fiddly to get right, and right *cleanly*,
in the time available for this project. The task this project fulfills
explicitly sanctions proving a smaller instance of the identical technique
instead and saying so plainly, which is what this section (and
`bend/pack_unpack/`) does.

**Arity 2:** pack two trits `t1, t0` into one digit via

```
digit = 3*t1 + t0
```

which ranges over `0..=8` (`3^2 = 9 <= 256`, so this fits in a byte too -
with far more slack than the 5-trit scheme: only 9 of 256 codepoints used,
about 3.5%). Unpacking is exactly one step of Euclidean div/mod by 3:
`t1 = digit / 3`, `t0 = digit % 3` - literally the base case of the same
5-step chain the target scheme would need, just stopped after one step
instead of five.

**This arity is not proposed as a real packing format.** Storing each
2-trit digit in its own byte costs `ceil(128/2) = 64` bytes for a 128-trit
block, i.e. `64*8/128 = 4` bits/weight for the codes alone - 2.46x worse
than the target scheme's 1.625 bits/weight, and worse than just storing
each trit in 2 raw bits (`0.5` bytes/trit `= 4` bits/weight also, no
arithmetic benefit at all over a naive 2-bit-per-trit layout). Its only
purpose is to make the Bend proof's case analysis small enough to write out
completely by hand (9 cases, or a short structural induction - see
`round-trip-law.md`) while using the *identical* technique (base-`k` digit
packing, inverted by div/mod) that the target scheme would need at arity 5.
`bend/pack_unpack/main.bend` states this in its header comment too.
