# Issue #26 - change spec: ramp completion checks

Instructions only. The reasoning is in the audit thread: "Check RTOS" waits to *see* the IPS in RTOS, which it can miss entirely when the ramp is shorter than the 500 ms poll, so the sequence waits forever. The replacement waits for the ramp to *finish* (HOLD **and** supply field = target), which cannot be true before the ramp is done and is already true when no ramp was needed.

All edits are in `src/Instrument.Oxford1820/Process.vi` except step 1.

## Status

| Item | What | Status |
|---|---|---|
| 1 | Field tolerance widened in `Instrument.1820.FloatApprox.vi` | **done**, verified |
| 2 | New state `Sequence: Check Ramp Done` (HOLD AND supply = target, with deadline) | **done**, verified |
| 3 | `Sequence: Check Targets Match` takes arguments, field only, with deadline | **done**, verified |
| 4 | `Sequence: Ramp PSU to Target` inserts the two new checks | **done**, verified |
| 5 | `Sequence: Ramp PSU to Magnet` inserts the two new checks | **done**, verified |
| 6 | `Sequence: Ramp PSU to Zero` inserts `Check Ramp Done >> 0` | **done**, verified |
| 7 | Delete `Check RTOS`, `Check RTOZ`, `Check PSU at Zero` | **done**, verified |
| Tests | T1-T7 below | **not run** |

Implemented 2026-09-23, built as 1.7.2. The public API and JSON payloads do not change, so this did not need a Transport release.

## Review of the implementation (2026-09-23)

Checked with `lvkit diff` against HEAD and, for `Sequence: Check Targets Match`, LabVIEW's own block-diagram export. All three edited VIs report clean health (no broken node, subVI, link or compile).

Three defects were found and fixed during review:

| # | What | Status |
|---|---|---|
| 1 | `Check Targets Match` had its timeout case frames swapped, so it raised 5432 on every entry (the normal, not-expired path) | **fixed**, verified |
| 2 | The deadline comparison ran on an unsigned value in both check states, so `<=0?` could only be true at the exact millisecond and no timeout ever fired | **fixed**, verified |
| 3 | `Check Targets Match`'s expired frame built the 5432 error but left Running Step alone and queued nothing, with no wait, so a genuinely rejected setpoint spun hard | **fixed**, verified |

Fix 2 in detail, since it is easy to reintroduce: the `Scan From String` deadline output is now **U32** (its default-value constant is U32), the `Subtract` is U32 - U32 (deadline - now), and a **Type Cast** with an I32 type constant feeds `<=0?`. Type Cast reinterprets the bits, so the wrap reads as negative and the test stays correct across the tick-count rollover and past 25 days of uptime. `To Long Integer` would **saturate** instead of wrapping - do not substitute it.

### Deviations from the steps below, both deliberate

- **Failure clusters go onto the loop error wire** rather than being logged in place with `Handle Error.vi`. This works here because `Error Handler` calls `Handle Error.vi` with `Stop on Unhandled Error` = FALSE and `Macro: Post Error Handling` restores the remaining states, so the queued `Instrument: Hold` and `Macro: Abort SetMagnet Sequence` still run and the failure is logged once. When testing T4-T6, expect one log entry and a magnet left holding, not an abort with no entry.
- **The 5433 "Rate coerced" warning is disabled**, by a True constant on its case selector, so the pass-through frame always runs and nothing is logged. It is off by decision, not by oversight. Side effect: the rate `FloatApprox` and the `rate` unbundle that feeds it are dead code in that frame. A Diagram Disable structure would read better than the True constant if this stays off.

## Before you start

