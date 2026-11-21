# Charts V1

Product approved by John on 2026-11-21. Implementation baseline is
NavigationFlight main at `0723ec76b7018a956b6b6ccb771666528bd84447`.

## Summary

Pilots can browse Israel AIP visual charts from the app's Charts tab. In Cockpit,
pilots can open charts for the loaded Flight Plan's departure and arrival,
with priority charts at the top and the last chart ready when they return.

## Current behavior

The adaptive shell exposes **Cockpit**, **Flight Plans**, **Flights**, and
**Settings**, as defined in the [recording spec](AUTOMATIC-FLIGHT-RECORDING-AND-RECOVERY_SPEC.md).
Cockpit **Map tools → Chart layers** opens a **Charts Unavailable** alert.
A loaded Flight Plan can include optional departure and arrival aerodrome
references, as in the [Herzliya–Rosh Pina fixture](../../NavigationFlightTests/Fixtures/FPLNav/V7/Official/llhz-llib-via-jerusalem-v7.fplnav).
The [V9 chart-text reader](V9-CHART-TEXT-READER.md) covers Flight Plan annotations
and is outside the AIP chart workflow.

## Behavior

### App navigation and library

- **CH-01** Charts is directly selectable in the native adaptive app shell.
  The order is **Cockpit**, **Flight Plans**, **Flights**, **Charts**,
  **Settings**. Show all five where they fit. Where overflow is needed, keep
  the first four destinations visible and put Settings under **More**.
  Preserve selection and navigation position across layout changes.
  [Apple tab bar guidance](https://developer.apple.com/design/human-interface-guidelines/tab-bars?changes=la_11)
- **CH-02** The library is available with or without a Flight Plan. It includes
  all published visual charts in the two linked sections and follows the AIP's
  grouping and order under **Airports** and **Airfields**, then by aerodrome.
  Use the published aerodrome and chart names.
  [Israel AIP Airports](https://www.gov.il/he/pages/aip?chapterIndex=7) ·
  [Israel AIP Airfields](https://www.gov.il/he/pages/aip?chapterIndex=8)
- **CH-03** Use the exact downloaded official files. Where the publisher
  includes a chart inside a larger PDF, open its original pages from that file.
  The pilot can zoom, pan, and return to the originating list.
- **CH-04** Ship one verified local AIP snapshot, available
  offline from both entry points from first launch. Show the publisher's date
  or edition where available and provide the official source reference. Refresh
  the set through app releases. If a chart fails to open, identify it and let
  the pilot return and select another chart. The supplied chapter pages yielded
  no readable inventory in the available browser tools. The current download
  inventory, chart pages, and edition details remain to be verified.

### Cockpit access

- **CH-05** **Cockpit → Map tools → Charts** replaces **Chart layers** and
  its unavailable alert. Offer only charts for departure and arrival aerodromes
  explicitly supplied by the loaded `.fplnav` version. If an endpoint reference
  is absent or cannot be matched unambiguously, or has no published charts,
  explain availability for that endpoint and keep the other endpoint usable.
  When both roles identify the same aerodrome, offer one set labeled for both.
- **CH-06** The first open for a Flight shows a list with the relevant
  departure and arrival procedures first, then circuit charts, then other
  charts for those aerodromes. Identify the aerodrome and Flight Plan role
  for each chart. Keep published order among equally ranked charts where
  applicable and skip empty groups.
- **CH-07** Reopening Charts in the same Flight resumes the last successfully
  opened chart, including after switching app sections. Closing without
  opening a new chart keeps that selection. A new or restarted Flight begins
  at the prioritized list. If the saved chart is unavailable, return to the
  current Flight's list. After app relaunch, including Flight recovery, open the prioritized list.
  Resume the chart selection during the running app session.
- **CH-08** The viewer offers a path to the Flight's list and back to the
  map. Using either Charts entry point preserves Flight Plan, Flight progress,
  timing, recording, and map context. Active leg changes leave the selected
  chart in place.

### Later work

- **CH-09** V1 displays documents. Georeferenced map overlays and opacity
  controls are deferred. Technical planning must preserve a way to associate
  georeferencing with a specific original chart page and revision later.

## Figma

**Direction approved by John** · Iteration 01 · 2026-11-21. The owner chose to start from
existing app patterns. The file was created in the
[Navigation Flight project](https://www.figma.com/files/folder/676737789).

- [Stable design file](https://www.figma.com/design/WfBJGtbq2I37ODQZj44Yz1)
- [Review index](https://www.figma.com/design/WfBJGtbq2I37ODQZj44Yz1?node-id=3-635)
- [Cockpit Charts on iPad Pro 11-inch portrait](https://www.figma.com/design/WfBJGtbq2I37ODQZj44Yz1?node-id=3-647)
- [Selected Herzliya circuit on iPad portrait](https://www.figma.com/design/WfBJGtbq2I37ODQZj44Yz1?node-id=6-73)

The [Charts panel](https://www.figma.com/design/WfBJGtbq2I37ODQZj44Yz1?node-id=3-745)
uses the current cockpit's trailing Map tools presentation. Chart rows identify
the aerodrome and Flight Plan role (CH-05). The
[procedures](https://www.figma.com/design/WfBJGtbq2I37ODQZj44Yz1?node-id=3-757),
[circuits](https://www.figma.com/design/WfBJGtbq2I37ODQZj44Yz1?node-id=3-772),
and [other charts](https://www.figma.com/design/WfBJGtbq2I37ODQZj44Yz1?node-id=3-787)
appear in that order (CH-06). Close returns to the map, with the Flight instruments
still in view (CH-08). The underlying map is schematic and the sample chart
labels are illustrative. The file's spec backlink is pending repository
publication.

At the owner's request, the direction review also shows the selected **Traffic
circuit** for **Departure · Herzliya (LLHZ)**. The viewer fits the complete
published Appendix XII page and shows the source edition and document zoom
controls (CH-03, CH-04). The original chart content is the unaltered page
render from [Israel AIP Amendment 2/25, PDF page 99](https://www.gov.il/BlobFolder/generalpage/idcunim-2025/he/aip_%D7%A7%D7%95%D7%91%D7%A5%20%D7%A2%D7%93%D7%9B%D7%95%D7%9F%202-25.pdf#page=99),
dated 2 October 2025. This example does not establish the V1 inventory.
In the prototype, the Herzliya circuit row opens the viewer, **Charts**
returns to the list, and **Close** returns to the [cockpit map](https://www.figma.com/design/WfBJGtbq2I37ODQZj44Yz1?node-id=6-109)
(CH-08). Zoom and pan are depicted as viewer behavior for implementation.

### Iteration 02 coverage review

**Approved by John** · 2026-11-21. The [coverage index](https://www.figma.com/design/WfBJGtbq2I37ODQZj44Yz1?node-id=13-825)
extends the approved portrait direction. The frame links below identify the
approved design targets for each in-scope requirement.

| Requirement | Design targets |
| --- | --- |
| CH-01 | [iPad portrait tabs](https://www.figma.com/design/WfBJGtbq2I37ODQZj44Yz1?node-id=9-274), [expanded iPad sidebar](https://www.figma.com/design/WfBJGtbq2I37ODQZj44Yz1?node-id=11-803), [five iPhone tabs](https://www.figma.com/design/WfBJGtbq2I37ODQZj44Yz1?node-id=9-458), [compact overflow](https://www.figma.com/design/WfBJGtbq2I37ODQZj44Yz1?node-id=9-535), and [Settings within More](https://www.figma.com/design/WfBJGtbq2I37ODQZj44Yz1?node-id=9-599). Existing Settings content is reused. Native platform behavior determines when overflow is needed. |
| CH-02 | [Airport and airfield library](https://www.figma.com/design/WfBJGtbq2I37ODQZj44Yz1?node-id=9-274) and [aerodrome charts](https://www.figma.com/design/WfBJGtbq2I37ODQZj44Yz1?node-id=9-339). The visible rows are examples. |
| CH-03, CH-04 | [Library viewer](https://www.figma.com/design/WfBJGtbq2I37ODQZj44Yz1?node-id=9-422), [cockpit viewer](https://www.figma.com/design/WfBJGtbq2I37ODQZj44Yz1?node-id=12-1004), [zoomed view](https://www.figma.com/design/WfBJGtbq2I37ODQZj44Yz1?node-id=12-889), and [unreadable file](https://www.figma.com/design/WfBJGtbq2I37ODQZj44Yz1?node-id=10-752). In the library, the same failure pattern returns to the originating aerodrome. Offline use follows the same installed-document flow. |
| CH-05, CH-06 | [Map tools entry](https://www.figma.com/design/WfBJGtbq2I37ODQZj44Yz1?node-id=10-370), [prioritized list](https://www.figma.com/design/WfBJGtbq2I37ODQZj44Yz1?node-id=12-928), [one endpoint unavailable](https://www.figma.com/design/WfBJGtbq2I37ODQZj44Yz1?node-id=10-451), [no endpoints specified](https://www.figma.com/design/WfBJGtbq2I37ODQZj44Yz1?node-id=10-540), and [shared endpoint](https://www.figma.com/design/WfBJGtbq2I37ODQZj44Yz1?node-id=10-634). Reuse the endpoint notice with a reason specific to an absent reference, an unresolved match, or unavailable charts. With neither endpoint available, retain the list shell and show the applicable reason. |
| CH-07 | Returning in the same running Flight opens the [selected-chart viewer](https://www.figma.com/design/WfBJGtbq2I37ODQZj44Yz1?node-id=12-1004) directly. A new or restarted Flight, relaunch or recovery, and an unavailable previous selection use the [prioritized list](https://www.figma.com/design/WfBJGtbq2I37ODQZj44Yz1?node-id=12-928). These rules are annotated in the coverage index. |
| CH-08 | Viewer **Charts** returns to the originating list and **Close** returns to the [cockpit map](https://www.figma.com/design/WfBJGtbq2I37ODQZj44Yz1?node-id=6-109). The prototype demonstrates the transitions. Flight-state preservation is an implementation behavior. |
| CH-09 | Georeferenced overlays and opacity are deferred. |

Review adaptations include [iPad landscape list](https://www.figma.com/design/WfBJGtbq2I37ODQZj44Yz1?node-id=11-555)
and [viewer](https://www.figma.com/design/WfBJGtbq2I37ODQZj44Yz1?node-id=11-659),
[iPhone portrait list](https://www.figma.com/design/WfBJGtbq2I37ODQZj44Yz1?node-id=11-694)
and [viewer](https://www.figma.com/design/WfBJGtbq2I37ODQZj44Yz1?node-id=11-772),
and [larger text and long labels](https://www.figma.com/design/WfBJGtbq2I37ODQZj44Yz1?node-id=11-860).
The index records the proposed VoiceOver focus order and semantic system
controls. Other supported compact portrait sizes and live accessibility
behavior require implementation verification. iPhone landscape follows the
project-wide exclusion.

John approved Iteration 02 and its paired product specification on 2026-11-21.
The exact V1 AIP inventory and the shareable repository backlink still require
verification and publication respectively. John approved the technical
design and confirmed direct redistribution authorization from רת״א on
2026-11-21. He subsequently selected the shared `aviation-maps` package to
own the AIP snapshot. The
[technical design](../technical/CHARTS-TECHNICAL-DESIGN.md) records the revised
release handoff. John approved the revised packaging and
[delivery plan](CHARTS-DELIVERY-PLAN.md) on 2026-11-21.
