# NavigationFlight Glossary

NavigationFlight supports preparing for and executing visual-navigation flights
while preserving the pilot as the navigation authority.

## Core flight concepts

**NavigationFlight**:
The application for executing navigation flights. It is the product name, not a
domain entity.

**App section**:
One of the application's top-level areas, such as Cockpit, Flight Plans, or
Settings, independent of whether the interface presents it as a tab or sidebar
item.
_Avoid_: Destination

**Flight Plan**:
The complete preparation for a Flight, including its route, map information,
headings, speeds, altitudes, radio information, and resolved planning data. A
`.fplnav` file contains one Flight Plan.
_Avoid_: Navigation plan, NavigationFlight

**Flight Plans**:
The application's offline library and app section containing imported Flight
Plans available to inspect and load in Cockpit.
_Avoid_: Flights, Flight library

**Flight**:
One actual execution of a Flight Plan, created when the pilot explicitly loads
or restarts that plan and retained through its ready, active, and completed
states. Separate loads or restarts create distinct Flights.
_Avoid_: Flight session

**Flights**:
The collection of actual Flight instances across their ready, active, completed,
or aborted states. It is reserved for a future app section and does not refer to
the Flight Plans library.

**Planned navigation**:
The resolved headings, speeds, timings, annotations, radio information, and
related planning values contained in a Flight Plan.
_Avoid_: Execution data

**Cockpit**:
The application's operational destination for executing the currently loaded
Flight.

## Manual navigation

**Manual-navigation primacy**:
The pilot remains the navigation authority during a Flight; the application
records pilot actions and presents explicitly requested cross-checks without
silently replacing those actions.

**Navigation target**:
An identification point or arrival waypoint toward which the pilot is navigating
within a leg.

**Pilot-reported position fix**:
The resolved map position of an identification point or waypoint that the pilot
reports reaching. It is the pilot's asserted position, not a GPS-confirmed
aircraft position.

**Passed without report**:
The historical state of an identification point preceding a later
pilot-reported position fix that was never itself reported reached. It has no
Actual ETA and its revisions can no longer be edited.

**Drift lines**:
Optional dashed reference lines drawn from a leg's endpoints using the configured
drift angle. They support manual heading calculation and do not represent an
actual or GPS-derived track.

**Revised ETA**:
The pilot's updated estimate of elapsed time from the start of the current leg
to a navigation target.

**Revised Heading**:
The pilot's updated heading for regaining or maintaining the intended track.

**Reference result**:
An application-computed value revealed only when the pilot explicitly requests
a cross-check after committing a result. It never overwrites or automatically
applies a pilot-authored revision.
