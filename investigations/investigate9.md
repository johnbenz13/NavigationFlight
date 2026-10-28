# Investigation: issue #9 design miss and usage consumption

Date: 2026-10-28

Scope: GitHub issue #9 and PR #27, repository authority and workflow, commit/source history, and the locally retained Codex rollout for the implementation session. This draft distinguishes facts from inferences and does not estimate unrecorded or billable token cost.

## Executive finding

The implementation did retrieve the authoritative Figma frames before editing, but it did not convert frame `81:583` into the repository-required state trace and measurable visual contract. The first implementation preserved the existing generic stacked disclosure UI instead of implementing the frame's distinct cross-check composition. The agent then reported the state as structurally matched before it had a post-refinement simulator capture. The repository's visual workflow was therefore present and consulted, but its fail-closed design-trace and rendered-comparison gates were not actually followed.

The usage spike is directly evidenced. In one 33-minute 50-second rollout, the recorded primary five-hour rate-limit utilization rose from 20% to 94%, and the secondary weekly utilization rose from 3% to 15%. The rollout recorded 21,200,454 cumulative tokens, of which 20,888,832 were cached input. Repeated polling and a long, continually replayed context were major contributors: 51 `wait` calls account for 5,393,254 recorded tokens and 14 `wait_agent` calls account for another 1,648,105. These are telemetry counts, not a claim about billing or the provider's exact rate-limit formula.

## Authoritative contract

### Verified facts

- Issue #9 explicitly assigned ownership of “Check availability, disclosure, labels, and signed comparison presentation,” linked the unavailable/committed frame `81:231`, revealed frame `81:583`, and unavailable exception `95:438`, and required human visual approval. Source: [issue #9](https://github.com/johnbenz13/NavigationFlight/issues/9), body under **Design evidence**.
- The product spec lists frames `81:231` and `81:583` as the approved Iteration 04 ETA states and defines Reference ETA as an explicitly requested cross-check that does not replace the pilot's operational Revised ETA. Source: `docs/features/FLYING-A-LEG_SPEC.md`, especially lines 7, 20–33, 82–88, and the ETA callout/revision behavior section.
- The technical design requires explicit Planned, Revised, Reference, and Actual labels, signed differences, meaningful presentation states rather than Boolean combinations, and view-only rendering of values calculated elsewhere. Source: `docs/technical/FLYING-A-LEG-TECHNICAL-DESIGN.md`, lines 405–429 and 517–530.
- The ticket workflow requires a trace for every affected state, including acceptance criterion, spec authority, exact Figma node, deterministic reproduction path, geometry, visual treatment, and provenance of every value. It also requires a current-simulator comparison before editing and a fresh side-by-side inspection after implementation. Missing or ambiguous evidence must be recorded as unverified. Source: `docs/agents/ticket-workflow.md`, sections 4 and 6.

## What happened

### Verified chronology

