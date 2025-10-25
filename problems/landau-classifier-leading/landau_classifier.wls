#!/usr/bin/env wolframscript
(* Landau singularity classifier with null-vector diagnostics. *)

Module[{here, repoRoot, utilsPath, analysisPath},
 here = DirectoryName[$InputFileName];
 If[here === $Failed || here === Null,
  here = Directory[];
 ];
 SetDirectory[here];
 repoRoot = FileNameJoin[{here, "..", ".."}];
 utilsPath = FileNameJoin[{repoRoot, "lib", "PhysicsCLI", "Utils.wl"}];
 analysisPath = FileNameJoin[{repoRoot, "lib", "PhysicsCLI", "Analysis.wl"}];
 Get[utilsPath];
 Get[analysisPath];
];

ClearAll[landauKey];
landauKey[i_Integer, j_Integer] := If[i <= j, {i, j}, {j, i}];

landauCayleyMatrixFn = Symbol["PhysicsCLI`Analysis`Private`landauCayleyMatrix"];
triangleDeterminantFn = Symbol["PhysicsCLI`Analysis`Private`landauTriangleDeterminant"];
boxDeterminantFn = Symbol["PhysicsCLI`Analysis`Private`landauBoxDeterminant"];
landauSecantRootFn = Symbol["PhysicsCLI`Analysis`Private`landauSecantRoot"];

specification = <|
  "topology" -> <|"Type" -> "String", "Default" -> "triangle",
    "Description" -> "Topology: triangle or box."|>,
  "internalMasses" -> <|"Type" -> "RealVector", "Required" -> True,
    "Description" -> "Internal masses as JSON array."|>,
  "externalSquares" -> <|"Type" -> "RealVector", "Required" -> True,
    "Description" -> "External invariant squares as JSON array."|>,
  "scanIndex" -> <|"Type" -> "PositiveInteger", "Default" -> 3,
    "Description" -> "Triangle scan index (1-3)."|>,
  "scanRange" -> <|"Type" -> "RealVector", "Default" -> Null,
    "Description" -> "Triangle scan range [min,max,count]."|>,
  "scanValue" -> <|"Type" -> "Real", "Default" -> Null,
    "Description" -> "Triangle evaluation value."|>,
  "s" -> <|"Type" -> "Real", "Default" -> Null,
    "Description" -> "Box Mandelstam s evaluation."|>,
  "t" -> <|"Type" -> "Real", "Default" -> Null,
    "Description" -> "Box Mandelstam t evaluation."|>,
  "sRange" -> <|"Type" -> "RealVector", "Default" -> Null,
    "Description" -> "Box s scan range [min,max,count]."|>,
  "tRange" -> <|"Type" -> "RealVector", "Default" -> Null,
    "Description" -> "Box t scan range [min,max,count]."|>,
  "workingPrecision" -> <|"Type" -> "PositiveInteger", "Default" -> 80,
    "Description" -> "Working precision for null-space diagnostics."|>,
  "nullTolerance" -> <|"Type" -> "PositiveReal", "Default" -> 1.*^-9,
    "Description" -> "Threshold on smallest singular value to accept a null vector."|>,
  "alphaTolerance" -> <|"Type" -> "PositiveReal", "Default" -> 5.*^-9,
    "Description" -> "Allowance for small negative components when judging alpha positivity."|>
|>;

args = Rest[$ScriptCommandLine];
parsed = PhysicsCLI`Utils`ParseOptions[specification, args];

If[Length[parsed["Warnings"]] > 0,
  Scan[PhysicsCLI`Utils`EmitWarning, parsed["Warnings"]];
];

If[Length[parsed["Errors"]] > 0,
  Print[ExportString[
    <|"status" -> "error", "message" -> First[parsed["Errors"]]|>,
    "JSON", "Compact" -> True
  ]];
  Exit[1];
];

options = parsed["Options"];

workingPrecision = Lookup[options, "workingPrecision", 80];
nullTolerance = Lookup[options, "nullTolerance", 1.*^-9];
alphaTolerance = Lookup[options, "alphaTolerance", 5.*^-9];

mapperOptions = KeyDrop[options, {"workingPrecision", "nullTolerance", "alphaTolerance"}];

mapperResult = PhysicsCLI`Analysis`LandauMapper[mapperOptions];
If[mapperResult === $Failed,
  Exit[1];
];

