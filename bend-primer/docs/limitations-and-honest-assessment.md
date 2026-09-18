# Limitations, verbatim, plus what we could and couldn't verify from outside

## Verbatim from `bendlang/bend`'s own `README.md`

Reproduced in full because a curated subset would understate it, and the point of this primer is
not to undersell the tool it's about to depend on:

```
- Bend 2 is a new language. Bend 1 programs and HVM do not carry over.
- Everything is annotated and nothing is inferred, so code is verbose.
- No type classes, no traits, and no macros beyond compile-time templates.
- Bend has no tactics or proof search; proving theorems takes extra effort.
- Values are affine: closures and arrays cannot be shared.
- Recursion must be terminating. (Use @unsafe to disable this checker.)
- Computed matches (match f(x)) aren't supported. Must split it manually.
- There is no syntax for if-then-else: a branch is a match on True and False.
- Numbers are Nat, U32 and F32 only: no U64, I64 or F64 (Metal has no f64).
- F32 is axiomatic: nothing about floating point can be proven.
- Strings are linked lists of characters, so text processing is slow.
- Base is small: expect to write helpers other languages ship built in.
- Effects are few: print, env, time, sleep, spawn, channels, files, TCP, UDP.
- No TLS, HTTP library, JSON or regex for now (but you can add them as foreigns).
- Targets are C, Metal, CUDA and JavaScript; Lua, Luau and Python are planned.
- The JavaScript target runs on one core and has no graphics or audio.
- Parallelism requires balanced calls. Flexible parallelism will be added later.
- Sharing arrays with atomics across threads is experimental and needs @unsafe.
- One GPU per program, one event loop, and no multi-machine execution yet.
- One C file per program: no separate compilation, no incremental builds.
- Compiling to native is slow (clang/CUDA/Metal). For fast development, use JS.
- The compiler is young and has blind spots (unusually slow programs). Report.
- We don't have as many benchmarks as we'd like yet, especially for the checker.
- The compiler (not kernel) is 99% AI-written and has not been fully audited yet.
- The Lean formalization and bend.ts mismatch. Early consistency bugs may occur.
- A binary needs clang 14+; ! needs 19+, Metal or CUDA 12.
- No Windows (WSL works); on Linux, Window and Audio need X11 and ALSA headers.
- The hub has no names, versions, accounts or search yet. Packages are hashes.
- Error messages are terse; no debugger, profiler, formatter, REPL or LSP.
- No editor support, no test framework and no documentation beyond the guide.
```

Two of these are worth flagging as specifically relevant to how this repo uses Bend:

- **"F32 is axiomatic: nothing about floating point can be proven."** This matters directly for
  `../quant-pack-proofs/`: quantization scale factors are floats. The laws written there are
  necessarily about the *integer* packing/unpacking arithmetic (bit layout, sign/magnitude codes),
  not about floating-point rounding error in the scale — that boundary is explicit in that
  project's docs, not glossed over.
- **"The compiler (not kernel) is 99% AI-written and has not been fully audited yet."** This is the
  compiler that checks the proofs everything else in this repo leans on. It's a real, stated
  caveat from the maintainers themselves, not something we're adding — reproduced here because a
  primer about "trust the proof, not the code" should not itself ask for blind trust in the prover.

## What we verified directly vs. took on trust

| Claim | Status |
|---|---|
| `bend 2.0.5` installs via the documented curl script and runs | **Verified** — installed and used throughout this session |
| `bend PROOF.bend` on 3 shipped demos + 1 new proof all print `All terms check.` | **Verified** — timed, ~0.19–0.20s each |
| Compiles to CUDA on Linux (`/usr/local/cuda`, CUDA 12) | **Not verified** — no `nvcc`, no GPU in this sandbox |
| Checker is "orders of magnitude" faster than Lean/Rocq/Isabelle/Agda | **Not independently verified** — this is the README's own benchmark claim; we did not run a comparative benchmark |
| The LAWS.bend / PROOF.bend convention is compiler-enforced | **Correction**: it is not. `bend` only requires that named laws (`law x:`) be discharged by a `def` of the matching name (`Laws.x`) *somewhere reachable*, and it does not care whether that `def` lives in a file literally named `PROOF.bend` or whether a file is literally named `LAWS.bend`. The two-file split is a **naming convention** the Bend team recommends (`GUIDE.md`), not a distinct language feature — worth knowing so nobody goes looking for a `--laws-file` flag that doesn't exist. |

See [`verification-notes.md`](verification-notes.md) for one specific case where a research
subagent's report contained fabricated detail, and how it was caught before it reached this file.
