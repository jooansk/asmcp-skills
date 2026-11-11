---
name: plant-simulation
description: "Sample skill: testing a machine on ARsim without hardware - the least simulation that makes each station answer (DevLib's Simulate parameters, a station's plant action, a plant program for parts between stations and for processes), one switch that keeps it off the real machine, ST patterns for cylinders, a belt with a part, neighbour stations, a tank and a temperature, and a test round that drives the operator panel and injects faults. Use when a machine or station must be tested on ARsim, or a neighbour machine is missing."
metadata:
  group: engineering
  version: "0.1.0"
  min-asmcp: "1.44.0"
  requires-tools: "add_station, add_program, write_variable, watch_variables, read_variables, assign_task"
---
# Plant simulation for ARsim tests (sample)

A station shows its steps, timeouts and alarms only when its sensors answer its commands. On ARsim nothing answers
by itself: the plant simulation plays the machine - the cylinders, the parts, the neighbours, the process - so the
real program runs unchanged. Write as little of it as the test needs.

**Status of this sample (0.1.0):** the five patterns of section 3 compile as printed, together in one program with
DevLib's types (2026-11-11, AS 6.7, a scratch project). The I/O point in section 2 is not measured.

## 1. The least simulation that works

| What must answer | Use | Code |
|---|---|---|
| a valve's end sensors, a vacuum switch (DevLib devices) | the device's parameter `Simulate` true: the sensors follow the outputs (as_guide 'devices') | none |
| a mapp Motion axis | ARsim runs the axis in simulation (as_guide 'axis') | none |
| a mapp Temperature zone, a hydraulic axis, a tension zone | the component's own simulation (as_guide 'temperature', 'hydraulics', 'webhandling') | configuration |
| a sensor that depends on the process inside one station (a height reached, a part under a sensor) | the station's plant action `SimPlant` (as_guide 'diagnosis' section 4) | an ST action |
| the station's neighbours (a part offered, a part taken) | the same plant action | a few lines |
| parts moving between stations, a tank, a temperature without mapp | a plant program in `Logical/Simulation` | a program |

Start with the first rows; add code only for what is still silent.

## 2. Never on the machine

- **One switch** for the whole machine: `gPlantSim : BOOL; (*ARsim only: TRUE runs the plant simulation*)` in
  Logical/Global.var, FALSE by default, never RETAIN. The test sets it with write_variable. Every plant action is
  called by a rung with `"when": "gPlantSim"`, and the plant program does nothing while it is FALSE. (as_guide
  'diagnosis' uses one `PlantSim` per station; with several stations, one global switch is simpler to test.)
- **When the project has a configuration for ARsim** (list_configurations), assign the plant program only there
  (`assign_task` in that configuration), and keep the switch as the second guard. Tell the user which configuration
  has it.
- **Sensors the plant writes:** the I/O system latches mapped inputs at the start of every cycle (as_guide 'runtime'
  section 6), so on ARsim it may overwrite what the plant wrote into a mapped `di...` variable. Not measured yet:
  check it once with watch_variables. If it does, leave those channels unmapped in the ARsim configuration (each
  configuration has its own I/O mapping) or let the station read the DevLib device's status instead.
- The plant program runs in the stations' task class, so a sensor answers one cycle after its command, as on the
  machine.

## 3. Patterns (ST)

Speeds and times are **variables with initial values**, not constants: the test slows one down with write_variable
to see a timeout or a step-time warning. Units per cycle of the plant's task class.

**A cylinder** whose station reads its sensors directly (no DevLib device with `Simulate`):
```
IF doClampClose THEN
	ClampPos := MIN(ClampPos + ClampStep, 1.0);
ELSE
	ClampPos := MAX(ClampPos - ClampStep, 0.0);
END_IF;
diClampClosed := ClampPos >= 1.0;
diClampOpen := ClampPos <= 0.0;
```
(`ClampPos : REAL; (*Simulation: 0 open .. 1 closed*)`, `ClampStep : REAL := 0.1; (*[1/cycle] Simulation: stroke per cycle*)`)

