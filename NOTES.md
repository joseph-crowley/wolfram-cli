# Working Notes

## 2025-10-22
- Sourced ~/.zprofile and ~/.zshrc to load Joe's environment, then inspected the repository root with `ls`.
- Reviewed `README.md`, `RUNBOOK.md`, and `FIELD_MANUAL.md` to understand documented workflows and validation procedures.
- Sampled `scripts/` contents via `ls` and inspected representative `.wls` scripts along with the `Makefile` to map supported CLI tooling.
- Confirmed the git worktree is clean and synced with `origin/main`.
- Ran `which wolframscript`, observed it was missing from PATH, exported `/Applications/Wolfram.app/Contents/MacOS` to PATH, and confirmed availability.
- Conducted a code audit across `.wls` scripts; noted repeated ad hoc argument parsing, unchecked `ToExpression` usage, undefined `err` symbols in error paths, and non ASCII symbols contrary to CLI legibility goals.
- Reviewed current wolframscript setup guidance to validate PATH handling heuristics and kernel selection steps.
- Built modular `PhysicsCLI` library (`Utils`, `Analysis`, `Classical`, `Quantum`, `CLI`) to centralize parsing, resilience, and reusable physics solvers.
- Replaced legacy scripts with thin wrappers over `PhysicsCLI` tasks and launched a new unified entry point `physics_cli.wls`.
- Expanded `scripts/smoke_tests.wls` into a library regression harness covering analytical, thermodynamic, quantum, and classical tasks.
- Updated documentation (README, RUNBOOK, FIELD_MANUAL) and the Makefile to reflect the new task catalog and ascii first conventions.
- Verified core workflows via the PhysicsCLI driver:
  - Statistical physics: `wolframscript -file physics_cli.wls --task=partition-function --beta=0.7 --spectrum='[0.5,1.5,2.5,3.5]'` returning `{Z≈1.3147, U≈1.2274, C≈0.4197}`.
  - Quantum mechanics: `wolframscript -file physics_cli.wls --task=qho-spectrum --n=6 --L=9 --m=1 --omega=1` yielding the first six harmonic energies near `(n + 1/2)`.
  - Classical dynamics: `wolframscript -file physics_cli.wls --task=damped-oscillator --gamma=0.05 --omega0=1 --force=1 --drive=0.9 --tmax=40 --samples=201` producing a 201-point trajectory with damping-induced beat structure.
  - QFT trace workflow currently blocked: `wolframscript -file physics_cli.wls --task=dirac-trace --muLabel=mu --nuLabel=nu` requires FeynCalc; bootstrap via `InstallFeynCalc[]` failed because https://www.feyncalc.org/install.m is unreachable from this environment.
  - Electromagnetic Helmholtz FEM example: `wolframscript -file physics_cli.wls --task=helmholtz-square --frequency=25 --waveSpeed=1 --meshDensity=300` terminates with `license error` (FEM components not available in the current Mathematica license). Classical alternatives remain operational.

## References
- https://www.wolfram.com/wolframscript/
- https://support.wolfram.com/47243/
- https://support.wolfram.com/46070
- https://resources.wolframcloud.com/PacletRepository/resources/Wolfram/CommandLineParser/
- https://feyncalc.github.io/
