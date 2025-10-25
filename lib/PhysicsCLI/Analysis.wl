baseDir = DirectoryName[$InputFileName];
If[baseDir =!= $Failed && baseDir =!= Null,
  If[!MemberQ[$Path, baseDir], AppendTo[$Path, baseDir]];
  parentDir = FileNameJoin[{baseDir, ".."}];
  If[DirectoryQ[parentDir] && !MemberQ[$Path, parentDir], AppendTo[$Path, parentDir]];
];

BeginPackage["PhysicsCLI`Analysis`", {"PhysicsCLI`Utils`"}];

AnalysisTaskSpecifications::usage = "AnalysisTaskSpecifications[] returns an Association describing CLI-accessible analysis tasks.";
FourierGaussianTransform::usage = "FourierGaussianTransform[config] evaluates the Fourier transform of a shifted Gaussian.";
PartitionFunctionFromSpectrum::usage = "PartitionFunctionFromSpectrum[config] computes canonical thermodynamics from a discrete spectrum.";
AsymptoticIntegralSeries::usage = "AsymptoticIntegralSeries[config] computes a truncated asymptotic expansion of a Gaussian-modulated oscillatory integral.";
LandauMapper::usage = "LandauMapper[config] maps Landau singular loci for triangle or box one-loop topologies.";
QuadratureCertificate::usage = "QuadratureCertificate[config] computes a bounded integral with guards and returns value, lower and upper bounds, timing and flags.";

Begin["`Private`"];

FourierGaussianTransform[config_Association] :=
 Module[{mu = config["mu"], sigma = config["sigma"], params = config["params"], tval = config["t"]},
  Assuming[sigma > 0,
   With[{result = FourierTransform[Exp[-(x - mu)^2/(2 sigma^2)], x, t, FourierParameters -> params]},
    <|
     "Problem" -> "Fourier transform of shifted Gaussian",
     "Inputs" -> <|"mu" -> mu, "sigma" -> sigma, "FourierParameters" -> params, "frequency" -> tval|>,
     "Result" -> ToString[Simplify[result /. t -> tval], InputForm]
    |>
   ]
  ]
 ];

PartitionFunctionFromSpectrum[config_Association] :=
 Module[{beta = config["beta"], spectrum = config["spectrum"], weights, Z, U, heatCapacity},
  weights = Exp[-beta spectrum];
  Z = Total[weights];
  U = Total[spectrum weights]/Z;
  heatCapacity = beta^2 (Total[spectrum^2 weights]/Z - U^2);
  <|
   "Problem" -> "Canonical partition function",
   "Inputs" -> <|"beta" -> beta, "SpectrumCount" -> Length[spectrum]|>,
   "PartitionFunction" -> N[Z, 15],
  "InternalEnergy" -> N[U, 15],
   "HeatCapacity" -> N[heatCapacity, 15]
  |>
 ];

AsymptoticIntegralSeries[config_Association] :=
 Module[{lambdaVal = config["lambda"], aVal = config["a"], terms = config["terms"], series},
  series = AsymptoticIntegrate[
    Cos[lambdaVal x^2] Exp[-aVal x^2], {x, -Infinity, Infinity},
    lambdaVal -> Infinity,
    SeriesTermGoal -> terms
   ];
  <|
   "Problem" -> "Asymptotic expansion of oscillatory Gaussian integral",
   "Inputs" -> <|"lambda" -> lambdaVal, "a" -> aVal, "terms" -> terms|>,
   "Series" -> ToString[series, InputForm]
  |>
 ];

(* ------------------------------------------------------------------ *)
(* Certified quadrature wrappers                                      *)
(* ------------------------------------------------------------------ *)

ClearAll[CertifiedIntegrate, QuadratureCertificate];

