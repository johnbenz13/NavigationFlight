# Charts V1 delivery plan

**Status.** Approved and published on 2026-11-21. John approved the revised
packaging and four-ticket breakdown and authorized publication. John approved the
[product spec](CHARTS_SPEC.md), [Figma Iteration 02](https://www.figma.com/design/WfBJGtbq2I37ODQZj44Yz1?node-id=13-825)
and [technical design](../technical/CHARTS-TECHNICAL-DESIGN.md). This plan
records the revised shared-package handoff, draft issue bodies, coverage,
and the remaining approval gates.

## Proposed tickets and blockers

| Ticket | Outcome | Blocked by |
| --- | --- | --- |
| [1. Verified AIP snapshot](https://github.com/johnbenz13/fplnav-spec/issues/23) | Publish a pinned private `aviation-maps` release with the complete original PDFs and shared chart index. Child of [fplnav-spec #14](https://github.com/johnbenz13/fplnav-spec/issues/14). | [Inventory #13](https://github.com/johnbenz13/fplnav-spec/issues/13) and availability of the reusable release tooling in [PR #16](https://github.com/johnbenz13/fplnav-spec/pull/16). Reconcile PDF payloads and validate the chart release in this slice. |
| [2. App Charts library](https://github.com/johnbenz13/NavigationFlight/issues/195) | Pin and stage the shared release, then browse and open the complete library offline in the shared viewer. | External released-artifact prerequisite from [fplnav-spec #23](https://github.com/johnbenz13/fplnav-spec/issues/23). |
| [3. Cockpit charts](https://github.com/johnbenz13/NavigationFlight/issues/196) | From Map tools, find the loaded plan's charts in priority order and return to the map. | [Navigation Flight #195](https://github.com/johnbenz13/NavigationFlight/issues/195) supplies shared document loading, rendering and recovery. |
| [4. Cockpit recall](https://github.com/johnbenz13/NavigationFlight/issues/197) | Resume the last chart in the running Flight and reset correctly on replacement, relaunch or recovery. | [Navigation Flight #196](https://github.com/johnbenz13/NavigationFlight/issues/196) supplies the cockpit viewer route and document-open result. |

Each ticket carries its own acceptance and test contract. Ticket 1 delivers
an independently verifiable shared release. Ticket 2 is the first
pilot-visible slice and installs the complete snapshot at build preparation. Tickets 3 and 4 extend normal cockpit flows.
All four are required for Charts V1 release.

## Coverage

| Requirement | Ticket | Design target | Verification |
| --- | --- | --- | --- |
| CH-01 app navigation | 2 | [Library and tab layout](https://www.figma.com/design/WfBJGtbq2I37ODQZj44Yz1?node-id=9-274), [More](https://www.figma.com/design/WfBJGtbq2I37ODQZj44Yz1?node-id=9-599) | Selection guard and ordering tests, adaptive tab and More review. |
| CH-02 complete AIP library | 1, 2 | [Airport and airfield groups](https://www.figma.com/design/WfBJGtbq2I37ODQZj44Yz1?node-id=9-274), [aerodrome list](https://www.figma.com/design/WfBJGtbq2I37ODQZj44Yz1?node-id=9-339) | Upstream publisher reconciliation and live browse through both groups. |
| CH-03 original PDF pages | 1, 2, 3 | [Library viewer](https://www.figma.com/design/WfBJGtbq2I37ODQZj44Yz1?node-id=9-422), [cockpit viewer](https://www.figma.com/design/WfBJGtbq2I37ODQZj44Yz1?node-id=12-1004), [zoom](https://www.figma.com/design/WfBJGtbq2I37ODQZj44Yz1?node-id=12-889) | Shared release hashes, consumer pin and staged bytes, selected page range, fit and zoom from both entry points. |
| CH-04 offline snapshot and errors | 1, 2, 3 | [Source and edition](https://www.figma.com/design/WfBJGtbq2I37ODQZj44Yz1?node-id=12-1004), [document error](https://www.figma.com/design/WfBJGtbq2I37ODQZj44Yz1?node-id=10-752) | Verified pin install and rollback, fresh offline build, source/date and unreadable-file return. |
| CH-05 cockpit scope | 3 | [Map tools](https://www.figma.com/design/WfBJGtbq2I37ODQZj44Yz1?node-id=10-370), [partial availability](https://www.figma.com/design/WfBJGtbq2I37ODQZj44Yz1?node-id=10-451), [no references](https://www.figma.com/design/WfBJGtbq2I37ODQZj44Yz1?node-id=10-540), [shared aerodrome](https://www.figma.com/design/WfBJGtbq2I37ODQZj44Yz1?node-id=10-634) | Resolver fixtures, roles, matching errors, endpoint deduplication and preserved drift controls. |
| CH-06 chart order | 3 | [Prioritized list](https://www.figma.com/design/WfBJGtbq2I37ODQZj44Yz1?node-id=12-928) | Deterministic cross-role ranking and visual row order. |
| CH-07 last chart recall | 4 | [Fit viewer and prioritized-list fallback](https://www.figma.com/design/WfBJGtbq2I37ODQZj44Yz1?node-id=13-825) | Success-only selection, stale load, tab and leg changes, restart, relaunch and recovery. |
| CH-08 return and Flight continuity | 3, 4 | [Viewer](https://www.figma.com/design/WfBJGtbq2I37ODQZj44Yz1?node-id=12-1004), [cockpit map](https://www.figma.com/design/WfBJGtbq2I37ODQZj44Yz1?node-id=6-109) | Charts and Close destinations, adaptive handoff, map, timing and recording continuity. |
| CH-09 georeferencing readiness | 1–3 | Source-document and map separation shown in the approved viewer | Stable page identity from the original asset and renderer, with no overlay or map configuration changes. |

## Tracker and release gates

Reuse the existing `johnbenz13/fplnav-spec` upstream tracks for private release
transport and chart inventory. They remain open with
[PR #16](https://github.com/johnbenz13/fplnav-spec/pull/16) and
[PR #17](https://github.com/johnbenz13/fplnav-spec/pull/17).
The shared release slice is a child of #14. The umbrella retains its
both-app acceptance. Later Editor adoption falls under that
umbrella. Tickets 2–4 belong to `johnbenz13/NavigationFlight`. No source
parent was found there. [NavigationFlight #157](https://github.com/johnbenz13/NavigationFlight/issues/157)
records the older temporary unavailable action. Approved CH-05 supersedes
that behavior. Ticket 3 references it as related history and preserves
drift controls. Any change to #157 itself remains a separate tracker decision.

Use native blocker links within each repo, with the repository's textual
fallback when necessary. Treat the cross-repository dependency as an external
release prerequisite. Record the upstream issue, merged evidence in its own
repository, and the immutable release/pin and verified staging receipt in the
consumer ticket. The Navigation Flight ticket does not wait on the Editor
viewer or on either consumer's base-map migration.

Published the shared issue first, then the three Navigation Flight issues.
The shared ticket tracks #13 as its native blocker. Shared release tooling
is a prerequisite. The chart ticket verifies its own private publication and
retrieval. Legacy base-map rollout and acceptance under #10 can be scheduled
separately. The two dependent Navigation Flight issues use native blockers. The
library documents the external shared release prerequisite explicitly.

The [approved product revision](https://github.com/johnbenz13/NavigationFlight/blob/bea6dba1c0ce69955ec416bf46e70a078b662ee9/docs/features/CHARTS_SPEC.md)
is linked from the approved Figma cover and each published issue.

John confirmed direct authorization from רת״א on 2026-11-21. Record its
scope as part of the shared release review. The release work still includes
checking the complete snapshot and proving pinned private retrieval. This
plan covers packaging and app adoption. Implementation, validation runs and
binary release publication each require their own authorization.
