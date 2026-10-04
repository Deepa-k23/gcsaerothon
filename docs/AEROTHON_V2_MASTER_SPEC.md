# AeroTHON-GCS V2 — MASTER FINAL APPROVAL, COMPLETE FEATURE SPECIFICATION, TELEMETRY ANIMATION REQUIREMENTS & IMPLEMENTATION AUTHORIZATION

This single prompt supersedes the previous approval/addendum prompts. Treat every requirement below as approved unless it explicitly says a hardware/network value must remain configurable or must be verified before real-world activation.

Do not omit, downgrade, silently reinterpret, or postpone a requirement merely because it appeared in an earlier planning section. Follow the engineering priority/order defined below, preserve PX4/QGC safety behaviour, keep V1 untouched, and build V2 only in the isolated V2 project tree.

---

# AeroTHON-GCS V2 — FINAL APPROVAL + ANSWERS TO BLOCKING QUESTIONS + START IMPLEMENTATION

I have reviewed your complete planning output.

## THE PLAN IS APPROVED.

Proceed with AeroTHON-GCS V2 implementation.

The existing project must remain untouched:

`/home/deepa/AeroTHON-GCS`

The new project must be created separately:

`/home/deepa/AeroTHON-GCS-V2`

Treat V1 as READ-ONLY reference.

Do not modify, clean, reset, rebuild, overwrite, or change the existing AeroTHON-GCS project.

---

# FINAL ANSWERS TO BLOCKING QUESTIONS

## Q1 — QGC CLONE BASELINE

### DECISION: OPTION A

Use the same known-good QGroundControl baseline as V1:

`80c91d9`

Before cloning, verify once more that this is truly the upstream/base commit used by V1.

Also inspect whether V1 contains any local commits or uncommitted patches on top of this commit.

Document:

- upstream commit
- local V1 commits
- local modifications
- carried-forward build fixes

Do NOT blindly copy the entire V1 custom directory.

Use the clean upstream baseline and selectively carry over only verified infrastructure that is still required.

Then:

```text
/home/deepa/AeroTHON-GCS
    OLD V1
    READ ONLY

/home/deepa/AeroTHON-GCS-V2
    NEW V2
    ACTIVE DEVELOPMENT

```

---

# Q2 — MISSION GRAPH TIMING

### DECISION: USE BOTH OPTION A AND OPTION B

For every mission node store at minimum:

- created/configured node ID
- started timestamp
- completed timestamp
- node state
- previous node
- next node

## Primary metric

Show:

`Previous node completion → Current node completion`

Call this:

`STAGE TIME`

This represents the real amount of mission timeline consumed between those two completed stages.

Example:

```text
Previous node completed: 12:04:10
Current node completed:  12:04:28

STAGE TIME:
18 s

```

## Secondary metric

Also show:

`Current node start → Current node completion`

Call this:

`EXECUTION TIME`

Example:

```text
Current node started:    12:04:17
Current node completed:  12:04:28

EXECUTION TIME:
11 s

```

For an ACTIVE node:

show live:

```text
STATUS
ACTIVE

ELAPSED
8 s

FROM PREVIOUS NODE
15 s

```

For NOT STARTED:

```text
STATUS
NOT COMPLETED

```

For FAILED:

show:

- failure state
- time when failure occurred
- reason if available

---

# Q3 — MISSION GRAPH LOCATION

I want to override the original A/B choice with a better layout.

## FINAL DECISION

Make the mission graph a **horizontal mission strip below the main operational workspace and directly above the bottom telemetry rail**.

Do NOT permanently put it under the cameras.

Do NOT permanently put it under the message panel.

The cameras need their vertical space.

The graph benefits from horizontal width.

Target layout:

```text
┌──────────────────────────────────────────────────────────────────────┐
│ TOP BAR                                                             │
├────┬────────────────────┬─────────────────────────┬──────────────────┤
│NAV │ HUD                │                         │ FPV              │
│    │                    │                         │                  │
│    ├────────────────────┤          MAP            ├──────────────────┤
│    │ QUICK ACTIONS      │                         │ NADIR            │
│    ├────────────────────┤                         │                  │
│    │ MESSAGES           │                         │                  │
├────┴────────────────────┴─────────────────────────┴──────────────────┤
│ MISSION GRAPH                                            [ EDIT ]   │
│ ✓───✓─────●╲────○─────○────○────○                                  │
├─────────────────────────────────────────────────────────────────────┤
│ GS │ VS │ ALT │ HDG │ BAT │ GPS │ WFB │ WP │ MISSION TIME          │
└──────────────────────────────────────────────────────────────────────┘

```

## Mission graph states

Support:

### COLLAPSED

Approximately 38–50 px.

Shows:

- node sequence
- active task
- overall mission progression

### NORMAL

Approximately 80–120 px.

Shows full zig-zag mission graph.

### EXPANDED / EDIT

Larger editor mode for configuring the graph.

This may temporarily consume more screen space.

Use animated geometry transitions.

On low-resolution screens, automatically collapse the graph if necessary.

---

# Q4 — AXON FLASK NETWORK ADDRESS

The final Axon/WFB tunnel address is not confirmed yet.

### DECISION

DO NOT BLOCK IMPLEMENTATION ON THIS.

Make the Axon Flask endpoint completely configurable.

Settings should expose something conceptually like:

```text
Axon Host
Axon Port
Connection Timeout
Health Poll Interval

```

Do not hardcode:

- 10.5.0.x
- 192.168.144.x
- localhost
- any guessed IP

Use configuration.

During development, support:

- mock Flask service
- localhost test service
- configurable real Axon endpoint

The final real IP can be inserted later without changing source code.

Suggested setting model:

```text
axonHost
axonPort

```

