# Maximum Entropy Spectral Reconstruction with Exact Sum Rules

Summary

Reconstruct a positive spectral density from a small set of Euclidean moments
and exact sum rules such as causality or superconvergence, while handling
fat tailed behavior robustly.

Exact Problem

Given limited moment data and exact integral constraints, produce a spectral
density that maximizes an entropy functional subject to these constraints,
returning the density, dual variables, and diagnostics. Quantify uncertainty
and tail sensitivity.

Pros

- Convex structure provides clear feasibility or infeasibility results.
- Directly targets heavy tail stability and diagnostics.
- Produces portable JSON outputs for downstream analysis.

Cons

- Choice of default model and entropy can affect reconstructions.
- Ill posed instances require careful regularization and certificates.

What Satisfies the Physics Community

- Transparent constraints, priors, and regularization choices.
- Recovery of known synthetic spectra and stability to noise.
- Public scripts and exact reproducibility from CLI.

Approach with This Repo

- Add maxent-spectrum CLI that takes moments, sum rules, grid, and prior.
- Solve convex dual for multipliers and export rho, multipliers, and fit
  statistics with tail indices and sensitivity metrics.

Deliverables and Milestones

- M1: dual solver and basic reconstructions on synthetic data.
- M2: tail constrained reconstructions with sensitivity reports.
- M3: documentation and reproducibility assets.

Validation and Benchmarks

- Bootstrap moment sets and report confidence intervals.
- Compare against ground truth on testbeds with known heavy tails.

Risks and Mitigations

- Overregularization: expose hyperparameters and add L curve diagnostics.
- Numerical grid bias: vary grids and report stability.

Planned CLI Sketch

- wolframscript -file physics_cli.wls --task=maxent-spectrum \
  --moments='[m0,m1,m2]' --sumrules='["sum1","sum2"]' --grid=1024

References

- https://arxiv.org
