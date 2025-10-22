# Notes

Date: 2025-10-22
Host: macOS Apple Silicon; wolframscript 1.13.0
Repo: wolfram-cli; RUNBOOK.md verified and followed (WL-only under problems/)

Objective

- Provide a rigorous, ASCII-only narrative solution for the angular-momentum
  radiation of a magnetic dipole and apply it to a misaligned pulsar. Keep all
  artifacts local to this directory. No equations in the report; constants and
  relationships are described in words.

Approach

- Part (a): Explain, in words, how the angular momentum flux follows from the
  Maxwell stress tensor integrated over a sphere using the radiation-zone field
  expansion for a localized magnetic dipole source. The leading contribution to
  the torque comes from the interference between radiation and induction terms,
  yielding a vector proportional to the cross product of the first and second
  time derivatives of the magnetic moment at retarded time. The universal
  angular integrals fix the numerical constant and the sign.
- Part (b): Represent the pulsar dipole as a constant-magnitude vector that
  rotates uniformly about the z axis with a fixed misalignment angle. Use the
  general result to obtain the axial torque and compare to the radiated power.
  The ratio equals the inverse angular speed with a negative sign for loss.

Validation

- WL script computes m dot and m double dot for a rigid rotation model,
  evaluates the angular-momentum loss vector, and the radiated power, and
  confirms constancy in time and the ratio of magnitudes.

Artifacts

- report.txt (ASCII)
- torque_power_vs_time.png (optional visualization; ignored by git)

References

https://link.aps.org/doi/10.1103/PhysRev.56.72
https://en.wikipedia.org/wiki/Magnetic_dipole_radiation
https://www.feynmanlectures.caltech.edu/II_28.html

