# S Matrix Bootstrap in 1+1 Dimensions

Summary

Bound low energy coefficients for elastic 2 to 2 scattering in 1 plus 1
dimensions using crossing, unitarity, and analyticity without model inputs.
Pose and solve small LP or SDP problems that produce feasible regions and
dual certificates.

Exact Problem

For a single channel elastic process in 1 plus 1, construct constraints from
unitarity of partial waves, crossing symmetry, and dispersion relations that
bound derivatives of the forward amplitude at threshold. Produce certified
regions for low energy parameters.

Pros

- Clean axiomatic setup with crisp convex structure.
- Lightweight numerics fits CI and headless runs.
- Results are immediately comparable across models.

Cons

- Bounds can be loose without additional assumptions.
- Careful normalization and crossing conventions required.

What Satisfies the Physics Community

- Transparent statement of assumptions and basis choices.
- Reproduction of bounds for integrable benchmarks.
- Dual certificates for any infeasibility claims.

Approach with This Repo

- Add s-matrix-1d CLI that assembles constraints and calls a small convex
  feasibility solver. Export region samples or vertices and the dual variables.
- Provide example configs under ai does physics with make recipes.

Deliverables and Milestones

- M1: forward limit single channel bounds with LP formulation.
- M2: SDP refinement and additional derivative orders.
- M3: documentation and reproducibility artifacts.

Validation and Benchmarks

- Compare to known integrable theories as sanity checks.
- Stability under discretization refinements and derivative order changes.

Risks and Mitigations

- Normalization drift: pin conventions early and test them in smoke.
- Numerical conditioning: scale variables and use precision control.

Planned CLI Sketch

- wolframscript -file physics_cli.wls --task=s-matrix-1d --order=4 --grid=80

References

- https://arxiv.org
