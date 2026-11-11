# Pick-and-place station: questions for the user

Ask before the first program; write the answers into ASMCP-work.md (as_guide 'workflow').

## Mechanics
- Slide: pneumatic cylinder with two end positions, or a servo axis (several place positions, a gantry)?
- Lift: a cylinder, or a second axis? Is there a middle position (e.g. a lower place height)?
- Gripper: vacuum with a vacuum switch, vacuum without a switch (time only), or a mechanical gripper with open / closed
  sensors (then a valve device instead of the vacuum)?
- Which end positions have sensors? Without one, the device counts the position as reached after its move time.
- Move times of each cylinder (for the timeouts and step-time supervision).

## Neighbours
- Which signal says a part waits at the pick position (the infeed's stop, a sensor of its own)?
- How does the infeed learn that the part is taken (`PickDone`), and when may it bring the next one?
- What says the place position is free, and how does the next station report that it took the part (`PartTaken`)?
- May the station already pick the next part while the last one still lies at the place position?

## Homing and faults
- A part in the gripper at homing: drop it at the pick position (the default: the infeed runs it out as a reject),
  set it down at the place position, or stop and wait for the operator to remove it?
- A part lost on the way (vacuum gone): alarm and stop (the default), or reject and go on?
- Blow-off pulse when releasing: needed, and how long?

## Manual
- Names on the manual page: Down / Up, Pick / Place, Suction on / off - or the machine's own words?
- Extra interlocks in Manual beyond the automatic ones (e.g. the lift only with a part present)?

## Production
- Cycle time target: does it need the slide moving while the lift is still finishing (overlapping steps)?
- Products with different heights or positions: a recipe value per product (as_guide 'features')?
