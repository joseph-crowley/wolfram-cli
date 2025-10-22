# Wolfram CLI Runbook

Last verified: October 22, 2025 on macOS with Mathematica installed at `/Applications/Wolfram.app`. This document captures the operational steps for the PhysicsCLI stack; see `FIELD_MANUAL.md` for the deep-dive physics workflows.

## 1. Environment Prerequisites

1. **Mathematica / Wolfram Engine** – ensure a local desktop installation; the current system reports:

   ```sh
   /Applications/Wolfram.app/Contents/MacOS/wolframscript -version
   # WolframScript 1.13.0 for Mac OS X ARM (64-bit)
   ```

2. **PATH configuration** – expose the binaries to the shell session used by Codex:

   ```sh
   export PATH="/Applications/Wolfram.app/Contents/MacOS:$PATH"
   ```

3. **Repository bootstrap** – from `/Users/joe/code/wolfram-cli` run `make smoke` to confirm the library loads cleanly (details in §6).

## 2. PhysicsCLI Layout

- `physics_cli.wls` – primary entry point; accepts `--task=<name>` plus task-specific flags.
- `lib/PhysicsCLI` – modular packages providing utilities, analysis, classical, and quantum toolkits. Load interactively via `Get["lib/PhysicsCLI/CLI.wl"]`.
- `scripts/` – thin wrappers that call into the shared task registry to preserve legacy automation (e.g., CI or Makefile targets).
- `paclets/` – drop offline paclet archives (for example `FeynCalc.paclet`) or set the environment variable `FAT_TAILED_PACLET_PATH`.
- `NOTES.md` – live operations log; update after each validation campaign.

Enumerate the current task catalog at any time:

```sh
wolframscript -file physics_cli.wls --task=list
```

## 3. Binary Discovery & Sanity Checks

1. **Executable discovery**

   ```sh
   which wolframscript || ls /Applications/Wolfram.app/Contents/MacOS
   ```

2. **Smoke checks** – verify numerical evaluation, structured output, stdin kernel execution, and headless graphics:

   ```sh
   wolframscript -code 'N[Zeta[3], 50]'
   wolframscript -code 'Range[5]^2 // InputForm'
   printf 'FactorInteger[2^61-1]\nQuit[]\n' | WolframKernel -noprompt
   wolframscript -code 'Export["bessel.pdf", Plot[BesselJ[0,x], {x,0,30}]]'
   ```

## 4. Operating the CLI

- **Unified driver** – preferred interface for automation:

  ```sh
  wolframscript -file physics_cli.wls --task=partition-function --beta=0.7 --spectrum='[0.5,1.5,2.5,3.5]'
  ```

- **Wrapper scripts** – legacy compatibility; each simply loads PhysicsCLI under the hood:

  ```sh
  wolframscript -file scripts/qho_eigs.wls --n=6 --L=8 --m=1 --omega=1 --out=qho.json
  ```

- **Task options** – every flag uses `--key=value` form. Numeric arguments are parsed with hardened validators (no `ToExpression` on raw user input). Arrays are passed as JSON literals (e.g., `--spectrum='[0.5,1.5,2.5]'`).

- **Output formats** – default is JSON. Override with `--output=text` for quick inspection.

## 5. Physics Task Inventory

| Domain | Task | Description | Notes |
| --- | --- | --- | --- |
| Statistical physics | `partition-function` | Canonical partition function, internal energy, heat capacity from a discrete spectrum. | Accepts JSON lists or file paths (wrapper) |
| Quantum mechanics | `qho-spectrum` | Finite-element harmonic oscillator eigenvalues (low modes). | Writes `qho_energies.json` via wrappers |
| Quantum angular momentum | `clebsch-gordan` | Non-zero Clebsch–Gordan coefficients tabulated as JSON. | Full numeric output |
| Quantum field theory | `dirac-trace` | `DiracTrace[γ^μ γ^ν]`; uses FeynCalc if available, otherwise analytic result `4 g^{μν}`. | Drop `FeynCalc.paclet` into `paclets/` for offline install |
| Classical dynamics | `damped-oscillator` | Forced damped oscillator response sampled at fixed cadence. | Returns trajectory plus suggested CSV name |
| Electrodynamics / waves | `helmholtz-square` | Finite-difference Helmholtz solve on the unit square with Dirichlet data. | Five-point stencil; no FEM license needed |
| Electrodynamics / waves | `helmholtz-sweep` | Mesh-density sweep emitting residual RMS and max norms. | Feed results into regression dashboards |
| Chaos / spectral | `stadium-billiard` | Stadium billiard eigen spectrum (still uses FEM). | Requires FEM-enabled license |

## 6. Routine Validation

1. Run the consolidated smoke suite:

   ```sh
   make smoke
   # wolframscript -file scripts/smoke_tests.wls
   ```

   The suite covers Fourier analytics, thermodynamics, QHO spectra, and oscillator integration; it exits non-zero on failure and prints offending tests.

2. Spot-check principal tasks (recommended before deployments):

   ```sh
   wolframscript -file physics_cli.wls --task=partition-function --beta=0.7 --spectrum='[0.5,1.5,2.5,3.5]'
   wolframscript -file physics_cli.wls --task=qho-spectrum --n=6 --L=9 --m=1 --omega=1
   wolframscript -file physics_cli.wls --task=damped-oscillator --gamma=0.05 --omega0=1 --force=1 --drive=0.9 --tmax=40 --samples=201
   wolframscript -file physics_cli.wls --task=helmholtz-square --frequency=25 --waveSpeed=1 --meshDensity=300
   wolframscript -file physics_cli.wls --task=dirac-trace --muLabel=mu --nuLabel=nu
   wolframscript -file physics_cli.wls --task=helmholtz-sweep --densities='[150,200,300,400]' --frequency=25 --waveSpeed=1
   ```

Document outcomes in `NOTES.md` after each run.

## 7. Troubleshooting & Resilience

- **Missing `wolframscript`** – use full path or symlink into `/usr/local/bin`.
- **JSON encoding errors** – ensure symbolic expressions are converted via `ToString[..., InputForm]` (handled automatically inside PhysicsCLI).
- **Helmholtz licensing** – the finite-difference implementation eliminates FEM licensing requirements; adjust `meshDensity` to balance fidelity/cost.
- **FeynCalc unavailable** – drop `FeynCalc.paclet` into `paclets/` (or point `FAT_TAILED_PACLET_PATH` to the directory containing it); PhysicsCLI auto-installs the paclet before evaluation.
- **Long running tasks** – prefer `physics_cli.wls` to isolate runs and guarantee clean exit codes; wrap invocations in shell scripts for retries/backoff.

## 8. Operational Hygiene

- Keep `PATH` exports in `~/.zprofile`/`~/.zshrc` so Codex sessions inherit them automatically.
- Maintain ASCII-only outputs to simplify log parsing (`physics_cli.wls` enforces this for all JSON/text streams).
- Record every validation session in `NOTES.md`, including command lines, notable outputs, and any environmental blockers.
- Push commits to the private GitHub remote after each coherent change:

  ```sh
  git status -sb
  git add ...
  git commit -m "<summary>"
  git push origin main
  ```

With these steps, the PhysicsCLI stack remains reproducible, license-compliant, and ready for Azure burst deployments or local exploratory physics workflows.
