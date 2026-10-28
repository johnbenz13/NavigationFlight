# NavigationFlight issue #8 token audit

## Executive finding

Historical telemetry is available for the Xcode Codex conversation. The implementation conversation and its three subagent rollouts were preserved as JSONL records under Xcode’s CodingAssistant storage.

The strongest findings are:

- Issue #8 used approximately **28.15 million recorded input tokens**, of which approximately **27.62 million were cached input tokens**. It produced about **39,005 output tokens**, including about **7,240 reasoning tokens**.
- These are model-processing tokens, not 28 million tokens of unique source material. Context was repeatedly resent on model calls; approximately 98% of recorded input was cached.
- The main implementation phase dominated consumption: **18.89 million parent-thread input tokens**, before adding the first simulator subagent’s approximately **2.45 million input tokens**.
- Context grew from roughly **20,274 input tokens on the first call** to **226,191** before compaction, against a recorded 258,400-token context window.
- The regression was not caused by a missing requirement. The committed state was present in the specification and its Figma node was linked there. The full specification was retrieved, but the specific committed-state Figma node was not retrieved until after the user reported the regression.
- Validation exercised the committed flow, but incorrectly declared the legacy committed UI consistent with the “Figma state family.” That was a substantive validation miss.
- Nested agents were expensive because their rollouts inherited large parent histories. Delegation did not isolate context.

No repository or session data was modified.

---

## 1. Telemetry availability and limitations

### Storage found

The relevant Xcode-specific store is:

`/Users/john/Library/Developer/Xcode/CodingAssistant/codex/`

It contains:

- `sessions/YYYY/MM/DD/rollout-*.jsonl`
- `state_5.sqlite`
- `logs_2.sqlite`
- `goals_1.sqlite`
- `memories_1.sqlite`

Issue #8’s parent record is:

`/Users/john/Library/Developer/Xcode/CodingAssistant/codex/sessions/2026/10/28/rollout-2026-10-28T00-35-22-01a17f80-ffa1-7522-989c-6e155e274d51.jsonl`

Three related subagent rollouts identify that parent through `parent_thread_id`.

There is also a separate `~/.codex` store. I did not assume it was Xcode telemetry. Issue #8’s implementation prompt and activity were found in the Xcode CodingAssistant store. One metadata caveat is that the rollout’s recorded source is `vscode`, despite residing in Xcode’s CodingAssistant directory.

### What is recorded

| Item | Availability | Classification |
| --- | --- | --- |
| Input tokens | Yes, per model call | Measured |
| Cached input tokens | Yes | Measured |
| Cache-write tokens | Yes; zero here | Measured |
| Output tokens | Yes | Measured |
| Reasoning output tokens | Yes | Measured; appears to be a subset of output |
| Model | Yes: `gpt-5.6-sol` | Measured |
| Context window | Yes: 258,400 | Measured |
| Context growth | Available through each call’s input count | Derived from measured events |
| Tool calls and results | Yes, including arguments and returned content | Measured |
| Subagent parent/depth/path | Yes | Measured |
| Context compaction | Yes | Measured |
| Monetary cost | No | Unavailable |
| Exact billing interpretation | No | Unavailable |
| Server-side cache policy or lifetime | No | Unavailable |

### Important de-duplication caveat

Subagent rollout files contain a copied parent history whose timestamps are rewritten to the subagent’s spawn time. Naïvely summing every token event across all four files substantially double-counts usage.

For the subagents, I excluded the copied spawn-time prefix and counted token events beginning after the copied block. Therefore:

- Parent-thread figures are measured directly.
- Subagent-exclusive and combined figures are derived from measured events.
- They should be treated as strong telemetry-derived measurements, not billing totals.

The telemetry’s `total_tokens` fields also contain a small component inconsistency around subagent activity. I therefore use the separately recorded input/output components rather than claiming an exact invoice-equivalent total.

### Context growth

- Initial model call: **20,274 input**, 11,264 cached.
- Maximum observed before compaction: **226,191 input**, 226,048 cached.
- Recorded context window: **258,400**.
- A compaction occurred at `2026-10-28T06:00:13Z`, recorded both as a `compacted` record and a `context_compacted` event.
- First call after compaction: **23,602 input**, 11,264 cached.
- No model switch was recorded.

---

## 2. Quantified issue #8 usage

### Parent conversation by phase

The boundaries below are based on user-message timestamps and recorded token events.