**One part on a belt section** up to a stopper (a DevLib motor `gInfeedBelt` and valve `gInfeedStopper`):
```
IF NOT PartOnBelt AND NextPartDelay.Q THEN
	PartOnBelt := TRUE;
	PartPos := 0.0;
END_IF;
IF PartOnBelt AND gInfeedBelt.Status.Running THEN
	PartPos := PartPos + BeltStep;
	IF gInfeedStopper.Status.AtFront THEN
		PartPos := MIN(PartPos, StopPos);
	END_IF;
END_IF;
diPartAtStop := PartOnBelt AND (ABS(PartPos - StopPos) < SensorWindow);
IF PartOnBelt AND ((PartPos > BeltLength) OR PartLifted) THEN
	PartOnBelt := FALSE;
END_IF;
NextPartDelay(IN := NOT PartOnBelt AND FeedParts, PT := FeedInterval);
```
Several parts at once: an array of positions, each kept at least one part pitch behind the one ahead.

**The neighbours of a station**, in its plant action (here the pick-and-place sample's handshakes):
```
IF PickDone THEN
	PartAtPick := FALSE;
END_IF;
OfferNextPart(IN := NOT PartAtPick AND NOT PickDone, PT := SimFeedDelay);
IF OfferNextPart.Q THEN
	PartAtPick := TRUE;
END_IF;
TakePlacedPart(IN := PartPlaced, PT := SimTakeDelay);
PartTaken := TakePlacedPart.Q;
```

**A tank** (level in litres, an analog input 0..32767):
```
IF gInletValve.Status.AtFront THEN
	TankLevel := TankLevel + InflowStep;
END_IF;
IF gDrainPump.Status.Running THEN
	TankLevel := TankLevel - DrainStep;
END_IF;
TankLevel := LIMIT(0.0, TankLevel, TankVolume);
aiTankLevel := REAL_TO_INT(TankLevel / TankVolume * 32767.0);
diTankHigh := TankLevel > HighLevel;
```

**A temperature** without mapp Temperature (first-order: towards the heater's end temperature, else the ambient):
```
IF doHeaterOn THEN
	TargetTemp := HeaterMaxTemp;
ELSE
	TargetTemp := AmbientTemp;
END_IF;
ActTemp := ActTemp + (TargetTemp - ActTemp) * TempFactor;
aiZoneTemp := REAL_TO_INT(ActTemp * 10.0);
```

Each needs its declarations with units (as_guide 'guidelines' C201) in the program's or station's Variables.var.

## 4. The test round

The user decides whether ARsim runs, and whose: check the running ARsim first, say how long the round takes, and
keep it to one measurement per new mechanism.
1. `build simulation=true transfer=true`, then write_variable `gPlantSim` TRUE.
2. The operator panel as in as_guide 'omc' section 9: `OmcArea1:diSafetyOk` TRUE, Start (homing), Ack, Auto.
3. watch_variables on `AutoArea1.Status`, the stations' step bits and handshakes - or the program monitor
   (as_guide 'diagnosis').
4. Every transition of the omc table, not only Auto: production stop, Stop held, safety stop with a part held,
   Manual and back.
5. Faults: slow one actuator down (its step variable) for a timeout and a step-time warning; hold a sensor; take a
   neighbour away. Each alarm must appear with its text and go with Ack.
6. Report per row what you saw, and what stays for the real machine: real sensor timing, drives under load, the
   safety functions (never tested by a plant).

## Pitfalls

- A plant that runs on the machine writes over real sensors: two guards (the switch, and the configuration).
- A plant in a slower task class than its stations: sensors answer late, step times are wrong.
- A plant that answers in the same cycle as the command hides timing faults: one cycle later is realistic.
- A perfect plant only shows the good case: the faults of step 5 are the reason for the plant.
- Task-local variables of another program cannot be written from a plant program: simulate a station's own signals
  in its plant action, and use globals only for what is global anyway.
