# Fractional Kinetics with Absorbing Walls

Summary

Compute survival probabilities and first passage time distributions for
space fractional diffusion on a finite interval with absorbing boundaries.
Quantify spectral gaps and extreme event tails.

Exact Problem

For a one dimensional space fractional diffusion process with index alpha
between 1 and 2 on an interval with absorbing walls, compute survival S(t)
and first passage distribution F(t) with controlled error, including tail
behavior and scaling of spectral gaps with alpha. Provide numerics and
asymptotics across meshes and step sizes.

Pros

- Models rare events and boundary layer physics explicitly.
- Extends our finite difference PDE toolkit with fractional stencils.
- Outputs are time series and scalars suitable for CI monitoring.

Cons

- Discretization choices for the fractional Laplacian have trade offs.
- Boundary effects complicate convergence and error estimates.

What Satisfies the Physics Community

- Transparent definition of the discrete fractional operator and its limits.
- Mesh refinement studies with residuals and convergence rates.
- Agreement with known limiting cases alpha to 2 and alpha to 1.

Approach with This Repo

- Implement a fractional Laplacian stencil in Classical.wl with options for
  different schemes and orders, plus residual checks like Helmholtz.
- Add fractional-survival CLI task that computes S(t), F(t), and spectra.
- Emit JSON with residuals, rates, and tail fit parameters, plus PNG plots.

Deliverables and Milestones

- M1: operator implementation and unit tests on simple functions.
- M2: survival curves and mesh sweep residuals.
- M3: tail analysis and documentation.

Validation and Benchmarks

- Consistency across discretization schemes and mesh densities.
- Recovery of classical diffusion results at alpha equals 2.

Risks and Mitigations

- Operator inconsistency across schemes: expose scheme choice and compare.
- Stability issues: add time step and mesh coupling guidance.

Planned CLI Sketch

- wolframscript -file physics_cli.wls --task=fractional-survival \
  --alpha=1.5 --grid=800 --tmax=100 --dt=0.01 --output=json

References

- https://en.wikipedia.org/wiki/Fractional_Laplacian
- https://arxiv.org