| Phase | Input | Cached input | Output | Reasoning |
| --- | ---: | ---: | ---: | ---: |
| Initial issue/workflow preflight | 172,357 | 148,992 | 1,349 | 328 |
| Branch-creation exchange | 105,478 | 104,704 | 333 | 19 |
| Implementation and initial validation | 18,885,021 | 18,575,104 | 20,778 | 3,857 |
| Regression diagnosis and correction | 4,842,675 | 4,804,480 | 7,041 | 1,761 |
| Resumed final checks/handoff | 104,050 | 88,064 | 532 | 136 |

The later qualitative token audit request is excluded from those numbers.

### Subagent-exclusive usage

| Subagent | Purpose | Input | Cached input | Output | Reasoning |
| --- | --- | ---: | ---: | ---: | ---: |
| `/root/simulator_validation` | Initial simulator verification | 2,445,503 | 2,369,792 | 5,036 | 634 |
| `/root/verify_committed_eta_fix` | Corrective validation coordinator | 492,753 | 473,216 | 1,114 | 143 |
| `/root/verify_committed_eta_fix/interact_eta_ui` | Nested post-fix simulator interaction | 1,097,895 | 1,055,872 | 2,822 | 362 |

### Combined derived totals

| Metric | Recorded amount |
| --- | ---: |
| Input tokens | Approximately 28,145,732 |
| Cached input tokens | Approximately 27,620,224 |
| Input not reported as cached | Approximately 525,508 |
| Output tokens | Approximately 39,005 |
| Reasoning output tokens | Approximately 7,240 |

Cached input is a subset of input, not additional input. The high cached proportion means repeated context was being processed cheaply relative to uncached context, but it was still recorded consumption and still contributed to context-window pressure.

---

## 3. Issue #8 execution timeline

### Initial retrieval and preflight

At 22:35 UTC the user asked: “Work on next task issue #8.”

The agent:

- Searched for GitHub/Xcode tooling.
- Attempted to install the GitHub plugin.
- Read the ticket workflow and issue-tracker documentation.
- Retrieved issue #8 with `gh`.
- Retrieved blockers #3 and #6, relevant pull requests, remote Git state, and open PR state.
- Revisited GitHub several times during readiness and acceptance reporting.

This phase was not a major token consumer by itself, though a tooling-discovery response was about 18,000 characters and the combined workflow/issue response about 27,000 characters.

### Product, design, and technical retrieval

After branch creation, the agent fetched in parallel:

- The complete `FLYING-A-LEG_SPEC.md`.
- The complete broad technical design.
- The separate progression-policy specification.
- The product-spec/Figma workflow.
- Several complete skill files and six SwiftUI reference documents.
- Five issue-linked Figma nodes:
  - `81:114`
  - `81:462`
  - `113:7`
  - `113:117`
  - `113:227`

Notably, it did **not** retrieve committed-state node `81:231` at this point, because that node was linked by the product specification but omitted from issue #8’s five-item “Design evidence” list.

Several responses reached approximately 40,000 characters, including:

- Skill/reference bundle.
- Five-node Figma retrieval.
- Broad Swift ETA grep.
- Seven-file source read.
- Additional source reads.
- Test grep.

This is direct evidence of unnecessarily broad retrieval, although the exact token contribution of each tool response is not separately metered.

### Code exploration

The agent:

- Ran a repository-wide Swift grep for `ETA|eta|pilotETA|revisedETA`, capped at 250 results.
- Read seven implementation files in parallel.
- Re-read large portions of `CockpitPresentationAdapter.swift`, `CockpitView.swift`, `AviationMapView.swift`, and `OfflineAviationMapView.swift`.
- Ran seven additional symbol searches.
- Read the ETA test file and later searched it again.

Repeated reads included:

- `OfflineAviationMapView.swift`: four explicit reads.
- `CockpitView.swift`: two explicit reads, in addition to earlier full-file/batched reads.

Understanding the code was not uniquely dominant; the cost arose from many model calls made after the context had grown beyond 100,000–220,000 tokens. Each later inspection or validation response caused another large cached context submission.

### Implementation

The agent modified eight files and added deterministic coverage for:

- Exact and rounded timer floors.
- Decrement clamping.
- Stale-draft rejection.
- Append-only commit history.
- Cancellation.
- Presentation/state wiring.

