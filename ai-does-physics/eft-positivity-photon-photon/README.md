# EFT Positivity for Photon Photon Scattering

Summary

Constrain Euler Heisenberg low energy Wilson coefficients for light by light
scattering using dispersion relations, crossing symmetry, and unitarity. Focus
on forward limit and small t derivatives, build automation that outputs allowed
regions and feasibility certificates.

Exact Problem

Given a low energy amplitude ansatz for gamma gamma to gamma gamma with
helicity structure and polynomial Wilson coefficients up to fixed order, impose
analyticity, crossing, and partial wave unitarity via subtracted dispersion
relations over the physical cut. Determine the allowed region for the Wilson
coefficients consistent with these principles, including polarization mixed
channels, and report regulator independent bounds when massless exchanges are
present.

Pros

- Strong theoretical control with clear axioms and verifiable constraints.
- High automation potential with clean CLI inputs and ASCII JSON outputs.
- Publishable if we unify finite energy sum rules and IR safe subtractions.
- Natural fit to symbolic and numeric capabilities of this repo.

Cons

- IR subtleties with massless states require careful subtractions and cuts.
- Bounds may be loose without model input; tuning subtraction points matters.
- Requires precise normalization conventions across helicity channels.

What Satisfies the Physics Community

- Clear statement of assumptions and dispersion setup with subtractions.
- Reproduction of known sign constraints from QED one loop as a sanity check.
- Robustness study versus number of subtractions and energy windows.
- Feasibility or infeasibility certificates from convex programs where used.
- Open artifacts: scripts, JSON regions, and plot assets produced headless.

Approach with This Repo

- Add CLI task eft-positivity that accepts an amplitude basis, subtraction
  scheme, energy window, and helicity channel list. Emit JSON with feasible
  region vertices or sample, regulator diagnostics, and a status block.
- Use Analysis.wl for transform style algebra, and Utils.wl for hardened
  parsing. Add a small convex feasibility solver or call built in optimizers.
- Provide smoke tests that reproduce QED sign constraints and a simple mixed
  channel bound. Integrate into make smoke with quick settings.

Deliverables and Milestones

- M1: forward limit bounds for single subtraction, single polarization.
- M2: mixed polarization and t derivatives. JSON region and plots.
- M3: IR safe subtractions with report on regulator independence.
- M4: documentation and reproducibility package under ai does physics.

Validation and Benchmarks

- Recover known QED coefficient signs at small coupling in the forward limit.
- Stress tests under truncated spectral integrals and different subtraction
  points. Report where results stabilize.

Risks and Mitigations

- IR risk: build subtraction schemes as first class options and compare.
- Normalization drift: pin conventions in README and in code comments.
- Overly loose bounds: add finite energy sum rules and partial wave cuts.

Planned CLI Sketch

- wolframscript -file physics_cli.wls --task=eft-positivity --channel=++ --order=4 \
  --subtractions=2 --smin=sth --smax=smax --t=0 --output=json

References

- https://arxiv.org
- https://feyncalc.github.io
