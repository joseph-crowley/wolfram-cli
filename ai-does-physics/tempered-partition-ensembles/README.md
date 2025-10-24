# Tempered Stable Mixed Canonical Ensembles

Summary

Define generalized canonical ensembles where inverse temperature is random with
tempered stable mixing. Compute partition function, internal energy, heat
capacity, and tail indices for discrete spectra under this mixing.

Exact Problem

Given a discrete spectrum and a tempered stable mixing distribution for beta,
compute ensemble averages and thermodynamic curves. Quantify how tail indices
propagate into observables and map regimes where tails dominate behavior.

Pros

- Directly aligned with fat tailed emphasis and risk awareness.
- Numerically stable with high precision arithmetic in WL.
- Yields actionable tail sensitivity indices.

Cons

- Parameter estimation for mixing requires care in applications.
- Closed forms may be unavailable; rely on stable quadratures.

What Satisfies the Physics Community

- Clear definitions of mixing distributions and parameter ranges.
- Reduction to standard canonical results in the appropriate limit.
- Reproducible sweeps with precision and tolerance controls.

Approach with This Repo

- Add tempered-partition CLI that accepts a spectrum and mixing parameters,
  returns Z, U, C, and tail indices across beta ranges.
- Integrate with Analysis.wl for stable quadrature and precision control.

Deliverables and Milestones

- M1: implementation and checks against canonical and q exponential limits.
- M2: sensitivity sweeps and tail index reporting.
- M3: documentation and reproducibility artifacts.

Validation and Benchmarks

- Recover canonical ensemble as tempering vanishes.
- Compare to synthetic data with known tail behavior.

Risks and Mitigations

- Quadrature difficulty: adaptive high precision evaluation with checks.
- Parameter pathologies: input validation and safe defaults.

Planned CLI Sketch

- wolframscript -file physics_cli.wls --task=tempered-partition \
  --spectrum='[0.5,1.5,2.5]' --alpha=1.5 --lambda=0.2 --output=json

References

- https://en.wikipedia.org/wiki/Tempered_stable_distribution
