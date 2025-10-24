# Positivity with Massless States and IR Subtractions

Summary

Sharpen EFT positivity bounds when amplitudes include massless exchanges.
Design subtracted dispersion relations that tame infrared singularities while
preserving analyticity and causality. Produce bounds and demonstrate regulator
independence where possible.

Exact Problem

For low energy 2 to 2 amplitudes with t channel massless poles or cuts, build
subtracted dispersion relations that remove IR divergences, then show how the
resulting sum rules constrain low energy coefficients. Quantify the dependence
on subtraction points and provide a path to regulator independent statements.

Pros

- Addresses a common stumbling block in positivity discussions.
- Methodological contribution with immediate reuse in multiple EFTs.
- Natural extension of the photon photon positivity automation.

Cons

- Careful bookkeeping needed for poles versus cuts and crossing.
- Risk that some statements remain subtraction scheme dependent.

What Satisfies the Physics Community

- Explicit construction of subtracted dispersion relations with clear inputs.
- Worked examples showing identical bounds across equivalent subtraction
  schemes within quoted error bars.
- Public scripts that reproduce all claims from the CLI with ASCII outputs.

Approach with This Repo

- Extend eft-positivity task with flags selecting subtraction count and scheme,
  plus toggles for excluding pole regions in partial waves.
- Add diagnostics that quantify sensitivity to subtraction scales and windows.
- Provide example configs under ai does physics with make recipes.

Deliverables and Milestones

- M1: single massless t channel example with two subtractions.
- M2: sensitivity analysis and stability report across schemes.
- M3: consolidated documentation and reproducibility artifacts.

Validation and Benchmarks

- Cross compare equivalent subtraction choices; demonstrate convergence of
  bounds and report residual dependence as error bars.

Risks and Mitigations

- Scheme dependence: present families of equivalent schemes, not single picks.
- Numerical fragility: use high precision and verified integral quadratures.

Planned CLI Sketch

- wolframscript -file physics_cli.wls --task=eft-positivity \
  --subtractions=2 --ir-scheme=cut-exclusion --t=0 --channels='["++","+-"]'

References

- https://arxiv.org
