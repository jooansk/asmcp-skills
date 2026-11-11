---
name: pick-and-place
description: "Sample skill: a pick-and-place station in an OMC machine - a gripper lift, a slide (pneumatic, or a servo axis on a gantry) and a vacuum gripper that move parts from an infeed to the next station: the devices, the three parts (homing that clears the gripper, manual control of each device with interlocks, the automatic cycle with handshakes on both sides), the part kept in the gripper across mode changes, the add_device and add_station calls, the ARsim test. Use when a machine lifts parts from one place and sets them down at another."
metadata:
  group: stations
  version: "0.2.0"
  min-asmcp: "1.44.0"
  requires-tools: "add_object, add_device, add_station, add_page, add_faceplate, write_variable, watch_variables"
---
# Pick-and-place station (sample)

A vacuum gripper on a lift takes a part at the pick position (the infeed's stop), a slide carries it to the place
position (the next station), the lift sets it down. Build it like every OMC station (as_guide 'omc', 'devices'):
design the three parts with the user before any code, using the questions in [checklist.md](checklist.md).

**Status of this sample (0.2.0):** the calls below were run as printed (2026-11-11, AS 6.7, AR 6.8.1 ARsim, a 100 ms
task class): 0 errors, and all eight rows of the ARsim test passed. The test found a bug in 0.1.0, fixed here (see
"Never reset a held state with the last homing step"). Not yet used on a real machine.

## The devices

| Device | Kind | Front / On | Sensors (default) | Interlock |
|---|---|---|---|---|
| `PickZ` gripper lift | valve | down | down and up | down only with the slide at one of its ends |
| `PickX` slide | valve (or axis, below) | place side | pick side and place side | moves only with the gripper up |
| `PickVacuum` suction cup | vacuum | suction on | vacuum switch | - |

First the machine-function package (add_device makes its program, but not the package; add_station would):
`add_object template=EmptyPackage name=Handling parent=Logical description='Handling: the pick-and-place station'`.
```
add_device name=PickZ kind=valve program=PickDev parent=Logical/Handling task_class=<the area's> description='Gripper lift: front = down' parameters={"MoveTime": "T#1s"} interlocks=[{"permit": "PermitFront", "when": "gPickX.Status.AtFront OR gPickX.Status.AtBack", "text": "slide between its ends"}]
add_device name=PickX kind=valve program=PickDev description='Slide: back = pick side, front = place side' parameters={"MoveTime": "T#2s"} interlocks=[{"permit": "PermitFront", "when": "gPickZ.Status.AtBack", "text": "gripper not up"}, {"permit": "PermitBack", "when": "gPickZ.Status.AtBack", "text": "gripper not up"}]
add_device name=PickVacuum kind=vacuum program=PickDev description='Suction cup on the gripper' parameters={"BlowTime": "T#100ms"}
```
The interlocks refer to each other: add all three, then build. Sensors the real machine lacks:
`HasFrontSensor` / `HasBackSensor` false (time-simulated), `HasSwitch` false for the vacuum.

## The three parts

1. **Automatic** (St1-St9): wait for a part and a free place position; lower; suck; lift; report the pick to the
   infeed and slide over; lower; release; lift and report the part placed; slide back. The infeed and the next
   station each get one handshake pair, and each signal has one producer (as_guide 'omc' section 5).
2. **Homing** (Hm1-Hm4): lift first (nothing collides), then slide back to the pick side, then open the gripper.
   A part still in the gripper drops at the pick position, and the infeed's homing runs it out as a reject - this is
   the default the checklist asks the user about (keep and place it, or wait for the operator, are the others).
3. **Manual**: each device by hand from the station's manual page; the interlocks above hold here too, and the
   faceplate shows the refused reason.

**The part in the gripper survives mode changes:** a reset request clears every step bit, so suction driven by the
steps alone would drop the part when the operator leaves Manual. `GripperLoaded` is set when the part is held and
reset only where the gripper is meant to open (St7, Hm3); the suction rung ORs it in. It is a holding command:
no mode bit in that rung (the user's rule). Only STOP switches the suction off (DevLib, the safety stop comes first).

## The station

```json
{ "area": "AutoArea1", "name": "PickPlace", "parent": "Logical/Handling",
  "description": "Pick and place: lifts a part at the infeed's stop and sets it down at the next station",
  "auto": [
    { "comment": "Wait for a part at the pick position and a free place position" },
    { "comment": "Lower the gripper onto the part", "when": "PartAtPick AND NOT PickDone AND NOT PartPlaced" },
    { "comment": "Down - suck the part", "when": "gPickZ.Status.AtFront" },
    { "comment": "Part held - lift it", "when": "gPickVacuum.Status.Held" },
    { "comment": "Up - report the pick, slide to the place position", "when": "gPickZ.Status.AtBack" },
    { "comment": "Over the place position - lower the part", "when": "gPickX.Status.AtFront" },
    { "comment": "Down - release the part", "when": "gPickZ.Status.AtFront" },
    { "comment": "Released - lift the gripper", "when": "NOT gPickVacuum.Status.Held" },
    { "comment": "Up - report the part placed, slide back to the pick position", "when": "gPickZ.Status.AtBack" } ],
  "cycle_done": { "when": "gPickX.Status.AtBack" },
  "homing": [
    { "comment": "Lift the gripper" },
    { "comment": "Up - slide back to the pick side", "when": "gPickZ.Status.AtBack" },
    { "comment": "At the pick side - open the gripper", "when": "gPickX.Status.AtBack" },
    { "comment": "Gripper open - homed", "when": "NOT gPickVacuum.Status.Held" } ],
  "commands": [
    { "comment": "Gripper down: lowering, sucking, lowering at the place position, releasing", "when": "St2 OR St3 OR St6 OR St7", "out": ["gPickZ.Cmd.Front"] },
    { "comment": "Slide on the place side from the pick report until the gripper is up again", "when": "St5 OR St6 OR St7 OR St8", "out": ["gPickX.Cmd.Front"] },
    { "comment": "A part is in the gripper: kept across mode changes and the reset request", "when": "St4", "out": ["S GripperLoaded"] },
    { "comment": "The gripper opens: release at the place position, or the homing", "when": "St7 OR Hm3", "out": ["R GripperLoaded"] },
    { "comment": "Suction while sucking and while a part is in the gripper (holding command: no mode bit)", "when": "St3 OR St4 OR GripperLoaded", "out": ["gPickVacuum.Cmd.On"] },
    { "comment": "Handshake to the infeed: the part is lifted off", "when": "St5", "out": ["S PickDone"] },
    { "comment": "Handshake: the infeed took its PartAtPick away", "when": "NOT PartAtPick", "out": ["R PickDone"] },
    { "comment": "Handshake to the next station: a part lies at the place position", "when": "St9", "out": ["S PartPlaced"] },
    { "comment": "Handshake: the next station took the part", "when": "PartTaken", "out": ["R PartPlaced"] } ],
  "timeouts": [
    { "step": "St2", "time": "T#2s", "alarm": "AlmGripperNotDown", "comment": "Gripper not down at the pick position" },
    { "step": "St3", "time": "T#1s", "alarm": "AlmNotSucked", "comment": "Part not sucked" },
    { "step": "St4", "time": "T#2s", "alarm": "AlmGripperNotUp", "comment": "Gripper not up after the pick" },
    { "step": "St5", "time": "T#3s", "alarm": "AlmSlideNotAtPlace", "comment": "Slide not at the place position" },
    { "step": "St6", "time": "T#2s", "alarm": "AlmGripperNotDown", "comment": "Gripper not down at the place position" },
    { "step": "St7", "time": "T#1s", "alarm": "AlmNotReleased", "comment": "Part not released" },
    { "step": "St8", "time": "T#2s", "alarm": "AlmGripperNotUp", "comment": "Gripper not up after the release" },
    { "step": "St9", "time": "T#3s", "alarm": "AlmSlideNotAtPick", "comment": "Slide not back at the pick position" },
    { "step": "Hm1", "time": "T#2s", "alarm": "AlmGripperNotUp", "comment": "Gripper not up while homing" },
    { "step": "Hm2", "time": "T#3s", "alarm": "AlmSlideNotAtPick", "comment": "Slide not back while homing" },
    { "step": "Hm3", "time": "T#1s", "alarm": "AlmNotReleased", "comment": "Gripper not open while homing" } ],
  "alarms": [
    { "when": "GripperLoaded AND NOT gPickVacuum.Status.Held", "delay": "T#200ms", "alarm": "AlmPartLost", "text": "Part lost from the gripper" },
    { "when": "gPickZ.Status.Error", "alarm": "AlmLiftError", "text": "Gripper lift: end position not reached" },
    { "when": "gPickX.Status.Error", "alarm": "AlmSlideError", "text": "Slide: end position not reached" } ],
  "variables": "PartAtPick : BOOL; (*From the infeed: a part waits at the pick position*)\nPartTaken : BOOL; (*From the next station: it took the part from the place position*)\nPickDone : BOOL; (*To the infeed: the part is lifted off*)\nPartPlaced : BOOL; (*To the next station: a part lies at the place position*)\nGripperLoaded : BOOL; (*A part is in the gripper: keeps the suction on*)" }
```

Notes:
- The station's name is its task's name: at most 10 characters (add_station refuses `PickStation`).
- No timeout on St1 (it waits for work) nor on Hm4 (the last homing step stays active).
- **Never reset a held state with the last homing step:** it stays set after the homing, in Auto too. A first
  version reset `GripperLoaded` with the last step, and on ARsim the suction dropped the part after every pick.
  Opening the gripper is therefore a step of its own (Hm3), and Hm4 only reports "homed".
- `PartAtPick` and `PartTaken` are station variables so the station builds and tests alone. In the machine, use
  the neighbours' reports in the `when`s instead (the conveyor station's "part ready", the next station's "taken"),
  or copy them in an ST action the first command rung calls.
- Step times (on by default) fit every step from St2: they are all the station's own moves.

## Servo slide instead of the valve (gantry)

`PickX` as `kind=axis` (an axis configuration first: as_guide 'axis') with `PermitMove` = `gPickZ.Status.AtBack`.
The slide's rungs change:
- St5 -> `gPickX.Cmd.MoveAbsolute` with `Cmd.Position` = the place position, St9 and Hm2 -> the pick position: an
  ST action sets `gPickX.Cmd.Position` from the step that uses it (as_guide 'omc', "a step's data in the step that
  uses it").
- The transitions wait for `AtPlace` / `AtPick`, each its own comparison on `gPickX.Status.Position` within a
  window, ANDed with `gPickX.Status.InPosition`; the lift's interlock uses the same two bits.
- `Cmd.MoveAbsolute` starts on its rising edge: the move steps must not follow each other directly.
- The homing homes the axis (`Cmd.Home`) after the lift is up, then moves to the pick position.

## Manual page

`add_page` `PickManual`, then `add_faceplate` per device (`device=PickZ front=Down back=Up`, `device=PickX
front=Place back=Pick`, `device=PickVacuum`), each enabled only in Manual (as_guide 'devices' section 5).

## Test on ARsim

The user decides whether ARsim runs. Without hardware: `Simulate` true in the valves' and the vacuum's parameters
(their sensors follow the outputs), the neighbours played with write_variable. Then as_guide 'omc' section 9
(`OmcArea1:diSafetyOk` TRUE, Start, Ack) and:

| # | Do | Expect |
|---|---|---|
| 1 | homing | Hm1-Hm4, `gPickPlace.HomingDone`; gripper up, slide on the pick side, suction off. The valves already go back in ReadyHoming (no step commands them), so Hm1-Hm2 pass at once |
| 2 | Auto, `PickPlace:PartAtPick` TRUE | St2-St5, `GripperLoaded` and `Held` TRUE, `PickDone` TRUE; `PartAtPick` FALSE -> `PickDone` FALSE |
| 3 | let it run on | St6-St9, the part held until St7, `PartPlaced` TRUE, back in St1 (measured: 5.6 s a cycle); a new `PartAtPick` waits until `PartTaken` |
| 4 | `PartTaken` TRUE until `PartPlaced` is FALSE, then FALSE | `PartPlaced` FALSE; the next cycle can start |
| 5 | Manual while St5 holds the part, then out of Manual | the suction stays on through Manual and the reset request (`GripperLoaded`); after Start, Hm3 opens the gripper and Hm4 reports homed, no `AlmPartLost` |
| 6 | Manual: lower the gripper (`gPickZ.Hmi.Front`), then move the slide | the slide is refused, `RefusedText` "gripper not up" |
| 7 | `diSafetyOk` FALSE with a part held | Stop at once, suction off, `AlmPartLost` after 200 ms; safety back -> ReadyAuto, Start -> the frozen cycle goes on |
| 8 | vacuum without `Simulate` (`gPickVacuum.Par.Simulate` FALSE) | St3 waits with the suction on, `AlmNotSucked` after 1 s |

All eight passed on ARsim (2026-11-11). How the test was driven:
- **Stopping the cycle in St5 with the part held** (rows 5 and 7): St5 to the release takes under 2 s, too short to
  switch modes by hand. Before the part: `gPickX.Par.Simulate` FALSE and `PickDev:diPickXBack` TRUE - the slide
  keeps its back sensor, the place sensor never comes, and St5 waits (with `AlmSlideNotAtPlace` after 3 s and the
  slide's device error). Put both back afterwards (`Simulate` TRUE, `diPickXBack` FALSE) and Ack.
- **A held Ack hides alarms:** the alarms-off rung resets them in every scan while Ack is TRUE. Write Ack TRUE, then
  FALSE, before looking for an alarm.
- **A handshake pulse must last a cycle:** two write_variable calls in a row can land in one 100 ms cycle. Write
  `PartTaken` TRUE with watch_variables `until PickPlace:PartPlaced = FALSE`, then FALSE.
- Run dependent watch_variables one after the other, never in one message: they run in parallel.

Report each row as seen.
