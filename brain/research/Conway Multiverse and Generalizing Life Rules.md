# The Conway Multiverse: Generalizing Conway's Game of Life

This document summarizes the core mathematical principles, rule generalizations, and specific "universes" explored in Cary Huang's (*carykh*) video, **"The Conway Multiverse"** (based on video [QK_KZv-YyOc](https://www.youtube.com/watch?v=QK_KZv-YyOc)).

---

## 1. Mathematical Framework for Rule Generalization

In a standard 2D two-state cellular automaton, the state of each cell in the next generation is determined entirely by its current state (alive/dead) and the count of its living neighbors (out of 8 possible in a Moore neighborhood).

These are known as **Life-like cellular automata** and are mathematically defined by two sets of neighbor counts:
*   **Birth ($B$):** The number of living neighbors required to turn a dead cell alive.
*   **Survival ($S$):** The number of living neighbors required for an active cell to remain alive.

### The Full State Space
*   There are **9 possible neighbor counts** ($0, 1, 2, 3, 4, 5, 6, 7, 8$) for both Birth and Survival.
*   For each count, the rule can either include it or exclude it (a binary decision).
*   This yields $2^9$ possible birth rules and $2^9$ possible survival rules.
*   Total possible Life-like universes: 
    $$\text{Total} = 2^9 \times 2^9 = 2^{18} = 262,144 \text{ universes}$$

---

## 2. The "Connected" Conway Multiverse

To visualize a subset of these universes, *carykh* introduced the concept of **Connected Rule Strings**. 

### Definition
A rule string is connected if both its Birth ($B$) and Survival ($S$) conditions form **contiguous ranges** (e.g., $B345$, not $B35$). 

> [!NOTE]
> Connected rule strings represent more "natural" organisms. It is mathematically counter-intuitive for an organism to survive with 4 or 6 neighbors, but die at exactly 5 neighbors. 

Limiting the multiverse to connected ranges reduces the number of valid rule strings from **262,144 to 2,116**.
*   *Note:* This filter excludes several classic CA rules like **HighLife** ($B36/S23$) or **Day & Night** ($B3678/S34678$).

### Grid Layout in the Multiverse
The $2,116$ connected universes are organized in a large grid:
*   **Vertical (Y-Axis):** Birth range start points ($0+$ to $8+$, plus Null birth).
*   **Horizontal (X-Axis):** Survival range start points ($0+$ to $8+$, plus Null survival).
*   **Sub-grids (Families):** For each start-point family, the internal coordinate determines the endpoint of the range:
    *   Moving **right** increases the survival range endpoint.
    *   Moving **up** increases the birth range endpoint.
    *   *Example:* The bottom-left of the $B3/S2$ family is $B3/S2$. Moving right yields $B3/S23$. Moving up from there yields $B34/S23$.

---

## 3. Notable Universes Explored

The video showcases several distinct families of universes, ranging from stable maze-builders to chaotic explosions.

```mermaid
graph TD
    classDef universe fill:#1e1e2f,stroke:#4f46e5,stroke-width:2px,color:#fff;
    classDef conway fill:#1e293b,stroke:#0ea5e9,stroke-width:2px,color:#fff;
    
    Conway["Conway's Life (B3/S23)"]:::conway
    
    Ant["Ant Colony (B3/S234)"]:::universe
    Fire["World on Fire (B34/S23)"]:::universe
    Blink["Blinkers (B345/S2)"]:::universe
    Maze["Maze / Mazectric (B3/S1234[5])"]:::universe
    LWD["Life Without Death (B3/S0-8)"]:::universe
    Aquatic["Aquatic Family (Coral, Assimilation, Eggs)"]:::universe

    Conway -->|Expand Survival +1| Ant
    Conway -->|Expand Birth +1| Fire
    Conway -->|Shift Survival & Birth| Blink
    Conway -->|Lower Survival to S1| Maze
    Conway -->|Remove Death (S0-8)| LWD
    Conway -->|High Survival (S4+)| Aquatic
```