CertifiedIntegrate[f_, {v_, a_, b_}, opts_Association] :=
 Module[{prec, acc, goal, rec, tcap, result, time, aborted = False, val,
   errAbs, lower, upper},
  prec = Lookup[opts, "precision", 60];
  acc = Lookup[opts, "accuracyGoal", 12];
  goal = Lookup[opts, "precisionGoal", 12];
  rec = Lookup[opts, "maxRecursion", 12];
  tcap = Lookup[opts, "timeCapSec", 20];
  {time, result} = AbsoluteTiming[
    TimeConstrained[
      Quiet[
        NIntegrate[
          f, {v, a, b},
          Method -> {"GlobalAdaptive", "SymbolicProcessing" -> 0},
          WorkingPrecision -> prec,
          AccuracyGoal -> acc,
          PrecisionGoal -> goal,
          MaxRecursion -> rec
        ],
        {NIntegrate::precw, NIntegrate::eincr}
      ],
      tcap,
      (aborted = True; $Aborted)
    ]
  ];
  If[result === $Aborted || result === $Failed,
    Return[<|"status" -> "aborted", "seconds" -> time|>]
  ];
  val = N[result, 16];
  (* Conservative absolute error budget; tighten in later phases *)
  errAbs = 10.^(-goal);
  lower = val - errAbs;
  upper = val + errAbs;
  <|
    "status" -> "ok",
    "seconds" -> time,
    "value" -> val,
    "lower" -> lower,
    "upper" -> upper,
    "aborted" -> aborted,
    "precisionGoal" -> goal,
    "accuracyGoal" -> acc,
    "maxRecursion" -> rec
  |>
 ];

QuadratureCertificate[config_Association] :=
 Module[{f, var, a, b, opts, cert},
  f = config["Integrand"];
  var = config["Variable"];
  a = config["Lower"];
  b = config["Upper"];
  opts = KeyDrop[config, {"Integrand", "Variable", "Lower", "Upper"}];
  cert = CertifiedIntegrate[f, {var, a, b}, opts];
  cert
 ];

(* ------------------------------------------------------------------ *)
(* Landau singularity mapper                                          *)
(* ------------------------------------------------------------------ *)

ClearAll[normalizeTopology, sanitizeNumeric, normalizeRangeSpec,
  validateLandauConfig, validateTriangleConfig, validateBoxConfig,
  landauKey, landauCayleyMatrix, landauTriangleDeterminant,
  landauBoxDeterminant, landauZeroBrackets, landauSecantRoot,
  landauTriangleRoots, landauBoxRowRoots, landauBoxColumnRoots,
  landauTriangleScan, landauBoxScan, landauTriangleResult,
  landauBoxResult];

normalizeTopology[value_] /; !StringQ[value] := Missing["InvalidTopology"];
normalizeTopology[value_String] := ToLowerCase[StringTrim[value]];

sanitizeNumeric[value_] := If[NumericQ[value], N[value], Null];

normalizeRangeSpec[Null] := Null;
normalizeRangeSpec[Missing[_]] := Null;
normalizeRangeSpec[range_List] :=
 Module[{clean = N[range], samples},
  If[Length[clean] != 3 || !VectorQ[clean, NumericQ], Return[$Failed]];
  samples = Round[clean[[3]]];
  If[samples < 2, Return[$Failed]];
  {clean[[1]], clean[[2]], samples}
 ];
normalizeRangeSpec[_] := $Failed;

validateLandauConfig[data_Association] :=
 Module[{topology = data["Topology"]},
  Which[
   topology === Missing["InvalidTopology"],
   <|"Valid" -> False, "Message" -> "topology must be triangle or box."|>,
   topology === "triangle",
   validateTriangleConfig[data],
   topology === "box",
   validateBoxConfig[data],
   True,
   <|"Valid" -> False, "Message" -> "topology must be triangle or box."|>
  ]
 ];

validateTriangleConfig[data_Association] :=
 Module[{masses = data["InternalMasses"], squares = data["ExternalSquares"],
   index = Clip[Round[data["ScanIndex"]], {1, 3}],
   range = normalizeRangeSpec[data["ScanRange"]],
   scanValue = sanitizeNumeric[data["ScanValue"]]},
  Which[
   Length[masses] != 3,
   <|"Valid" -> False, "Message" -> "triangle requires 3 internal masses."|>,
   Length[squares] != 3,
   <|"Valid" -> False, "Message" -> "triangle requires 3 external squares."|>,
   range === $Failed,
   <|"Valid" -> False,
     "Message" -> "triangle scanRange must be [min,max,count>=2]."|>,
   range === Null && scanValue === Null,
   <|"Valid" -> False,
     "Message" -> "triangle needs scanRange or scanValue."|>,
   True,
   <|
    "Valid" -> True,
    "Normalized" -> <|
      "Topology" -> "triangle",
      "InternalMasses" -> masses,
      "ExternalSquares" -> squares,
      "ScanIndex" -> index,
      "ScanRange" -> range,
      "ScanValue" -> scanValue
     |>
   |>
  ]
 ];