with safe defaults that do not pretend a connection exists.

---

# FLASK POLLING RATE

Use:

`1 Hz`

for normal Axon health updates.

Do NOT queue overlapping HTTP requests.

If the previous request is still pending, handle that correctly.

Use reasonable timeout/retry logic.

Critical Axon disconnect detection should be based on response age and/or heartbeat age.

---

# Q5 — PAYLOAD RELEASE

### DECISION

Use the existing PX4/QGC safe command architecture for the GCS-side action.

Do NOT implement direct unsafe hardware control inside QML.

The final actuator/channel mapping must remain configurable and must be verified before real hardware activation.

Until actual actuator mapping is confirmed:

- implement the UI
- implement confirmation flow
- implement backend abstraction
- keep actual hardware release disabled or explicitly unconfigured

## Safety behaviour

PAYLOAD RELEASE must require deliberate confirmation.

Example:

```text
RELEASE PAYLOAD?

Mission:
TASK 06 — PAYLOAD

Vehicle:
ARMED

[ CANCEL ]     [ CONFIRM RELEASE ]

```

The action should also be guarded by an allowed operational state.

Do not allow an accidental single keyboard press to release the payload.

`Ctrl+Shift+P`

should open/trigger the protected release flow, not bypass it.

Do not bypass PX4 safety or mission state requirements.

---

# Q6 — FLIGHT MODE SHORTCUTS

Implement:

```text
Ctrl+Shift+A     ARM
Ctrl+Shift+D     DISARM
Ctrl+Shift+R     RTL
Ctrl+Shift+L     LAND
Ctrl+Shift+P     PAYLOAD RELEASE

Ctrl+1           MANUAL / equivalent supported mode
Ctrl+2           STABILIZED
Ctrl+3           ACRO
Ctrl+4           RESERVED unless RATTITUDE actually exists
Ctrl+5           ALTITUDE
Ctrl+6           POSITION
Ctrl+7           MISSION

```

## IMPORTANT

Do not silently map unsupported modes.

Inspect the exact PX4/QGC mode list.

If RATTITUDE does not exist:

`Ctrl+4`

must remain:

`UNASSIGNED / RESERVED`

Do NOT map it to Acro behind my back.

The UI may show:

```text
Ctrl+4
Not assigned

```

in shortcut settings.

If Rattitude genuinely exists on the actual firmware later, enable the binding.

---

# Q7 — BOTTOM TELEMETRY

### DECISION: OPTION A

Keep ONE compact bottom telemetry rail.

Target height:

approximately:

`50–56 px`

Do NOT restore the old bottom Quick Actions section.

Quick Actions stay below the HUD.

Bottom rail should display information such as:

```text
GS
VS
REL ALT
HDG
BAT
GPS
WFB
WP
MISSION TIME

```

Example:

```text
GS 4.8 m/s │ VS +0.2 │ ALT 12.4 m │ HDG 284° │ BAT 84% │ GPS 18 │ WFB 24 dB │ WP 3/12

```

Use the space efficiently.

---

# TELEMETRY MICRO GRAPHS

Do not put a graph in every telemetry box.

Use micro charts only where they add useful information.

Recommended:

### ALTITUDE

10–30 second rolling trace

### BATTERY

short discharge trend

### WFB

SNR or packet-loss history

Potentially:

### GROUND SPEED

small trace if it remains readable

Charts refresh visually at:

`1 Hz`

---

# Q8 — LOGO

### DECISION

Use the existing Aerokle/AeroTHON logo asset during initial V2 development.

Do NOT invent a new permanent logo.

Search V1 thoroughly for:

- SVG
- PNG
- high-resolution source
- existing symbol-only asset
- branding source

If only:

`aerokle_logo.jpeg`

exists, use it temporarily.

Create the logo component so the asset can later be replaced with SVG without modifying the shell architecture.

The logo should be in the:

## TOP-LEFT CORNER

and should remain compact.

Do not redesign the brand identity without my approval.

---

# ADDITIONAL APPROVED ARCHITECTURE DECISIONS

## QGC CORE

Keep QGC backend behaviour intact.

Use it for:

- MAVLink
- Vehicle
- MissionManager
- FactSystem
- parameters
- GPS
- battery
- flight modes
- standard PX4 messages
- map
- normal mission behaviour
- guided commands

---

# AEROTHON CUSTOM C++ LAYER

The proposed architecture is approved in principle:

```text
QGC Backend
      │
      ▼
AeroTHON Custom C++ Services
      │
      ▼
AeroTHON QML UI

```

Proceed with isolated AeroTHON-specific C++ managers rather than contaminating QML with protocol logic.

Planned classes may include:

```text
AeroTHONManager
AeroPreflightManager
AeroMissionGraphModel
AeroAlertModel
AeroVideoReceiver

```

But verify QGC's exact APIs at commit `80c91d9` before implementing each hook.

Do not assume an API exists merely because it was mentioned in the planning report.

---

# MAVLINK HOOK

Before implementing:

`QGCCorePlugin::mavlinkMessageReceived()`

VERIFY that the exact mechanism exists and is appropriate at the selected QGC commit.

If it exists and is clean:

use it.

If not:

find the least-invasive supported hook.

Do not modify QGC core unnecessarily.

Document the chosen interception path.

---

# AEROTHON MAVLINK DIALECT

Carry forward:

`custom/mavlink/aerothon.xml`

as a starting point.

But do NOT assume it is automatically final.

Before generating bindings, compare the dialect against V2 requirements for:

- mission graph
- mission progress
- QR events
- banner events
- obstacle events
- Axon health
- camera health
- vision health
- command acknowledgement
- mission completion
- WFB if required

Prefer standard MAVLink messages whenever possible.

Only extend the custom dialect when truly required.

