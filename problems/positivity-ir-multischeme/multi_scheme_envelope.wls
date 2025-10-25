#!/usr/bin/env wolframscript
(*
  Primal-dual envelope solver for multi-scheme IR-subtracted dispersion bounds.
  Constructs a discrete heavy-spectrum envelope, solves a linear program to
  minimise the worst-case renormalised bound across schemes, and emits primal
  and dual certificates with KKT diagnostics.
*)

SetDirectory[DirectoryName[$InputFileName]];

Get[FileNameJoin[{"..", "..", "lib", "PhysicsCLI", "Utils.wl"}]];
Get[FileNameJoin[{"..", "..", "lib", "PhysicsCLI", "IR.wl"}]];

ClearAll[optionsSpec];
optionsSpec := <|
  "gridNodes" -> <|"Type" -> "PositiveInteger", "Default" -> 20|>,
  "certificateTolerance" -> <|"Type" -> "PositiveReal", "Default" -> 1.*^-9|>,
  "subtractions" -> <|"Type" -> "PositiveInteger", "Default" -> 2|>,
  "poleStrength" -> <|"Type" -> "PositiveReal", "Default" -> 0.2|>,
  "heavyThreshold" -> <|"Type" -> "PositiveReal", "Default" -> 1.5|>,
  "heavyStrength" -> <|"Type" -> "PositiveReal", "Default" -> 1.0|>,
  "heavyScale" -> <|"Type" -> "PositiveReal", "Default" -> 3.0|>,
  "growthPower" -> <|"Type" -> "Real", "Default" -> 3.0|>,
  "tailExponent" -> <|"Type" -> "PositiveReal", "Default" -> 6.5|>,
  "integrationMax" -> <|"Type" -> "Real", "Default" -> Infinity|>,
  "precision" -> <|"Type" -> "PositiveInteger", "Default" -> 60|>,
  "accuracyGoal" -> <|"Type" -> "PositiveInteger", "Default" -> 12|>,
  "precisionGoal" -> <|"Type" -> "PositiveInteger", "Default" -> 12|>,
  "maxRecursion" -> <|"Type" -> "PositiveInteger", "Default" -> 12|>,
  "schemes" -> <|"Type" -> "String", "Default" -> "Automatic"|>
|>;

defaultSchemes[] := {
  <|"scheme" -> "analytic"|>,
  <|"scheme" -> "cutoff", "sCut" -> 0.25|>,
  <|"scheme" -> "excludeBelow", "sMin" -> 2.0|>,
  <|"scheme" -> "bandGap", "sMin" -> 2.0, "sMax" -> 2.8|>
};

ClearAll[prefactor];
prefactor[subtractions_Integer] :=
  If[subtractions === 2, 2./Pi, Missing["Unsupported"]];

ClearAll[heavyIntegrandFunction];
heavyIntegrandFunction[opts_Association, subtractions_Integer, prec_Integer] := Module[
  {
   threshold = SetPrecision[N[opts["heavyThreshold"]], prec],
   strength = SetPrecision[N[opts["heavyStrength"]], prec],
   scale = SetPrecision[N[opts["heavyScale"]], prec],
   growth = SetPrecision[N[opts["growthPower"]], prec],
   tail = SetPrecision[N[opts["tailExponent"]], prec]
  },
  Function[{s},
    Which[
      s <= threshold, 0.,
      True,
      Module[{y = s - threshold},
        strength*(y^growth)/(1. + y/scale)^tail/s^(subtractions + 1)
      ]
    ]
  ]
];

ClearAll[parseSchemes];
parseSchemes["Automatic"] := defaultSchemes[];
parseSchemes[str_String] := Module[{parsed},
  parsed = Quiet@Check[ImportString[str, "JSON"], $Failed];
  If[parsed === $Failed || !ListQ[parsed], defaultSchemes[], parsed]
];
parseSchemes[_] := defaultSchemes[];