- **No new typedef or class field.** Each waiting state carries its own deadline as a state argument, the way `Sequence: Wait >> 30000` already does. Rejected alternative: reusing `Wait Logic.vi`, which holds one shared timer for the whole process.
- **Error codes.** This spec uses **5430** (ramp did not finish), **5431** (supply clamped mid-ramp) and **5432** (IPS did not accept the setpoint). Confirm they are unused first; the only custom code in `Process.vi` today is 42 (unhandled state).
- **Logging** means: build the cluster with `Error Cluster From Error Code.vi`, pass it to `Instrument.Oxford1820.lvclass:Handle Error.vi` with **`Stop on Unhandled Error` = FALSE**, and do not wire its error outputs onto the loop error wire.
- Deadlines are `Tick Count (ms)` values. Compare rollover-safe: `To Long Integer(deadline - now) <= 0` means expired. Never compare the U32s directly.

## Step 1 - tolerance (`src/Instrument.Oxford1820/Community/Instrument.1820.FloatApprox.vi`)

In the **enabled** frame, `False` case, change the `In Range and Coerce` upper limit from `5e-05` to **`2e-4`** (leave the lower limit at 0).

Why: if the IPS reports field to 0.0001 T, two readings of the same field can differ by one digit in the last place. At 5e-5 that counts as "different", which starts millisecond-long ramps - exactly the ones the old check missed. 2e-4 is about two counts of readback, which is 1e-5 of full scale at 18 T, far below anything that matters when closing the switch.

Callers affected, all of them "is it already there?" checks that benefit from the same change: the skip tests in `Ramp PSU to Target` and `Ramp PSU to Magnet`, the already-at-field test in `Macro: Load SetMagnet Sequence`, and `Check PSU at Zero`.

## Step 2 - new state `Sequence: Check Ramp Done`

Add a frame to the state case structure, in the `---------- Sequence ----------` region. **Start by copying `Sequence: Check RTOS`** - the skeleton (Running Step in/out, `Data: Update Status` re-queue, the 0/500 ms `Select` into `Wait (ms)__ogtk.vi`) is exactly right; only the condition and the failure path are new.

Argument form: `Sequence: Check Ramp Done >> <target field> <deadline ms>`, e.g. `Sequence: Check Ramp Done >> 17.750000 1234567`.

Body:

1. `Scan From String` with format `%f %d` on the `Parse State Queue` argument output (terminal 8, the one `Sequence: Wait` uses) -> `target` (DBL) and deadline (I32 -> `To Unsigned Long Integer`).
2. `Read IPS Status.vi` -> `Status String to Cluster.vi` -> unbundle **Holding** and **Clamp**.
3. `Read IPS PSU Field.vi` -> supply field. Chain its class and error wires after `Read IPS Status.vi`, as the other checks do.
4. `done?` = `Holding` AND `Instrument.1820.FloatApprox.vi(supply field, target)`.
5. `expired?` = `To Long Integer(deadline - Tick Count (ms)) <= 0`.
6. `failed?` = `Clamp` OR (`expired?` AND NOT `done?`).
7. Case structure on `failed?`:
   - **False:** as `Check RTOS` does today, but selected on `done?` - `done?` true advances Running Step and waits 0 ms; false leaves Running Step alone and waits 500 ms.
   - **True:** leave Running Step alone. Log **5431** if `Clamp`, else **5430**, message `Ramp did not finish: supply %.4f T, target %.4f T, status %s` (supply field, target, the raw status string). Queue `Instrument: Hold` followed by `Macro: Abort SetMagnet Sequence` through `Add State(s) to Queue` with Remaining States wired in, so the abort clears the rest of the sequence.

`Macro: Abort SetMagnet Sequence` needs no change: it empties `sequence`, sets Running Step to 0 and replaces the queue with `Macro: Run Sequence`, which then stops cleanly.

## Step 3 - `Sequence: Check Targets Match` takes arguments

Today it compares the IPS target readback with `setMagnet.field` / `.rate` from the state cluster and waits forever if they never match. Two problems: the magnet ramp uses a different target than `setMagnet`, and the IPS legitimately coerces the rate (see the rate tables on the UI panel), so a rate that never matches would hang.