Never change message IDs casually.

---

# SECOND VIDEO STREAM

Proceed with the dual-stream architecture, but first inspect QGC's exact video implementation at the selected commit.

Goal:

```text
FPV
UDP 5600

NADIR
UDP 5601

```

Both H.264.

Required:

- simultaneous playback
- independent state
- automatic reconnect
- independent expand
- fullscreen
- resize without restarting pipeline where possible

Do not blindly duplicate VideoManager code until its architecture is understood.

---

# CAMERA EXPANSION

Both camera panels must support:

```text
NORMAL
EXPANDED
FULLSCREEN

```

A camera panel click or expand control should animate into the larger state.

ESC should return.

The decoder should remain alive during layout transitions.

---

# TELEMETRY UPDATE MODEL

This requirement is FINAL.

## Normal displayed telemetry

Refresh presentation at:

# 1 Hz

Examples:

- altitude
- ground speed
- vertical speed
- heading
- battery
- GPS count
- CPU
- RAM
- NPU
- WFB numeric values
- normal charts

Backend data may arrive faster.

Do NOT artificially throttle backend MAVLink reception.

---

# EVENT-DRIVEN STATES

The following must NOT wait for the 1-second UI timer:

- ARM/DISARM
- flight-mode change
- vehicle disconnect
- EKF critical failure
- critical battery state
- WFB link-loss event
- camera lost
- camera recovered
- Axon lost
- critical alert
- mission completion
- payload acknowledgement

These should update as soon as valid backend state is received.

Architecture should therefore separate:

```text
RAW SOURCE DATA
        │
        ├── EVENT-DRIVEN OPERATIONAL STATES
        │
        └── 1 Hz PRESENTATION TELEMETRY

```

---

# UI FONT SIZE

The old UI font was too small.

For V2:

## NORMAL UI TEXT BASELINE = 12 PX

Do not use normal operational text below 12 px.

Suggested hierarchy:

```text
Micro / exceptional annotation   11–12 px
Body                             12–13 px
Panel labels                     13–14 px
Section heading                  14–16 px
Telemetry value                  20–28 px
Large important value            24–32 px
Critical action                  15–18 px

```

Screen density must come from layout engineering, not unreadably tiny fonts.

---

# V2 VISUAL DIRECTION IS APPROVED

Combine:

## Structural layout

Dense professional mission-control layout.

## Technical outer language

From the cyan technical reference:

- dark navy
- thin cyan lines
- angular clipped details
- circuit/path geometry
- small yellow mission highlights
- ring gauges
- precision graph treatment

## Internal widgets

From the premium dark dashboard reference:

- smooth navy surfaces
- clear typography
- clean numeric hierarchy
- compact charts
- modern progress widgets
- controlled rounding
- sophisticated depth

Do not copy third-party branding/assets.

Create an original AeroTHON design system.

---

# UI MUST REMAIN TECHNICAL, NOT GAMING

Do not create:

- Tron UI
- cyberpunk HUD
- meaningless neon
- random hexagons
- animated background particles
- fake graphs
- constant cyan glow
- tiny unreadable techno text

All graphical treatment must represent real data or useful structure.

---

# FINAL FLIGHT SCREEN

Proceed toward:

```text
┌────────────────────────────────────────────────────────────────────────────┐
│ LOGO │ NAVIGATION              PX4 ● AXON ● WFB ● MODE │ ARM/DISARM       │
├─────┬─────────────────────┬────────────────────────────┬───────────────────┤
│ NAV │ HUD                 │                            │ FPV               │
│     │                     │                            │ ↗ EXPAND          │
│     ├─────────────────────┤            MAP             ├───────────────────┤
│     │ QUICK ACTIONS       │                            │ NADIR             │
│     │ RTL HOLD LAND ...   │                            │ ↗ EXPAND          │
│     ├─────────────────────┤                            │                   │
│     │ MESSAGES            │                            │                   │
│     │                     │                            │                   │
├─────┴─────────────────────┴────────────────────────────┴───────────────────┤
│ MISSION TASK GRAPH                                             [ EDIT ]   │
│ ✓ PREFLIGHT ━ ✓ TAKEOFF ━ ● SEARCH ╲ ○ QR ╲ ○ BANNER ╲ ○ RTL            │
├────────────────────────────────────────────────────────────────────────────┤
│ GS │ VS │ REL ALT │ HDG │ BAT │ GPS │ WFB │ WP │ MISSION TIME           │
└────────────────────────────────────────────────────────────────────────────┘

```

Do not interpret this as fixed literal pixel geometry.

Preserve responsiveness.

---

# DIRECT NAVIGATION

Provide small direct-navigation controls on the left.

I should be able to directly open important pages without traversing QGC Settings.

Required candidates:

- Flight
- Map
- Plan
- Mission
- Vehicle
- Parameters
- Analyze / Logs
- Systems
- Settings

Verify QGC page architecture.

Use the cleanest routing approach.

---

# QUICK ACTIONS

Quick Actions stay BELOW HUD.

Required candidates:

```text
RTL
HOLD
LAND
TAKEOFF
PAUSE
PAYLOAD
PREFLIGHT

```

ARM/DISARM stays more prominent in the global/top area.

Use compact technical buttons.

---

# MESSAGES

Below Quick Actions.

Filter and display:

```text
CRITICAL
WARNING
MISSION
SYSTEM
INFO

```

Sources:

- PX4
- Pixhawk
- Axon
- WFB
- cameras
- vision
- mission graph
- preflight
- operator commands

Do not print raw logs into the operational panel.

---

# MISSION GRAPH — APPROVED AS A CORE V2 FEATURE

This is not optional polish.

Build it as a central AeroTHON feature.

Each node must contain:

