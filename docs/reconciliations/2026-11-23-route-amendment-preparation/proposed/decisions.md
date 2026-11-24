# Owner decisions and state vocabulary

John approved Q1–Q27 and Q29–Q31 with “yes to all” over the conversation rounds
on 2026-11-23. Q28 was approved with an additional request for a more elegant
current-leg timing strip. These are behavioral decisions for a future iteration,
not proof of delivery or visual approval. The original screenshots and
observations remain dated evidence of the earlier experience.

On 2026-11-24, John approved Q33–Q36 and explicitly resolved Q32: remove
**Start now** from the proposed flow. Reconsider any immediate-departure action
only during the later flying-amendment reconciliation.

## Proposed vocabulary

These definitions are scoped to this proposal. Apply the corresponding glossary
updates alongside an approved contract update; do not silently rewrite existing
meaning. The current glossary defines Route amendment as already pilot-confirmed.

**Amendment draft:** A prepared replacement for part of the current Flight's
operational route that the pilot has not armed.

**Valid route:** A continuous replacement from an eligible departure to a
strictly later rejoin on the operational route, with distinct consecutive points.

**Ready amendment:** An unarmed amendment with a valid route and a usable heading
and positive leg time for each replacement leg.

**Armed amendment:** A durably accepted replacement the pilot has explicitly
chosen to use, awaiting the existing departure flow.

**Flying amendment:** An amendment whose first replacement leg has started.
A reported departure awaiting Manual Start leg retains the grey Armed indicator
and the explanation “Awaiting Start leg”; green begins when that leg starts.

**Leg time:** The planned duration of one leg, distinct from its elapsed timer
and from an arrival clock time.

Avoid **Activate** for arming: it blurs commitment and departure. Avoid a separate
**Validated** lifecycle state: readiness is derived from route/values. Ready here
describes amendment preparation; it does not rename the regular Cockpit's Ready
leg state. Editor visibility and plotting are independent UI states.

## Decision register

| Topic | Owner-approved decision | Main stories |
| --- | --- | --- |
| Readiness | Readiness follows validity automatically; no Validate action. Assisted missing estimates need entry. | G03, G04 |
| Arm effect | Arm retains scheduled confirmation's operational effect, including a shortened destination; departure execution stays existing. | G04 |
| Pencil exit | Pencil toggles editor/Cockpit without a dialog, preserves unfinished and partial work, leaves no draft after untouched exit. | G01, G05 |
| Continuous workspace | Use one growing vertical leg list and Plot points toggle; values can be edited before rejoin. | G02, G03 |
| Armed editing | Armed inspection is read-only until Disarm and edit; disarming restores prior pending-route behavior and retains work. | G04 |
| Rejoin | Tapping a suitable downstream route point explicitly rejoins and ends plotting; line crossings alone do not. Resolve occurrences; offer explicit Continue plotting when needed. | G02 |
| Wheels | Heading 001°–360°; time minute/second wheels capped at 60:00; 00:00 invalid. Missing values stay Not set. Optional values can be unset. | G03 |
| Check | Check remains in the modal; remove the green per-row Check action. | G03 |
| Recovery | Unfinished drafts and partial modal entries survive restart; restore unarmed and recheck eligibility. | G05 |
| Mode | Capture Settings mode per draft, display it, preserve it across recovery, and apply Settings changes to the next draft. | G03 |
| Partial values | Save each field independently; Done preserves partial values and closes. Incompleteness prevents arming, not editor exit. | G03 |
| Geometry edits | Geometry changes clear affected Manual headings/times; recalculate affected Assisted values and identify updates. Preserve unchanged legs and cues on surviving legs. Undo restores values and geometry together. | G02, G03 |
| Discard | Confirm Discard amendment; remove saved draft and return to Cockpit. Armed deletion explicitly says Disarm and discard. | G05 |
| Save failures | Arm returns to Cockpit only after durable success; failure keeps work and offers Retry. Draft-save failure is visible and cannot claim recovery. | G04, G05 |
| Radio granularity | First slice uses 25 kHz VHF channel steps, with MHz and fractional-channel wheels. Defer 8.33 kHz. | G03 |
| Flown inspection | Green Flying pencil opens read-only inspection. Editing/replacing a flown amendment is deferred from this slice. | G07 |
| Plotting entry | Entry/reentry has plotting off; Plot points first selects departure, then plots. Restore selection/entries. Existing rejoin needs explicit Change return point before extension. | G01, G02 |
| Timing context | Keep current-leg timing context, only amendment legs in list, hide unarmed geometry outside editor and retain armed geometry. Improve the dark strip's visual treatment. | G06 |
| Restore destination | Restore unfinished work with the Flight to normal Cockpit, unarmed; validate route eligibility again. | G05 |
| Immediate departure · Q32 | Remove Start now from the proposed flow. Preparation ends at Arm → Cockpit. Reconsider an immediate-departure action only when reconciling flying. | G04 |
| Manual handoff · Q33 | Keep the pencil grey while the first replacement leg awaits Start leg; show Awaiting Start leg. Green begins when that leg starts. | G01, G07 |
| Altitude bounds · Q34 | Selector covers −1,500 to 20,000 ft MSL in 100 ft steps. Preserve existing values outside that range without silent rounding. | G03 |
| Map selection · Q35 | With plotting off, waypoint selection exposes Move/Remove; leg or row selection opens its value editor. Move explicitly enables replacement placement. | G02 |
| Flight ownership · Q36 | Drafts belong to their Flight and resume only with that unfinished Flight. Failed saves preserve in-memory work after pencil exit; show unsaved status. Never carry a draft into another Flight. | G05 |
| Behavioral direction | Shared behavioral direction agreed; record and verify it before design. | All |

