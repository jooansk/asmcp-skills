---
name: conveyor-station
description: "Sample skill: a belt conveyor station in an OMC machine - its three parts (homing that empties the belt, manual control of the belt and the stopper, the automatic sequence) and how ASMCP's tools build it. Use when a machine has a belt conveyor with part sensors and a stopper."
metadata:
  group: stations
  version: "0.1.0"
  min-asmcp: "1.44.0"
  requires-tools: "add_station, add_device"
---
# Conveyor station (sample)

A belt conveyor carries parts to a stop position, where the next station takes them. Build it like every OMC station
(asmcp-omc): design the three parts with the user before any code.

## The three parts

1. **Homing** empties the belt: the stopper retracts, the belt runs until no part sensor has seen a part for a set
   time, then stops.
2. **Manual**: the belt (forward, stop) and the stopper (extend, retract) as devices on the HMI's device page
   (asmcp-devices).
3. **Automatic**: stopper out, belt runs until the part sensor at the stop sees a part, belt stops, the station
   reports "part ready"; after the next station took the part, the stopper retracts briefly to let it pass.

## With ASMCP's tools

- `add_device` for the belt motor and the stopper valve (time-simulated sensors work without hardware).
- `add_station` for the station's Ladder sequence, then the steps from part 3.
- Test every part on ARsim before the next one.

The open questions to ask the user are in [checklist.md](checklist.md).
