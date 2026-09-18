//! Mirrors `bend/scan_matches_sequential/main.bend`'s `parallel_scan` and
//! `sequential_scan`. See `../docs/bend-proof.md` for the line-by-line
//! correspondence and the proof that they always agree.
//!
//! Bend's `parallel_scan`/`sequential_scan` operate on `Tree` (a full
//! binary tree of Nat leaves), because Bend's termination checker wants
//! structural recursion and its fork-join primitive wants an actual data
//! split, not index arithmetic on a flat array. Rust has neither
//! restriction, so these operate directly on `&[u32]` / `Vec<u32>` --
//! `xs.split_at(mid)` here is what `match t: case Node{l, r}:` is in the
//! Bend version; `Leaf{x}` there is the length-1 slice here.

/// The exclusive prefix sum of `xs`, computed by recursive doubling: split
/// into two halves, scan each half independently (the right half as if it
/// were its own list starting at carry 0 -- the actual parallel step, two
/// independent recursive calls with no data dependency between them), then
/// add the ambient carry-in *and* the left half's total onto every element
/// of the (already-scanned) right half. Mirrors `parallel_scan` in
/// `main.bend`.
pub fn parallel_scan(xs: &[u32]) -> Vec<u32> {
    parallel_scan_go(xs, 0)
}

fn parallel_scan_go(xs: &[u32], c: u32) -> Vec<u32> {
    match xs.len() {
        0 => Vec::new(),
        1 => vec![c],
        n => {
            let mid = n / 2;
            let (left, right) = xs.split_at(mid);
            let sl = parallel_scan_go(left, c);
            let sr0 = parallel_scan_go(right, 0);
            let total_l: u32 = left.iter().sum();
            let offset = c + total_l;
            let sr = sr0.into_iter().map(|v| v + offset);
            sl.into_iter().chain(sr).collect()
        }
    }
}

/// The exclusive prefix sum of `xs`, computed the obvious way: walk the
/// elements left to right, threading a running carry, emitting the carry
/// *before* adding the current element. Structurally different from
/// `parallel_scan` -- no split, no fork, no patch-up step -- not just a
/// sequential reordering of the same calls (see `docs/bend-proof.md` for
/// why that distinction is what makes `parallel_scan == sequential_scan`
/// a real theorem rather than a restatement). Mirrors `sequential_scan`
/// in `main.bend`.
pub fn sequential_scan(xs: &[u32]) -> Vec<u32> {
    let mut carry: u32 = 0;
    let mut out = Vec::with_capacity(xs.len());
    for &x in xs {
        out.push(carry);
        carry += x;
    }
    out
}

/// The buggy first attempt kept in `bend/scan_matches_sequential/buggy_first_attempt.bend`:
/// offsets the right half by the RIGHT half's own total instead of the
/// LEFT half's. Kept here, unused by `parallel_scan`, purely so the Rust
/// tests can demonstrate the same disagreement Bend caught (see
/// `tests/scan_matches_sequential.rs`).
pub fn parallel_scan_buggy(xs: &[u32]) -> Vec<u32> {
    parallel_scan_buggy_go(xs, 0)
}

fn parallel_scan_buggy_go(xs: &[u32], c: u32) -> Vec<u32> {
    match xs.len() {
        0 => Vec::new(),
        1 => vec![c],
        n => {
            let mid = n / 2;
            let (left, right) = xs.split_at(mid);
            let sl = parallel_scan_buggy_go(left, c);
            let sr0 = parallel_scan_buggy_go(right, 0);
            let total_r: u32 = right.iter().sum(); // BUG: should be `left`
            let offset = c + total_r;
            let sr = sr0.into_iter().map(|v| v + offset);
            sl.into_iter().chain(sr).collect()
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn matches_the_bend_demo() {
        // bend/scan_matches_sequential/main.bend's own main(): the flattened
        // result of parallel_scan on [10,20,30,40,50,60,70,80] is
        // 0,10,30,60,100,150,210,280.
        let xs = [10, 20, 30, 40, 50, 60, 70, 80];
        assert_eq!(
            parallel_scan(&xs),
            vec![0, 10, 30, 60, 100, 150, 210, 280]
        );
        assert_eq!(parallel_scan(&xs), sequential_scan(&xs));
    }

    #[test]
    fn buggy_version_disagrees_even_on_two_elements() {
        // bend/scan_matches_sequential/buggy_first_attempt_disproved.bend's
        // own counterexample: [10, 20] should scan to [0, 10]; the buggy
        // version (offset by the RIGHT half's total, not the left's)
        // produces [0, 20] instead.
        let xs = [10, 20];
        assert_eq!(sequential_scan(&xs), vec![0, 10]);
        assert_eq!(parallel_scan_buggy(&xs), vec![0, 20]);
        assert_ne!(parallel_scan_buggy(&xs), sequential_scan(&xs));
    }
}