ClearAll[validateOptions];
validateOptions[opts_Association] := Module[
  {subtractions = Round[opts["subtractions"]]},
  If[subtractions =!= 2,
    Return[<|"Valid" -> False, "Message" -> "Only two subtractions are supported."|>]
  ];
  If[opts["tailExponent"] <= opts["growthPower"] + 2,
    Return[<|"Valid" -> False,
      "Message" -> "tailExponent must exceed growthPower + 2 for convergence."|>]
  ];
  If[opts["integrationMax"] =!= Infinity && opts["integrationMax"] <= opts["heavyThreshold"],
    Return[<|"Valid" -> False,
      "Message" -> "integrationMax must exceed heavyThreshold."|>]
  ];
  <|"Valid" -> True, "Message" -> "OK"|>
];

ClearAll[schemeIntervals];
schemeIntervals[scheme_Association, opts_Association] :=
  PhysicsCLI`IR`IntegrationIntervalsForScheme[scheme, opts];

segmentGrid[opts_Association, intervalMap_List, gridNodes_Integer] := Module[
  {
   threshold = N[opts["heavyThreshold"]],
   scale = N[opts["heavyScale"]],
   integrationMax = opts["integrationMax"],
   finiteUpper, basePoints, schemePoints, finitePoints, sortedPoints, segments, tol
  },
  tol = 10.^-12;
  finiteUpper = Which[
    NumericQ[integrationMax] && integrationMax =!= Infinity,
      N[integrationMax],
    True,
      Module[{cap = threshold + Max[5.*scale, 1.] + scale*(gridNodes/2.)},
        Max[cap, threshold + 1.]
      ]
  ];
  basePoints = Table[
    threshold + (finiteUpper - threshold)*(i/gridNodes)^2,
    {i, 0, gridNodes}
  ];
  schemePoints = Flatten[
    Table[
      Flatten[
        Table[
          If[interval[[j]] === Infinity, Nothing,
            N[interval[[j]]]
          ],
          {j, 1, Length[interval]}
        ]
      ],
      {interval, Flatten[intervalMap, 1]}
    ]
  ];
  finitePoints = DeleteDuplicates@Select[
      Join[basePoints, schemePoints],
      NumericQ[#] && # >= threshold - tol && # <= finiteUpper + tol &
    ];
  sortedPoints = Sort[Append[finitePoints, finiteUpper]];
  segments = Partition[sortedPoints, 2, 1];
  segments = Select[segments, #[[2]] > #[[1]] + tol &];
  If[integrationMax === Infinity,
    Append[segments, {Last[sortedPoints], Infinity}],
    segments
  ]
];

ClearAll[segmentIntegral];
segmentIntegral[integrand_, seg_List, opts_Association, prec_Integer] := Module[
  {lower = seg[[1]], upper = seg[[2]], wp, acc, goal, rec},
  {wp, acc, goal, rec} = Lookup[opts, {"precision", "accuracyGoal", "precisionGoal", "maxRecursion"}];
  Quiet@Check[
    NIntegrate[
      integrand[s],
      {s, lower, upper},
      Method -> {"GlobalAdaptive", "SymbolicProcessing" -> 0},
      WorkingPrecision -> wp,
      AccuracyGoal -> acc,
      PrecisionGoal -> goal,
      MaxRecursion -> rec
    ],
    Missing["IntegrationFailure"]
  ]
];

ClearAll[segmentCoefficients];
segmentCoefficients[segments_List, intervals_List] := Module[
  {tol = 10.^-10},
  Table[
    Module[{seg = segments[[k]], lower, upper, a, b},
      {a, b} = seg;
      If[
        AnyTrue[
          intervals,
          Function[{iv},
            {lower, upper} = iv;
            Which[
              upper === Infinity, lower <= a + tol,
              True, lower <= a + tol && upper >= b - tol
            ]
          ]
        ],
        1.,
        0.
      ]
    ],
    {k, Length[segments]}
  ]
];

ClearAll[sanitizeJSON];
sanitizeJSON[assoc_Association] := AssociationMap[sanitizeJSON, assoc];
sanitizeJSON[list_List] := sanitizeJSON /@ list;
sanitizeJSON[val_] /; val === Infinity := "Infinity";
sanitizeJSON[val_] /; val === -Infinity := "-Infinity";
sanitizeJSON[Missing[___]] := "Missing";
sanitizeJSON[val_?NumericQ] := N[val, 16];
sanitizeJSON[other_] := other;

main[] := Module[
  {
   parsed, opts, validation, schemeInput, schemeCanonical, intervals,
   integrand, segments, segIntegrals, failure, baseIntegral, pref,
   prefHalf, coeffs, numSegments, vars, boundVar, ineqExprs, eqExprs,
   objective, solution, primal, primalWeights, boundValue, dual, dualGap,
   dualIneq, dualEq, schemeBounds, schemeSummary, aggregate, tol,
   eqResidual, ineqValues, ineqViolation, slacks, compSlack, payload,
   analyticBound
  },
  parsed = PhysicsCLI`Utils`ParseOptions[optionsSpec, Rest[$ScriptCommandLine]];
  If[parsed["Errors"] =!= {},
    PhysicsCLI`Utils`EmitJSON[
      <|"status" -> "error", "message" -> StringRiffle[parsed["Errors"], "; "]|>
    ];
    Return[];
  ];
  opts = parsed["Options"];
  schemeInput = parseSchemes[opts["schemes"]];
  schemeCanonical = Module[{result = PhysicsCLI`IR`CanonicalizeSchemeList[schemeInput]},
    If[Lookup[result, "Valid", {}] === {}, defaultSchemes[], Lookup[result, "Valid", {}]]
  ];
  opts["schemes"] = schemeCanonical;
  validation = validateOptions[opts];
  If[!validation["Valid"],
    PhysicsCLI`Utils`EmitJSON[
      <|"status" -> "error", "message" -> validation["Message"]|>
    ];
    Return[];
  ];
  integrand = heavyIntegrandFunction[opts, Round[opts["subtractions"]], opts["precision"]];
  intervals = schemeIntervals[#, opts] & /@ schemeCanonical;
  segments = segmentGrid[opts, intervals, opts["gridNodes"]];
  segIntegrals = segmentIntegral[integrand, #, opts, opts["precision"]] & /@ segments;
  failure = Select[segIntegrals, MatchQ[#, Missing["IntegrationFailure"]] &];
  If[failure =!= {},
    PhysicsCLI`Utils`EmitJSON[
      sanitizeJSON[
        <|
          "status" -> "error",
          "message" -> "Integration failure in segment integrals.",
          "segments" -> segments,
          "integrals" -> segIntegrals
        |>
      ]
    ];
    Return[];
  ];
  baseIntegral = Total[segIntegrals];
  pref = prefactor[Round[opts["subtractions"]]];
  If[!NumericQ[pref],
    PhysicsCLI`Utils`EmitJSON[
      <|"status" -> "error", "message" -> "Unsupported subtraction count for envelope."|>
    ];
    Return[];
  ];
  prefHalf = N[pref/2., 16];
  coeffs = segmentCoefficients[segments, #] & /@ intervals;
  numSegments = Length[segments];
  vars = Table[Symbol["w$" <> ToString[i]], {i, numSegments}];
  boundVar = Symbol["b$"];
  envelopeTol = 1.*^-12;
  ineqExprs = Join[
    (-# - envelopeTol) & /@ vars,
    vars - (segIntegrals*(1. + envelopeTol)),
    {-boundVar},
    (prefHalf*Total[#*vars] - boundVar) & /@ coeffs
  ];
  eqExprs = {Total[vars] - baseIntegral};
  objective = boundVar;
  lpPrecision = Module[{prec = Precision[baseIntegral]},
    Which[
      prec === MachinePrecision, 16,
      NumericQ[prec], Min[opts["precision"], Max[20, Floor[prec]]],
      True, opts["precision"]
    ]
  ];
  solution = Quiet[
    LinearOptimization[
      objective,
      Join[Thread[ineqExprs <= 0], Thread[eqExprs == 0]],
      Join[vars, {boundVar}],
      {"PrimalMinimizer", "PrimalMinimumValue", "DualMaximumValue", "DualMaximizer", "DualityGap"},
      WorkingPrecision -> lpPrecision,
      Method -> If[lpPrecision == 16, "CLP", "Simplex"]
    ],
    LinearOptimization::precw
  ];
  If[solution === $Failed || !MatchQ[solution, {_List, _?NumericQ, _?NumericQ, {_List, _List}, _?NumericQ}],
    PhysicsCLI`Utils`EmitJSON[
      <|"status" -> "error", "message" -> "Linear program failed to produce a certificate."|>
    ];
    Return[];
  ];
  {primal, primalMinimum, dualMaximum, dual, dualGap} = solution;
  primalWeights = Take[primal, numSegments];
  boundValue = Last[primal];
  {dualIneq, dualEq} = dual;
  dualIneqVec = PadRight[N[Flatten[{dualIneq}], 16], Length[ineqExprs], 0.];
  dualEqVec = N[Flatten[{dualEq}], 16];
  schemeBounds = prefHalf*Total[#*primalWeights] & /@ coeffs;
  analyticBound = First[schemeBounds];
  segmentsPayload = Table[
    <|
      "index" -> idx,
      "start" -> N[segments[[idx, 1]], 16],
      "end" -> If[segments[[idx, 2]] === Infinity, "Infinity", N[segments[[idx, 2]], 16]],
      "integral" -> N[segIntegrals[[idx]], 16]
    |> ,
    {idx, numSegments}
  ];
  schemeSummary = MapThread[
    Association[
      {
        "scheme" -> #1["scheme"],
        "parameters" -> KeyDrop[#1, {"scheme"}],
        "bound" -> N[#2, 16],
        "slack" -> N[boundValue - #2, 16]
      }
    ] &,
    {schemeCanonical, schemeBounds}
  ];
  tol = opts["certificateTolerance"];
  aggregate = <|
    "maxBound" -> N[Max[schemeBounds], 16],
    "minBound" -> N[Min[schemeBounds], 16],
    "spread" -> N[Max[schemeBounds] - Min[schemeBounds], 16],
    "analyticBound" -> N[analyticBound, 16],
    "consistentWithAnalytic" -> (Abs[Max[schemeBounds] - analyticBound] <= tol)
  |>;
  eqResidual = Module[{val = N[Max[Abs[Total[primalWeights] - baseIntegral]], 16]}, If[Abs[val] < 1.*^-12, 0., val]];
  ineqValues = (ineqExprs /. Thread[vars -> primalWeights] /. boundVar -> boundValue);
  ineqViolation = Module[{val = N[Max[0., Max[ineqValues /. x_?NumericQ :> x]], 16]}, If[Abs[val] < 1.*^-12, 0., val]];
  slacks = (Max[0., -#] &) /@ (ineqValues /. x_?NumericQ :> x);
  compSlack = If[dualIneqVec === {}, 0., Module[{val = N[Max[Abs[dualIneqVec*slacks]], 16]}, If[Abs[val] < 1.*^-12, 0., val]]];
  primalPayload = <|
    "weights" -> N[primalWeights, 16],
    "bound" -> N[boundValue, 16],
    "minimumValue" -> N[primalMinimum, 16]
  |>;
  dualPayload = <|
    "inequalityMultipliers" -> dualIneqVec,
    "equalityMultipliers" -> dualEqVec,
    "dualMaximum" -> N[dualMaximum, 16],
    "dualityGap" -> Module[{val = N[dualGap, 16]}, If[Abs[val] < 1.*^-12, 0., val]]
  |>;
  payload = <|
    "status" -> "ok",
    "inputs" -> <|
      "gridNodes" -> opts["gridNodes"],
      "certificateTolerance" -> tol,
      "subtractions" -> opts["subtractions"],
      "heavyThreshold" -> N[opts["heavyThreshold"], 16],
      "heavyStrength" -> N[opts["heavyStrength"], 16],
      "heavyScale" -> N[opts["heavyScale"], 16],
      "growthPower" -> N[opts["growthPower"], 16],
      "tailExponent" -> N[opts["tailExponent"], 16],
      "integrationMax" -> If[opts["integrationMax"] === Infinity, "Infinity", N[opts["integrationMax"], 16]],
      "precision" -> opts["precision"],
      "accuracyGoal" -> opts["accuracyGoal"],
      "precisionGoal" -> opts["precisionGoal"],
      "maxRecursion" -> opts["maxRecursion"]
    |>,
    "segments" -> segmentsPayload,
    "primal" -> primalPayload,
    "dual" -> dualPayload,
    "schemes" -> schemeSummary,
    "kkt" -> <|
      "equalityResidual" -> eqResidual,
      "inequalityViolation" -> ineqViolation,
      "complementarySlackness" -> compSlack
    |>,
    "aggregate" -> aggregate
  |>;
  PhysicsCLI`Utils`EmitJSON[sanitizeJSON[payload]];
];

main[];
