# Magnetic Dipole Radiation: Angular Momentum and Pulsar Spin-down

This directory contains a complete Wolfram Language, headless solution for the
two-part problem on angular momentum radiation by a time-dependent magnetic
dipole and its application to a rotating neutron star with a misaligned frozen
in magnetic moment.

Scope

- Part (a): Show that a time-dependent magnetic dipole radiates angular
  momentum at a rate proportional to the cross product of the first and second
  time derivatives of the dipole moment evaluated at the retarded time. The
  sign and constant follow from the far-field expansion and the Maxwell stress
  tensor with standard angular integrals on the unit sphere.
- Part (b): Apply the result to a pulsar modeled as a rigid rotor with fixed
  magnetic dipole magnitude misaligned by a constant angle with the rotation
  axis. Compare the time averages of the axial angular momentum loss rate and
  the total radiated power.

Conventions

- SI units, vacuum. The speed of light and vacuum permeability are treated as
  symbols in the report and as double-precision constants in the optional
  numeric demonstration.
- The retarded-time evaluation is implicit in the radiation-zone formulas and
  referenced explicitly in the narrative.

How to run

- From the repository root on macOS:

  /Applications/Wolfram.app/Contents/MacOS/wolframscript \
    -file problems/pulsar-dipole-angular-momentum/solve.wls

Outputs

- report.txt: complete ASCII narrative for parts (a) and (b), with clear
  statements of the proportionalities and constants, and a compact physical
  interpretation for the pulsar case.
- torque_power_vs_time.png: optional figure demonstrating that both the axial
  torque and the radiated power are constant in time for uniform rotation with
  a fixed misalignment. The image is ignored by git per repo policy.

References

https://link.aps.org/doi/10.1103/PhysRev.56.72
https://en.wikipedia.org/wiki/Magnetic_dipole_radiation
https://www.feynmanlectures.caltech.edu/II_28.html

