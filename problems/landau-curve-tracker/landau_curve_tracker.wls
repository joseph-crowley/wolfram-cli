#!/usr/bin/env wolframscript
(* ::Package:: *)

(*
  Landau curve tracker for one loop box topologies.
  Extends the approach playbook priority problem C by turning the
  Cayley determinant zero locus into a tracked implicit curve rather
  than isolated roots. The script integrates the implicit function
  equations dt/ds = - (dC/ds) / (dC/dt) or its reciprocal, producing
  machine readable samples with residual diagnostics suitable for
  fat tailed scans.
*)

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

boxDeterminantFn =
  Symbol["PhysicsCLI`Analysis`Private`landauBoxDeterminant"];

ClearAll[parseArgs, parseValue, parseList, toNumber, toBoolean];

parseArgs[] := Module[
  {raw = Rest[$ScriptCommandLine], result = <||>, key, value},
  Do[
    If[StringMatchQ[item, "--" ~~ __ ~~ "=" ~~ __],
      {key, value} = StringSplit[StringDrop[item, 2], "=", 2];
      result[key] = parseValue[value];
    ],
    {item, raw}
  ];
  result
];

parseValue[str_String] := Module[{trim = ToLowerCase[StringTrim[str]]},
  Which[
    StringStartsQ[trim, "["] && StringEndsQ[trim, "]"],
      Quiet@Check[ImportString[str, "JSON"], Missing["Invalid"]],
    StringMatchQ[trim, NumberString ~~ ___],
      toNumber[str],
    MemberQ[{"true", "false"}, trim],
      toBoolean[trim],
    True,
      str
  ]
];
parseValue[other_] := other;

toNumber[str_String] := Module[{normalized, expr},
  normalized = StringReplace[str, RegularExpression["[eE]"] :> "*^"];
  Quiet@Check[
    expr = ToExpression[normalized];
    If[NumericQ[expr], N[expr], Missing["Invalid"]],
    Missing["Invalid"]
  ]
];
toNumber[val_?NumericQ] := N[val];
toNumber[_] := Missing["Invalid"];

toBoolean["true"] := True;
toBoolean["false"] := False;
toBoolean[str_String] := toBoolean[ToLowerCase[str]];
toBoolean[_] := False;

parseList[val_List] := DeleteCases[N /@ val, _Missing];
parseList[_Missing] := {};
parseList[_] := {};

ClearAll[defaultOptions];
defaultOptions := <|
  "topology" -> "box",
  "internalMasses" -> Missing["Required"],
  "externalSquares" -> Missing["Required"],
  "initialPoint" -> Missing["Required"],
  "parameter" -> "s",
  "range" -> Missing["Required"],
  "samplesForward" -> 80,
  "samplesBackward" -> 80,
  "workingPrecision" -> 80,
  "accuracyGoal" -> 12,
  "precisionGoal" -> 12,
  "maxStep" -> 0.05,
  "tolerance" -> 10.^-9,
  "derivativeTolerance" -> 10.^-12,
  "reportGradients" -> False
|>;

