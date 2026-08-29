# Cube Scrambler

A scramble generator for the 3x3 and 2x2, as a native macOS app. It exists because
`scramble.cubing.net` does the first half of the job well and the second half badly: the
notation is right, but the picture never tells you **which way** a face is supposed to
turn. `L` and `L'` look almost identical, and you end up guessing.

This is a scrambler only. No timer, no solver, no solve history.

## What it does differently

Every turn is shown four ways at once, and all four are generated from the same rotation,
so they cannot contradict each other:

**A sentence, not a symbol.** `L'` on its own is the problem, so the notation is never
shown alone. It is always paired with something like *"LEFT face - turn it so the front
column of the left face slides UP."* Every direction is stated in one fixed frame - what
you see, looking at the cube head-on with white on top and green in front - rather than
"clockwise", which is only meaningful once you've decided whose clockwise.

**A curved arrow on the actual face**, wrapping the layer that is about to move, pointing
the real direction. It is centred on the exact row or column the sentence names, so the
arrowhead lands where the words say the stickers are going.

**The turning layer lights up and everything else dims**, so you can't grab the wrong one.

**The view swings round** to whichever face is turning, ending off-axis rather than
dead-on so the depth cues that make a rotation readable survive. If you'd rather the cube
on screen kept matching the cube in your hands, **Lock orientation** in the toolbar holds
the camera still and lets the arrow do the work on its own.

**One turn at a time.** A new scramble sits solved and does nothing until you press. `->`
plays one turn, `<-` takes it back. It's meant to be followed with a cube in your hands,
not watched.

## Scrambles

Both puzzles use **uniform random state** - every position equally likely - which is the
standard competitions use. A fixed number of random turns is not the same thing and
clusters around certain positions.

| Puzzle | Positions | How | Typical scramble |
| --- | --- | --- | --- |
| 3x3 | 43,252,003,274,489,856,000 | Kociemba's two-phase search, solution inverted | 19-21 turns |
| 2x2 | 3,674,160 | Exhaustive breadth-first search, optimal solution inverted | 8-11 turns |

The 2x2 is small enough to solve *perfectly*: one search from solved measures the exact
distance to all 3.67 million positions, so its scrambles are provably the shortest that
reach the position. The 3x3 is not - 43 quintillion positions rules that out - so it uses
the two-phase algorithm, which is why scrambles come out around 20 turns instead of the 60
a layer-by-layer solve would give.

Generating a 3x3 scramble takes roughly a third of a second, so the next one is always
being worked out in the background while you step through the current one.

Nothing here should be used to scramble an official WCA competition; that requires the
official scrambling program.

## Keyboard

| | |
| --- | --- |
| `->` | Next turn |
| `<-` | Previous turn |
| `Space` | Play the rest of the scramble |
| `Home` / `End` | Jump to solved / scrambled |
| `R` or `Cmd-N` | New scramble |
| `Cmd-1` / `Cmd-2` | 3x3 / 2x2 |

Dragging in the cube view turns it round by hand.

## Building

```
./build.sh
```

Builds in release, assembles the `.app` around it, and installs to `/Applications`. Always
build this way - `swift build` alone leaves a bare executable and the installed copy
silently falls behind.

## Data

```
~/Library/Application Support/CubeScrambler/
```

- `history.json` - the last 50 scrambles, newest first
- `settings.json` - last puzzle used, and the orientation lock
- `pruning-333-v1.bin`, `distances-222-v1.bin` - the generated search tables

The two `.bin` files are derived data and safe to delete; the first launch after that
spends about a second rebuilding them. Everything else decodes field by field with
fallbacks, so adding a setting later cannot wipe the file.

## Tests

```
swift test
```

The interesting ones are the cross-checks, because the parts they compare were written
independently:

- **Cube model vs. plain geometry.** The permutation tables are Kociemba's, entered by
  hand, and the sticker-to-screen mapping is also by hand. A third model in the test target
  does nothing but rotate stickers in 3D. All 18 turns have to agree. When they didn't, it
  was three transposed sticker indices and six unpainted centres.
- **Round trip.** Generate a random position, scramble for it, apply the scramble to a
  solved cube, and require the result to be that exact position.
- **The 2x2 depth histogram** has to match the published counts - 1, 9, 54, 321, 1847,
  9992, 50136, 227536, 870072, 1887748, 623800, 2644 - which it will not if any coordinate
  or move table is subtly wrong.
- **Arrow vs. sentence.** The drawn arrow and the English sentence are worked out
  separately; the test requires the arrow to point the way the words say, and to sit over
  the row the words name.
