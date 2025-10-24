# Landau Singularity Mapper for One Loop Topologies

Summary

Automate the solution of Landau equations for scalar triangles and boxes with
mixed internal masses. Output pinch conditions, branch cut locations, and
amplitude zero loci across kinematic regions, as ASCII JSON and simple plots.

Exact Problem

Given a one loop Feynman integral topology and mass assignment, solve the
Landau equations to determine singular manifolds in external kinematic space
and classify them. Provide practical maps that analysts can use to avoid or
exploit singularities in amplitude studies.

Pros

- Concrete automation with immediate value for practitioners.
- Mix of symbolic solving and numeric sampling fits repo strengths.
- Results are visual and checkable without heavy dependencies.

Cons

- Full generality across arbitrary masses and momenta is ambitious.
- Some cases require careful case splits and sign discipline.

What Satisfies the Physics Community

- Correct reproduction of textbook singular sets for canonical examples.
- Clear classification of branch cuts and pinch conditions with region logic.
- Cross checks by local numerical evaluation near predicted loci.

Approach with This Repo

- Add landau-mapper CLI that takes topology, masses, and kinematic ranges.
- Use Analysis.wl for system solving and inequality region building, then
  sample and export JSON polyhedral descriptions and PNG sketches.
- Optional check with Package X at select kinematic points.

Deliverables and Milestones

- M1: massless triangle and equal mass box verified against references.
- M2: mixed masses and external invariants with region decomposition.
- M3: documentation and reproducibility package with examples.

Validation and Benchmarks

- Compare to analytic expectations and verify numerically by contour
  continuation or stable local expansions at sample points.

Risks and Mitigations

- Complex case splits: encode region logic cleanly and export it as JSON.
- Numerical instability: use controlled precision and input validation.

Planned CLI Sketch

- wolframscript -file physics_cli.wls --task=landau-mapper --topology=box \
  --masses='[m1,m2,m3,m4]' --smin=... --smax=... --tmin=... --tmax=...

References

- https://arxiv.org
- https://packagex.hepforge.org
