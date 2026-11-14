# Record a Flight and understand its result

[Back to the map](../README.md) · [Recording proposals](../proposed/flights-and-recovery.md)

**Status:** observed 2026-11-14; account approved by John on 2026-11-14. [Batch08](../evidence/capture-batch-08.md)
uses the same baseline on iPad Pro 11-inch (M5), iOS 27, portrait. The lifecycle uses
real UI actions with synthetic location input; it is not real-flight validation.

## S50 · Open Flights before any recording

Open Flights with an empty disposable store. The screen explains that recording starts
with movement and takeoff detection and directs the pilot to load a Flight Plan.

![Empty Flights explains how to begin](../assets/current/batch-08/01-empty-flights.png)

## S51 · Inspect recording status and keep recording

Load the synthetic plan, Start, then open recording status. A GPS Gap explanation says
recording continues without interpolation. Choose End Recording to see confirmation,
then Keep Recording. Navigation remains active and the later status shows GPS Resumed.
This demonstrates the fixture-driven status transition, not sensor segmentation accuracy.

![Active recording explains a GPS gap](../assets/current/batch-08/02-recording-status.png)

![End confirmation before navigation completion](../assets/current/batch-08/03-end-cancel-confirm.png)

![Keep Recording returns to active navigation](../assets/current/batch-08/04-end-cancelled.png)

## S52 · Search for IP Undo and check a committed ETA

Report IP1 reached at 00:26. Its callout shows ten seconds late and Revise Next ETA,
with no Undo. Dismiss the callout: the full cockpit at 00:35, nine seconds later,
also exposes no Undo in the screenshot or hierarchy. This confirms the bounded
missing-affordance observation from [S41](continuity-and-adaptations.md#s41--report-an-identification-point-reached);
it does not establish whether an internal Undo command exists.

![Immediate reached-IP callout](../assets/current/batch-08/05-ip-reached-undo-check.png)

![Dismissed callout within the twenty-second correction window](../assets/current/batch-08/06-ip-dismissed-no-undo.png)

Commit a revised destination ETA of 00:50. Check is enabled. Tapping it displays
reference 01:05 from IP timing, while retaining 00:50 as the pilot's operational value.
The message says the revision is fifteen seconds earlier than reference and that the
reference does not replace or verify it. This successful branch reduces the earlier
Check evidence gap; unavailable Check before prerequisites is not a missing capability.

![Committed revision enables Check](../assets/current/batch-08/07-check-after-commit.png)

![Reference Check retains the operational revision](../assets/current/batch-08/08-check-result.png)

## S53 · End after navigation completion and inspect the saved Flight

Report the final destination reached. Navigation becomes Complete while recording
continues. End Recording then promises that the “action-only recording will close as
complete.” Confirm it: status instead becomes Recording ended · Incomplete, while
the disabled destination action still says Navigation Complete · Recording Continues.

![Final reach completes navigation while recording continues](../assets/current/batch-08/09-navigation-complete.png)

![Confirmation promises Complete](../assets/current/batch-08/10-end-complete-confirm.png)

![After confirmation, recording status and destination wording disagree](../assets/current/batch-08/11-closed-complete.png)

Open Flights and its new row. The actual newly created recording is Manually Ended;
detail reports Incomplete, Manual, Partial GPS · 5%, with start/end times from this run.
This is a UI-created result, not a seeded closed-recording presentation. Persistence
after relaunch and the raw recording bytes were not checked in this sequence.

![Newly saved Flight in the library](../assets/current/batch-08/12-actual-saved-flight.png)

![Saved detail identifies manual closure and partial GPS](../assets/current/batch-08/13-actual-closed-detail.png)

The synthetic run provided some GPS and no demonstrated landing. Incomplete may be
correct under the recording rules; the misleading promise and stale status are the
bounded discrepancy, [G19](../proposed/flights-and-recovery.md#g19--describe-recording-closure-truthfully).

## S54 · Understand recording failure and degradation

With injected recording failure, Start produces Couldn't Start Leg and retains Ready
00:00. With the separate degradation input, navigation is active and the explanation
says some track data could not be saved while navigation remains available. These
exercise distinct injected paths; neither proves real disk-exhaustion behavior.

![Failed start clearly retains the ready state](../assets/current/batch-08/14-recording-failure.png)

![Track degradation permits navigation and explains incomplete recording](../assets/current/batch-08/15-recording-degradation.png)

## S55 · Review an active recording without export or deletion

Open the seeded In Progress recording and scroll to the bottom. Continue Flight is
available; neither export nor deletion appears in the full detail/hierarchy. The seed
bypasses normal startup recovery, so its presence here does not establish that unresolved
recovery is normally exposed in the library.

![Active detail offers Continue Flight](../assets/current/batch-08/16-active-record-detail.png)

![Bottom of active detail has no delete action](../assets/current/batch-08/17-active-record-bottom.png)

## S56 · Understand export and deletion failures

In separate seeded closed-recording runs, request export or confirm deletion with the
respective injected failure. Each alert retains the detail and offers Cancel/Retry.
The export alert says no file was shared; deletion says files remain on device. These
are observed error presentations, not an independent byte-level preservation check
or a successful retry. The earlier stale row after successful deletion remains distinct.

![Injected export failure retains detail](../assets/current/batch-08/18-export-failure.png)

![Injected deletion failure retains detail](../assets/current/batch-08/19-delete-failure.png)
