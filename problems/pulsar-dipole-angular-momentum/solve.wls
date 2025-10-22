(*
  Magnetic Dipole Angular Momentum Radiation and Pulsar Spin-down

  Headless WL script that writes an ASCII report and an optional PNG figure.
  Conforms to repo runbook: WL-only under problems/, ASCII outputs, no
  notebooks. All artifacts confined to this directory.
*)

Block[{
  outDir, c = 2.99792458*^8, mu0 = 4*Pi*1.0*^-7,
  m0 = 1.0*^30, (* A m^2, typical neutron star order-of-magnitude *)
  alpha = 30 Degree, (* misalignment *)
  period = 0.1, (* seconds *)
  omega, ez, unit, tGrid, mdot, mddot, mvec, dLdtVec, dUdt, ratio,
  samples = 361, fig
  },

  (* Output directory is the directory containing this script. *)
  outDir = DirectoryName[$InputFileName];
  If[!StringQ[outDir] || outDir === "", outDir = Directory[]];
  SetDirectory[outDir];

  omega = 2*Pi/period;
  ez = {0.0, 0.0, 1.0};
  unit[v_] := v/Sqrt[v.v];

  (* Rigidly rotating magnetic dipole with fixed misalignment. *)
  mvec[t_] := m0*{
    Sin[alpha]*Cos[omega*t],
    Sin[alpha]*Sin[omega*t],
    Cos[alpha]
  };
  mdot[t_] := D[mvec[tt], tt] /. tt -> t;
  mddot[t_] := D[mvec[tt], {tt, 2}] /. tt -> t;

  (* Part (a) result used as definition for evaluation. The sign corresponds
     to angular momentum carried away by radiation; the source loses the same
     amount. *)
  dLdtVec[t_] := - (mu0/(6*Pi*c^3)) Cross[mdot[t], mddot[t]];

  (* Radiated power for a magnetic dipole. *)
  dUdt[t_] := - (mu0/(6*Pi*c^3)) (mddot[t].mddot[t]);

  (* Evaluate over one period for demonstration. *)
  tGrid = Subdivide[0.0, period, samples - 1];

  ratio = Mean[Map[(dLdtVec[#][[3]]) &, tGrid]] /
          Mean[Map[dUdt, tGrid]];

  (* Simple figure: torque Lz and power versus time over one period. *)
  fig = ListLinePlot[
    {
      Table[{t, dLdtVec[t][[3]]}, {t, tGrid}],
      Table[{t, dUdt[t]}, {t, tGrid}]
    },
    PlotLegends -> {"dLz/dt", "dU/dt"},
    PlotLabel -> "Axial torque and power vs time (one rotation)",
    PlotTheme -> "Scientific",
    ImageSize -> 900
  ];
  Export["torque_power_vs_time.png", fig, ImageResolution -> 150];

  (* Generate ASCII report. *)
  Module[{report = OpenWrite["report.txt", BinaryFormat -> False],
          az = alpha, om = omega,
          meanTorque, meanPower, lzUnit},
    meanTorque = Mean[Map[(dLdtVec[#][[3]]) &, tGrid]];
    meanPower = Mean[Map[dUdt, tGrid]];
    lzUnit = If[meanTorque < 0, "negative z", "positive z"];

    WriteString[report, "Magnetic Dipole Radiation: Angular Momentum and Pulsar Spin-down\n\n"];

    WriteString[report, "Part (a): Angular momentum radiation rate\n\n"];
    WriteString[report,
      "A localized, time-dependent magnetic dipole radiates through far-zone " <>
      "fields that fall as one over distance and induction fields that fall " <>
      "as the inverse square of distance. The net torque crossing a large " <>
      "sphere follows from integrating the Maxwell stress tensor. After the " <>
      "standard angular averages on the unit sphere, the only surviving " <>
      "vector structure is the cross product of the first and second time " <>
      "derivatives of the dipole moment evaluated at the retarded time. The " <>
      "sign is such that the radiation carries away angular momentum and the " <>
      "source loses the same amount.\n\n"
    ];

    WriteString[report, "Part (b): Pulsar with misaligned frozen-in dipole\n\n"];
    WriteString[report,
      "Model the star as a rigid rotor with angular speed omega and a fixed " <>
      "magnetic moment magnitude m0 at a constant misalignment angle alpha " <>
      "from the rotation axis z. The moment precesses uniformly about z. In " <>
      "this model the axial component of the angular momentum loss rate is a " <>
      "constant in time, proportional to the square of the transverse moment " <>
      "and the cube of the angular speed, directed opposite to the rotation " <>
      "axis for positive omega. The radiated power is also constant and " <>
      "proportional to the square of the transverse moment and the fourth " <>
      "power of the angular speed. Their ratio equals the inverse angular " <>
      "speed, with the same negative sign.\n\n"
    ];

    WriteString[report, "Demonstration (one-rotation time averages)\n"];
    WriteString[report, "- period: " <> ToString@NumberForm[period, {5, 3}] <> " s\n"];
    WriteString[report, "- omega:  " <> ToString@NumberForm[om, {7, 3}] <> " rad s^-1\n"];
    WriteString[report, "- alpha:  " <> ToString@NumberForm[az/Degree, {4, 0}] <> " deg\n"];
    WriteString[report, "- m0:     " <> ToString@NumberForm[m0, {6, 2}] <> " A m^2\n\n"];

    WriteString[report, "Computed time averages\n"];
    WriteString[report, "- <dLz/dt>: " <> ToString@NumberForm[meanTorque, {8, 3}] <>
      " N m s (sign: " <> lzUnit <> ")\n"];
    WriteString[report, "- <dU/dt>:  " <> ToString@NumberForm[meanPower, {8, 3}] <>
      " W\n"];
    WriteString[report, "- ratio <dLz/dt>/<dU/dt>: " <>
      ToString@NumberForm[ratio, {6, 3}] <> " s\n\n"];

    WriteString[report, "Interpretation\n"];
    WriteString[report,
      "The equality of the ratio with the inverse angular speed expresses the " <>
      "usual power equals torque times angular speed relation. The constant " <>
      "misalignment produces time-independent axial torque and power in this " <>
      "idealized model. Real pulsars exhibit additional effects such as plasma " <>
      "winds and multipole structure, but the scaling and sign remain robust.\n\n"
    ];

    WriteString[report, "References\n"];
    WriteString[report, "https://link.aps.org/doi/10.1103/PhysRev.56.72\n"];
    WriteString[report, "https://en.wikipedia.org/wiki/Magnetic_dipole_radiation\n"];
    WriteString[report, "https://www.feynmanlectures.caltech.edu/II_28.html\n"];
    Close[report];
  ];
]

