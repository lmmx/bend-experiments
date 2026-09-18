# move_preserves_resolvability: the law. Human-authored (by convention --
# see ../../../AGENTS.md), PROOF.bend discharges it.
#
# Precondition, precisely:
#   h_dst_wf   -- dst is well-formed before the move: every def already in
#                 dst has every name it needs resolvable in dst.
#   h_moved    -- the group of defs being MOVED is self-sufficient: every
#                 name any of them needs comes from src's imports, or from
#                 another def in the SAME moving group. This is the task's
#                 stated scope (mvdef's README: "move/copy function/classes
#                 and their associated import statements" -- imports only,
#                 plus whatever's moving together). See
#                 ../../docs/mvdef-scope-note.md.
#   h_remaining -- the group of defs LEFT BEHIND is ALSO self-sufficient:
#                 every name any of them needs comes from src's imports, or
#                 from another def that is ALSO staying behind. This rules
#                 out a remaining def secretly depending on a def that's
#                 moving away -- the mirror-image of h_moved, and the
#                 closure condition tied directly to
#                 ../../docs/mvdef-scope-note.md's intra-module-dependency
#                 finding: mvdef's real Agenda machinery has no equivalent
#                 check, so if this precondition is violated in practice,
#                 nothing warns you (see that doc's empirical case).
#
# Conclusion: after move_defs, every def in the resulting dst (the moved
# ones and whatever was already there) still has every name it needs
# resolvable in dst, AND every def remaining in src still has every name
# it needs resolvable in src.

import Base
import ./main.bend as S

law move_preserves_resolvability:
  for +src: S.Module
  for +dst: S.Module
  for +move_names: List<&2, Nat>
  for h_dst_wf: {True{} == S.all_defs_ok(dst, S.defs_of(dst)) : Bool}
  for h_moved: {True{} == S.self_sufficient(S.moved_defs(S.defs_of(src), move_names), S.imports_of(src)) : Bool}
  for h_remaining: {True{} == S.self_sufficient(S.remaining_defs(S.defs_of(src), move_names), S.imports_of(src)) : Bool}
  {True{} == S.move_ok(src, dst, move_names) : Bool}