validateBoxConfig[data_Association] :=
 Module[{masses = data["InternalMasses"], squares = data["ExternalSquares"],
   sVal = sanitizeNumeric[data["s"]], tVal = sanitizeNumeric[data["t"]],
   sRange = normalizeRangeSpec[data["sRange"]],
   tRange = normalizeRangeSpec[data["tRange"]]},
  Which[
   Length[masses] != 4,
   <|"Valid" -> False, "Message" -> "box requires 4 internal masses."|>,
   Length[squares] != 4,
   <|"Valid" -> False, "Message" -> "box requires 4 external squares."|>,
   sRange === $Failed,
   <|"Valid" -> False,
     "Message" -> "box sRange must be [min,max,count>=2] when provided."|>,
   tRange === $Failed,
   <|"Valid" -> False,
     "Message" -> "box tRange must be [min,max,count>=2] when provided."|>,
   sRange === Null && sVal === Null,
   <|"Valid" -> False,
     "Message" -> "box needs s or sRange."|>,
   tRange === Null && tVal === Null,
   <|"Valid" -> False,
     "Message" -> "box needs t or tRange."|>,
   True,
   <|
    "Valid" -> True,
    "Normalized" -> <|
      "Topology" -> "box",
      "InternalMasses" -> masses,
      "ExternalSquares" -> squares,
      "sValue" -> sVal,
      "tValue" -> tVal,
      "sRange" -> sRange,
      "tRange" -> tRange
     |>
   |>
  ]
 ];

landauKey[i_Integer, j_Integer] := If[i <= j, {i, j}, {j, i}];

landauCayleyMatrix[masses_List, diffs_Association] :=
 Module[{n = Length[masses]},
  Table[
   If[i == j,
     2. masses[[i]]^2,
     masses[[i]]^2 + masses[[j]]^2 - diffs[landauKey[i, j]]
    ],
   {i, n}, {j, n}
  ]
 ];

landauTriangleDeterminant[masses_List, squares_List] :=
 Module[{diffs = Association[
      landauKey[1, 2] -> squares[[1]],
      landauKey[2, 3] -> squares[[2]],
      landauKey[1, 3] -> squares[[3]]
     ]},
  Det[landauCayleyMatrix[masses, diffs]]
 ];

landauBoxDeterminant[masses_List, squares_List, s_, t_] :=
 Module[{diffs = Association[
      landauKey[1, 2] -> squares[[1]],
      landauKey[2, 3] -> squares[[2]],
      landauKey[3, 4] -> squares[[3]],
      landauKey[1, 4] -> squares[[4]],
      landauKey[1, 3] -> s,
      landauKey[2, 4] -> t
     ]},
  Det[landauCayleyMatrix[masses, diffs]]
 ];

landauZeroBrackets[grid_List, values_List, tol_: 10.^-10] :=
 Module[{pairs = Partition[Transpose[{grid, values}], 2, 1], harvest},
  harvest = Reap[
    Scan[
     Function[{pair},
      With[{left = pair[[1]], right = pair[[2]]},
       Which[
        Abs[left[[2]]] <= tol,
        Sow[<|"interval" -> {left[[1]], left[[1]]}, "type" -> "exact"|>],
        Abs[right[[2]]] <= tol,
        Sow[<|"interval" -> {right[[1]], right[[1]]}, "type" -> "exact"|>],
        left[[2]] right[[2]] < 0,
        Sow[<|"interval" -> Sort[{left[[1]], right[[1]]}], "type" -> "bracket"|>]
       ]
      ]
     ],
     pairs
    ]
   ];
  If[Length[harvest] > 1 && harvest[[2]] =!= {},
   Flatten[harvest[[2]], 1],
   {}
  ]
 ];

