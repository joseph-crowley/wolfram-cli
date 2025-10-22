# Wolfram CLI Helpers

PhysicsCLI is a composable Wolfram Language toolkit for graduate level physics workflows driven entirely from the command line. The repository packages reusable solver functions, a declarative task registry, and backwards compatible wrapper scripts so you can wire Mathematica or the Wolfram Engine into automation, CI, and Azure batch pipelines without notebooks.

## Quick Start

1. Verify the Wolfram binaries:

   ```sh
   ls /Applications/Wolfram.app/Contents/MacOS
   /Applications/Wolfram.app/Contents/MacOS/wolframscript -version
   ```

2. Expose the CLI tools:

   ```sh
   export PATH="/Applications/Wolfram.app/Contents/MacOS:$PATH"
   ```

3. Run the PhysicsCLI smoke suite and an example task:

   ```sh
   make smoke
   wolframscript -file physics_cli.wls --task=fourier-gaussian --mu=0 --sigma=1 --params='[-1,1]' --t=0
   ```

Transverse-Field Zeroes (Electrodynamics)

- Purpose: complete WL workflow that constructs E and B from a complex seed, verifies Maxwell, and characterizes transverse zero loci in the large-g regime.
- Run:
  - export PATH="/Applications/Wolfram.app/Contents/MacOS:$PATH"
  - wolframscript -file problems/transverse-field-zeroes/solve.wls
- Outputs:
  - problems/transverse-field-zeroes/report.txt with symbolic checks and conditions.
  - problems/transverse-field-zeroes/sketch.png showing the electric zero axis and the rotating elliptic helix of magnetic zeroes.

## Library Layout

- `lib/PhysicsCLI/Utils.wl` provides hardened argument parsing, error reporting, and deterministic output helpers.
- `lib/PhysicsCLI/Analysis.wl` implements analytical transforms, partition functions, and asymptotic expansions.
- `lib/PhysicsCLI/Classical.wl` covers driven oscillators, a finite-difference Helmholtz solver, and stadium billiard spectra.
- `lib/PhysicsCLI/Quantum.wl` exposes quantum harmonic oscillator spectra, Clebsch-Gordan tables, and Dirac traces.
- `lib/PhysicsCLI/CLI.wl` unifies the task catalog and dispatch logic.
- `physics_cli.wls` is the primary entry point for all tasks.
- `scripts/` hosts wrapper executables that remain friendly for ad hoc usage and older automations.
- `paclets/` stores offline paclet archives (drop `FeynCalc.paclet` here or set `FAT_TAILED_PACLET_PATH`).

## Core Tasks (PhysicsCLI`CLI`TaskCatalog[])

- `analysis`  
  - `fourier-gaussian`: Fourier transform of exp(-(x-mu)^2/(2 sigma^2)) evaluated at a target frequency.  
  - `partition-function`: Canonical partition function and thermodynamics from a supplied spectrum.  
  - `asymptotic-series`: Large-parameter asymptotic expansion of a cosine-Gaussian integral.
- `classical`  
  - `damped-oscillator`: Driven damped oscillator trajectory sampling with optional CSV export hints.  
  - `helmholtz-square`: Finite-difference solution of the Helmholtz equation on the unit square (no FEM license required).  
  - `helmholtz-sweep`: Mesh-density sweep returning residual statistics for regression monitoring.  
  - `stadium-billiard`: Dirichlet eigenvalues and mode samples for the stadium billiard.
  - `transverse-field-zeroes`: WL reference lives under problems/transverse-field-zeroes; run as above.
- `quantum`  
  - `qho-spectrum`: Low-lying eigenvalues of the one dimensional harmonic oscillator via FEM.  
  - `clebsch-gordan`: Non-zero Clebsch-Gordan coefficients with numeric evaluation.  
  - `dirac-trace`: FeynCalc-backed Dirac gamma traces with analytic fallback if the paclet is absent.

Inspect available metadata:

```wolfram
Get["lib/PhysicsCLI/CLI.wl"];
PhysicsCLI`CLI`TaskCatalog[]
```

## CLI Usage Patterns

- Invoke the unified driver:  
  `wolframscript -file physics_cli.wls --task=qho-spectrum --n=8 --L=8 --m=1 --omega=1 --output=json`
- Run individual wrappers (compatible with older pipelines):  
  `wolframscript -file scripts/qho_eigs.wls --n=8 --L=8 --m=1 --omega=1 --out=qho.json`
- Pipe JSON into downstream tools:  
  `wolframscript -file physics_cli.wls --task=partition-function --beta=0.5 --spectrum='[0.5,1.5,2.5]' | jq .`
- Export high throughput trajectories:  
  `wolframscript -file scripts/damped_oscillator.wls --gamma=0.05 --omega0=1 --force=1 --drive=0.8 --tmax=100 --samples=4001 --out=response.csv`
- Monitor Helmholtz residuals:  
  `wolframscript -file physics_cli.wls --task=helmholtz-sweep --densities='[150,200,300,400]' --frequency=25 --waveSpeed=1`

All task options follow strict `--key=value` syntax. Numbers are validated against a restricted grammar to resist accidental `ToExpression` evaluation. Vector inputs are encoded as JSON arrays (for example `[-1,1]`).

## Make Targets

- `make smoke` exercises the PhysicsCLI smoke suite.
- `make qho` computes default harmonic oscillator energies and writes `qho_energies.json`.
- `make helmholtz` exports a JSON summary of the Helmholtz solution.
- `make helmholtz-sweep` runs a residual sweep over representative mesh densities.
- `make billiards` produces `stadium_eigs.json` with the default eigen spectrum.
- `make fourier`, `make partition`, `make physics` demonstrate common PhysicsCLI invocations.

## Resilience Principles

- ASCII only outputs keep logs parsable across remote shells.
- Every task returns machine readable Associations so you can compose results across simulation stages without relying on notebooks.
- Finite-difference defaults avoid FEM licensing while mesh density remains configurable to manage compute costs.
- Local paclet caching (via `paclets/` or `FAT_TAILED_PACLET_PATH`) keeps gamma-trace tooling available without network access.
- Smoke tests cover Fourier analytics, thermodynamics, quantum spectra, and classical integration to catch regressions rapidly.
- Language policy: this repository is Wolfram Language only for problem solutions and automation; do not add Python or other non-WL sources under `problems/` or `scripts/`. Keep any exploratory code out of version control.
- For electromagnetic phasor workflows, set $Assumptions for real parameters and apply c = omega/k early. Use ComplexExpand before imposing real-equality constraints.

## Further Reading

- `RUNBOOK.md` documents installation, kernel discovery, and operational checklists.
- `FIELD_MANUAL.md` surveys graduate level workflows that combine these CLI tasks into end-to-end pipelines.
