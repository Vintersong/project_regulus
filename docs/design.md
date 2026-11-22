# Regulus — Design Notes

## Core loop
- The player moves along the edge of the claimed area, then cuts into open territory to draw a line.
- Closing the line back on claimed territory captures the enclosed region (flood fill, on the side away from the enemy).
- Enemies that touch the line, or the player while drawing, cost a life.
- A level is cleared at the capture target (default 75%), which reveals that sign's plate.

## Structure
- 12 levels, one per zodiac sign, each with its own plate.
- Platform: desktop first, mobile after. Landscape.

## Powerups (open, details undecided)
- **Earth:** an earthquake creates fracture lines. A section completes when a fracture connects to the player's line.
- **Fire:** sets the line on fire and kills enemies that touch it.
- **Water:** enemies pass through the line harmlessly.
- **Air:** speed boost.

## Reward
- The plate shines like a golden card as territory is captured, with a full flourish when the level completes.
- Planned approach: a fragment-shader foil sheen over the static plate. Flutter shaders inside Flame are untested, so this needs a spike.

## Open questions
- Grid resolution vs. plate resolution (currently 240x144 cells at 5px).
- Input: keyboard on desktop. A swipe or stick for mobile is TBD.
- Enemy roster per sign.