landauSecantRoot[f_, {a_, b_}] :=
 Module[{var = Unique["s"], guess, root},
  guess = Mean[{a, b}];
  Quiet[
   Check[
    root = FindRoot[f[var], {var, guess}, Method -> "Secant"];
    With[{value = var /. root},
     If[NumericQ[value], N[value], Missing["NoRoot"]]
    ],
    Missing["NoRoot"],
    {FindRoot::lstol, FindRoot::cvmit, FindRoot::cvdiv, FindRoot::precw}
   ]
  ]
 ];

landauTriangleRoots[masses_List, squares_List, index_Integer, brackets_List] :=
 Module[{roots},
  roots = Reap[
    Scan[
     Function[{candidate},
      If[candidate["type"] === "bracket",
       With[{root = landauSecantRoot[
            Function[s,
             landauTriangleDeterminant[
              masses,
              ReplacePart[squares, index -> s]
             ]
            ],
            candidate["interval"]
           ]},
        If[NumericQ[root], Sow[root]]
       ]
      ]
     ],
     brackets
    ]
   ];
  If[Length[roots] > 1,
   DeleteDuplicates[Flatten[roots[[2]]], (Abs[#1 - #2] < 10^-8) &],
   {}
  ]
 ];

landauTriangleScan[masses_List, squares_List, index_Integer, range_List] :=
 Module[{grid, dets, brackets, roots},
  grid = N@Subdivide[range[[1]], range[[2]], range[[3]] - 1];
  dets = landauTriangleDeterminant[
      masses,
      ReplacePart[squares, index -> #]
     ] & /@ grid // N;
  brackets = landauZeroBrackets[grid, dets];
  roots = landauTriangleRoots[masses, squares, index, brackets];
  <|
   "variableIndex" -> index,
   "gridValues" -> grid,
   "determinants" -> dets,
   "zeroCandidates" -> brackets,
   "roots" -> roots
  |>
 ];

landauBoxRowRoots[masses_List, squares_List, sGrid_List, tGrid_List, dets_List] :=
 Module[{roots},
  roots = Reap[
    Do[
     With[{tVal = tGrid[[row]], rowVals = dets[[row]],
       brackets = Select[landauZeroBrackets[sGrid, rowVals],
         #["type"] === "bracket" &]},
      Scan[
       Function[{candidate},
        With[{root = landauSecantRoot[
             Function[s, landauBoxDeterminant[masses, squares, s, tVal]],
             candidate["interval"]
            ]},
         If[NumericQ[root], Sow[{root, tVal}]]
        ]
       ],
       brackets
      ]
     ],
     {row, Length[tGrid]}
    ]
   ];
  If[Length[roots] > 1,
   DeleteDuplicates[Flatten[roots[[2]], 1], (Norm[#1 - #2] < 10^-8) &],
   {}
  ]
 ];

landauBoxColumnRoots[masses_List, squares_List, sGrid_List, tGrid_List,
  dets_List] :=
 Module[{roots},
  roots = Reap[
    Do[
     With[{sVal = sGrid[[col]], colVals = dets[[All, col]],
       brackets = Select[landauZeroBrackets[tGrid, colVals],
         #["type"] === "bracket" &]},
      Scan[
       Function[{candidate},
        With[{root = landauSecantRoot[
             Function[t, landauBoxDeterminant[masses, squares, sVal, t]],
             candidate["interval"]
            ]},
         If[NumericQ[root], Sow[{sVal, root}]]
        ]
       ],
       brackets
      ]
     ],
     {col, Length[sGrid]}
    ]
   ];
  If[Length[roots] > 1,
   DeleteDuplicates[Flatten[roots[[2]], 1], (Norm[#1 - #2] < 10^-8) &],
   {}
  ]
 ];

landauBoxScan[masses_List, squares_List, sRange_List, tRange_List] :=
 Module[{sGrid, tGrid, dets, rowRoots, colRoots, combined},
  sGrid = N@Subdivide[sRange[[1]], sRange[[2]], sRange[[3]] - 1];
  tGrid = N@Subdivide[tRange[[1]], tRange[[2]], tRange[[3]] - 1];
  dets = Table[
    N@landauBoxDeterminant[masses, squares, s, t],
    {t, tGrid}, {s, sGrid}
   ];
  rowRoots = landauBoxRowRoots[masses, squares, sGrid, tGrid, dets];
  colRoots = landauBoxColumnRoots[masses, squares, sGrid, tGrid, dets];
  combined = DeleteDuplicates[Join[rowRoots, colRoots],
    (Norm[#1 - #2] < 10^-8) &
   ];
  <|
   "sGrid" -> sGrid,
   "tGrid" -> tGrid,
   "determinants" -> dets,
   "rowRoots" -> rowRoots,
   "columnRoots" -> colRoots,
   "curvePoints" -> combined
  |>
 ];

landauTriangleResult[data_Association] :=
 Module[{masses = data["InternalMasses"], squares = data["ExternalSquares"],
   index = data["ScanIndex"], range = data["ScanRange"],
   scanValue = data["ScanValue"], determinantExpr, evaluation, scan},
  determinantExpr = Simplify[landauTriangleDeterminant[masses, squares]];
  evaluation = If[scanValue === Null,
    Null,
    N@landauTriangleDeterminant[
      masses, ReplacePart[squares, index -> scanValue]
     ]
   ];
  scan = If[range === Null,
    Null,
    landauTriangleScan[masses, squares, index, range]
   ];
  <|
   "Problem" -> "Landau singularity mapper",
   "Topology" -> "triangle",
   "Inputs" -> <|
     "InternalMasses" -> masses,
     "ExternalSquares" -> squares,
     "ScanIndex" -> index,
     "ScanRange" -> range,
     "ScanValue" -> scanValue
   |>,
  "Determinant" -> <|
     "Expression" -> ToString[determinantExpr, InputForm],
     "Evaluation" -> evaluation
   |>,
   "Scan" -> scan
  |>
 ];

landauBoxResult[data_Association] :=
 Module[{masses = data["InternalMasses"], squares = data["ExternalSquares"],
   sVal = data["sValue"], tVal = data["tValue"], sRange = data["sRange"],
   tRange = data["tRange"], determinantExpr, evaluation, scan, uVal},
  determinantExpr = Simplify[
    landauBoxDeterminant[
     masses,
     squares,
     If[sVal === Null, Symbol["s"], sVal],
     If[tVal === Null, Symbol["t"], tVal]
    ]
   ];
  evaluation = If[sVal =!= Null && tVal =!= Null,
    N@landauBoxDeterminant[masses, squares, sVal, tVal],
    Null
   ];
  scan = If[sRange === Null || tRange === Null,
    Null,
    landauBoxScan[masses, squares, sRange, tRange]
   ];
  uVal = If[sVal =!= Null && tVal =!= Null,
    Total[squares] - sVal - tVal,
    Null
   ];
  <|
   "Problem" -> "Landau singularity mapper",
   "Topology" -> "box",
   "Inputs" -> <|
     "InternalMasses" -> masses,
     "ExternalSquares" -> squares,
     "s" -> sVal,
     "t" -> tVal,
     "sRange" -> sRange,
     "tRange" -> tRange
   |>,
  "Determinant" -> <|
     "Expression" -> ToString[determinantExpr, InputForm],
     "Evaluation" -> evaluation,
     "u" -> uVal
   |>,
   "Scan" -> scan
  |>
 ];

LandauMapper[config_Association] :=
 Module[{topology = normalizeTopology[Lookup[config, "topology", "triangle"]],
   sanitized, validation, normalized},
  sanitized = <|
    "Topology" -> topology,
    "InternalMasses" -> N@Lookup[config, "internalMasses", {}],
    "ExternalSquares" -> N@Lookup[config, "externalSquares", {}],
    "ScanIndex" -> Lookup[config, "scanIndex", 3],
    "ScanRange" -> Lookup[config, "scanRange", Null],
    "ScanValue" -> Lookup[config, "scanValue", Null],
    "s" -> Lookup[config, "s", Null],
    "t" -> Lookup[config, "t", Null],
    "sRange" -> Lookup[config, "sRange", Null],
    "tRange" -> Lookup[config, "tRange", Null]
   |>;
  validation = validateLandauConfig[sanitized];
  If[!TrueQ[validation["Valid"]],
   EmitError["landau-mapper: " <> validation["Message"]];
   Return[$Failed]
  ];
  normalized = validation["Normalized"];
  Which[
   normalized["Topology"] === "triangle",
   landauTriangleResult[normalized] /. Missing[_] :> Null,
   normalized["Topology"] === "box",
   landauBoxResult[normalized] /. Missing[_] :> Null,
   True,
   EmitError["landau-mapper: internal error."];
   $Failed
  ]
 ];

AnalysisTaskSpecifications[] :=
 <|
  "fourier-gaussian" -> <|
    "Description" -> "Evaluate the Fourier transform of exp(-(x-mu)^2/(2 sigma^2)) at a chosen frequency.",
    "Spec" -> <|
      "mu" -> <|"Type" -> "Real", "Default" -> 0., "Description" -> "Shift parameter"|>,
      "sigma" -> <|"Type" -> "PositiveReal", "Default" -> 1., "Description" -> "Width parameter"|>,
      "params" -> <|"Type" -> "RealVector", "Default" -> {-1., 1.}, "Description" -> "FourierParameters pair"|>,
      "t" -> <|"Type" -> "Real", "Default" -> 0., "Description" -> "Evaluation frequency"|>
    |>,
    "Handler" -> FourierGaussianTransform
   |>,
  "partition-function" -> <|
    "Description" -> "Compute the canonical partition function from a discrete energy spectrum.",
    "Spec" -> <|
      "beta" -> <|"Type" -> "PositiveReal", "Default" -> 1., "Description" -> "Inverse temperature"|>,
      "spectrum" -> <|"Type" -> "RealVector", "Required" -> True, "Description" -> "Energy levels as JSON array"|>
    |>,
    "Handler" -> PartitionFunctionFromSpectrum
   |>,
  "asymptotic-series" -> <|
    "Description" -> "Compute the leading asymptotic series for a cosine-Gaussian integral at large lambda.",
    "Spec" -> <|
      "lambda" -> <|"Type" -> "PositiveReal", "Default" -> 10., "Description" -> "Oscillation frequency parameter"|>,
      "a" -> <|"Type" -> "PositiveReal", "Default" -> 1., "Description" -> "Gaussian width parameter"|>,
      "terms" -> <|"Type" -> "PositiveInteger", "Default" -> 2, "Description" -> "Number of series terms"|>
    |>,
    "Handler" -> AsymptoticIntegralSeries
   |>,
  "landau-mapper" -> <|
    "Description" -> "Locate leading Landau singular surfaces for triangle or box one-loop topologies.",
    "Spec" -> <|
      "topology" -> <|"Type" -> "String", "Default" -> "triangle", "Description" -> "Topology: triangle or box."|>,
      "internalMasses" -> <|"Type" -> "RealVector", "Required" -> True, "Description" -> "Internal masses as JSON array."|>,
      "externalSquares" -> <|"Type" -> "RealVector", "Required" -> True, "Description" -> "External invariant squares as JSON array."|>,
      "scanIndex" -> <|"Type" -> "PositiveInteger", "Default" -> 3, "Description" -> "Triangle scan index (1-3)."|>,
      "scanRange" -> <|"Type" -> "RealVector", "Default" -> Null, "Description" -> "Triangle scan range [min,max,count]."|>,
      "scanValue" -> <|"Type" -> "Real", "Default" -> Null, "Description" -> "Triangle evaluation value."|>,
      "s" -> <|"Type" -> "Real", "Default" -> Null, "Description" -> "Box Mandelstam s evaluation."|>,
      "t" -> <|"Type" -> "Real", "Default" -> Null, "Description" -> "Box Mandelstam t evaluation."|>,
      "sRange" -> <|"Type" -> "RealVector", "Default" -> Null, "Description" -> "Box s scan range [min,max,count]."|>,
      "tRange" -> <|"Type" -> "RealVector", "Default" -> Null, "Description" -> "Box t scan range [min,max,count]."|>
    |>,
    "Handler" -> LandauMapper
   |>
 |>;

End[];
EndPackage[];
