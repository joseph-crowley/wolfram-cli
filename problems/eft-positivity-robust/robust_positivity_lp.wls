#!/usr/bin/env wolframscript
(* ::Package:: *)

(*
  Robust photon-photon positivity via fat-tailed linear programming.
  This script distributes partial-wave spectral weight across a log-spaced
  mass grid while enforcing non-negative densities, Pareto-style caps, and
  fixed total moments. Linear optimization then finds extremal Wilson
  coefficients (a1, a2) consistent with those constraints, quantifying how
  fat-tailed uncertainty propagates into the Euler-Heisenberg EFT bounds.
  Outputs ASCII JSON capturing the feasible region diagnostics.
*)

SetDirectory[DirectoryName[$InputFileName]];

ClearAll[parseArgs, parseValue, toNumber, parseJSON, defaultOptions,
  mergeOptions, validateOptions, logMassGrid, paretoCaps, buildVariables,
  linearProgramData, solveObjective, directionObjectives, summarizeResults,
  exportJSON];

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

parseValue[str_String] := Module[{trim = StringTrim[str]},
  Which[
    StringStartsQ[trim, "["] && StringEndsQ[trim, "]"],
    parseJSON[trim],
    StringMatchQ[trim, NumberString ~~ ___],
    toNumber[trim],
    True,
    trim
  ]
];
parseValue[other_] := other;

toNumber[str_String] := Module[{normalized, expr},
  normalized = StringReplace[str, RegularExpression["[eE]"] :> "*^"];
  Quiet@Check[
    expr = ToExpression[normalized];
    If[NumericQ[expr], N[expr], Missing["InvalidNumber"]],
    Missing["InvalidNumber"]
  ]
];
toNumber[val_] /; NumericQ[val] := N[val];
toNumber[_] := Missing["InvalidNumber"];

parseJSON[str_String] := Quiet@Check[ImportString[str, "JSON"], Missing["InvalidJSON"]];
parseJSON[_] := Missing["InvalidJSON"];

defaultOptions := <|
  "massMin" -> 0.7,
  "massMax" -> 120.,
  "nodes" -> 18,
  "rho1Total" -> 1.6,
  "rho2Total" -> 2.4,
  "evenTotal" -> 0.5,
  "oddTotal" -> 0.35,
  "tailExponent" -> 3.2,
  "capMultiplier" -> 1.8,
  "precision" -> 80,
  "objectiveDirections" -> {
    {1., 0.},
    {0., 1.},
    {-1., 0.},
    {0., -1.},
    {1., 1.},
    {1., -1.}
  }
|>;