ClearAll[mergeOptions];
mergeOptions[defaults_Association, overrides_Association] := Module[
  {result = Association[defaults]},
  KeyValueMap[
    If[#2 =!= Missing["Invalid"], result[#1] = #2] &,
    overrides
  ];
  result
];

ClearAll[sanitizeOptions];
sanitizeOptions[opts_Association] := Module[
  {topology, masses, squares, initial, parameter, range, forward, backward,
   prec, acc, precGoal, maxStep, tol, dTol, gradients},
  topology = If[StringQ[opts["topology"]],
    ToLowerCase[StringTrim[opts["topology"]]], Missing["Invalid"]];
  masses = parseList[opts["internalMasses"]];
  squares = parseList[opts["externalSquares"]];
  initial = parseList[opts["initialPoint"]];
  range = parseList[opts["range"]];
  parameter = If[StringQ[opts["parameter"]],
    ToLowerCase[StringTrim[opts["parameter"]]], "s"];
  forward = Round[Lookup[opts, "samplesForward", 0]];
  backward = Round[Lookup[opts, "samplesBackward", 0]];
  prec = Lookup[opts, "workingPrecision", 80];
  acc = Lookup[opts, "accuracyGoal", 12];
  precGoal = Lookup[opts, "precisionGoal", 12];
  maxStep = Lookup[opts, "maxStep", 0.05];
  tol = Lookup[opts, "tolerance", 10.^-9];
  dTol = Lookup[opts, "derivativeTolerance", 10.^-12];
  gradients = TrueQ[Lookup[opts, "reportGradients", False]];
  <|
    "topology" -> topology,
    "internalMasses" -> masses,
    "externalSquares" -> squares,
    "initialPoint" -> initial,
    "parameter" -> parameter,
    "range" -> range,
    "samplesForward" -> forward,
    "samplesBackward" -> backward,
    "workingPrecision" -> N[prec],
    "accuracyGoal" -> acc,
    "precisionGoal" -> precGoal,
    "maxStep" -> N[maxStep],
    "tolerance" -> N[tol],
    "derivativeTolerance" -> N[dTol],
    "reportGradients" -> gradients
  |>
];

ClearAll[validateStructure];
validateStructure[opts_Association] := Module[
  {errors = {}, topology = opts["topology"], parameter = opts["parameter"],
   range = opts["range"], initial = opts["initialPoint"]},
  If[topology =!= "box",
    AppendTo[errors, "Only box topology is supported in this tracker."]
  ];
  If[Length[opts["internalMasses"]] =!= 4,
    AppendTo[errors, "internalMasses must supply four values."]
  ];
  If[Length[opts["externalSquares"]] =!= 4,
    AppendTo[errors, "externalSquares must supply four values."]
  ];
  If[Length[initial] =!= 2,
    AppendTo[errors, "initialPoint must be a JSON array [s0,t0]."]
  ];
  If[Length[range] =!= 2,
    AppendTo[errors, "range must be a JSON array [min,max]."]
  ];
  If[Length[range] == 2 && range[[1]] >= range[[2]],
    AppendTo[errors, "range must satisfy min < max."]
  ];
  If[opts["samplesForward"] < 0 || opts["samplesBackward"] < 0,
    AppendTo[errors, "sample counts must be non negative integers."]
  ];
  If[opts["workingPrecision"] < 30,
    AppendTo[errors, "workingPrecision must be at least 30 digits."]
  ];
  If[opts["maxStep"] <= 0,
    AppendTo[errors, "maxStep must be positive."]
  ];
  If[opts["tolerance"] <= 0 || opts["derivativeTolerance"] <= 0,
    AppendTo[errors,
      "tolerance and derivativeTolerance must be positive."]
  ];
  If[!MemberQ[{"s", "t"}, parameter],
    AppendTo[errors, "parameter must be s or t."]
  ];
  If[errors === {} && parameter === "s",
    If[!(range[[1]] <= initial[[1]] <= range[[2]]),
      AppendTo[errors, "initial s must lie within range."]
    ]
  ];
  If[errors === {} && parameter === "t",
    If[!(range[[1]] <= initial[[2]] <= range[[2]]),
      AppendTo[errors, "initial t must lie within range."]
    ]
  ];
  If[errors =!= {},
    <|"valid" -> False, "message" -> StringRiffle[errors, " "]|>,
    <|"valid" -> True, "message" -> "OK"|>
  ]
];

ClearAll[buildLandauFunctions];
buildLandauFunctions[masses_List, squares_List, precision_] := Module[
  {mPrec = SetPrecision[masses, precision],
   sPrec = SetPrecision[squares, precision], sVar, tVar,
   detExpr, dSExpr, dTExpr},
  sVar = Unique["s"];
  tVar = Unique["t"];
  detExpr = Simplify[
    boxDeterminantFn[mPrec, sPrec, sVar, tVar]
  ];
  dSExpr = D[detExpr, sVar];
  dTExpr = D[detExpr, tVar];
  <|
    "detExpr" -> ToString[detExpr, InputForm],
    "det" -> Function[{sVal, tVal},
      N[detExpr /. {sVar -> SetPrecision[sVal, precision],
        tVar -> SetPrecision[tVal, precision]}, precision]
    ],
    "dS" -> Function[{sVal, tVal},
      N[dSExpr /. {sVar -> SetPrecision[sVal, precision],
        tVar -> SetPrecision[tVal, precision]}, precision]
    ],
    "dT" -> Function[{sVal, tVal},
      N[dTExpr /. {sVar -> SetPrecision[sVal, precision],
        tVar -> SetPrecision[tVal, precision]}, precision]
    ]
  |>
];

ClearAll[slopeS, slopeT];
slopeS[funcs_Association, sVal_?NumericQ, tVal_?NumericQ, dTol_?NumericQ] := Module[
  {den = funcs["dT"][sVal, tVal]},
  If[!NumericQ[den], Indeterminate,
    If[Abs[den] <= dTol, Indeterminate,
      -funcs["dS"][sVal, tVal]/den
    ]
  ]
];
slopeS[___] := Indeterminate;
slopeT[funcs_Association, sVal_?NumericQ, tVal_?NumericQ, dTol_?NumericQ] := Module[
  {den = funcs["dS"][sVal, tVal]},
  If[!NumericQ[den], Indeterminate,
    If[Abs[den] <= dTol, Indeterminate,
      -funcs["dT"][sVal, tVal]/den
    ]
  ]
];
slopeT[___] := Indeterminate;

ClearAll[sampleSolution];
sampleSolution[funcs_Association, solution_, parameter_, domain_List,
  samples_Integer, opts_Association] :=
 Module[{grid, values, pairs, detVals, gradVals, slopes},
  If[samples <= 0,
    Return[<|"points" -> {}, "maxResidual" -> 0., "maxIndex" -> -1|>]
  ];
  grid = Rest@Subdivide[domain[[1]], domain[[2]], samples];
  values = Quiet@Check[solution /@ grid, $Failed];
  If[values === $Failed,
    Return[<|"points" -> {}, "maxResidual" -> Indeterminate,
      "maxIndex" -> -1|>]
  ];
  pairs = Transpose[{grid, values}];
  detVals = funcs["det"] @@@ pairs;
  gradVals = Transpose[{funcs["dS"] @@@ pairs, funcs["dT"] @@@ pairs}];
  slopes = If[parameter === "s",
    slopeS[funcs, #1, #2, opts["derivativeTolerance"]] & @@@ pairs,
    slopeT[funcs, #1, #2, opts["derivativeTolerance"]] & @@@ pairs
  ];
  With[{points = MapThread[
      Module[{assoc = <|
          parameter -> #1,
          "s" -> If[parameter === "s", #1, #2],
          "t" -> If[parameter === "s", #2, #1],
          "residual" -> #3,
          "gradientNorm" ->
            If[VectorQ[#4, NumericQ], Norm[#4], Indeterminate],
          "slope" -> #5
        |>},
        If[TrueQ[opts["reportGradients"]] && VectorQ[#4, NumericQ],
          assoc = Join[assoc, <|
              "gradient" -> <|
                "dCds" -> #4[[1]],
                "dCdt" -> #4[[2]]
              |>
            |>]
        ];
        assoc
      ]&,
      {grid, values, detVals, gradVals, slopes}
    ]},
    Module[{absVals = Abs[detVals], maxPos},
      maxPos = If[Length[absVals] > 0,
        First@Ordering[absVals, -1],
        -1
      ];
      <|
        "points" -> points,
        "maxResidual" ->
          If[maxPos > 0, absVals[[maxPos]], 0.],
        "maxIndex" -> maxPos
      |>
    ]
  ]
];

ClearAll[findTForS, findSForT];
findTForS[funcs_Association, sTarget_, guess_, opts_Association] := Module[
  {prec = opts["workingPrecision"], acc = opts["accuracyGoal"],
   precGoal = opts["precisionGoal"], masses, squares, solution, value, t,
   g1, g2},
  masses = SetPrecision[Rationalize[opts["internalMasses"], 0], prec];
  squares = SetPrecision[Rationalize[opts["externalSquares"], 0], prec];
  {g1, g2} = If[ListQ[guess],
    {guess[[1]], guess[[2]]},
    {guess, guess - 0.05}
  ];
  {g1, g2} = SetPrecision[{g1, g2}, prec];
  If[Abs[g1 - g2] < 10^-6,
    g2 = g1 - 0.1;
  ];
  solution = Quiet[
    Check[
      FindRoot[
        boxDeterminantFn[masses, squares, sTarget, t],
        {t, g1, g2},
        WorkingPrecision -> prec,
        AccuracyGoal -> acc,
        PrecisionGoal -> precGoal,
        Method -> "Secant"
      ],
      $Failed,
      {FindRoot::jsing, FindRoot::lstol, FindRoot::cvmit, FindRoot::cvdiv}
    ],
    {FindRoot::precw, FindRoot::fddis}
  ];
  If[solution === $Failed, Return[$Failed]];
  value = t /. solution;
  If[!NumericQ[value], Return[$Failed]];
  If[Abs[Im[value]] > 10^-6, Return[$Failed]];
  N[Re[value], prec]
];

findSForT[funcs_Association, tTarget_, guess_, opts_Association] := Module[
  {prec = opts["workingPrecision"], acc = opts["accuracyGoal"],
   precGoal = opts["precisionGoal"], masses, squares, solution, value, s,
   g1, g2},
  masses = SetPrecision[Rationalize[opts["internalMasses"], 0], prec];
  squares = SetPrecision[Rationalize[opts["externalSquares"], 0], prec];
  {g1, g2} = If[ListQ[guess],
    {guess[[1]], guess[[2]]},
    {guess, guess - 0.05}
  ];
  {g1, g2} = SetPrecision[{g1, g2}, prec];
  If[Abs[g1 - g2] < 10^-6,
    g2 = g1 - 0.1;
  ];
  solution = Quiet[
    Check[
      FindRoot[
        boxDeterminantFn[masses, squares, s, tTarget],
        {s, g1, g2},
        WorkingPrecision -> prec,
        AccuracyGoal -> acc,
        PrecisionGoal -> precGoal,
        Method -> "Secant"
      ],
      $Failed,
      {FindRoot::jsing, FindRoot::lstol, FindRoot::cvmit, FindRoot::cvdiv}
    ],
    {FindRoot::precw, FindRoot::fddis}
  ];
  If[solution === $Failed, Return[$Failed]];
  value = s /. solution;
  If[!NumericQ[value], Return[$Failed]];
  If[Abs[Im[value]] > 10^-6, Return[$Failed]];
  N[Re[value], prec]
];

ClearAll[solveByParameter];
solveByParameter[funcs_Association, opts_Association, direction_] :=
 Module[
  {parameter = opts["parameter"], initial = opts["initialPoint"],
   range = opts["range"], tol = opts["tolerance"],
   dTol = opts["derivativeTolerance"], maxStep = opts["maxStep"],
   samples = If[direction === "forward",
     opts["samplesForward"], opts["samplesBackward"]],
   startParam, targetParam, length, stepCount, grid, currentS, currentT,
   points = {}, status = "ok", termination = "range", lastParam,
   rootVal, residual, grad, gradNorm, slopeVal, derivativeMag,
   parameterValue, sVal, tVal, currentSlope, prediction},
  {startParam, targetParam} = Which[
    parameter === "s" && direction === "forward",
      {initial[[1]], range[[2]]},
    parameter === "s" && direction === "backward",
      {initial[[1]], range[[1]]},
    parameter === "t" && direction === "forward",
      {initial[[2]], range[[2]]},
    True,
      {initial[[2]], range[[1]]}
  ];
  length = Abs[targetParam - startParam];
  If[length <= tol || samples <= 0,
    Return[<|
      "direction" -> direction,
      "status" -> "skipped",
      "domain" -> {startParam, startParam},
      "termination" -> "range",
      "maxResidual" -> 0.,
      "maxIndex" -> -1,
      "points" -> {}
    |>]
  ];
  stepCount = Max[samples, Ceiling[length/maxStep]];
  grid = Rest@Subdivide[startParam, targetParam, stepCount];
  currentS = initial[[1]];
  currentT = initial[[2]];
  lastParam = startParam;
  currentSlope = If[parameter === "s",
    slopeS[funcs, currentS, currentT, dTol],
    slopeT[funcs, currentS, currentT, dTol]
  ];
  Do[
    parameterValue = value;
    If[parameter === "s",
      prediction = If[NumericQ[currentSlope],
        currentT + currentSlope*(parameterValue - currentS),
        currentT - 0.05
      ];
      rootVal = findTForS[funcs, parameterValue, {currentT, prediction},
        opts],
      prediction = If[NumericQ[currentSlope],
        currentS + currentSlope*(parameterValue - currentT),
        currentS - 0.05
      ];
      rootVal = findSForT[funcs, parameterValue, {currentS, prediction},
        opts]
    ];
    If[rootVal === $Failed,
      status = "failed";
      termination = "solver";
      Break[];
    ];
    If[parameter === "s",
      {sVal, tVal} = {parameterValue, rootVal},
      {sVal, tVal} = {rootVal, parameterValue}
    ];
    residual = funcs["det"][sVal, tVal];
    grad = {funcs["dS"][sVal, tVal], funcs["dT"][sVal, tVal]};
    gradNorm = If[VectorQ[grad, NumericQ], Norm[grad], Indeterminate];
    slopeVal = If[parameter === "s",
      slopeS[funcs, sVal, tVal, dTol],
      slopeT[funcs, sVal, tVal, dTol]
    ];
    derivativeMag = If[parameter === "s",
      Abs[funcs["dT"][sVal, tVal]],
      Abs[funcs["dS"][sVal, tVal]]
    ];
    AppendTo[points,
      Module[{assoc = <|
          parameter -> parameterValue,
          "s" -> sVal,
          "t" -> tVal,
          "residual" -> residual,
          "gradientNorm" -> gradNorm,
          "slope" -> slopeVal
        |>},
        If[TrueQ[opts["reportGradients"]] && VectorQ[grad, NumericQ],
          assoc = Join[assoc, <|
              "gradient" -> <|
                "dCds" -> grad[[1]],
                "dCdt" -> grad[[2]]
              |>
            |>]
        ];
        assoc
      ]
    ];
    currentS = sVal;
    currentT = tVal;
    lastParam = parameterValue;
    currentSlope = If[parameter === "s",
      slopeS[funcs, currentS, currentT, dTol],
      slopeT[funcs, currentS, currentT, dTol]
    ];
    If[!NumericQ[derivativeMag] || derivativeMag <= dTol,
      termination = "derivative";
      Break[];
    ],
    {value, grid}
  ];
  <|
    "direction" -> direction,
    "status" -> status,
    "domain" -> {startParam, lastParam},
    "termination" -> termination,
    "maxResidual" -> If[Length[points] > 0,
      Max[Abs[#["residual"]] & /@ points],
      0.
    ],
    "maxIndex" -> If[Length[points] > 0,
      First@Ordering[Abs[#["residual"]] & /@ points, -1],
      -1
    ],
    "points" -> points
  |>
];

ClearAll[combineResults];
combineResults[initial_Association, forward_Association,
  backward_Association] :=
 Module[{pointsForward, pointsBackward, merged},
  pointsForward = If[forward["status"] === "ok",
    forward["points"], {}];
  pointsBackward = If[backward["status"] === "ok",
    backward["points"], {}];
  merged = Join[
    Reverse[pointsBackward],
    {initial},
    pointsForward
  ];
  merged
];

ClearAll[initialReport];
initialReport[funcs_Association, opts_Association] := Module[
  {s0 = opts["initialPoint"][[1]],
   t0 = opts["initialPoint"][[2]],
   residual, grad},
  residual = funcs["det"][s0, t0];
  grad = {funcs["dS"][s0, t0], funcs["dT"][s0, t0]};
  <|
    "point" -> <|"s" -> s0, "t" -> t0|>,
    "residual" -> residual,
    "gradient" -> grad,
    "gradientNorm" ->
      If[VectorQ[grad, NumericQ], Norm[grad], Indeterminate]
  |>
];

ClearAll[validateInitialPoint];
validateInitialPoint[funcs_Association, opts_Association] := Module[
  {s0 = opts["initialPoint"][[1]],
   t0 = opts["initialPoint"][[2]],
   parameter = opts["parameter"], residual, grad},
  residual = Abs[funcs["det"][s0, t0]];
  grad = {funcs["dS"][s0, t0], funcs["dT"][s0, t0]};
  Which[
   residual > 10*opts["tolerance"],
   <|"valid" -> False,
     "message" -> "Initial point is not on the Landau surface."|>,
   parameter === "s" && Abs[grad[[2]]] <= opts["derivativeTolerance"],
   <|"valid" -> False,
     "message" -> "dC/dt vanishes at the initial point; cannot parameterise by s."|>,
   parameter === "t" && Abs[grad[[1]]] <= opts["derivativeTolerance"],
   <|"valid" -> False,
     "message" -> "dC/ds vanishes at the initial point; cannot parameterise by t."|>,
   True,
   <|"valid" -> True, "message" -> "OK"|>
  ]
];

ClearAll[summaryFromPoints];
summaryFromPoints[points_List, funcs_Association] := Module[
  {residuals, maxResidual, rmsResidual},
  residuals = Abs[funcs["det"] @@@ ({#["s"], #["t"]} & /@ points)];
  maxResidual = If[Length[residuals] > 0, Max[residuals], 0.];
  rmsResidual = If[Length[residuals] > 0,
    Sqrt[Mean[residuals^2]], 0.];
  <|
    "totalPoints" -> Length[points],
    "maxResidual" -> maxResidual,
    "rmsResidual" -> rmsResidual
  |>
];

ClearAll[main];
main[] := Module[
  {args, optsRaw, opts, structure, funcs, initialOk, initialData,
   initialSlope, initialRecord, forward, backward, combined, summary,
   output},
  args = parseArgs[];
  optsRaw = mergeOptions[defaultOptions[], args];
  opts = sanitizeOptions[optsRaw];
  structure = validateStructure(opts);
  If[!structure["valid"],
    Print[ExportString[
      <|"status" -> "error", "message" -> structure["message"]|>,
      "JSON", "Compact" -> True]];
    Return[];
  ];
  funcs = buildLandauFunctions[
    opts["internalMasses"],
    opts["externalSquares"],
    opts["workingPrecision"]
  ];
  initialOk = validateInitialPoint[funcs, opts];
  If[!initialOk["valid"],
    Print[ExportString[
      <|"status" -> "error", "message" -> initialOk["message"]|>,
      "JSON", "Compact" -> True]];
    Return[];
  ];
  initialData = initialReport[funcs, opts];
  initialSlope = If[opts["parameter"] === "s",
    slopeS[funcs,
      initialData["point"]["s"],
      initialData["point"]["t"],
      opts["derivativeTolerance"]],
    slopeT[funcs,
      initialData["point"]["s"],
      initialData["point"]["t"],
      opts["derivativeTolerance"]]
  ];
  initialData = Append[initialData, "slope" -> initialSlope];
  initialRecord = <|
    opts["parameter"] ->
      If[opts["parameter"] === "s", initialData["point"]["s"],
        initialData["point"]["t"]],
    "s" -> initialData["point"]["s"],
    "t" -> initialData["point"]["t"],
    "residual" -> initialData["residual"],
    "gradientNorm" -> initialData["gradientNorm"],
    "slope" -> initialSlope
  |>;
  If[TrueQ[opts["reportGradients"]] &&
      VectorQ[initialData["gradient"], NumericQ],
    initialRecord = Join[initialRecord, <|
        "gradient" -> <|
          "dCds" -> initialData["gradient"][[1]],
          "dCdt" -> initialData["gradient"][[2]]
        |>
      |>]
  ];
  forward = solveByParameter[funcs, opts, "forward"];
  backward = solveByParameter[funcs, opts, "backward"];
  combined = combineResults[
    initialRecord,
    forward,
    backward
  ];
  summary = summaryFromPoints[combined, funcs];
  output = <|
    "status" -> "ok",
    "topology" -> opts["topology"],
    "parameter" -> opts["parameter"],
    "inputs" -> <|
      "internalMasses" -> opts["internalMasses"],
      "externalSquares" -> opts["externalSquares"],
      "initialPoint" -> opts["initialPoint"],
      "range" -> opts["range"],
      "samplesForward" -> opts["samplesForward"],
      "samplesBackward" -> opts["samplesBackward"],
      "workingPrecision" -> opts["workingPrecision"],
      "accuracyGoal" -> opts["accuracyGoal"],
      "precisionGoal" -> opts["precisionGoal"],
      "maxStep" -> opts["maxStep"],
      "tolerance" -> opts["tolerance"],
      "derivativeTolerance" -> opts["derivativeTolerance"]
    |>,
    "determinant" -> funcs["detExpr"],
    "initial" -> initialData,
    "forward" -> forward,
    "backward" -> backward,
    "summary" -> summary,
    "points" -> combined
  |>;
  Print[ExportString[output, "JSON", "Compact" -> True]];
];

main[];
