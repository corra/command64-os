# Pac-Man Game Specification

## Overview
Pac-Man is a classic arcade game where players control the titular character through a maze, eating dots while avoiding ghosts. The objective is to clear each level of dots while maximizing score and avoiding death by ghost contact.

## Core Game Elements

### Maze Layout
- Contains 240 small dots
- 4 power pellets located in corners
- Warp tunnels on left and right sides allowing travel to opposite side
- Total points available per maze: 2,600 points

### Scoring System
- Small dots: 10 points each
- Power pellets: 50 points each
- Ghost consumption (during power pellet mode):
  - First ghost: 200 points
  - Second ghost: 400 points
  - Third ghost: 800 points
  - Fourth ghost: 1,600 points
- Fruit bonuses appear periodically with increasing values in higher levels

### Characters

#### Pac-Man
- Player-controlled character
- Starting speed: 80% of maximum
- Reaches full speed by level 5
- Slows down briefly when eating dots
- Can consume ghosts after eating power pellets
- Dies upon contact with non-vulnerable ghost

#### Ghosts
Four unique ghosts with distinct AI behaviors:

1. **Blinky (Red)**
   - Primary strategy: Direct pursuit of Pac-Man
   - Most aggressive ghost

2. **Pinky (Pink)**
   - Strategy: Attempts to position ahead of Pac-Man
   - Uses ambush tactics

3. **Inky (Cyan)**
   - Strategy: Similar to Pinky, tries to cut off Pac-Man's path
   - More complex movement patterns

4. **Clyde (Orange)**
   - Strategy: Alternates between pursuit and retreat
   - Most unpredictable ghost

Ghost Behavior Modes:
- Alternate between "scatter" and "chase" modes at timed intervals
- Slower movement in warp tunnels
- Turn blue and vulnerable when Pac-Man consumes power pellet

### Power Pellets
- Located in four corners of the maze
- Temporarily makes ghosts vulnerable
- Vulnerability duration decreases in higher levels
- Ghosts turn blue and can be consumed for points
- Ghosts return to spawn point when eaten

### Level Progression
- Increasing game speed with each level
- Decreasing ghost vulnerability time
- Higher fruit bonus values
- Pac-Man speed increases until level 5
- Game continues until level 256 (kill screen due to integer overflow)

### Lives and Game Over
- Player starts with 3 lives
- Life lost upon contact with non-vulnerable ghost
- Game ends when all lives are depleted

## Technical Notes
- Ghost movement speeds vary based on mode and current level
- Precise timing mechanisms control ghost behavior switches
- Warp tunnels affect ghost speed (reduced when entering/exiting)
- Integer overflow occurs at level 256, creating the famous "kill screen"

## Scoring Strategy
To maximize score:
1. Clear all dots (2,600 base points per level)
2. Consume all ghosts during power pellet vulnerability
3. Collect fruit bonuses when they appear
4. Progress to higher levels for increased point opportunities 