triangleDiffs[squares_List] := Association[
  landauKey[1, 2] -> squares[[1]],
  landauKey[2, 3] -> squares[[2]],
  landauKey[1, 3] -> squares[[3]]
];

boxDiffs[squares_List, sVal_, tVal_] := Association[
  landauKey[1, 2] -> squares[[1]],
  landauKey[2, 3] -> squares[[2]],
  landauKey[3, 4] -> squares[[3]],
  landauKey[1, 4] -> squares[[4]],
  landauKey[1, 3] -> sVal,
  landauKey[2, 4] -> tVal
];

orientVector[vec_List, tol_] := Module[{first},
  first = Select[vec, Abs[#] > tol &, 1];
  If[first === {}, vec,
    If[first[[1]] < 0, -vec, vec]
  ]
];

normalizeAlpha[vec_List, tol_] := Module[
  {absSum, simplex, minVal, maxVal, sumVal, classification, simplexSum},
  absSum = Total[Abs[vec]];
  If[absSum == 0,
    <|"status" -> "zeroVector"|>,
    simplex = vec/absSum;
    minVal = Min[simplex];
    maxVal = Max[simplex];
    classification = Which[
      minVal > tol, "leading-positive",
      minVal >= -tol && maxVal > tol, "edge-degenerate",
      True, "sign-indefinite"
    ];
    sumVal = Total[vec];
    simplexSum = If[Abs[sumVal] > tol, vec/sumVal, Null];
    <|
      "status" -> "ok",
      "classification" -> classification,
      "l1Normalised" -> simplex,
      "sumNormalised" -> simplexSum,
      "minEntry" -> minVal,
      "maxEntry" -> maxVal
    |>
  ]
];

bracketedRoot[f_, {a_, b_}, precision_] := Module[
  {var, solution, value},
  Quiet[
    Check[
     solution = FindRoot[
       f[var],
       {var, a, b},
       WorkingPrecision -> precision,
       MaxIterations -> 80
      ];
     value = var /. solution;
     If[NumericQ[value], N[value, 15], Missing["NoRoot"]],
     Missing["NoRoot"],
     {FindRoot::lstol, FindRoot::cvmit, FindRoot::cvdiv, FindRoot::precw, FindRoot::jsing}
    ]
   ]
 ];

collectBoxCandidates[sGrid_List, tGrid_List, dets_List, masses_List,
  squares_List, tol_, precision_] :=
 Module[{candidates = {}, addCandidate, rows, cols, gridTol, refineS,
   refineT},
  rows = Length[tGrid];
  cols = Length[sGrid];
  gridTol = Max[tol, 10.^-10];
  addCandidate[{sVal_?NumericQ, tVal_?NumericQ}] :=
   candidates = Append[candidates, {N[sVal, 15], N[tVal, 15]}];
  refineS[row_, col_] := Module[{bracket = {sGrid[[col]], sGrid[[col + 1]]},
      root},
    root = bracketedRoot[
      Function[s, boxDeterminantFn[masses, squares, s, tGrid[[row]]]],
      bracket,
      precision
     ];
    If[NumericQ[root], addCandidate[{root, tGrid[[row]]}]]
   ];
  refineT[row_, col_] := Module[{bracket = {tGrid[[row]], tGrid[[row + 1]]},
      root},
    root = bracketedRoot[
      Function[t, boxDeterminantFn[masses, squares, sGrid[[col]], t]],
      bracket,
      precision
     ];
    If[NumericQ[root], addCandidate[{sGrid[[col]], root}]]
   ];
  Do[
   Do[
    With[{value = dets[[row, col]]},
     If[Abs[value] <= gridTol,
      addCandidate[{sGrid[[col]], tGrid[[row]]}]
     ];
     If[col < cols,
      With[{next = dets[[row, col + 1]]},
       If[value*next < 0,
        refineS[row, col]
       ]
      ]
     ]
    ],
    {col, cols}
   ],
   {row, rows}
  ];
  Do[
   Do[
    With[{value = dets[[row, col]]},
     If[row < rows,
      With[{next = dets[[row + 1, col]]},
       If[value*next < 0,
        refineT[row, col]
       ]
      ]
     ]
    ],
    {col, cols}
   ],
   {row, rows - 1}
  ];
  DeleteDuplicates[candidates, Norm[#1 - #2] < gridTol &]
 ];

computeNullData[matrix_, precision_, tol_] := Module[
  {mp, svd, singularValues, v, index, value, vector},
  mp = SetPrecision[matrix, precision];
  svd = SingularValueDecomposition[mp];
  singularValues = Diagonal[svd[[2]]];
  index = First[Ordering[singularValues, 1]];
  value = singularValues[[index]];
  v = Transpose[svd[[3]]];
  vector = v[[index]];
  <|"singularValue" -> value, "vector" -> vector|>
];

triangleClassifier[result_Association, precision_, svTol_, alphaTol_] := Module[
  {inputs, masses, baseSquares, scanInfo, index, roots, extra, detFunction,
   diagnostics, singularities},
  inputs = result["Inputs"];
  masses = inputs["InternalMasses"];
  baseSquares = inputs["ExternalSquares"];
  index = inputs["ScanIndex"];
  scanInfo = Lookup[result, "Scan", <||>];
  roots = Lookup[scanInfo, "roots", {}];
  extra = If[inputs["ScanValue"] === Null, {}, {inputs["ScanValue"]}];
  detFunction = Function[{sVal},
    Quiet[
      triangleDeterminantFn[masses, ReplacePart[baseSquares, index -> sVal]],
      {Det::luc, Det::sing}
    ]
  ];
  singularities = Reap[
     Scan[
       Function[{root},
        Module[{squares, diffAssoc, matrix, nullData, oriented, normalised,
          detVal, slopeVal},
         squares = ReplacePart[baseSquares, index -> root];
         diffAssoc = triangleDiffs[squares];
         matrix = landauCayleyMatrixFn[masses, diffAssoc];
         nullData = computeNullData[matrix, precision, svTol];
         If[nullData["singularValue"] > svTol,
           Sow[<|
             "location" -> root,
             "residual" -> N[Abs[detFunction[root]], 15],
             "status" -> "singular-value-above-threshold",
             "singularValue" -> nullData["singularValue"]
           |>],
           oriented = orientVector[nullData["vector"], alphaTol];
           normalised = normalizeAlpha[oriented, alphaTol];
           detVal = N[detFunction[root], 15];
           slopeVal = N[Derivative[1][detFunction][root], 15];
           Sow[<|
             "location" -> root,
             "determinant" -> detVal,
             "derivative" -> slopeVal,
             "singularValue" -> nullData["singularValue"],
             "alphaRaw" -> N[oriented, 15],
             "alphaL1" -> If[normalised["status"] === "ok",
               N[normalised["l1Normalised"], 15], Null],
             "alphaSum1" -> If[normalised["status"] === "ok",
               If[normalised["sumNormalised"] === Null, Null,
                N[normalised["sumNormalised"], 15]
               ],
               Null
              ],
             "classification" -> If[normalised["status"] === "ok",
               normalised["classification"],
               "zero-vector"
              ],
             "minEntry" -> If[normalised["status"] === "ok",
               normalised["minEntry"], Null],
             "maxEntry" -> If[normalised["status"] === "ok",
               normalised["maxEntry"], Null],
             "residual" -> N[Abs[detFunction[root]], 15]
           |>]
         ]
        ]
       ],
       DeleteDuplicates[Join[roots, extra]]
     ]
   ][[2]];
  diagnostics = <|
    "rootCount" -> Length[roots],
    "extraPointsCount" -> Length[extra],
    "classifiedCount" -> Length[singularities],
    "precision" -> precision,
    "nullTolerance" -> svTol,
    "alphaTolerance" -> alphaTol
  |>;
  <|"singularities" -> singularities, "diagnostics" -> diagnostics|>
];

boxClassifier[result_Association, precision_, svTol_, alphaTol_] := Module[
  {inputs, masses, squares, scanInfo, points, evaluation, detFunction,
   classifyPoint, combined},
  inputs = result["Inputs"];
  masses = inputs["InternalMasses"];
  squares = inputs["ExternalSquares"];
  scanInfo = Lookup[result, "Scan", <||>];
  points = Lookup[scanInfo, "curvePoints", {}];
  evaluation = If[inputs["s"] =!= Null && inputs["t"] =!= Null,
    {{inputs["s"], inputs["t"]}},
    {}
  ];
  detFunction = Function[{sVal, tVal},
    Quiet[
      boxDeterminantFn[masses, squares, sVal, tVal],
      {Det::luc, Det::sing}
    ]
  ];
  gridCandidates = If[
    MatchQ[scanInfo, _Association] &&
     KeyExistsQ[scanInfo, "sGrid"] &&
     KeyExistsQ[scanInfo, "tGrid"] &&
     KeyExistsQ[scanInfo, "determinants"],
    collectBoxCandidates[
     scanInfo["sGrid"],
     scanInfo["tGrid"],
     scanInfo["determinants"],
     masses,
     squares,
     alphaTol,
     precision
    ],
    {}
   ];
  classifyPoint[{sVal_, tVal_}] := Module[
    {diffAssoc, matrix, nullData, oriented, normalised, detVal, gradS, gradT},
    diffAssoc = boxDiffs[squares, sVal, tVal];
    matrix = landauCayleyMatrixFn[masses, diffAssoc];
    nullData = computeNullData[matrix, precision, svTol];
    If[nullData["singularValue"] > svTol,
      <|
        "coordinates" -> {sVal, tVal},
        "determinant" -> N[detFunction[sVal, tVal], 15],
        "status" -> "singular-value-above-threshold",
        "singularValue" -> nullData["singularValue"],
        "residual" -> N[Abs[detFunction[sVal, tVal]], 15]
      |>,
      oriented = orientVector[nullData["vector"], alphaTol];
      normalised = normalizeAlpha[oriented, alphaTol];
      detVal = N[detFunction[sVal, tVal], 15];
      gradS = N[D[detFunction[s, tVal], s] /. s -> sVal, 15];
      gradT = N[D[detFunction[sVal, t], t] /. t -> tVal, 15];
      <|
        "coordinates" -> {sVal, tVal},
        "determinant" -> detVal,
        "gradient" -> {gradS, gradT},
        "singularValue" -> nullData["singularValue"],
        "alphaRaw" -> N[oriented, 15],
        "alphaL1" -> If[normalised["status"] === "ok",
          N[normalised["l1Normalised"], 15], Null],
        "alphaSum1" -> If[normalised["status"] === "ok",
          If[normalised["sumNormalised"] === Null, Null,
           N[normalised["sumNormalised"], 15]
          ],
          Null
         ],
        "classification" -> If[normalised["status"] === "ok",
          normalised["classification"],
          "zero-vector"
         ],
        "minEntry" -> If[normalised["status"] === "ok",
          normalised["minEntry"], Null],
        "maxEntry" -> If[normalised["status"] === "ok",
          normalised["maxEntry"], Null],
        "residual" -> N[Abs[detVal], 15]
      |>
    ]
  ];
  combined = DeleteDuplicates[Join[points, evaluation, gridCandidates],
    Norm[#1 - #2] < Max[alphaTol, 10.^-10] &
   ];
  <|
    "singularities" -> classifyPoint /@ combined,
    "diagnostics" -> <|
      "curvePointCount" -> Length[points],
      "evaluationCount" -> Length[evaluation],
      "classifiedCount" -> Length[combined],
      "precision" -> precision,
      "nullTolerance" -> svTol,
      "alphaTolerance" -> alphaTol
    |>
  |>
];

topology = ToLowerCase[mapperResult["Topology"]];

classification = Switch[topology,
  "triangle",
  triangleClassifier[mapperResult, workingPrecision, nullTolerance, alphaTolerance],
  "box",
  boxClassifier[mapperResult, workingPrecision, nullTolerance, alphaTolerance],
  _, <|"singularities" -> {}, "diagnostics" -> <|"error" -> "unsupported topology"|>|>
];

payload = <|
  "Problem" -> "Landau singularity classifier",
  "Topology" -> mapperResult["Topology"],
  "Inputs" -> Association[
    mapperResult["Inputs"],
    "workingPrecision" -> workingPrecision,
    "nullTolerance" -> nullTolerance,
    "alphaTolerance" -> alphaTolerance
  ],
  "Singularities" -> classification["singularities"],
  "Diagnostics" -> classification["diagnostics"]
|>;

Print[ExportString[payload /. Missing[_] :> Null, "JSON", "Compact" -> True]];