- unique ID
- name
- type
- state
- start timestamp
- completion timestamp
- optional mission-item association
- metadata
- previous/next relationships

States:

```text
NOT STARTED
ACTIVE
COMPLETED
FAILED
SKIPPED

```

---

# MISSION GRAPH HOVER

Hover a node and display:

```text
TASK
QR SCAN

STATUS
COMPLETED

STARTED
12:42:17

COMPLETED
12:42:31

STAGE TIME
18 s

EXECUTION TIME
14 s

```

For ACTIVE:

show live elapsed time.

For NOT STARTED:

show:

`NOT COMPLETED`

---

# GRAPH EDITOR

Provide an EDIT button.

Support planning/configuration of mission-specific graphs:

- add node
- remove node
- rename node
- reorder node
- change task type
- connect nodes
- duplicate
- insert
- save
- load
- cancel
- reset

Structural mission-graph editing must be restricted while the mission is active.

Do not let the operator accidentally restructure the active mission graph mid-flight.

---

# GRAPH STORAGE

Use a safe AeroTHON-specific persistence format.

Do NOT modify QGC `.plan` format unless absolutely necessary.

Preferred initial architecture:

AeroTHON JSON sidecar/profile associated with mission identity.

Design it so high-level AeroTHON tasks can optionally map to one or multiple QGC mission items.

The AeroTHON graph is NOT simply a duplicate of the QGC waypoint list.

---

# DETECTION ↔ MAP ↔ GRAPH SYNCHRONIZATION

APPROVE this additional feature.

When a QR/banner/obstacle event occurs:

1. add map marker if position exists
2. attach event to active mission node
3. highlight corresponding graph node briefly
4. add message/event entry
5. store timestamp and detection metadata

When clicking a detection marker:

show:

- detection
- mission task
- timestamp
- confidence if available
- position
- associated camera

Where practical, synchronize selection back to the graph.

---

# CAMERA SNAPSHOT LINKING

Implement architecture for associating a Nadir snapshot with important detections such as successful QR decode.

Do not allow uncontrolled storage growth.

Create configurable retention/storage policy.

The mission graph/event UI can show the associated snapshot.

---

# PREFLIGHT — APPROVED

Preflight is a small Quick Action button.

Full inspection opens only when clicked.

Maximum completion target:

# 60 SECONDS

Do not wait the full minute when systems respond sooner.

Run independent checks in parallel where appropriate.

---

# PREFLIGHT CHECK GROUPS

## PIXHAWK

Check:

- heartbeat
- vehicle connected
- PX4 state
- sensor health
- GPS
- EKF
- home
- battery
- mission
- failsafe
- armability

## AXON

Check:

- Flask response
- heartbeat
- CPU/RAM health
- temperature
- storage
- vision service
- mission service
- WFB service

## FPV

Check:

- camera/input
- decoder
- recent frames
- WFB output

## NADIR

Check:

- camera/input
- decoder
- recent frames
- QR/vision service
- WFB output

## LINK

Check:

- MAVLink
- WFB
- RSSI
- SNR
- packet loss

---

# PREFLIGHT RESULTS

Use:

```text
READY
READY WITH ADVISORIES
NOT READY
TIMEOUT

```

Use compact animated rows.

PX4 remains final authority for actual arming.

---

# AXON FLASK SERVICE — APPROVED

Proceed with a Flask-based companion health/preflight service.

Use Flask only for companion/system information.

Do NOT move Pixhawk flight control into REST.

Plan/implement versioned endpoints such as:

```text
/api/v1/health
/api/v1/system
/api/v1/cameras
/api/v1/vision
/api/v1/wfb
/api/v1/mission
/api/v1/preflight

```

Final exact endpoint structure may be refined during implementation.

Provide:

- Flask application
- collectors
- configuration
- logging
- systemd service
- installation instructions
- test commands
- mock/test service

---

# WFB

Implement:

- RSSI
- SNR
- packet loss
- bitrate
- telemetry status
- FPV status
- Nadir status where data allows

Thresholds remain:

```text
loss < 10%
NORMAL

10% <= loss < 30%
WARNING

loss >= 30%
CRITICAL

```

Do not invent metrics if unavailable.

---

# AI DIAGNOSTICS

Proceed with:

## V2 = RULES-BASED DIAGNOSTICS FIRST

This is approved.

It should explain common:

- preflight failures
- PX4 arm-denied reasons
- EKF issues
- GPS issues
- WFB degradation
- camera failure
- Axon loss
- mission task failure

Use actual state and known patterns.

No internet dependency.

Design interfaces so a local/remote LLM could be added later without rewriting the UI architecture.

AI remains advisory only.

---

# HIGH-VALUE IDEAS — APPROVED FOR V2

Include these in the implementation roadmap:

1. Mission phase ribbon / collapsed graph state
2. Detection linked to map and graph
3. Camera snapshot linked to mission node
4. Automatic mission summary
5. Quick diagnostic drill-down

Medium-value features may be implemented after core V2 stability:

6. WFB quality mapped on route
7. Mission-stage duration statistics
8. Preflight history
9. Estimated stage completion time
10. System health timeline

Do not delay core mission functionality for medium-priority analytics.

---

# AUTOMATIC MISSION SUMMARY

At mission completion, design/export a mission summary containing:

- mission name
- vehicle
- start/end time
- total duration
- stage durations
- execution durations
- waypoint progress
- detections
- QR result
- banner detections
- alerts
- camera health summary
- WFB summary
- preflight result

JSON is mandatory.

PDF may be implemented once JSON/report data is stable.

---

# BUILD ORDER

Proceed phase-by-phase according to the approved roadmap.

Do NOT attempt all 17 phases in one uncontrolled change set.

For every phase:

