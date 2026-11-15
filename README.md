# Depots and the Crawler

Project files for tutorial 03 of the Spotless Moon series by Phaix on YouTube (https://www.youtube.com/@Phaix).

Depots and the Crawler for a moon cleaning game in Godot 4: a placement ghost with a foundation, a Crawler you drive that cleans a lane into its own pack and unloads beside a Dustwell.

![Screenshot](screenshot.png)

## Steps

Every step of the video is its own folder in `steps/`, the exact state at the end of that
part. Open the project in Godot 4.7, then open `steps/<step>/main.tscn` and press F6 to run
that step. The project's main scene is the final step.

| Folder | Part of the video |
|---|---|
| `steps/step_00_start` | Starting point (the final state of the previous tutorial) |
| `steps/step_01_place` | Step 1 - Placing a Dustwell |
| `steps/step_02_crawler` | Step 2 - The Crawler |
| `steps/step_03_roller` | Step 3 - The roller |
| `steps/step_04_unload` | Step 4 - Unloading |

## Controls

- W A S D or the arrow keys walk, and so does the left stick of a gamepad.
- The mouse or the right stick looks around.
- Space or the A button jumps.
- Esc gives the mouse back, and a left click captures it again.
- Hold the left mouse button or the right trigger to brush the dust away.
- E or the X button uses the machine within reach (3.5 m of its middle), places the machine you carry, and gets you into a vehicle and out again. The line at the bottom of the screen says what it will do.
- In a vehicle, W and S or the up and down arrows drive forward and back, A and D or the left and right arrows steer while it moves, the left stick does both, and the mouse or the right stick turns the camera around it.
- Placing works from `step_01_place`, the vehicles from `step_02_crawler`.

## Tests

```sh
godot --headless --path . -s res://tests/run_tests.gd
```

## Support

Support the channel: https://ko-fi.com/phaix or https://github.com/sponsors/schemann

## License

Code and scenes: MIT (see LICENSE).
The brush sound (four cloth rustles): RPG Audio by Kenney (www.kenney.nl, https://kenney.nl/assets/rpg-audio), CC0, see sounds/CREDITS.md.