1. Argument form: `Sequence: Check Targets Match >> <field> <deadline ms>`. Parse it exactly as in step 2; drop the unbundle of `setMagnet`.
2. Advance when the **field** target readback (`Read IPS PSU Targets.vi` field output) matches within `FloatApprox`. Do not gate on rate.
3. Keep reading the rate: if the rate readback differs from `setMagnet.rate`, log it once as a **warning** (`is warning?` = T) - it means the IPS coerced the rate. Do not block on it.
4. On expiry, same failure path as step 2 but with code **5432**, message `IPS did not accept setpoint %.4f T (reads %.4f T)`.

## Step 4 - `Sequence: Ramp PSU to Target`

In the `False` frame (the branch that actually ramps), the `Insert Into Array` currently inserts one element, `'Sequence: Check RTOS'`. Insert **two** instead - the `Sequence: Switch` frame already does this, so copy that idiom:

1. `Sequence: Check Targets Match >> %f %d` built with `Format String` from `field` and `Tick Count (ms) + 5000`.
2. `Sequence: Check Ramp Done >> %f %d` from `field` and `Tick Count (ms) + budget`.

Budget in ms, from the values already on the diagram (`field`, `rate`, the supply field read in this frame):

```
budget = 60000 + 2 * 60000 * |field - supply field| / max(rate, 0.01)
```

That is a doubled estimate of the ramp time plus a minute, so a legitimate slow ramp never trips it. Clamp the result to U32.

## Step 5 - `Sequence: Ramp PSU to Magnet`

Same edit, with the magnet field from `Read IPS Magnet Field.vi` as the target and the frame's hardcoded `1.0` T/min as the rate in the budget.

## Step 6 - `Sequence: Ramp PSU to Zero`

Replace the inserted `'Sequence: Check RTOZ'` with `Sequence: Check Ramp Done >> 0.000000 %d`. Budget from the supply field read in the frame (add a `Read IPS PSU Field.vi` if there is not one) and `setMagnet.rate`, falling back to 1.0 T/min when the rate is 0.

This is the case that hangs today whenever you set B = 0 T in Persistent mode: the supply is already at zero when RTOZ is sent, so the IPS may never be seen in RTOZ.

Optional, not required once the above is in: skip sending RTOZ when the supply is already at zero, the way `Ramp PSU to Target` skips.

## Step 7 - delete the superseded states

Once steps 4-6 are in, nothing inserts `Sequence: Check RTOS`, `Sequence: Check RTOZ` or `Sequence: Check PSU at Zero`. Delete all three frames. Keep `Sequence: Check Hold`: the sequence strings in `Macro: Load SetMagnet Sequence` still use it after the initial `Sequence: Hold`.

The `Sequence: Check Hold` that trails each ramp in those strings is now redundant, since `Check Ramp Done` already requires HOLD. It is harmless (it passes on the first poll) - leave it unless you are editing those strings anyway.

## Tests

Dev machine first if the simulator can fake the IPS; otherwise all of these are quick on hardware.

| # | Setup | Expect |
|---|---|---|
| T1 | Persistent, magnet at 18 T, target 17.75 T, SET B = TARGET | Full sequence runs: hold, leads to 18 T, switch on, ramp to 17.75 T, switch off, leads to zero. No stall at any check |
| T2 | Persistent, request a field 0.0001 T from the present one | Completes. This is the case that hangs today in `Check RTOS` |
| T3 | Persistent, target 0 T | Completes. This is the case that hangs today in `Check RTOZ` |
| T4 | Request a field above the IPS limit | **5432** within about 5 s, sequence aborts, magnet left holding |
| T5 | Mid-ramp, put the IPS in HOLD from its own panel | **5430**, `Instrument: Hold`, sequence aborts |
| T6 | Mid-ramp, clamp the supply | **5431**, same abort path |
| T7 | Mid-check, press Hold on the UI | Aborts as before; Running Step goes to -1 and the process returns to idle |

Pass for T4-T6: the magnet is left in a safe state (holding, switch untouched) and one log entry explains why.

After the edits, run `lvkit diff` against HEAD on each changed VI to confirm nothing else moved. Note that lvkit misreads VI reentrancy and can mislabel class private-data fields in Bundle/Unbundle By Name; check anything surprising against LabVIEW's own block-diagram export.
