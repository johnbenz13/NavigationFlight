# NavigationFlight Glossary

## Manual-navigation primacy

During normal flight, the pilot is the navigation authority. The pilot starts each leg, identifies and reports reaching navigation targets, performs navigation calculations, and decides which heading and timing values to use. The app may present recorded observations and provide an explicitly requested cross-check, but it does not silently perform or replace these pilot actions.

## Navigation target

An identification point or arrival waypoint toward which the pilot is navigating within a leg.

## Pilot-reported position fix

The resolved map position of an identification point or waypoint that the pilot reports reaching. The app treats this report as the pilot's asserted position for manual-navigation purposes, but it is not independently verified and must not be described as a GPS-confirmed aircraft position.

## Passed without report

The historical state of an identification point that precedes a later pilot-reported position fix but was never itself reported reached. A passed-without-report point has no Actual ETA and its revisions can no longer be edited.

## Drift lines

Optional dashed reference lines drawn from a leg's endpoints using the configured drift angle. They are graphical aids for the pilot's manual heading calculation and do not represent the aircraft's actual or GPS-derived track.

## Revised ETA

The pilot's updated estimate of elapsed time from the start of the current leg to a navigation target. The pilot calculates and commits this value using observed progress, including the difference between Planned ETA and Actual ETA at a reached identification point.

## Revised Heading

The pilot's updated heading for regaining or maintaining the intended track. The pilot calculates and commits this value from observed drift and the planned navigation information.

## Reference result

An app-computed value revealed only when the pilot explicitly requests a cross-check after committing their own result. A Reference result never overwrites or automatically applies a pilot-authored revision.
