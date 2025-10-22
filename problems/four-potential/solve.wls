(*
  Four-Potential Problem Solver (WL, headless)

  - Part (a): produces an ASCII explanation in report.txt arguing that the
    scalar and vector potentials transform together as a single spacetime
    four-quantity under Lorentz transformations, once a covariant gauge is
    fixed. No equations are printed, only words.

  - Part (b): computes the retarded scalar potential of a uniformly moving
    point charge in the lab frame at a fixed time slice and extracts the
    cross-sectional contour where the potential equals one. Overlays this
    contour for speeds 0.3, 0.5, 0.7, and 0.9 times the speed of light and
    exports a PNG figure.

  Repository policy: ASCII-only artifacts, WL-only under problems/, headless
  execution via wolframscript. This script writes report.txt and
  equipotential_cross_section.png into its own directory.
*)

Block[{
  (* Numeric conventions *)
  c = 1.0, (* speed of light in code units *)
  phi0 = 1.0, (* target potential value defining the contour *)
  betas, colors, plotRange, outDir
  },

  (* Discover the directory of this script and place outputs there. *)
  outDir = DirectoryName[$InputFileName];
  If[!StringQ[outDir] || outDir === "", outDir = Directory[]];
  SetDirectory[outDir];

  (* Speeds as fractions of c and plot cosmetics. *)
  betas = {0.3, 0.5, 0.7, 0.9};
  colors = {
    RGBColor[0.0, 0.45, 0.70], (* blue *)
    RGBColor[0.87, 0.29, 0.10], (* red *)
    RGBColor[0.00, 0.62, 0.45], (* green *)
    RGBColor[0.80, 0.47, 0.65]  (* purple *)
  };
  plotRange = {{-2.6, 2.6}, {-2.6, 2.6}};

  ClearAll[retardedTime, phiLW, gamma, safeSqrt];

  (* Robust positive square root wrapper that returns Indeterminate on
     negative input to help ContourPlot avoid bad samples. *)
  safeSqrt[z_?NumericQ] := If[z >= 0.0, Sqrt[z], Indeterminate];

  (* Closed-form retarded time for uniform motion along +x at lab time t = 0. *)
  retardedTime[x_?NumericQ, y_?NumericQ, beta_?NumericQ] := Module[
    {d, disc},
    d = 1.0 - beta*beta; (* 1 - beta^2 > 0 for speeds below light *)
    disc = x*x + y*y*d;  (* discriminant inside the square root *)
    If[d <= 0.0, Return[Indeterminate]];
    If[disc < 0.0, Return[Indeterminate]];
    (* Choose the negative root to enforce causality with t = 0. *)
    (- x*beta - safeSqrt[disc]) / d
  ];

  (* Scalar potential using the standard Lienard Wiechert form. Constants are
     scaled so that charge times Coulomb prefactor equals one. *)
  phiLW[x_?NumericQ, y_?NumericQ, beta_?NumericQ] := Module[
    {s, rx, ry, r, nx, denom},
    s = retardedTime[x, y, beta];
    If[!NumericQ[s], Return[Indeterminate]];
    rx = x - beta*s; (* x-component of vector from retarded source to field *)
    ry = y;
    r = Sqrt[rx*rx + ry*ry];
    If[r <= 0.0, Return[Infinity]];
    nx = rx/r; (* cosine of angle between velocity and R-hat *)
    denom = (1.0 - beta*nx) * r;
    If[denom <= 0.0, Return[Indeterminate]];
    1.0/denom
  ];

  gamma[beta_?NumericQ] := 1.0/Sqrt[1.0 - beta*beta];

  (* Build a single-contour plot for a given beta and color. *)
  makeContour[beta_?NumericQ, col_] := Module[{b = beta},
    ContourPlot[
      phiLW[x, y, b],
      {x, plotRange[[1, 1]], plotRange[[1, 2]]},
      {y, plotRange[[2, 1]], plotRange[[2, 2]]},
      Contours -> {phi0},
      ContourStyle -> {AbsoluteThickness[2.0], col},
      ColorFunction -> None,
      ContourShading -> False,
      Frame -> True,
      FrameLabel -> {"x", "y"},
      PlotPoints -> 80,
      MaxRecursion -> 2,
      AspectRatio -> 1,
      PlotRange -> plotRange
    ]
  ];

  (* Axis intercepts for the chosen normalization. By construction,
     the static case yields a unit circle. Along +x with y = 0 the
     potential equals one at x = 1 for all subluminal speeds, while along
     x = 0 the y-intercept equals the Lorentz factor. *)
  xIntercept[beta_?NumericQ] := 1.0;
  yIntercept[beta_?NumericQ] := gamma[beta];

  (* Generate the overlaid contour figure. *)
  contours = MapThread[makeContour, {betas, colors}];
  legendLabels = Map[
    Function[b, "v/c = " <> ToString@NumberForm[b, {2, 1}]], betas
  ];

  base = Show[contours, PlotRange -> plotRange, ImageSize -> 900,
    GridLines -> Automatic, GridLinesStyle -> Directive[GrayLevel[0.9], Dashed],
    PlotLabel -> "Equipotential cross section at fixed lab time"
  ];

  (* Simple manual legend via Epilog to keep ASCII-safe styling. *)
  legend = Graphics[
    Table[
      {
        colors[[i]],
        AbsoluteThickness[2.0],
        Line[{{-2.4, 2.4 - 0.2*i}, {-2.1, 2.4 - 0.2*i}}],
        Black,
        Text[Style[legendLabels[[i]], 12], {-1.7, 2.4 - 0.2*i}]
      },
      {i, Length[betas]}
    ],
    PlotRange -> plotRange
  ];

  fig = Show[base, legend];
  Export["equipotential_cross_section.png", fig, ImageResolution -> 180];

  (* Prepare numeric validation for report. *)
  interceptData = Table[
    With[{b = betas[[i]], g = gamma[betas[[i]]]},
      <|
        "beta" -> b,
        "gamma" -> N[g, 8],
        "xIntercept" -> N[xIntercept[b], 8],
        "yIntercept" -> N[yIntercept[b], 8]
      |>
    ],
    {i, Length[betas]}
  ];

  (* Write the report. *)
  report = OpenWrite["report.txt", BinaryFormat -> False];
  WriteString[report, "Four-Potential Problem Report\n\n"];
  WriteString[report, "Part (a): Covariant structure of potentials\n\n"];
  WriteString[report,
    "The spacetime gradient transforms as a covector and the electric and " <>
    "magnetic fields transform together under Lorentz maps. Demanding that " <>
    "spacetime derivatives of a single candidate potential reproduce those " <>
    "field transformations forces the scalar potential and the spatial vector " <>
    "potential to transform together as one four-quantity. Gauge freedom " <>
    "allows addition of a spacetime gradient of a scalar, which preserves the " <>
    "fields. Fixing a covariant gauge removes that ambiguity and leaves a " <>
    "linear Lorentz transformation law for the four-potential.\n\n"
  ];

  WriteString[report, "Part (b): Equipotential cross section\n\n"];
  WriteString[report,
    "We evaluate the standard retarded scalar potential of a uniformly moving " <>
    "point charge at a fixed laboratory time. The target contour value is " <>
    "chosen so the static case is a unit circle. For nonzero speeds the " <>
    "contours flatten along the motion and expand transversely, forming oblate " <>
    "ellipses. The figure equipotential_cross_section.png overlays four speeds.\n\n"
  ];

  WriteString[report, "Numeric intercepts (units where the static radius is 1)\n"];
  Do[
    With[{row = interceptData[[i]]},
      WriteString[report,
        StringRiffle[{
          "v/c = " <> ToString@NumberForm[row["beta"], {2, 1}],
          "gamma = " <> ToString@NumberForm[row["gamma"], {4, 3}],
          "x-intercept ~ " <> ToString@NumberForm[row["xIntercept"], {5, 3}],
          "y-intercept ~ " <> ToString@NumberForm[row["yIntercept"], {5, 3}]
        }, ", "] <> "\n"
      ]
    ],
    {i, Length[interceptData]}
  ];

  WriteString[report, "\nArtifacts\n"];
  WriteString[report, "- report.txt (this file)\n"];
  WriteString[report, "- equipotential_cross_section.png (overlaid contours)\n\n"];

  WriteString[report, "References\n"];
  WriteString[report, "https://www.feynmanlectures.caltech.edu/II_26.html\n"];
  WriteString[report, "https://en.wikipedia.org/wiki/Li%C3%A9nard%E2%80%93Wiechert_potential\n"];
  Close[report];
]