### A. Ant Colony ($B3/S234$)
*   **Behavior:** Forms maze-like corridors in the interior with a highly active, expanding outer boundary.
*   **Stabilizing Corridors:** In corridors, a "dead end" requires the living cell at the tip to have at least 4 neighbors (2 to the left, 2 to the right). Under Conway's rules ($S23$), this cell dies from overpopulation. Under Ant Colony rules ($S234$), it survives, stabilizing the walls.

### B. World on Fire ($B34/S23$)
*   **Behavior:** Rapid, chaotic, runaway growth that refuses to settle down.
*   **Destruction of Still Lives:** The Conway **Loaf** has empty interior cells with exactly 4 living neighbors. In Conway's Life, these stay dead. In World on Fire ($B34$), these cells are born, eating the loaf from the inside like a parasite and causing it to explode into active chaos.
*   **Universal Similarities:** Despite the chaos, some structures evolve identically; a $T$-tetramino develops into the same 4-blinker "traffic light" configuration as in Conway, albeit slightly more spread apart.

### D. Blinkers ($B345/S2$)
*   **Behavior:** A desolate universe that quickly fizzles out, leaving either an empty grid or a scattering of lonely period-2 blinkers.
*   **Death of the Block:** The standard Conway **Block** is a stable $2 \times 2$ still life where each cell has 3 neighbors. Because survival is strictly $S2$ in this universe, any block that forms immediately dies.
*   **Highlights:** Despite the desolation, Goucher's catalog lists large spaceships moving at $c/4$ and $c/5$ (where $c$ is the speed of light: 1 cell per generation). An equal symbol (`=`) forms a rare, complex period-16 oscillator.

### D. Maze ($B3/S12345$) & Mazectric ($B3/S1234$)
*   **Behavior:** Generates highly rectangular, branching mazes. Maze features shorter corridors; Mazectric features longer, cleaner straightaways.
*   **The Dangler Rule:** Mazes contain hairpin turns, which require a single wall-tip cell called a "dangler" to survive with only 1 neighbor. In Ant Colony ($S234$), this cell dies, disrupting the wall. In Maze/Mazectric ($S1234$), the $S1$ rule keeps the dangler alive, creating stable walls.
*   **Mazectric with Mice ($B37/S1234$):** Adding birth at 7 allows cells in long corridors (which normally have 6 neighbors) to be born if an active "mouse" cell is adjacent (raising neighbors to 7). This creates a moving pulse that simulates a mouse running down the corridor. Its 1D behavior matches **Rule 18**, producing Sierpinski triangles.

### E. Life Without Death ($B3/S012345678$)
*   **Behavior:** Cells are born at 3 neighbors but can never die.
*   **Topography:** Forms a solid mass dotted with "Swiss cheese" holes at roughly 19% density. Because birth at 8 is disabled, these holes can never be filled.
*   **Growth Mechanics:** Oscillators and spaceships cannot exist since cells never disappear. Instead, growth is driven by **Ladders** (vines growing orthogonally at $c/3$) and **Ladder Runners** (which traverse the ladders at $2c/3$).

### F. The Aquatic Family (High Survival thresholds)
*   **Coral ($B3/S45678$):** Similar to Life Without Death but lacks survival below 4 neighbors. This creates a "breathing" outer boundary. Grows 6x slower than Life Without Death.
*   **Assimilation ($B3/S4567$):** Creates diamond-shaped boundaries with shimmering, electric-current-like borders. **Slow Assimilation** ($B3/S456$) behaves similarly but takes much longer to resolve boundary chaos.
*   **Healthy Egg ($B3/S45678$) vs. Rotten Egg ($B3/S345678$) vs. Bacteria ($B3/S235678$):**
    *   *Healthy Egg:* Expands into almost entirely solid, cavity-free circles.
    *   *Rotten Egg:* Expands with numerous interior hollow cavities.
    *   *Bacteria:* Remains a squirming, chaotic soup.
*   **Lifeguard 2 ($B3/S4567$):** Differs from Coral ($S45678$) only by the lack of survival at 8. Without $S8$, Lifeguard 2 cannot maintain large solid blocks of living cells, causing it to shrivel and die where Coral would conquer the grid.