1. implement
2. build
3. run/test
4. inspect logs
5. fix regressions
6. commit/checkpoint if repository workflow supports it
7. continue

---

# PHASE 1 START AUTHORIZED

You may now:

1. verify V1 baseline read-only
2. clone QGC to `/home/deepa/AeroTHON-GCS-V2`
3. checkout verified baseline commit
4. initialize required submodules
5. create V2 planning/docs structure
6. create reproducible baseline build
7. verify stock QGC launches
8. only then begin AeroTHON V2 customization

---

# IMPORTANT — DO NOT KEEP ASKING FOR APPROVAL FOR NORMAL WORK

The overall plan is now approved.

Proceed independently through the roadmap.

Do not stop before every normal file change.

Only ask me again if there is a **genuine new blocker**, for example:

- required hardware mapping cannot be determined
- actual QGC API makes approved architecture impossible
- a requested PX4 operation is unsupported
- an implementation would require changing PX4 safety behaviour
- Axon network topology requires information that cannot be discovered
- a major design/architecture decision has no safe default

For non-blocking implementation decisions:

make the best professional engineering choice and document it.

---

# MAINTAIN IMPLEMENTATION LOG

Keep:

`docs/IMPLEMENTATION_STATUS.md`

Update after every phase.

Use:

```text
PHASE
STATUS

COMPLETED

FILES CHANGED

TESTS

ISSUES

NEXT STEP

```

Also maintain:

`docs/KNOWN_ISSUES.md`

Do not hide failures.

---

# FINAL REQUIREMENT

Build AeroTHON-GCS V2 as a serious autonomous UAV mission-control system.

The final product must combine:

- PX4/QGC reliability
- dense technical mission UI
- cyan/navy AeroTHON visual identity
- premium data widgets
- 12 px+ readable typography
- 1 Hz normal telemetry presentation
- event-driven safety-critical states
- dual expandable video
- compact HUD
- Quick Actions below HUD
- Messages below Quick Actions
- direct navigation
- customizable mission graph
- node timing/status hover
- one-minute preflight
- Pixhawk/Axon/camera readiness
- Flask companion health
- WFB monitoring
- alerts
- rules-based diagnostics
- mission reporting
- smooth purposeful animation

Never disturb:

`/home/deepa/AeroTHON-GCS`

That remains the working V1 reference.

---

# COMPLETE FEATURE APPROVAL + TELEMETRY ANIMATION REQUIREMENTS

This is an ADDITIONAL FINAL APPROVAL to the implementation authorization already given.

Everything in your proposed architecture, roadmap and `J. NEW IDEAS` section is approved.

Do not ask me again whether those proposed features should be included.

Proceed with them according to sensible implementation priority.

---

# 1. COMPLETE APPROVAL OF ALL PROPOSED IDEAS

I approve ALL ideas you proposed.

This includes:

## HIGH VALUE

1. Mission phase ribbon
2. Detection linked to map and mission graph
3. Camera snapshot linked to mission node
4. Automatic mission summary
5. Quick diagnostic drill-down

## MEDIUM VALUE

6. WFB quality mapped along flight route
7. Mission-stage duration statistics
8. Preflight history
9. Estimated stage completion time
10. System-health timeline

## PREVIOUSLY MARKED "LATER"

11. Telemetry freeze/replay
12. Event bookmarks
13. Route completion heatmap
14. AI diagnostics architecture

All of these are approved as AeroTHON features.

However, implementation must still follow engineering priority.

Do not delay:

- stable flight control
- telemetry
- map
- video
- preflight
- mission graph
- alerts

because an analytics/replay feature is unfinished.

Architect for all approved features from the beginning and implement them progressively after the core GCS is stable.

---

# 2. FEATURE PRIORITY

Use this priority:

```text
P0 — FLIGHT CRITICAL

PX4 connection
Vehicle state
Map
HUD
Telemetry
Arm/Disarm
Flight modes
RTL
Land
Mission
Alerts
Null safety

P1 — MISSION OPERATIONS

FPV
Nadir
Quick Actions
Messages
Mission graph
Preflight
Axon health
WFB health
Detection integration

P2 — MISSION INTELLIGENCE

Mission phase ribbon
Detection synchronization
Camera snapshots
Diagnostics
Mission summary
Stage timing
Preflight history

P3 — ANALYTICS

WFB route-quality map
System-health timeline
Estimated stage completion
Telemetry replay
Event bookmarks
Route heatmap
Historical mission statistics

```

Do not mix priority with visual importance.

Everything is approved.

Priority only defines implementation sequence.

---

# 3. TELEMETRY ROW ANIMATION IS NOW A REQUIRED FEATURE

The bottom telemetry rail must NOT look static/dead.

I want polished, technical animation whenever telemetry updates.

Normal displayed telemetry updates at:

# 1 Hz

The animation should make each update visibly smooth without making the values difficult to read.

---

# 4. TELEMETRY ROW CONTENT

Current intended compact rail:

```text
GS
VS
REL ALT
HDG
BAT
GPS
WFB
WP
MISSION TIME

```

Potential additional values may be available contextually.

Do not make the rail excessively tall.

Target approximately:

`50–56 px`

in normal desktop mode.

---

# 5. NUMBER TRANSITION ANIMATION

When a numeric telemetry value changes, do not abruptly replace the old number when a smooth transition is appropriate.

Examples:

```text
ALT
11.8
   ↓
12.4

```

should transition smoothly.

Likewise:

```text
GS
4.2 → 4.8

```

Use a restrained numeric interpolation/tween.

Recommended visual duration:

```text
180–300 ms

```

after the new 1 Hz sample arrives.

The full animation must finish well before the next normal telemetry sample.

---

# 6. DO NOT USE DISTRACTING ODOMETER ANIMATION EVERYWHERE

