# Oxford-1820

LevyLab's LabVIEW driver for the Oxford 18/20 T magnet system: an Oxford Mercury IPS (magnet power supply, switch heater, He/N2 levels) and a Mercury ITC (temperature, lambda-point fridge needle valve and pressure). It is an Instrument Framework driver (JKI SMO) and implements the `Instrument.Cryostat` interface from `levylab_lib_instrument_type`. Targets LabVIEW 2019 64-bit.

The README is out of date (it says LabVIEW 2016 32-bit). Trust the `.vipb` and `.vipc`.

## Products

One repo, one product, built through the shared `build.bat` flow driven by `build support\build.cfg`.

| Output | Details |
| --- | --- |
| VI package | `build support\Oxford 1820 API.vipb` produces `Levylab_lib_Oxford_1820_API`. It installs to `<user.lib>\Levylab\Oxford-1820` and adds a JKI SMO template under `LevyLab Instrument`. It is published to the VIPM feed in `levylabpitt.github.io\packages\levylab_lib_oxford_1820_api`. |
| Application + installer | Build specs `Oxford-1820 Application` and `Oxford-1820 Installer` in `Oxford-1820-(x64).lvproj`. `build support\Inno.iss` wraps the NI installer (`builds\Installer\Volume`). |

- Tags are bare versions (`1.6.6.27`); `TAG_PREFIX` is empty. `DO_RELEASE=true` commits, merges `develop` into `main`, tags, pushes and creates the GitHub release.
- The build number in the `.vipb` (`Library_Version`) is bumped by the build and is already the *next* build number (after the 1.6.6.27 release it reads 1.6.6.28).
- `<Release_Notes>` in the `.vipb` are not cleared after a release. Rewrite them before each build; they become the GitHub release body.
- `builds\` is gitignored.

## Release notes style

Short bullet lists, one per release, headed by the minor version:

```text
[1.6.6]
- build with Instrument-Framework/1.15.13.55
  - <notable framework change that affects this driver>
- build with Remote-Control-ZMQ/1.3.7.30
- #22 fix HELP
```

- Name rebuilds against new dependencies as `build with <Repo>/<version>`, with sub-bullets only for changes that affect this driver.
- Reference this repo's GitHub issues as `#N`.
- Rebuilds that only pick up dependencies have bumped the third field (1.6.4 -> 1.6.5 -> 1.6.6).

## Layout

- `src\Instrument.Oxford1820\Instrument.Oxford1820.lvclass`: the driver class.
  - `API\`: public API (`Open`, `Close`, `getMagnet`/`setMagnet`, `getMagnetTarget`, `Get All`, `AbortSequence`). Only `getMagnet`, `setMagnet` and `Open` are palette entries in the `.vipb`.
  - `Methods (Overrides)\`: framework overrides (`Handle Command`, `Handle getAll`, `Handle setAllData`, `Open/Close Hardware`, SMO name/port/database paths, configuration file read/write, event creation).
  - `Private\Handle Command\`: one VI per IPS/ITC read or set command.
  - `Private\`: `Open IPS.vi`, `Open ITC.vi`, status parsing, `IPS/ITC Reply to PGSQL.vi`, and `1820 State History.vi`.
  - `Community\`: helpers (ramp, hold, switch heater, fill mode, sweep ETA).
  - `Tests\`: `Test Open Close`, `Test Messaging`, `Test Action Status`, `Test Inheritance`.
- `src\Instrument.Oxford1820 UI\Instrument UI.Oxford1820.lvclass`: the front-end UI (level colors, circular buffer for cryogen graphs).
- `build support\`: `.vipb`, `.vipc`, `build.cfg`, `Inno.iss`, `1820 Build.vi`, `Post-Build Custom Action.vi`, icons.
- `documentation\Tree.pptx`: class tree diagram.

## Dependencies

- **Package dependencies** (the `.vipb` `Additional_External_Dependencies`, which are authoritative):
  - `levylab_lib_levylab_instruments >= 1.15.13.55` (Instrument Framework). That package in turn pins Debug, Configuration, Logger, Logger.Error, Logger.PGSQL, RemoteControl and RemoteControl.ZMQ minimums.
  - `oxford_lib_mercury_ixx >= 2.0.0.6` (Oxford's Mercury iXX instr.lib driver, `Mercury iXX.lvlib`).
- The `.vipc` lists no packages; install dependencies with VIPM from the LevyLab feed.
- **Where dependency sources live:**
  - Instrument Framework and Instrument Type: `C:\Users\patrick\Documents\GitHub\Instrument-Framework`.
  - Subsystems (Debug, Configuration, Logger, Logger.Error, Logger.PGSQL, Logger.syslog, RemoteControl, RemoteControl.ZMQ, RemoteControl.STM, SCPI): one repo each under `C:\Users\patrick\Documents\GitHub\Instrument-Subsystems\`. They were split out of Instrument-Framework on 2026-08-03; tags before that date live in Instrument-Framework with prefixes like `Remote-Control-ZMQ/1.3.7.28`.
  - Published versions and dates: git history of `C:\Users\patrick\Documents\GitHub\levylabpitt.github.io\packages\` (commits named `Patrick Builder publish packages: <pkg>-<ver>`). Old `.vip` files were pruned on 2026-07-02, so use the commit log, not the folder listing, to see older versions.
- A fix to a dependency is released from its own repo; this repo then rebuilds and raises its `.vipb` minimum.

## Sharp edges

- **Handle GET / Handle SET (framework >= 1.15.13):** the base methods return error 5402 "parameter not supported" for unhandled parameters. This driver dispatches through `Handle Command`; if any override calls the parent for a parameter it handles itself, it will now error. Only call the parent in the `Default` case.
- **State History:** the framework moved `State History.vi` into the Debug package (`levylab_lib_debug >= 1.2.1.10`). This driver still has its own `Private\1820 State History.vi`; check whether it duplicates the Debug one before changing it.
- **RemoteControl 1.4:** messages now carry an error and the default timeout is 500 ms (was 0). Behavior around lost connections changed with RemoteControl.ZMQ 1.3.7.29+.
- **Remote-Control-ZMQ 1.3.6.27** did not create `%LOCALAPPDATA%\levylab\zmq\` if missing (fixed in 1.3.7.28). Old installs may need `mkdir %localappdata%\levylab\zmq\`.
- **Stale links:** after the subsystem split, VIs can still link to old `1-subsystems\...` paths. Relink to `user.lib` and save before building.

## Open issues worth knowing

- #24: He/N2 level readings can freeze at a stale value (e.g. after a power glitch drops the instrument connection) until the PC is restarted. The proposed fix is an interval check (12-24 h) that alerts when a channel has not updated.
- #15: gentle UI "lockout" while the instrument is under remote control.