The record groups related decisions by topic. The owner accepted the recommended
answers across the conversation rounds; Q28 also adds the timing-strip direction.

## Original owner intent also retained

- Completed original legs should be greyed out. The agreed follow-up explicitly
  excludes completed anchors and uses pilot-reported progress within the current leg.
- A same-leg triangle with a later rejoin is valid; route order, not distance or
  coordinate uniqueness across the whole route, determines forward progress.
- Optional cues remain altitude, frequency and visual reference. Altitude uses
  100 ft steps; frequency uses valid radio channel granularity, not free decimals.
- Amber draft dot, grey Ready pause, grey Armed play, green Flying play, and the
  existing open-editor highlight are the approved indicator direction. Exact
  visual choices still need design approval.
- Flying, rejoin, Flight Undo, history and debrief will be reconciled later.

## Boundaries to resolve before ticket contracts

These are unresolved details, not permission to invent implementation behavior.

1. **Immediate departure:** resolved on 2026-11-24 by removing Start now. Do not
   retain or relocate it in the proposed preparation or armed-inspection flow.
   Any replacement is deferred to the flying reconciliation.
2. **Armed/Ready handoff:** resolved by Q33. Grey with Awaiting Start leg until
   the first replacement leg starts; no green indicator for an untimed Ready leg.
3. **Cue picker details:** Q34 settles altitude bounds and preservation of existing
   out-of-range values. Finalize the valid 25 kHz COM channel list and handling of
   existing off-step values without silent rounding during the contract pass.
4. **Editing interactions:** Q35 settles point-versus-leg selection and explicit
   move placement. Design the Continue plotting choice without a Finish here gate.
5. **Draft continuity:** Q36 settles Flight isolation, unfinished-Flight resumption,
   and visible unsaved status with in-memory preservation after exit. Specify
   corruption/version handling in the technical contract without automatic arming.
6. **Legacy flight paths:** The green-pencil read-only rule deliberately defers
   creating a further amendment while flying, which the earlier RA-12 allowed.
   Record this scoped supersession explicitly when updating the shared contract.

The product choices raised in Q32–Q36 are resolved. Design and technical-contract
details above remain to be completed before implementation-ready tickets; they
do not reopen the agreed preparation direction.

## Owner design review · 2026-11-24

John is globally satisfied with D02, subject to two corrections: clearly
separate the Heading wheel from the minutes/seconds group, and keep the console
from jumping in height when switching between amendment and regular Cockpit.
[D03](design-revision-d03.md) applies these changes for review. It reuses the
existing resting-layout extents and scrolls the leg list internally. D03 approval
and implementation authorization remain separate.