Do NOT make every digit continuously roll like a casino counter.

The interface must remain technical.

Preferred behaviour:

- smooth numeric tween where meaningful
- small opacity/position transition where interpolation is inappropriate
- stable unit and label
- stable container geometry

No bouncing numbers.

No exaggerated elastic effects.

No layout shifting.

---

# 7. FIXED-WIDTH / TABULAR TELEMETRY

Telemetry values must use tabular/fixed-width numerals where the selected font supports them.

Example:

```text
 9.8
10.1
11.7

```

must not cause the telemetry layout to move left/right.

The value region should have a stable width.

Units must remain fixed.

---

# 8. TELEMETRY VALUE HIERARCHY

Each item should resemble:

```text
ALT
12.4 m

```

not:

```text
RELATIVE ALTITUDE

12.4

METRES

```

Use:

- small technical label
- prominent value
- muted unit

Minimum normal font:

`12 px`

Primary telemetry values may use:

`20–26 px`

depending on resolution.

---

# 9. VALUE-CHANGE MICRO ANIMATION

When a value receives a new 1 Hz sample:

Possible sequence:

```text
NEW SAMPLE RECEIVED

old value
   ↓
subtle 80–120 ms fade/translate
   ↓
interpolated new value
   ↓
settle within ~250 ms

```

The movement should typically be only:

`1–3 px`

if translation is used.

Do not slide numbers across large distances.

---

# 10. TREND INDICATOR

Where useful, show a tiny transient trend indicator.

Examples:

Altitude increasing:

`▲`

Altitude decreasing:

`▼`

Vertical speed naturally already communicates direction.

WFB improving:

small upward indicator.

Battery falling normally:

do not generate constant warning arrows.

Trend icons should be subtle and disappear/settle after a short interval.

---

# 11. TELEMETRY MICRO CHART ANIMATION

Approved charts:

## RELATIVE ALTITUDE

Rolling line history.

## BATTERY

Discharge/voltage trend.

## WFB

SNR / packet-loss trend.

## OPTIONAL GROUND SPEED

Rolling speed trace if useful.

Charts update at:

`1 Hz`

---

# 12. GRAPH UPDATE ANIMATION

When a new graph sample arrives:

Do not redraw the entire graph abruptly.

Animate the plot naturally.

Preferred behaviour:

```text
old points shift left smoothly
new point enters from right

```

or use a controlled path interpolation.

Target transition:

```text
200–350 ms

```

Do not animate graph values in a way that misrepresents the actual sample.

The data is still discrete at 1 Hz.

---

# 13. CHART HISTORY

Default rolling history should be planned around approximately:

```text
Altitude       20–30 s
Ground speed   20–30 s
Battery        30–60 s
WFB            20–30 s

```

Make the architecture configurable.

Do not hardwire each chart implementation independently.

Create common rolling-history models/components.

---

# 14. TELEMETRY ACTIVE SAMPLE EFFECT

Consider a very subtle AeroTHON signature when a sample updates.

For example:

- a short cyan underline pulse
- tiny border highlight
- small graph-node glow
- 120 ms accent sweep

But only one subtle mechanism should be chosen.

Do NOT make the entire telemetry bar flash every second.

---

# 15. COLOR TRANSITIONS

Semantic state colors should animate smoothly when state changes.

Examples:

```text
WFB GOOD
green
   ↓
WFB DEGRADED
amber

```

Use approximately:

```text
150–250 ms

```

color transition.

For critical state:

the state may become red immediately or nearly immediately.

Do not make safety information wait for decorative animation.

---

# 16. CRITICAL TELEMETRY OVERRIDES NORMAL ANIMATION

Critical events must take priority over visual smoothness.

Examples:

- link lost
- critical battery
- EKF failure
- GPS loss
- Axon lost
- camera lost

These must update immediately.

Do NOT spend 300 ms interpolating into a critical value before showing the warning.

Use:

```text
critical state change
→ immediate semantic state
→ optional short warning entrance animation

```

---

# 17. FLIGHT MODE ANIMATION

When flight mode changes:

Example:

```text
POSITION
   ↓
MISSION

```

Animate the mode chip/label.

Suggested:

- old mode fades/slides out
- new mode fades/slides in
- state color updates

Duration:

`150–220 ms`

But actual flight mode state must be reflected immediately internally.

---

# 18. ARM / DISARM ANIMATION

ARM state is safety critical.

State transition should be obvious.

Example:

```text
DISARMED
   ↓
ARMING / command pending
   ↓
ARMED

```

Use actual PX4 acknowledgement/state.

Do not animate to ARMED merely because the button was clicked.

Only animate to the confirmed state when the vehicle reports it.

---

# 19. GPS ANIMATION

Satellite count:

```text
16 → 17 → 18

```

may animate numerically.

Fix-state changes:

```text
3D FIX → NO FIX

```

must be immediate and visually obvious.

Do not smooth away GPS failures.

---

# 20. WFB ANIMATION

WFB telemetry is a strong place to use the technical reference style.

Compact cell may show:

```text
WFB
24 dB

```

and tiny rolling graph.

When quality degrades:

```text
24 dB
21 dB
16 dB

```

numeric value transitions smoothly at normal 1 Hz sampling.

State threshold changes:

```text
GOOD
WARNING
CRITICAL

```

should receive semantic emphasis.

Packet-loss thresholds remain:

```text
<10%          NORMAL

10–29.999%    WARNING

>=30%         CRITICAL

```

---

# 21. BATTERY ANIMATION

Battery value should update smoothly.

Example:

```text
84%
↓
83%

```

Do not animate battery percentage continuously between backend samples.

Use only the actual received/displayed sample.

Small trend chart may move smoothly.

