# Levy Driven Langevin Tails

Summary

Characterize stationary distributions and large deviation rate functions for a
damped oscillator driven by alpha stable noise in 1 less than alpha less than 2.
Quantify tail scalings and crossovers. Validate with Monte Carlo using variance
reduction.

Exact Problem

For the linear Langevin system with damping and external alpha stable noise,
determine the stationary density tail behavior and compute an accurate rate
function over a wide range including rare events. Provide asymptotics and
numeric estimates that agree within stated tolerances.

Pros

- Direct showcase of fat tailed behavior and where Gaussian intuition fails.
- Builds on existing damped oscillator scripts and CLI patterns.
- Mix of asymptotics and numerics well suited to the repo.

Cons

- Stable law sampling and variance reduction require careful engineering.
- Saddlepoint methods have branch cut subtleties.

What Satisfies the Physics Community

- Explicit tail exponents with controlled error and crossover scales.
- Agreement between asymptotics and Monte Carlo aggregates in the far tail.
- Reproducible CLI runs with fixed seeds and precision settings.

Approach with This Repo

- Add levy-oscillator task with alpha stable noise generator and sampling.
- Add rate function analyzer implementing Fourier Laplace and saddlepoint
  evaluation with contour selection diagnostics.
- Export JSON with tail slopes, crossover points, and MC confidence bands.

Deliverables and Milestones

- M1: stable noise generator and basic stationary samples.
- M2: asymptotic tail derivation and numeric saddlepoint evaluator.
- M3: Monte Carlo validation and variance reduction harness.

Validation and Benchmarks

- Convergence studies in time step and sample count.
- Consistency between analytic and numeric tails across alpha and damping.

Risks and Mitigations

- Sampling bias: use known stable generators and test suites.
- Numerical contour issues: automate contour choice with diagnostics.

Planned CLI Sketch

- wolframscript -file physics_cli.wls --task=levy-oscillator --alpha=1.5 \
  --gamma=0.1 --tmax=1e5 --samples=1e6 --output=json

References

- https://www.juliafinance.org/stable-distributions
- https://en.wikipedia.org/wiki/Stable_distribution
