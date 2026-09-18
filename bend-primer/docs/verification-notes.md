# Verification notes: process, and one caught hallucination

This repo was built by parallel subagents: Haiku instances doing web research, Sonnet instances
writing code, one coordinating session doing both direct primary-source reading and cross-checks.
This file is the paper trail for the second part, because "we used an LLM to research a tool for
catching LLM mistakes, without checking its work" would be a bad look and, more importantly, bad
practice.

## What happened

A Haiku subagent was asked to research Bend 2 via web search (its own tool access; it cannot read
this repo's local clone). Its final report, verbatim in part:

> **Installation:** `curl -fsSL https://bend-lang.com/install.sh | sh` or `cargo install bend-lang`.
> Requires Rust nightly, LLVM 19+, clang 14+, CUDA 12.x (optional for GPU). Linux/macOS only.
>
> **Syntax:** Two dialects (imperative Python-like "Imp" or functional "Fun"). Example law: `law
> winning_impossible: for moves {...}`.

The curl install command is correct — it matches the repo's own `README.md` exactly, and we ran it
successfully in this session. Everything else in that paragraph is fabricated:

- `cargo install bend-lang`: there is no such crate as the install path; the actual installer
  writes a small shell launcher to `~/.bend/bin/bend` that self-updates from `bend-lang.com`, not
  a Rust binary shipped via crates.io.
- "Requires Rust nightly, LLVM 19+": Bend's own docs state clang 14+ (19+ specifically for
  programs using `!`) and CUDA 12/Metal as the *GPU* compilation requirements. There is no
  Rust-nightly or LLVM-19 requirement for Bend itself (that requirement, as it happens, *does*
  apply to a completely different project — NVIDIA's `cuda-oxide`, researched separately for
  `../mistralrs-cuda-notes/`, which really does pin a nightly Rust toolchain. This looks like
  cross-contamination between the two research tasks somewhere in the model's synthesis, not a
  citation to a real source about Bend.)
- "Two dialects (imperative Python-like 'Imp' or functional 'Fun')": no such distinction exists
  anywhere in `GUIDE.md`, `README.md`, or `AGENTS.md`. Bend has one syntax.

None of this was used. The actual primer content in this directory was written from direct reads
of the cloned `bendlang/bend` repository (`GUIDE.md` in full, `README.md` in full, `AGENTS.md`,
relevant slices of `bend2/base.bend`, and four demo `LAWS.bend`/`PROOF.bend`/`main.bend` files),
and every syntax claim was additionally checked by actually running `bend` against either a
shipped demo or a new proof written for this session.

## What was corroborated, not just asserted

The same subagent's other claims — the `LAWS.bend`/`PROOF.bend` split, "Bend can only verify Bend
code, not Rust/Python/etc.", the general shape of `law`/`for`/`exs` syntax — matched the primary
source closely enough to be usable as a cross-check, and are consistent with what's written
elsewhere in this primer. The install command, HVM3-as-interaction-nets description, and general
"proof language for constraining AI codegen" framing were all independently confirmed against the
repo's own `README.md`.

Two other web-research subagents in this session (on the CUDA-Rust ecosystem and on the Pumpkin
solver) were spot-checked the same way — specific claims re-fetched directly (NVIDIA's blog post,
Pumpkin's actual `README.md` via `raw.githubusercontent.com`, `lmmx/hello-pumpkin`'s actual
`main.rs` files) rather than trusted outright — and held up well; see
`../mistralrs-cuda-notes/docs/cuda-rust-ecosystem.md` and `../pumpkin-bridge/README.md` for those
citations. The PrismML research (a llama.cpp fork's 1-bit quantization format) was corroborated on
the format *names* (`Q1_0_G128`, `PTQ1_0`, the "1.75 bpw, lossless vs PQ2_0" framing all matched
independent search results, including a real upstream PR title) but the precise byte-layout
formulas it reported were not traced to an actual source file we read ourselves — see
`../quant-pack-proofs/README.md` for exactly where that project draws the line between "confirmed
format name and bit-width" and "illustrative packing scheme in that style."

## The general rule this session followed

Treat a research subagent's report as a lead, not a citation. Before anything from one goes into a
doc as a factual claim (a version number, an API signature, a file layout, a named format), either
re-fetch the primary source directly, or find independent corroboration from a second source, or
label it explicitly as unverified. Specific numbers and specific proper nouns (crate names,
function signatures, byte counts) are exactly where small models confabulate plausibly, and exactly
where a reader has no way to tell confabulation from fact just by reading the prose — so the
burden was on us to check before writing it down, not on the reader to doubt it.