Critical threshold crossing must immediately apply critical state.

---

# 22. HEADING ANIMATION

Heading requires special handling because it wraps at:

`359° → 0°`

Do NOT interpolate:

```text
359 → 0

```

by rotating backwards through 359 degrees.

Implement shortest-path angular interpolation.

Examples:

```text
358° → 2°

```

should animate approximately:

`+4°`

not:

`-356°`.

This applies to:

- heading number if interpolated
- mini compass
- HUD heading element

---

# 23. ROLL / ATTITUDE ANIMATION

Do not force attitude itself down to 1 Hz.

The HUD needs smoother real-time movement.

Important distinction:

## HUD ATTITUDE

Use native/high-enough QGC attitude update rate for:

- artificial horizon
- roll
- pitch

with appropriate smoothing.

## TELEMETRY TEXT RAIL

Normal text presentation may update at 1 Hz.

Do NOT make the artificial horizon move only once per second.

That would make the HUD unusable.

---

# 24. VERTICAL SPEED

The VS display may use:

- numeric tween
- directional arrow
- compact accent

If the sign changes:

```text
+0.5
→
-0.4

```

transition direction clearly.

Do not use overly elaborate effects.

---

# 25. MISSION TIME

Mission time should behave like a real timer.

Do NOT update it only when a MAVLink packet happens to arrive.

Once mission timing is established from the backend state:

display elapsed mission time continuously and correctly.

A 1-second visual tick is appropriate.

---

# 26. WAYPOINT PROGRESS ANIMATION

Example:

```text
WP 3 / 12
      ↓
WP 4 / 12

```

When waypoint advances:

- number transition
- corresponding graph node state updates
- mission ribbon advances
- map active waypoint changes

Synchronize these visually.

Do not let three different parts of the UI update inconsistently.

---

# 27. MISSION GRAPH ANIMATIONS

Approved.

Graph should be one of the strongest AeroTHON animated elements.

When a task becomes ACTIVE:

- active node gains cyan highlight
- connector toward it becomes active
- small controlled pulse once
- task name becomes prominent

When completed:

- node transitions to completed state
- incoming edge fills/completes
- completion timing becomes available

When failed:

- node switches to failure state
- associated message appears
- relevant diagnostics become accessible

---

# 28. EDGE PROGRESS ANIMATION

Mission graph connector lines should be able to show progression.

Concept:

```text
●━━━━━━━○

```

During stage transition:

```text
●━━━╺────○

```

progress may advance along the edge if meaningful stage progress is known.

If exact progress is unknown:

do NOT fabricate a percentage.

Use an active-edge animation indicating "currently transitioning" rather than fake progress.

---

# 29. MISSION PHASE RIBBON — FULL APPROVAL

The Mission Phase Ribbon is approved.

Implement it as the collapsed state of the mission graph where practical.

Example:

```text
PREFLIGHT ✓  →  TAKEOFF ✓  →  SEARCH ●  →  QR ○  →  BANNER ○  →  RTL ○

```

Target height:

approximately:

`28–40 px`

depending on typography.

Active stage visible immediately.

---

# 30. DETECTION ↔ MAP ↔ GRAPH — FULL APPROVAL

Fully implement the proposed synchronization.

Example QR detection:

```text
QR received
   ↓
Map marker created
   ↓
Mission graph current node highlights
   ↓
Message inserted
   ↓
Nadir snapshot associated
   ↓
Detection record stored

```

Selections should synchronize where practical.

---

# 31. CAMERA SNAPSHOT — FULL APPROVAL

When mission-relevant detection occurs:

capture/retain an appropriate frame.

Associate with:

- mission node
- detection record
- timestamp
- geographic location if available

Provide storage management.

Do not save endless frames uncontrolled.

---

# 32. AUTOMATIC MISSION SUMMARY — FULL APPROVAL

Approved.

At mission completion produce structured mission summary.

Required first format:

# JSON

Include:

- mission identity
- start/end
- total duration
- task durations
- task execution times
- waypoint progression
- detections
- QR content
- banner events
- alerts
- preflight
- camera health
- Axon health summary
- WFB statistics

Then add:

# PDF REPORT

once the underlying report data is stable.

---

# 33. QUICK DIAGNOSTIC DRILL-DOWN — FULL APPROVAL

Approved.

Click:

```text
GPS
EKF
WFB
BAT
AXON
CAMERA

```

and open small contextual diagnostics next to the clicked item.

Avoid navigating away from Flight View.

Use:

- popover
- anchored panel
- click-away dismissal

---

# 34. WFB QUALITY MAP — FULL APPROVAL

Approved.

Record:

```text
timestamp
lat
lon
RSSI
SNR
loss
bitrate

```

at an appropriate rate.

Post-mission:

display link quality along the flown path.

Do not make the live operational map excessively colorful.

Provide toggle:

`LINK QUALITY`

---

# 35. MISSION-STAGE STATISTICS — FULL APPROVAL

Approved.

Track historical mission runs.

Example:

```text
SEARCH-1

RUNS      8
AVG       14.2 s
MIN        9.8 s
MAX       22.1 s

```

Keep mission/profile identities separated.

Do not mix statistics from unrelated mission definitions.

---

# 36. PREFLIGHT HISTORY — FULL APPROVAL

Approved.

Persist every preflight session.

Store:

- timestamp
- aircraft
- mission
- result
- individual checks
- failure reasons
- duration

Expose in Systems/Logs.

Use a robust format.

JSONL is acceptable initially if architecture supports migration later.

---

# 37. ESTIMATED STAGE COMPLETION — FULL APPROVAL

Approved.

Only calculate ETA when enough historical information exists.

Do NOT present false precision.

Example:

```text
SEARCH
Estimated remaining:
~12 s

```