The first implementation changed the focused editor and domain behavior but retained the pre-existing committed branch in `TimingTargetCalloutContent`:

- `ETA`
- `PLAN`
- `Set`
- `Edit ETA`

That stale branch was the reported visual regression.

### Initial testing and simulator verification

The parent ran:

- File-local diagnostics in multiple batches.
- A build-for-testing.
- The full test plan.
- A second build after subsequent UI changes.
- Selected UI tests.
- `git diff --check` more than once.
- Test discovery.

The simulator subagent then:

- Loaded the fixture.
- Opened the future-target editor.
- Changed `06:20` to `06:25`.
- Committed.
- Observed the legacy summary showing `ETA 06:25`, `PLAN 06:22`, and `Set`.
- Reopened and canceled.
- Reported that the visual states were “consistent with the referenced Figma state family.”

That report is crucial evidence: the regression was visible during validation, but was accepted.

### Acceptance review

The agent posted an issue comment mapping acceptance criteria to test and simulator evidence. It correctly left final visual approval unchecked, but also claimed:

- Planned, draft, and committed values were visually distinct.
- Simulator interaction verified each state without overlap.
- The rendered editor/committed/re-edit states were consistent with nodes `81:114`, `81:462`, and the state family.

The comment also admitted that exact timer fixture screenshots were not reproduced. More importantly, node `81:231` had never been retrieved, so the committed-state comparison was not against its actual authoritative frame.

### User-reported regression and correction

At 22:59 UTC the user supplied screenshots and the direct Figma link to node `81:231`.

The agent then:

- Loaded bug-diagnosis instructions.
- Retrieved node `81:231` for the first time.
- Read the relevant `OfflineAviationMapView.swift` section again.
- Identified the legacy branch.
- Replaced it with the committed-state design.
- Added a textual regression check rejecting the old `Edit ETA` and `timingRow("ETA", committed...)` renderer.
- Rebuilt and ran focused ETA tests.
- Added a further patch for the visible Check state.
- Rebuilt again and ran the full suite again.

The corrected implementation now has a dedicated committed state in [OfflineAviationMapView.swift](/Users/john/Code/Aviation/NavigationFlight/NavigationFlight/Map/OfflineAviationMapView.swift:1770), with explicit Revised and Planned hierarchy.

### Corrective simulator verification

A depth-one validation agent spawned a depth-two interaction agent. The post-fix simulator pass did not complete because the simulator tool hit a usage limit.

After compaction and user continuation, the parent explicitly reported:

- Build passed.
- 125/125 tests passed.
- `git diff --check` passed.
- Earlier simulator flow passed.
- The post-fix screenshot rerun was blocked and final visual approval remained outstanding.

That final distinction was accurate.

---

## 4. Repetition and inefficiency evidence

### Repeated or broad retrieval

Verified:

- Full product spec, broad technical design, progression spec, and workflow were retrieved together.
- The progression specification was not materially relevant to the ETA editor change.
- Multiple complete skill files and six SwiftUI reference files were loaded.
- Tool discovery returned large tool schemas multiple times.
- Five Figma nodes were fetched in one call, producing an approximately 40,000-character response.
- Node `81:231`, the one that would have prevented the regression, was fetched only after the user report.
- The source search initially covered all Swift files and generic `ETA` variants, then seven files were read, followed by narrower searches and repeated sections.

The issue itself was not repeatedly fetched throughout implementation. GitHub was revisited mainly for readiness, blockers, assignment, and acceptance reporting—separate workflow functions rather than repeated specification reading.

### Repeated validation

Recorded parent-call counts include:

- Four actual builds, plus one tool-discovery mention.
- Two full test-plan runs.
- Three focused or selected test runs.
- Six file-diagnostic invocations.
- Five `git diff --check` mentions/calls.
- One test-list retrieval.

Some repetition was justified:

- A new build was appropriate after material UI corrections.
- The full suite after the corrective patch was appropriate.
- Final `git diff --check` is mandated.

The weaker operations were:

- Running the complete suite before simulator validation and then again after the regression correction.
- A second pre-simulator build caused by continued editing after the first build.
- Repeated diagnostics on the same UI file.
- Simulator delegation with a full inherited context.

These save fewer tokens than retrieval/context improvements because build output itself was small. Their larger indirect cost was that each validation tool result caused another model turn with a very large accumulated context.

### Subagent overhead

Verified:

