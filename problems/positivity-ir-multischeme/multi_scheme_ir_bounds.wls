#!/usr/bin/env wolframscript
(* ::Package:: *)

(*
  Multi-scheme IR-subtracted positivity analysis for forward 2 -> 2
  amplitudes with a massless t-channel exchange. The script evaluates the
  twice-subtracted dispersion integral for a fat-tailed heavy spectrum and
  compares renormalised bounds across analytic subtraction, cutoff
  regularisation, and partial-wave exclusion windows. Outputs ASCII JSON
  capturing scheme diagnostics, spreads, and worst-case requirements on the
  renormalised s^2 Wilson coefficient.
*)

SetDirectory[DirectoryName[$InputFileName]];

$Assumptions = {
  Element[s, Reals], s >= 0
};

ClearAll[parseArgs, parseValue, toNumber, parseList];
parseArgs[] := Module[
  {raw = Rest[$ScriptCommandLine], result = <||>, key, value},
  Do[
    If[StringStartsQ[item, "--"] && StringContainsQ[item, "="],
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
      Quiet@Check[ImportString[trim, "JSON"], Missing["Invalid"]],
    StringMatchQ[trim, NumberString ~~ ___],
      toNumber[trim],
    trim === "Infinity", Infinity,
    trim === "-Infinity", -Infinity,
    True,
      trim
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
toNumber[val_] /; NumericQ[val] := N[val];
toNumber[_] := Missing["Invalid"];

parseList[val_List] := DeleteCases[N /@ val, _Missing];
parseList[_Missing] := {};
parseList[_] := {};

ClearAll[normalizeScheme];
normalizeScheme[spec_] := Which[
  AssociationQ[spec], spec,
  MatchQ[spec, {_Rule ..}], Association[spec],
  True, <||>
];

ClearAll[defaultSchemes];
defaultSchemes[] := {
  <|"scheme" -> "analytic"|>,
  <|"scheme" -> "cutoff", "sCut" -> 0.25|>,
  <|"scheme" -> "cutoff", "sCut" -> 0.15|>,
  <|"scheme" -> "excludeBelow", "sMin" -> 2.0|>,
  <|"scheme" -> "bandGap", "sMin" -> 2.0, "sMax" -> 2.8|>
};

ClearAll[defaultOptions];
defaultOptions := <|
  "poleStrength" -> 0.2,
  "subtractions" -> 2,
  "heavyStrength" -> 1.,
  "heavyScale" -> 3.,
  "heavyThreshold" -> 1.5,
  "growthPower" -> 3.,
  "tailExponent" -> 6.5,
  "integrationMax" -> Infinity,
  "precision" -> 60,
  "accuracyGoal" -> 12,
  "precisionGoal" -> 12,
  "maxRecursion" -> 12,
  "schemes" -> Automatic,
  "cRen" -> Missing["NotProvided"],
  "schemeTolerance" -> 1.*^-11
|>;

ClearAll[mergeOptions];
mergeOptions[defaults_Association, overrides_Association] := Module[
  {result = defaults},
  KeyValueMap[
    If[#2 =!= Missing["Invalid"], result[#1] = #2] &,
    overrides
  ];
  result
];

ClearAll[validateOptions];
validateOptions[opts_Association] := Module[
  {subtractions = Round[opts["subtractions"]]},
  If[subtractions =!= 2,
    Return[<|"valid" -> False,
      "message" -> "Only two subtractions are supported."|>]
  ];
  If[opts["heavyThreshold"] <= 0,
    Return[<|"valid" -> False,
      "message" -> "heavyThreshold must be positive."|>]
  ];
  If[opts["tailExponent"] <= opts["growthPower"] + 2,
    Return[<|"valid" -> False,
      "message" -> "tailExponent must exceed growthPower + 2 for convergence."|>]
  ];
  If[opts["integrationMax"] =!= Infinity && opts["integrationMax"] <= opts["heavyThreshold"],
    Return[<|"valid" -> False,
      "message" -> "integrationMax must exceed heavyThreshold."|>]
  ];
  If[opts["schemeTolerance"] <= 0,
    Return[<|"valid" -> False,
      "message" -> "schemeTolerance must be positive."|>]
  ];
  <|"valid" -> True, "message" -> "OK"|>
];

ClearAll[prefactor];
prefactor[subtractions_Integer] :=
  If[subtractions === 2, 2./Pi, Missing["Unsupported"]];

ClearAll[heavyIntegrandFunction];
heavyIntegrandFunction[opts_Association, subtractions_Integer] := Module[
  {threshold = N[opts["heavyThreshold"]],
   strength = N[opts["heavyStrength"]],
   scale = N[opts["heavyScale"]],
   growth = N[opts["growthPower"]],
   tail = N[opts["tailExponent"]]},
  Function[{x},
    If[x <= threshold,
      0.,
      With[{y = x - threshold},
        strength*(y^growth)/(1. + y/scale)^tail/x^(subtractions + 1)
      ]
    ]
  ]
];

ClearAll[integrationIntervals];
integrationIntervals[spec_Association, opts_Association] := Module[
  {scheme = ToLowerCase[ToString[Lookup[spec, "scheme", ""]]],
   threshold = N[opts["heavyThreshold"]],
   upper = opts["integrationMax"], sMin, sMax},
  Switch[scheme,
    "analytic" | "cutoff",
      {{threshold, upper}},
    "excludebelow",
      sMin = N[Lookup[spec, "sMin", Missing["Invalid"]]];
      If[!NumericQ[sMin],
        Return[Missing["InvalidScheme", "sMin required for excludeBelow."]]
      ];
      {{Max[threshold, sMin], upper}},
    "bandgap",
      sMin = N[Lookup[spec, "sMin", Missing["Invalid"]]];
      sMax = N[Lookup[spec, "sMax", Missing["Invalid"]]];
      If[!NumericQ[sMin] || !NumericQ[sMax],
        Return[Missing["InvalidScheme", "sMin and sMax required for bandGap."]]
      ];
      If[sMax <= sMin,
        Return[Missing["InvalidScheme", "Require sMax > sMin for bandGap."]]
      ];
      If[sMax <= threshold,
        {{threshold, upper}},
        If[sMin <= threshold,
          {{threshold, sMax}, {Max[sMax, threshold], upper}},
          {{threshold, sMin}, {sMax, upper}}
        ]
      ],
    _,
      Missing["InvalidScheme", "Unsupported scheme."]
  ]
];

ClearAll[integrateIntervals];
integrateIntervals[integrand_, intervals_List, opts_Association] := Module[
  {prec = opts["precision"], acc = opts["accuracyGoal"],
   goal = opts["precisionGoal"], rec = opts["maxRecursion"], sum = 0., res},
  Do[
    If[interval[[1]] >= interval[[2]], Continue[]];
    res = Quiet@Check[
      NIntegrate[
        integrand[s],
        {s, interval[[1]], interval[[2]]},
        Method -> {"GlobalAdaptive", "SymbolicProcessing" -> 0},
        WorkingPrecision -> prec,
        AccuracyGoal -> acc,
        PrecisionGoal -> goal,
        MaxRecursion -> rec
      ],
      Missing["IntegrationFailure"]
    ];
    If[res === Missing["IntegrationFailure"],
      Return[Missing["IntegrationFailure"]]
    ];
    sum += res,
    {interval, intervals}
  ];
  sum
];

ClearAll[masslessCounterterm];
masslessCounterterm[spec_Association, prefactor_, opts_Association] := Module[
  {scheme = ToLowerCase[ToString[Lookup[spec, "scheme", ""]]],
   pole = N[opts["poleStrength"]]},
  Which[
    !NumericQ[prefactor], Missing["Unsupported"],
    scheme === "cutoff",
      Module[{sCut = N[Lookup[spec, "sCut", Missing["Invalid"]]]},
        If[!NumericQ[sCut] || sCut <= 0,
          Missing["InvalidScheme", "Positive sCut required for cutoff."],
          prefactor*pole/(3.*sCut^3)
        ]
      ],
    scheme === "analytic",
      0.,
    True,
      0.
  ]
];

ClearAll[lossFraction];
lossFraction[integral_, base_] := Module[
  {},
  If[base <= 0,
    "NotEvaluated",
    N[Max[0., 1. - integral/base], 16]
  ]
];

ClearAll[evaluateScheme];
evaluateScheme[spec_Association, integrand_, opts_Association,
    subtractions_Integer, prefactor_, baseIntegral_, baseBound_] := Module[
  {intervals, integral, counterterm, bound, heavyContribution, residual,
   loss, schemeName, status = "ok", message = ""},
  intervals = integrationIntervals[spec, opts];
  If[Head[intervals] === Missing,
    status = "error";
    message = If[Length[List @@ intervals] >= 2,
      ToString[intervals[[2]]],
      "Invalid scheme specification."
    ];
    Return[<|
      "status" -> status,
      "scheme" -> Lookup[spec, "scheme", "unknown"],
      "message" -> message
    |>]
  ];
  integral = integrateIntervals[integrand, intervals, opts];
  If[integral === Missing["IntegrationFailure"],
    status = "error";
    message = "Failed to integrate heavy spectrum for scheme.";
    Return[<|
      "status" -> status,
      "scheme" -> Lookup[spec, "scheme", "unknown"],
      "message" -> message
    |>]
  ];
  heavyContribution = prefactor*integral;
  bound = heavyContribution/2.;
  counterterm = masslessCounterterm[spec, prefactor, opts];
  residual = bound - baseBound;
  loss = lossFraction[integral, baseIntegral];
  schemeName = ToString[Lookup[spec, "scheme", "unknown"]];
  <|
    "status" -> status,
    "scheme" -> schemeName,
    "parameters" -> KeyTake[spec, {"sCut", "sMin", "sMax"}],
    "heavyIntegral" -> integral,
    "heavyContribution" -> heavyContribution,
    "renormalisedBound" -> bound,
    "counterterm" -> counterterm,
    "residual" -> residual,
    "lostFraction" -> loss
  |>
];

ClearAll[aggregateSchemes];
aggregateSchemes[schemeResults_List, opts_Association, baseBound_] :=
 Module[{success, bounds, residuals, tolerance = opts["schemeTolerance"],
   maxSpread, minBound, maxBound, consistent, counterterms, losses,
   numericLosses},
  success = Select[schemeResults, Lookup[#, "status", ""] === "ok" &];
  If[success === {},
    Return[<|
      "message" -> "No successful schemes evaluated.",
      "schemeCount" -> Length[schemeResults]
    |>]
  ];
  bounds = Lookup[success, "renormalisedBound"];
  residuals = Lookup[success, "residual"];
  counterterms = Lookup[success, "counterterm"];
  losses = Lookup[success, "lostFraction"];
  numericLosses = DeleteCases[losses, "NotEvaluated"];
  minBound = Min[bounds];
  maxBound = Max[bounds];
  maxSpread = maxBound - minBound;
  consistent = Max[Abs[bounds - baseBound]] <= tolerance;
  <|
    "schemeCount" -> Length[success],
    "minBound" -> minBound,
    "maxBound" -> maxBound,
    "spread" -> maxSpread,
    "baseBound" -> baseBound,
    "consistentWithBase" -> consistent,
    "maxResidual" -> Max[Abs[residuals]],
    "countertermSummary" -> <|
      "maxCounterterm" -> Max[counterterms /. {Missing[__] -> 0.}],
      "minCounterterm" -> Min[counterterms /. {Missing[__] -> 0.}]
    |>,
    "lossStatistics" -> <|
      "maxLoss" -> If[numericLosses === {}, "NotEvaluated", Max[numericLosses]],
      "minLoss" -> If[numericLosses === {}, "NotEvaluated", Min[numericLosses]]
    |>
  |>
];

ClearAll[userEvaluator];
userEvaluator[cRen_, schemeResults_List] := Module[
  {numeric = NumericQ[cRen], filtered, evaluations},
  If[!numeric,
    Return[<|
      "provided" -> "NotProvided",
      "schemeEvaluations" -> {}
    |>]
  ];
  filtered = Select[schemeResults, Lookup[#, "status", ""] === "ok" &];
  evaluations = Table[
    With[{bound = res["renormalisedBound"]},
      <|
        "scheme" -> res["scheme"],
        "bound" -> bound,
        "margin" -> (cRen - bound),
        "satisfies" -> (cRen >= bound)
      |>
    ],
    {res, filtered}
  ];
  <|
    "provided" -> cRen,
    "schemeEvaluations" -> evaluations
  |>
];

ClearAll[sanitize];
sanitize[val_] := Which[
  val === Infinity, "Infinity",
  val === -Infinity, "-Infinity",
  NumericQ[val], N[val, 16],
  True, val
];

ClearAll[sanitizeAll];
sanitizeAll[expr_] := Map[sanitize, expr, {0, Infinity}];

ClearAll[main];
main[] := Module[
  {args, opts, validity, subtractions, pref, integrand, schemes, baseIntervals,
   baseIntegral, baseBound, schemeResults, aggregate, userReport, payload},
  args = parseArgs[];
  opts = mergeOptions[defaultOptions[], args];
  If[opts["schemes"] === Automatic,
    schemes = defaultSchemes[],
    schemes = opts["schemes"];
    If[!ListQ[schemes], schemes = defaultSchemes[]]
  ];
  schemes = Select[normalizeScheme /@ schemes, AssociationQ];
  If[schemes === {}, schemes = defaultSchemes[]];
  validity = validateOptions[opts];
  If[!validity["valid"],
    Print[ExportString[
      <|"status" -> "error", "message" -> validity["message"]|>,
      "JSON", "Compact" -> True
    ]];
    Return[];
  ];
  subtractions = Round[opts["subtractions"]];
  pref = prefactor[subtractions];
  If[!NumericQ[pref],
    Print[ExportString[
      <|"status" -> "error", "message" -> "Unsupported subtraction count."|>,
      "JSON", "Compact" -> True
    ]];
    Return[];
  ];
  integrand = heavyIntegrandFunction[opts, subtractions];
  baseIntervals = {{N[opts["heavyThreshold"]], opts["integrationMax"]}};
  baseIntegral = integrateIntervals[integrand, baseIntervals, opts];
  If[baseIntegral === Missing["IntegrationFailure"],
    Print[ExportString[
      <|
        "status" -> "error",
        "message" -> "Failed to integrate heavy spectrum for base configuration."
      |>,
      "JSON", "Compact" -> True
    ]];
    Return[];
  ];
  baseBound = pref*baseIntegral/2.;
  schemeResults = evaluateScheme[#, integrand, opts, subtractions, pref,
      baseIntegral, baseBound] & /@ schemes;
  aggregate = aggregateSchemes[schemeResults, opts, baseBound];
  userReport = userEvaluator[opts["cRen"], schemeResults];
  payload = <|
    "status" -> "ok",
    "subtractions" -> subtractions,
    "prefactor" -> pref,
    "inputs" -> <|
      "poleStrength" -> opts["poleStrength"],
      "heavyStrength" -> opts["heavyStrength"],
      "heavyScale" -> opts["heavyScale"],
      "heavyThreshold" -> opts["heavyThreshold"],
      "growthPower" -> opts["growthPower"],
      "tailExponent" -> opts["tailExponent"],
      "integrationMax" -> opts["integrationMax"],
      "precision" -> opts["precision"],
      "accuracyGoal" -> opts["accuracyGoal"],
      "precisionGoal" -> opts["precisionGoal"],
      "maxRecursion" -> opts["maxRecursion"],
      "schemeTolerance" -> opts["schemeTolerance"]
    |>,
    "base" -> <|
      "heavyIntegral" -> baseIntegral,
      "heavyContribution" -> pref*baseIntegral,
      "renormalisedBound" -> baseBound
    |>,
    "schemes" -> schemeResults,
    "aggregate" -> aggregate,
    "userCoefficient" -> userReport
  |>;
  Print[ExportString[sanitizeAll[payload], "JSON", "Compact" -> True]];
];

main[];
