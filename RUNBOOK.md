# Wolfram CLI Runbook

Last verified: October 14, 2025 on macOS with Mathematica installed at `/Applications/Wolfram.app`. See `FIELD_MANUAL.md` for an extended physics-focused CLI handbook built on these steps.

## Prerequisites

- Mathematica or the standalone Wolfram Engine must be installed locally.
- Ensure the CLI tooling shipped with the install is present. On this machine `wolframscript` reports `WolframScript 1.13.0 for Mac OS X ARM (64-bit)`:

  ```sh
  /Applications/Wolfram.app/Contents/MacOS/wolframscript -version
  ```

- Optional: add the binaries directory to PATH to avoid typing the full path each time.

  ```sh
  export PATH="/Applications/Wolfram.app/Contents/MacOS:$PATH"
  ```

## Discovering the Binaries

1. Try the PATH lookup first:

   ```sh
   which wolframscript || which WolframKernel || which math
   ```

   If nothing is returned, fall back to the application bundle.

2. Confirm the install directory:

   ```sh
   ls /Applications/Wolfram.app/Contents/MacOS
   ```

   Expected executables include `wolframscript`, `WolframKernel`, `MathKernel`, and helpers like `wolfram`.

## Quick Sanity Checks

Run these after confirming the binaries to ensure everything works end-to-end.

```sh
# One-liner numeric check
/Applications/Wolfram.app/Contents/MacOS/wolframscript -code 'N[Zeta[3], 50]'

# Structure-preserving output
/Applications/Wolfram.app/Contents/MacOS/wolframscript -code 'Range[5]^2 // InputForm'

# Kernel via stdin
printf 'FactorInteger[2^61 - 1]\nQuit[]\n' | /Applications/Wolfram.app/Contents/MacOS/WolframKernel -noprompt

# Headless export (writes bessel.pdf in the current directory)
/Applications/Wolfram.app/Contents/MacOS/wolframscript -code 'Export["bessel.pdf", Plot[BesselJ[0,x], {x,0,30}]]'
```

## Usage Patterns

- **One-liners:** Use `-code` for inline expressions. Append `// InputForm` or wrap with `ExportString[..., "JSON"]` for machine-friendly output.
- **Reading from stdin:** Pipe expressions into `WolframKernel -noprompt`. Always terminate with `Quit[]` to exit cleanly.
- **Script files:** Save `.wl` files and execute with `wolframscript -file script.wl`. For executables, add a shebang and `chmod +x script.wl`. Because the shebang uses `/usr/bin/env wolframscript`, the `wolframscript` binary must be discoverable on `PATH`. When running locally without modifying shell profiles, prefix commands with `PATH="/Applications/Wolfram.app/Contents/MacOS:$PATH" ./script.wl`.

  ```wl
  #!/usr/bin/env wolframscript
  Print[Integrate[Exp[-x^2], {x, -Infinity, Infinity}]];
  ```

- **Argument handling:** Inside scripts, drop the program name with `Rest @ $ScriptCommandLine`. Example:

  ```wl
  args = Rest @ $ScriptCommandLine;
  data = Import[args[[1]], "Table"];
  nlm = LinearModelFit[data, x, x];
  Export[args[[2]], {nlm["BestFitParameters"], nlm["RSquared"]} // InputForm];
  ```

  Run with `wolframscript -file fit.wl data.csv result.txt`.

- **Headless graphics & exports:** `Export["plot.png", Plot[Sin[x], {x, 0, 2 Pi}]]` works without a notebook front end.
- **Parallel control:** Default parallelization kicks in automatically for parallel constructs. Use `LaunchKernels[n]` or `SetSystemOptions["ParallelOptions" -> "ParallelThreadNumber" -> n]` for deterministic core counts.
- **Exit codes:** Wrap top-level operations with `Check`/`If` and call `Exit[1]` or `Exit[0]` to propagate failures to calling shells.

## Troubleshooting

- **`ls` or direct invocation hangs:** Verify permissions on the app bundle (`stat /Applications/Wolfram.app`). If needed, clear quarantine attributes (`xattr -d com.apple.quarantine ...`).
- **`wolframscript` missing:** Use the fully qualified path (`/Applications/Wolfram.app/Contents/MacOS/wolframscript`) or symlink it into `/usr/local/bin`.
- **Unexpected box-form output:** Post-process with `InputForm`, `FullForm`, or `ExportString[..., "JSON"]`.
- **Long-running jobs:** Start scripts with `-noprompt` and prefer `wolframscript -file` to avoid accumulating state between runs.
- **Version drift:** Rerun the sanity checks and `-version` command after upgrades to confirm nothing broke.

## Next Steps

- Consider wrapping common invocations in shell scripts or a Makefile target for reproducibility.
- Add automated smoke tests (e.g., in CI) that run the sanity commands to catch environment regressions early.