- Three subagent rollouts.
- One was nested at depth two.
- Their exclusive input consumption was approximately 4.04 million tokens.
- Their rollout files inherited the parent conversation, including the issue, documentation, design responses, code exploration, and prior reasoning.
- The nested agent did not complete the intended post-fix visual verification.

This demonstrates that “use a cheaper agent for validation” will not automatically save tokens if the agent receives a full-history fork. Context isolation is more important than agent role naming.

---

## 5. Root cause of the UI regression

The best-supported classification is:

- **Primary implementation cause: 3 — retrieved but overlooked during implementation.**
- **Manifestation: 4 — implemented incorrectly, by retaining the legacy committed branch.**
- **Control failure: 5 — not adequately covered by validation despite the acceptance requirement.**

It was not category 1 or 2.

### Why it was not missing

The product specification explicitly linked the committed design at [FLYING-A-LEG_SPEC.md](/Users/john/Code/Aviation/NavigationFlight/docs/features/FLYING-A-LEG_SPEC.md:84).

It also required:

- Explicit Revised-versus-Planned labeling at [line 228](/Users/john/Code/Aviation/NavigationFlight/docs/features/FLYING-A-LEG_SPEC.md:228).
- Distinct Planned, Revised, Reference, and Actual semantics throughout the ETA section.
- Committed history and operational selection at [line 226](/Users/john/Code/Aviation/NavigationFlight/docs/features/FLYING-A-LEG_SPEC.md:226).

The technical design similarly required meaningful callout presentation states and explicit labels at [FLYING-A-LEG-TECHNICAL-DESIGN.md](/Users/john/Code/Aviation/NavigationFlight/docs/technical/FLYING-A-LEG-TECHNICAL-DESIGN.md:401).

### Why “retrieved but overlooked” is verified

The implementation conversation retrieved the entire product specification before editing. Therefore the node link and committed-state requirements entered the conversation context.

However, the agent selected only the five Figma nodes copied into the issue body. It did not follow the specification’s committed-state link to node `81:231`.

### Why implementation was incorrect

The original implementation left the old committed renderer active. The corrective patch explicitly removed:

- `timingRow("ETA", committed...)`
- `timingRow("PLAN", ...)`
- the `Set` label
- the `Edit ETA` button

and introduced the dedicated committed component now visible at [OfflineAviationMapView.swift](/Users/john/Code/Aviation/NavigationFlight/NavigationFlight/Map/OfflineAviationMapView.swift:1770).

### Why validation also failed

Issue #8 required:

- Planned, draft, and committed states to be visually distinct.
- UI matching approved Iteration 08.
- Simulator evidence for every linked state.
- Human visual approval.

The simulator agent actually observed the legacy committed state and still marked the state family consistent. The initial acceptance comment overstated the committed-state comparison despite never retrieving node `81:231`.

The unchecked final human-approval criterion prevented formal completion, but it did not prevent the premature claim that the implementation was visually consistent.

---

## 6. Documentation and retrieval efficiency

### What the documentation already does well

The component documentation identifies state ownership and relevant files accurately:

- Map callouts render in `OfflineAviationMapView`, not the unused overlay, at [COCKPIT-VIEW.md](/Users/john/Code/Aviation/NavigationFlight/docs/technical/COCKPIT-VIEW.md:101).
- ETA callbacks are listed at [line 128](/Users/john/Code/Aviation/NavigationFlight/docs/technical/COCKPIT-VIEW.md:128).
- ETA actions and state command routing are mapped at [line 176](/Users/john/Code/Aviation/NavigationFlight/docs/technical/COCKPIT-VIEW.md:176).
- The source trace points directly to `OfflineAviationMapView.swift` at [line 204](/Users/john/Code/Aviation/NavigationFlight/docs/technical/COCKPIT-VIEW.md:204).
- The broad technical design also maps target states to `AviationMapPresentation.swift` and `OfflineAviationMapView.swift`.

Therefore the evidence does not support a generic conclusion that poor architecture documentation forced the broad exploration.

### Actual demonstrated gaps

1. The issue’s design-evidence list omitted the committed-state node, even though the acceptance criteria included committed-state distinction.

2. The relevant component document says where callouts live, but does not provide a compact state-to-renderer-to-Figma matrix. The agent still had to inspect a large private SwiftUI component to discover the legacy branch.

3. The issue agent fetched the broad feature technical design but did not fetch the narrower `COCKPIT-VIEW.md`, which contained the most useful ownership and source-trace information.