mergeOptions[defaults_Association, overrides_Association] := Module[
  {result = defaults},
  KeyValueMap[
    If[#2 =!= Missing["InvalidNumber"] && #2 =!= Missing["InvalidJSON"],
      result[#1] = #2
    ] &,
    overrides
  ];
  result
];

validateOptions[opts_Association] := Module[
  {min = opts["massMin"], max = opts["massMax"], nodes = Round[opts["nodes"]],
   cap = opts["capMultiplier"], tail = opts["tailExponent"]},
  Which[
    !NumericQ[min] || !NumericQ[max] || min <= 0 || max <= min,
    <|"valid" -> False, "message" -> "Mass range must satisfy 0 < massMin < massMax."|>,
    nodes < 4,
    <|"valid" -> False, "message" -> "nodes must be at least 4 for stability."|>,
    cap < 1.,
    <|"valid" -> False, "message" -> "capMultiplier must be >= 1."|>,
    tail <= 0,
    <|"valid" -> False, "message" -> "tailExponent must be positive."|>,
    AnyTrue[{"rho1Total", "rho2Total", "evenTotal", "oddTotal"}, opts[#] < 0 &],
    <|"valid" -> False, "message" -> "All total weights must be non-negative."|>,
    True,
    <|"valid" -> True, "message" -> "OK"|>
  ]
];

logMassGrid[min_, max_, nodes_Integer, prec_] := Module[
  {logStep, raw},
  logStep = (Log[max] - Log[min])/(nodes - 1);
  raw = Exp[Log[min] + logStep*Range[0, nodes - 1]];
  SetPrecision[raw, prec]
];

paretoCaps[total_, masses_List, alpha_, multiplier_, prec_] := Module[
  {reference = First[masses], profile, capBase},
  If[total == 0.,
    ConstantArray[0., Length[masses]],
    profile = (reference/masses)^alpha;
    capBase = total*multiplier;
    SetPrecision[capBase*profile/Total[profile], prec]
  ]
];

buildVariables[nodes_Integer] := Module[
  {
   u = Array[Unique["u"], nodes],
   v = Array[Unique["v"], nodes],
   w = Array[Unique["w"], nodes],
   z = Array[Unique["z"], nodes]
  },
  <|
    "u" -> u,
    "v" -> v,
    "w" -> w,
    "z" -> z,
    "all" -> Join[u, v, w, z]
  |>
];

linearProgramData[opts_Association] := Module[
  {
   prec = opts["precision"],
   masses, n,
   totals = <|"rho1" -> opts["rho1Total"], "rho2" -> opts["rho2Total"],
     "even" -> opts["evenTotal"], "odd" -> opts["oddTotal"]|>,
   caps, vars, constraints, eqs, inequalities,
   factor0, factor2, factor3, massPowers, coeffs
  },
  masses = logMassGrid[opts["massMin"], opts["massMax"], Round[opts["nodes"]], prec];
  n = Length[masses];
  caps = <|
    "rho1" -> paretoCaps[totals["rho1"], masses, opts["tailExponent"],
      opts["capMultiplier"], prec],
    "rho2" -> paretoCaps[totals["rho2"], masses, opts["tailExponent"],
      opts["capMultiplier"], prec],
    "even" -> paretoCaps[totals["even"], masses, opts["tailExponent"],
      opts["capMultiplier"], prec],
    "odd" -> paretoCaps[totals["odd"], masses, opts["tailExponent"],
      opts["capMultiplier"], prec]
  |>;
  vars = buildVariables[n];
  eqs = {
    Total[vars["u"]] == totals["rho1"],
    Total[vars["v"]] == totals["rho2"],
    Total[vars["w"]] == totals["even"],
    Total[vars["z"]] == totals["odd"]
  };
  inequalities = Join[
    Thread[vars["u"] >= 0.],
    Thread[vars["v"] >= 0.],
    Thread[vars["w"] >= 0.],
    Thread[vars["z"] >= 0.],
    Thread[vars["u"] <= caps["rho1"]],
    Thread[vars["v"] <= caps["rho2"]],
    Thread[vars["w"] <= caps["even"]],
    Thread[vars["z"] <= caps["odd"]]
  ];
  factor0 = SetPrecision[16.*Pi, prec];
  factor2 = SetPrecision[80.*Pi, prec];
  factor3 = SetPrecision[112.*Pi, prec];
  massPowers = masses^6;
  coeffs = <|
    "f2" -> SetPrecision[factor0/massPowers, prec],
    "g2rho2" -> SetPrecision[factor0/massPowers, prec],
    "g2even" -> SetPrecision[factor2/massPowers, prec],
    "g2odd" -> SetPrecision[factor3/massPowers, prec]
  |>;
  <|
    "masses" -> masses,
    "totals" -> totals,
    "caps" -> caps,
    "vars" -> vars,
    "constraints" -> Join[eqs, inequalities],
    "coeffs" -> coeffs,
    "precision" -> prec,
    "nodes" -> n
  |>
];

solveObjective[data_Association, coeffVec_List, tag_] := Module[
  {vars = data["vars"]["all"], objectiveVec, res, primal, pmin, dmax, dual,
   gap, metrics, ineqs, eqs, mu, nu, eqResidual, ineqViolation, compSlack,
   constraints = data["constraints"], reportedValue},
  objectiveVec = SetPrecision[coeffVec, data["precision"]];
  res = Quiet@Check[
    LinearOptimization[
      objectiveVec.vars,
      constraints,
      vars,
      {"PrimalMinimizer", "PrimalMinimumValue", "DualMaximumValue",
       "DualMaximizer", "DualityGap"}
    ],
    $Failed
  ];
  If[res === $Failed || !MatchQ[res, {{__?NumericQ}, _?NumericQ, _?NumericQ, {__List}, _?NumericQ}],
    Return[<|"status" -> "error", "tag" -> tag, "message" -> "Linear program failed."|>]
  ];
  {primal, pmin, dmax, dual, gap} = res;
  reportedValue = If[Lookup[tag, "sense", "minimize"] === "maximize",
    -N[pmin],
    N[pmin]
  ];
  metrics = summarizeResults[data, primal];
  (* Split constraints by type to align with dual multipliers structure {ineq, eq} *)
  eqs = Select[constraints, Head[#] === Equal &];
  ineqs = Select[constraints, Or[Head[#] === LessEqual, Head[#] === GreaterEqual] &];
  mu = If[Length[dual] >= 1 && ListQ[dual[[1]]], N[dual[[1]]], {}];
  nu = If[Length[dual] >= 2 && ListQ[dual[[2]]], N[dual[[2]]], {}];
  eqResidual = If[eqs === {}, 0., Module[{resList},
      resList = ((# /. Thread[vars -> primal]) /. (lhs_ == rhs_) :> (N[lhs - rhs])) & /@ eqs;
      Max[Abs /@ resList]
    ]
  ];
  ineqViolation = If[ineqs === {}, 0., Max[
    With[{val = (# /. Thread[vars -> primal])},
      Which[
        Head[val] === LessEqual, N[Max[0., (val[[1]] - val[[2]])]],
        Head[val] === GreaterEqual, N[Max[0., (val[[2]] - val[[1]])]],
        True, 0.
      ]
    ] & /@ ineqs
  ]];
  compSlack = If[ineqs === {} || mu === {}, 0.,
    Module[{slacks},
      slacks = With[{val = (# /. Thread[vars -> primal])},
          Which[
            Head[val] === LessEqual, N[Max[0., (val[[2]] - val[[1]])]],
            Head[val] === GreaterEqual, N[Max[0., (val[[1]] - val[[2]])]],
            True, 0.
          ]
        ] & /@ ineqs;
      Max[Abs[mu*slacks]]
    ]
  ];
  Association[
    <|
      "status" -> "ok",
      "tag" -> tag,
      "objectiveValue" -> reportedValue,
      "certificate" -> <|
        "primalMinimum" -> N[pmin],
        "dualMaximum" -> N[dmax],
        "dualityGap" -> N[gap],
        "kkt" -> <|
          "equalityResidual" -> eqResidual,
          "inequalityViolation" -> ineqViolation,
          "complementarySlackness" -> compSlack
        |>
      |>
    |>,
    metrics
  ]
];

summarizeResults[data_Association, vec_List] := Module[
  {
   n = data["nodes"],
   coeffs = data["coeffs"],
   masses = data["masses"],
   caps = data["caps"],
   totals = data["totals"],
   split, u, v, w, z, f2, g2, a1, a2,
   capCount
  },
  split = Partition[vec, n];
  {u, v, w, z} = split;
  f2 = coeffs["f2"].u;
  g2 = coeffs["g2rho2"].v + coeffs["g2even"].w + coeffs["g2odd"].z;
  a1 = (g2 + f2)/16.;
  a2 = (g2 - f2)/16.;
  capCount[values_List, limits_List] := Count[
    MapThread[
      Function[{val, limit}, Abs[limit - val] <= 10^-8],
      {values, limits}
    ],
    True
  ];
  <|
    "a1" -> N[a1],
    "a2" -> N[a2],
    "f2" -> N[f2],
    "g2" -> N[g2],
    "massMoments" -> <|
      "meanMassRho1" -> If[totals["rho1"] > 0,
        N[(masses.u)/totals["rho1"]],
        0.
      ],
      "meanMassRho2" -> If[totals["rho2"] > 0,
        N[(masses.v)/totals["rho2"]],
        0.
      ],
      "meanMassEven" -> If[totals["even"] > 0,
        N[(masses.w)/totals["even"]],
        0.
      ],
      "meanMassOdd" -> If[totals["odd"] > 0,
        N[(masses.z)/totals["odd"]],
        0.
      ]
    |>,
    "capSaturation" -> <|
      "rho1" -> capCount[u, caps["rho1"]],
      "rho2" -> capCount[v, caps["rho2"]],
      "even" -> capCount[w, caps["even"]],
      "odd" -> capCount[z, caps["odd"]]
    |>,
    "solution" -> <|
      "rho1" -> N[u],
      "rho2" -> N[v],
      "even" -> N[w],
      "odd" -> N[z]
    |>
  |>
];

directionObjectives[data_Association, directions_List, coeffA1_List, coeffA2_List] := Module[
  {
   results = {},
   coeffCombined, tag
  },
  Do[
    coeffCombined = dir[[1]]*coeffA1 + dir[[2]]*coeffA2;
    tag = <|"direction" -> dir, "sense" -> "minimize"|>;
    AppendTo[results, solveObjective[data, coeffCombined, tag]],
    {dir, directions}
  ];
  results
];

exportJSON[payload_] := Print[
  ExportString[payload, "JSON", "Compact" -> True]
];

Module[
  {
   args = parseArgs[],
   opts, validation, data,
   coeffA1, coeffA2,
   coeffF2, coeffG2,
   resultA1Min, resultA1Max,
   resultA2Min, resultA2Max,
   directionResults, summary
  },
  opts = mergeOptions[defaultOptions, args];
  validation = validateOptions[opts];
  If[!validation["valid"],
    exportJSON[<|"status" -> "error", "message" -> validation["message"]|>];
    Return[];
  ];
  data = linearProgramData[opts];
  coeffF2 = Join[
    data["coeffs"]["f2"],
    ConstantArray[0., 3*data["nodes"]]
  ];
  coeffG2 = Join[
    ConstantArray[0., data["nodes"]],
    data["coeffs"]["g2rho2"],
    data["coeffs"]["g2even"],
    data["coeffs"]["g2odd"]
  ];
  coeffA1 = (coeffF2 + coeffG2)/16.;
  coeffA2 = (coeffG2 - coeffF2)/16.;
  resultA1Min = solveObjective[data, coeffA1, <|"quantity" -> "a1", "sense" -> "minimize"|>];
  resultA1Max = solveObjective[data, -coeffA1, <|"quantity" -> "a1", "sense" -> "maximize"|>];
  resultA2Min = solveObjective[data, coeffA2, <|"quantity" -> "a2", "sense" -> "minimize"|>];
  resultA2Max = solveObjective[data, -coeffA2, <|"quantity" -> "a2", "sense" -> "maximize"|>];
  directionResults = directionObjectives[data, opts["objectiveDirections"], coeffA1, coeffA2];
  summary = <|
    "status" -> "ok",
    "parameters" -> <|
      "massMin" -> opts["massMin"],
      "massMax" -> opts["massMax"],
      "nodes" -> data["nodes"],
      "tailExponent" -> opts["tailExponent"],
      "capMultiplier" -> opts["capMultiplier"],
      "precision" -> opts["precision"]
    |>,
    "totals" -> data["totals"],
    "masses" -> N[data["masses"]],
    "caps" -> AssociationMap[N, data["caps"]],
    "ranges" -> <|
      "a1" -> <|
        "min" -> resultA1Min["a1"],
        "max" -> resultA1Max["a1"]
      |>,
      "a2" -> <|
        "min" -> resultA2Min["a2"],
        "max" -> resultA2Max["a2"]
      |>,
      "f2" -> <|
        "min" -> resultA1Min["f2"],
        "max" -> resultA1Max["f2"]
      |>,
      "g2" -> <|
        "min" -> resultA2Min["g2"],
        "max" -> resultA2Max["g2"]
      |>
    |>,
    "extremals" -> <|
      "a1Min" -> resultA1Min,
      "a1Max" -> resultA1Max,
      "a2Min" -> resultA2Min,
      "a2Max" -> resultA2Max
    |>,
    "directionScans" -> directionResults
  |>;
  exportJSON[summary];
];