If data confidence is insufficient:

do not display estimate.

---

# 38. SYSTEM HEALTH TIMELINE — FULL APPROVAL

Approved.

Systems screen should provide approximately:

- CPU
- RAM
- NPU
- temperature
- battery
- WFB

over session history.

Normal live telemetry rail still uses tiny charts.

Systems screen gets the larger detailed graphs.

---

# 39. TELEMETRY FREEZE / REPLAY — FULL APPROVAL

Approved.

Plan the recording architecture now.

Record sufficient timestamped state to support later replay.

Do not interfere with QGC's existing ULog/telemetry logging.

AeroTHON replay is an additional operator/session view.

Consider SQLite for V2 if appropriate.

---

# 40. REPLAY SYNCHRONIZATION

Long-term replay should synchronize:

```text
map
mission graph
telemetry
messages
detections
WFB
system health

```

and, where recorded video/time references exist:

camera events.

Do not require all replay capabilities before basic session recording can ship.

---

# 41. EVENT BOOKMARKS — FULL APPROVAL

Approved.

Add operator bookmark capability.

Possible shortcut can be proposed.

Bookmark stores:

- timestamp
- mission time
- current task
- vehicle location
- optional note

Show in Logs/Replay.

---

# 42. ROUTE COMPLETION HEATMAP — FULL APPROVAL

Approved.

This is post-mission/historical analysis.

Do not overload live Flight View.

Provide as optional map layer.

---

# 43. AI DIAGNOSTICS — FULL APPROVAL

Approved architecture:

## V2

Rules-based/offline first.

## Future enhancement

LLM adapter can be added without changing UI architecture.

Design an abstraction such as:

```text
DiagnosticEngine
    │
    ├── RulesEngine
    └── FutureLLMProvider

```

Do not make an internet service mandatory.

---

# 44. ANIMATION SYSTEM MUST BE CENTRALIZED

Create one motion definition system.

Example conceptual tokens:

```text
AeroMotion.instant
AeroMotion.micro
AeroMotion.fast
AeroMotion.normal
AeroMotion.panel
AeroMotion.camera
AeroMotion.major

```

Do not hardcode random durations in every QML file.

---

# 45. REDUCE MOTION

Provide:

`Reduce Motion`

setting.

When enabled:

- eliminate decorative transitions
- retain necessary state changes
- keep safety information immediate
- retain essential graph updates without distracting interpolation

---

# 46. PERFORMANCE BUDGET

Animations must not compromise:

- FPV
- Nadir
- map
- MAVLink
- HUD
- alerts

Target:

`60 FPS UI where hardware permits`

Normal charts:

`1 Hz`

Normal telemetry text:

`1 Hz`

HUD attitude:

higher native rate

Safety states:

event driven

---

# 47. IMPLEMENTATION AUTHORIZATION

All proposed ideas are approved.

You do NOT need to ask me:

"Should I add the mission ribbon?"

"Should I implement preflight history?"

"Should I add WFB route mapping?"

"Should I add replay?"

"Should I implement mission summary?"

The answer is:

# YES.

Include them in the architecture and implementation roadmap.

Only ask me again for genuine blockers involving:

- unknown hardware mappings
- unsupported PX4 functionality
- unavailable network topology
- safety-critical ambiguity
- major unavoidable architecture conflicts

---

# 48. KEEP CORE DEVELOPMENT ORDER

Do not jump straight into analytics.

Build in this sequence:

```text
BASE QGC
    ↓
DESIGN SYSTEM
    ↓
FLIGHT SHELL
    ↓
REAL TELEMETRY
    ↓
HUD
    ↓
MAP
    ↓
DUAL VIDEO
    ↓
ACTIONS
    ↓
MESSAGES
    ↓
MISSION GRAPH
    ↓
AXON
    ↓
PREFLIGHT
    ↓
WFB
    ↓
DETECTIONS
    ↓
DIAGNOSTICS
    ↓
MISSION INTELLIGENCE
    ↓
HISTORY / ANALYTICS
    ↓
REPLAY
    ↓
POLISH
    ↓
VALIDATION

```

---

# 49. FINAL UI FEEL

AeroTHON should feel technically alive.

Not because random things constantly move.

It should feel alive because:

- telemetry transitions smoothly
- charts continuously accumulate real history
- attitude responds smoothly
- mission graph reflects real progression
- camera panels expand naturally
- messages enter cleanly
- preflight visibly progresses
- map/detections synchronize
- state changes have purposeful motion
- operator interactions receive immediate feedback

This is the desired animation philosophy.

---

# 50. FINAL APPROVAL

The complete V2 concept is approved.

Proceed with:

- all original requirements
- all approved architectural decisions
- all 14 proposed ideas
- all telemetry animations defined above
- all mission graph functionality
- all Axon/Flask work
- all WFB functionality
- all dual-video functionality
- all preflight functionality
- all approved analytics
- all rules-based diagnostics
- fresh isolated QGC V2 project
- full visual redesign

Do not disturb:

`/home/deepa/AeroTHON-GCS`

Build only in:

`/home/deepa/AeroTHON-GCS-V2`

Proceed with implementation.

---

# FINAL EXECUTION COMMAND

All planning decisions, architecture choices, feature approvals, telemetry-animation requirements, mission-intelligence features, analytics features, and implementation priorities above are approved.

Proceed independently through the approved phased implementation. Stop only for a genuine new blocker involving an unknown hardware mapping, unavailable network topology, unsupported PX4 capability, safety-critical ambiguity, or unavoidable major architecture conflict.

Do not disturb `/home/deepa/AeroTHON-GCS`.

Build only in `/home/deepa/AeroTHON-GCS-V2`.

# START IMPLEMENTATION NOW.