4. The broad technical design proposes an `ETAEditorView` composition concept, while the actual rendering remains a private component inside `OfflineAviationMapView.swift`. That mismatch makes the broad document less useful as a direct source locator.

These are specific issue #8 findings, not a recommendation to expand every document.

---

## 7. Ranked improvement opportunities

| Rank | Improvement | Problem evidence | Token-saving potential | Rework prevention | Effort | Correctness risk | Confidence |
| ---: | --- | --- | --- | --- | --- | --- | --- |
| 1 | Require an issue-local visual-state inventory covering every acceptance state and its exact Figma node | Committed state was required but node `81:231` was absent from the issue list | Low–medium | Very high | Low | Very low | High |
| 2 | Retrieve relevant spec sections and the narrow component/source-trace document before broad technical documents | Full product, progression, workflow, broad design, and many skill references were loaded; `COCKPIT-VIEW.md` was skipped | High | Medium | Low | Low if fallback expansion remains allowed | High |
| 3 | Compare each visual acceptance state against its exact Figma node, not a “state family” | Simulator saw the legacy UI and accepted it; authoritative node was never loaded | Medium | Very high | Low | Very low | High |
| 4 | Avoid full-history subagent forks for simulator/test-only tasks | Three agents consumed about 4.04M input tokens; one nested pass did not finish | High | Neutral–medium | Medium | Medium if prompts omit necessary evidence | High |
| 5 | Stop rediscovering tool schemas when direct tool names are already known | Several tool-discovery responses approached 40K characters | Medium | None | Low | Very low | High |
| 6 | Use focused tests and diagnostics until the implementation stabilizes, then one build/full suite before simulator acceptance | Four builds and two full suites occurred, though later reruns were partly caused by the regression | Low–medium | Low | Low | Medium | Medium |
| 7 | Add a concise callout-state/source/Figma matrix to the existing component documentation | Current docs locate the file but not the private state branches | Medium over multiple tickets | Medium | Medium | Low | Medium |
| 8 | Split acceptance reporting into a compact evidence pass that receives a prepared result summary | Acceptance posting reused the entire implementation context | Medium | Low | Medium | Medium | Medium |

### Smallest changes worth testing first

1. Add no new workflow stage; simply ensure the issue’s design evidence lists every visual acceptance state, including committed states.

2. In the implementation conversation, retrieve:

   - Issue body.
   - Only the relevant specification section plus linked nodes.
   - `COCKPIT-VIEW.md` source trace.
   - Then targeted source symbols.

3. Make simulator evidence state-specific: “draft node checked,” “committed node checked,” “stale node checked,” rather than “consistent with state family.”

4. If using a validation agent, give it a compact prompt containing:

   - Build identifier.
   - Exact simulator steps.
   - Exact node URLs.
   - Acceptance observations to return.

   Do not fork the full implementation history, and avoid nested validation agents.

These changes preserve the intended separation between product/design work and each fresh implementation conversation.

---

## 8. Lightweight future measurement proposal

For the next three comparable UI issues, record a read-only worksheet outside the repository or in the final conversation report:

| Measurement | Method |
| --- | --- |
| Conversation/session ID | Parent rollout metadata |
| Model | `turn_context.model` |
| Parent input/cached/output/reasoning | Sum per-call telemetry components |
| Subagent-exclusive usage | Exclude copied spawn-time history before summing |
| Maximum context size | Maximum `last_token_usage.input_tokens` |
| Compactions | Count logical compaction timestamps, not duplicate record forms |
| Tool-response volume | Sum returned text characters by retrieval category |
| Unique and repeated file reads | Count paths in tool-call arguments |
| Figma nodes requested | Count exact node IDs |
| Builds/full tests/focused tests | Count tool calls, grouped before and after corrective edits |
| Rework | Record user-reported defect, corrective patch, and repeated validation |
| Acceptance escape | Whether a required visual state was not directly compared |

Use issue #8 as the baseline, then test one change at a time—for example targeted retrieval first, isolated validation agent second. Compare absolute telemetry and outcomes; do not claim percentage savings until multiple similar tickets exist.

The key distinction should remain:

- **Token optimization:** narrower retrieval, reduced tool-schema output, minimal-context delegation.
- **Rework prevention:** complete visual-state inventory and exact-node simulator comparison.

For issue #8, rework prevention is the higher-value first intervention.
