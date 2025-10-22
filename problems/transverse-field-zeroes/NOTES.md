# Notes

Date: 2025-10-22
Host: macOS on Apple Silicon, wolframscript 1.13.0
Repo: wolfram-cli (RUNBOOK.md verified)

Objective

- Solve the transverse-field zeroes problem entirely in Wolfram Language.
- Keep artifacts and documentation confined to this directory.
- Respect repo policy: WL-only; no Python or other non-WL sources in `problems/`.

Summary of Method

- Defined the complex scalar psi with a traveling-wave factor and an affine
  polynomial in x and y prime. Verified it satisfies the source-free wave
  equation in free space under the dispersion relation c equals omega over k.
- Built E with transverse components proportional to psi and deduced the
  longitudinal component from Gauss law by integrating minus the transverse
  divergence with respect to z. Chose zero integration constant to obtain the
  minimal longitudinal field compatible with propagation.
- Constructed B from Faraday law for time-harmonic fields with temporal factor
  exp of minus i omega t, yielding B equals one over i omega times the curl of
  E. Verified Ampere law with the same dispersion relation.
- Analyzed the regime g much larger than 1 by dropping the k x squared sin
  delta contribution in psi. This preserves the coupling between y and z via
  y prime while simplifying the x dependence.

Results

- Wave equation holds exactly with the dispersion relation. The symbolic check
  returns True.
- The deduced longitudinal electric field is proportional to the traveling
  phase and contains a constant term in x plus a linear term in x. Magnetic
  field components satisfy Ampere law identically when c equals omega over k.
- Electric zero locus in the g much greater than 1 limit is characterized by
  x equals 0 and y prime equals 0. The latter implies the straight line
  y equals negative z tan delta in the plane x equals 0. This is the axis
  of symmetry, which we denote z prime.
- Magnetic transverse zeroes in the same limit are obtained using polar
  coordinates defined by g x equals r cos theta and y prime equals r sin
  theta. Enforcing the simultaneous vanishing of the real transverse magnetic
  components yields a fixed radius r equals sin delta over k and a phase angle
  theta that equals negative of k z minus omega t. The resulting locus is an
  elliptic helix of radius components r over g along x and r along y prime,
  rotating in time with angular frequency omega and advancing with wavevector
  k along the propagation direction. The helix winds around the electric zero
  axis z prime.

Artifacts

- report.txt summarizes the symbolic checks and the zero-locus conditions.
- sketch.png provides a visualization with two projections versus z, showing
  both the x and y prime components of the magnetic zero helix; the electric
  zero axis is the line x equals 0, y prime equals 0.

Commands Executed

- wolframscript -file problems/transverse-field-zeroes/solve.wls

Notes

- All intermediate manipulations use symbolic calculus with assumptions that
  k, omega, g, c are positive and variables are real. No numeric substitution
  is needed beyond the plotting phase, which uses a fixed time slice.
- The sketch intentionally uses y prime as an axis to make the orthogonal
  relationship between y prime and z prime explicit without rotating the full
  coordinate system.

Learnings: Wolfram Language for graduate physics

- Symbolic discipline
  - Keep parameters as named symbols and set global assumptions for reality
    and positivity. Avoid generating unnamed Unique symbols, which produce
    unstable logs.
  - Apply the dispersion relation c equals omega divided by k early when
    checking partial differential equations. This collapses many terms and
    exposes true zeros.
  - Write outputs with InputForm to preserve ASCII and make diffs stable.

- Maxwell workflow patterns
  - Build the electric field from a transverse seed and deduce the longitudinal
    component by integrating the negative transverse divergence with respect to
    the propagation coordinate. Track the integration constant explicitly and
    select the minimal longitudinal field; verify by substituting back into the
    remaining Maxwell equations.
  - Use the phasor convention with time factor exp i of k z minus omega t.
    Under this convention, the magnetic field equals one over i omega times the
    curl of the electric field, and Ampere reduces to the curl of B equals one
    over c squared times the time derivative of E. Consistent signs are
    essential; one mismatch infects all derived relations.

- Real fields and zero sets
  - Resolve real and imaginary parts with ComplexExpand after declaring real
    parameters. Do not ask Solve over the real domain while complex units are
    still present. First expand to real trigonometric form, then enforce real
    equalities.
  - For loci problems, move to coordinates aligned with the physics. The linear
    change to y prime and the scaled polar mapping in the transverse plane
    reduce the zero conditions to a constant radius and a phase relation tied to
    the traveling wave. The helix appears as an immediate corollary, with
    ellipticity set by the x scaling of one over g.

- Headless robustness
  - Avoid any dependence on a front end. Use Export for plots and write text
    reports with OpenWrite and WriteString. This keeps wolframscript runnable in
    CI and on Azure batch nodes.

- Reproducibility and cost hygiene
  - Emit deterministic ASCII artifacts, avoid notebooks for operational runs,
    and place all problem files in a confined directory. This minimizes merge
    noise and storage while remaining audit ready.

- Edge cases and fat tails
  - The helix radius collapses when the parameter delta tends to values where
    its sine vanishes; note this degeneracy explicitly. The large g asymptotic
    approximation is controlled but should be validated if g is not truly
    large. Prefer exact symbolic verification of identities to protect against
    rare numerical pathologies.

Date: 2025-10-22 16:15:00 PDT
Command: wolframscript -file problems/transverse-field-zeroes/solve.wls
Outcome: success; report.txt and sketch.png written