1. At 15:12:31Z, the user asked the agent to begin issue #9. The agent completed dependency/branch preflight and announced use of the mandatory Figma skills. Source: local rollout `/Users/john/Library/Developer/Xcode/CodingAssistant/codex/sessions/2026/10/28/rollout-2026-10-28T17-12-28-01a18311-de01-7980-9eab-4696ba68fc18.jsonl`; user/agent events at 15:12:31Z–15:13:20Z.
2. At 15:13:40Z, it fetched design context for all three issue-linked nodes, including `81:583`. At 15:13:51Z, it accurately summarized that the revealed state should show Planned, Revised as operational, Reference ETA, and signed difference. Source: same rollout, the `get_design_context` call at 15:13:40Z and agent message at 15:13:51Z.
3. The first implementation retained the pre-existing generic revealed UI: `TIMING REFERENCE`, `DIFFERENCE`, “If the observed pace continues,” and one Hide Check button nested into the normal revised card. The final commit diff shows this exact code being removed and replaced by `TimingTargetCrossCheckView`. Source: `git diff 5dc7cda..a4330b3 -- NavigationFlight/Map/OfflineAviationMapView.swift`, hunk beginning near old line 1799.
4. At 15:21:38Z, before direct screenshot inspection, the agent said both states had been reproduced “without crashes, overlap, or truncation.” At 15:21:40Z it opened the screenshots. Only after that inspection did it add the dedicated cross-check view at 15:21:56Z. Source: rollout agent messages/tool calls at those timestamps.
5. The 15:22:47Z GitHub acceptance comment explicitly records that the revealed screenshot was “before final visual refinement,” lists the missing side-by-side Planned/Revised hierarchy, signed green comparison treatment, and both Hide Check/Edit Revision actions, and says the refined state still needed a fresh simulator capture. Source: [issue comment 6473032891](https://github.com/johnbenz13/NavigationFlight/issues/9#issuecomment-6473032891).
6. Despite that known gap, the 15:22:58Z handoff said the presentations were updated “to match approved Figma structure.” No refreshed post-refinement screenshot existed at that point. Source: rollout agent message at 15:22:58Z and the preceding issue comment.
7. At 15:32:11Z, the user supplied screenshots showing two defects: closing/reopening restored the wrong expanded state, and the revealed Check design did not match Figma `81:583`. Source: rollout user message at 15:32:11Z.
8. The follow-up diagnosis found that dismissal did not clear visibility, the narrow nested rows wrapped `REVISED · OPERATIONAL`, and the kicker used a map waypoint name rather than the route identifier. The agent reloaded `81:583`, implemented a dedicated cross-check view, and captured fresh simulator evidence. Source: rollout messages 15:32:26Z–15:39:29Z; [issue comment 6473429353](https://github.com/johnbenz13/NavigationFlight/issues/9#issuecomment-6473429353).
9. Commit `a4330b337f902396398362a893882bac4fef6c46` contains both the original behavior work and the corrective UI work in one commit. PR #27 remains open and states human product/visual acceptance is pending. Sources: `git show a4330b3`; [PR #27](https://github.com/johnbenz13/NavigationFlight/pull/27).

## Root cause and design-trace failure

### Verified facts

- The frame was not unavailable: it was retrieved before implementation.
- The issue and specs were not ambiguous about the required values and roles.
- No state-by-state trace or visual-contract artifact appears in the rollout, issue, branch, or PR. The agent announced a high-level summary, then moved directly into source exploration and editing.
- The initial simulator pass discovered the mismatch only after code and tests were substantially complete.
- The refined UI was not recaptured before the initial handoff; the agent itself documented that omission.

### Best-supported inference

The primary root cause was a translation/control failure, not an authority-discovery failure. The agent understood the semantic requirements but treated the existing callout as the default visual structure and incrementally inserted the new values. Without recording geometry, hierarchy, actions, identifiers, and deterministic states from `81:583`, it optimized for behavioral correctness and generic content presence rather than frame fidelity. The premature “match” wording then weakened the fail-closed gate and allowed the work to be handed off with an acknowledged missing capture.

A secondary root cause was incomplete state-transition tracing. The workflow required every conditional branch touched by the transition, but the implementation focused on show/hide/history and did not initially trace the dismiss → reopen branch. That is why disclosure visibility survived callout dismissal and reopened the expanded design.

### Unknowns

- The retained evidence does not prove whether the Figma image was visually studied in sufficient detail before coding; it proves only that design context was fetched and that its broad semantics were summarized.
- The initial post-fetch internal reasoning is not fully observable, so no claim can be made about intent or attention.
- The user-provided screenshots are referenced in rollout metadata but are not durable repository artifacts, so this investigation relies on the user's written report and the agent's subsequent diagnosis rather than re-evaluating those attachments.

## Usage and context analysis

### Verified telemetry

The local rollout contains 812 JSONL records and is 20,225,023 bytes. It began at 15:12:28.861Z and completed at 15:46:18.530Z.

| Recorded measure | First event | Final event | Change |
| --- | ---: | ---: | ---: |
| Primary 300-minute limit used | 20% | 94% | +74 percentage points |
| Secondary 10,080-minute limit used | 3% | 15% | +12 percentage points |
| Cumulative tokens | 20,445 | 21,200,454 | +21,180,009 |
| Cumulative input tokens | 20,290 | 21,169,807 | +21,149,517 |
| Cumulative cached input tokens | 11,264 | 20,888,832 | +20,877,568 |
| Cumulative output tokens | 155 | 30,647 | +30,492 |
| Cumulative reasoning output tokens | 48 | 5,308 | +5,260 |

Source: rollout `token_count` events at 15:12:36.794Z and 15:46:18.527Z. These cumulative counters are the only defensible token figures available; they must not be relabeled as billable tokens.

Call attribution by the immediately following telemetry event:

| Call type | Calls | Recorded tokens |
| --- | ---: | ---: |
| `exec` | 102 | 12,606,605 |
| `wait` | 51 | 5,393,254 |
| `wait_agent` | 14 | 1,648,105 |
| Other collaboration calls | 8 | 1,178,356 |

The rollout compacted context once at 15:33:35.950Z. Before compaction, repeated one-second polls of two full test runs repeatedly replayed a context of roughly 68–77k input tokens per call; after compaction, subsequent calls still carried a growing context. The largest avoidable pattern is visible directly: 16 polls for the first all-tests run and 35 polls for the second. The agent also spawned a device-verification subagent, then used 14 mailbox waits plus interrupt/follow-up coordination.

### Best-supported inference

The near-exhaustion was caused less by generated code than by orchestration overhead against a large context: high-frequency polling, full-suite runs twice, agent coordination, repeated long tool-output ingestion, and then rework after the design miss. Cached input dominated the telemetry, consistent with the same long prefix being replayed on each turn. The corrective phase was necessary once the defect was reported, but the earlier visual-contract gate would likely have avoided much of that phase.

### Unknowns and limits

- Telemetry does not expose the provider's exact rate-limit weighting, so the +74-point primary-limit movement cannot be converted reliably into a token price or billable amount.
- Some rate-limit utilization may include other concurrent sessions in the same account/window; the monotonically rising values align with this rollout but cannot prove exclusive causation.
- No exact counterfactual establishes how much usage a correct first pass would have consumed.

## Workflow assessment

The workflow itself correctly addresses this failure mode: it requires direct design retrieval, a per-state trace, pre-edit simulator comparison, a detailed visual contract, deterministic reproduction, fresh screenshots, direct side-by-side inspection, and “unverified” when either artifact is missing. The problem was compliance, not absence of guidance.

However, enforcement remains largely narrative. The issue comment and PR template accepted prose without a machine-checkable trace table or durable screenshot references. The first acceptance comment correctly disclosed the missing refreshed capture, but nothing prevented a contradictory “match” statement in the handoff. The workflow itself acknowledges that current repository checks cannot prove the contract was derived or inspected (`docs/agents/ticket-workflow.md`, end of section 6).

## Targeted recommendations

1. Enforce the workflow's existing pre-edit state trace in implementation notes: criterion, state/branch, spec invariant, authoritative Figma reference, and reproduction path. Carry that trace into the acceptance comment without creating another product source of truth, and block editing when a required row is missing or ambiguous.
2. Require the visual contract to enumerate hierarchy and actions, not only displayed data. For `81:583`, that would have made the side-by-side columns, operational label, reference basis, green signed comparison, two actions, safety note, and route identifier explicit before coding.
3. Add transition rows, not only static-state rows. For this ticket: committed → Check revealed; revealed → close; closed → reopen; reopened → Check revealed again; unavailable Check → no mutation.
4. Forbid “matched” or “matches Figma” unless the cited screenshot was captured after the final relevant UI mutation. A structured evidence check can require an authoritative reference, a durable screenshot identifier, and an explicit result; visual correctness still requires human approval.
5. Preserve simulator screenshots in a durable issue/PR artifact location. Temporary `/var/folders/...` paths are not independently reviewable later.
6. Poll long-running tools at coarse intervals (for example, 10–30 seconds) rather than one second. The 51 `wait` calls are a concrete high-cost pattern.
7. Run the smallest focused test set during iteration; run the full suite once after the visual/state contract is satisfied. This session ran complete suites before and after user-reported rework.
8. Keep device verification in the implementing context when the workflow makes the implementer responsible for direct comparison, or delegate once with a complete fixed contract and a single completion notification. Avoid repeated mailbox polling and interrupt/restart cycles.
9. Bound tool output and avoid re-reading long skills/workflows in later turns when their operative checklist has already been recorded locally in compact form.
10. Add a PR evidence check that rejects contradictory claims: if any comment says a state needs a fresh capture or human approval, the PR must list that state as unverified until a newer cited artifact and approval exist.

## Bottom line

Issue #9 did not fail because the authoritative design was missing. It failed because retrieved design authority was reduced to semantic content rather than converted into an enforceable visual and transition contract. The same missing gate produced rework, and the session's high-frequency polling plus large replayed context made that rework unusually expensive in recorded usage. The final commit contains the corrective structure, but PR #27 appropriately still leaves human visual acceptance pending.
