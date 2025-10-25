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
(* Load IR package via relative path to repo root. *)
Get[FileNameJoin[{"..", "..", "lib", "PhysicsCLI", "IR.wl"}]];

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

(* Scheme normalization and validation is provided by PhysicsCLI`IR`. *)

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
  "schemeTolerance" -> 1.*^-11,
  "intervalAbsTol" -> 1.*^-10,
  "intervalRelTol" -> 1.*^-6,
  "intervalTimeCap" -> 60.,
  "intervalMaxRefine" -> 3,
  "intervalPrecisionBump" -> 10,
  "intervalGoalBump" -> 2,
  "intervalRecursionBump" -> 2
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

(* Integration intervals now delegated to the IR module. *)

ClearAll[integrateIntervals];
integrateIntervals[integrand_, intervals_List, opts_Association,
    override_: <||>] := Module[
  {prec, acc, goal, rec, timeCap, sum = 0., res, interval},
  prec = Lookup[override, "precision", opts["precision"]];
  acc = Lookup[override, "accuracyGoal", opts["accuracyGoal"]];
  goal = Lookup[override, "precisionGoal", opts["precisionGoal"]];
  rec = Lookup[override, "maxRecursion", opts["maxRecursion"]];
  timeCap = Lookup[override, "intervalTimeCap",
    Lookup[opts, "intervalTimeCap", 60.]];
  Do[
    interval = current;
    If[interval[[1]] >= interval[[2]], Continue[]];
    res = Quiet@Check[
      TimeConstrained[
        NIntegrate[
          integrand[s],
          {s, interval[[1]], interval[[2]]},
          Method -> {"GlobalAdaptive", "SymbolicProcessing" -> 0},
          WorkingPrecision -> prec,
          AccuracyGoal -> acc,
          PrecisionGoal -> goal,
          MaxRecursion -> rec
        ],
        timeCap,
        Missing["TimedOut"]
      ],
      Missing["IntegrationFailure"]
    ];
    If[res === Missing["IntegrationFailure"] || res === Missing["TimedOut"],
      Return[res]
    ];
    sum += res,
    {current, intervals}
  ];
  sum
];

ClearAll[refinedIntegralEstimate];
refinedIntegralEstimate[integrand_, intervals_List,
    opts_Association] := Module[
  {absTol, relTol, maxRefine, precisionBump, goalBump, recursionBump,
   basePrec, baseAcc, baseGoal, baseRec, values = {}, attempts = 0,
   override, res, last = Missing["NotSet"], allowedWidth = Infinity,
   diff = Infinity, success = False, center = 0., width = 0.,
   finalAllowed = Infinity, level},
  absTol = N[Lookup[opts, "intervalAbsTol", 1.*^-10]];
  relTol = N[Lookup[opts, "intervalRelTol", 1.*^-6]];
  maxRefine = Max[1, Round[Lookup[opts, "intervalMaxRefine", 3]]];
  precisionBump = Lookup[opts, "intervalPrecisionBump", 10];
  goalBump = Lookup[opts, "intervalGoalBump", 2];
  recursionBump = Lookup[opts, "intervalRecursionBump", 2];
  basePrec = Lookup[opts, "precision", 60];
  baseAcc = Lookup[opts, "accuracyGoal", 12];
  baseGoal = Lookup[opts, "precisionGoal", 12];
  baseRec = Lookup[opts, "maxRecursion", 12];
  Do[
    override = <|
      "precision" -> basePrec + precisionBump*level,
      "accuracyGoal" -> baseAcc + goalBump*level,
      "precisionGoal" -> baseGoal + goalBump*level,
      "maxRecursion" -> Min[baseRec + recursionBump*level, 30],
      "intervalTimeCap" -> Lookup[opts, "intervalTimeCap", 60.]
    |>;
    res = integrateIntervals[integrand, intervals, opts, override];
    attempts++;
    If[res === Missing["IntegrationFailure"] ||
       res === Missing["TimedOut"],
      Return[<|
        "value" -> res,
        "interval" -> <||>,
        "attempts" -> attempts,
        "success" -> False,
        "message" -> If[res === Missing["TimedOut"],
          "Timed out during integration.",
          "Integration failure during refinement."
        ]
      |>]
    ];
    AppendTo[values, res];
    If[last =!= Missing["NotSet"],
      allowedWidth = absTol +
        relTol*Max[Abs[res], Abs[last], 1.*^-40];
      diff = Abs[res - last];
      If[diff <= allowedWidth/2.,
        center = res;
        width = Min[allowedWidth, 2.*diff];
        success = True;
        finalAllowed = allowedWidth;
        Break[];
      ];
    ];
    last = res,
    {level, 0, maxRefine}
  ];
  If[!TrueQ[success],
    center = Last[values];
    If[Length[values] >= 2,
      diff = Abs[values[[-1]] - values[[-2]]];
      finalAllowed = absTol +
        relTol*Max[Abs[center], Abs[values[[-2]]], 1.*^-40];
      width = Min[finalAllowed, 2.*diff];
      success = diff <= finalAllowed/2.,
      finalAllowed = absTol + relTol*Max[Abs[center], 1.*^-40];
      width = finalAllowed;
      success = False;
    ];
  ];
  <|
    "value" -> N[center, 16],
    "interval" -> <|
      "center" -> N[center, 16],
      "lower" -> N[center - width/2., 16],
      "upper" -> N[center + width/2., 16],
      "width" -> N[width, 16],
      "allowedWidth" -> N[finalAllowed, 16],
      "absTolerance" -> N[absTol, 16],
      "relTolerance" -> N[relTol, 16],
      "withinTolerance" -> TrueQ[success]
    |>,
    "attempts" -> attempts,
    "success" -> TrueQ[success]
  |>
];

ClearAll[scaleIntervalAssoc];
scaleIntervalAssoc[interval_Association, factor_] := Module[
  {f = N[factor, 16], center, lower, upper, width, allowed, absTol, relTol},
  center = f*Lookup[interval, "center", 0.];
  lower = f*Lookup[interval, "lower", 0.];
  upper = f*Lookup[interval, "upper", 0.];
  width = Abs[f]*Lookup[interval, "width", 0.];
  allowed = Abs[f]*Lookup[interval, "allowedWidth", 0.];
  absTol = Abs[f]*Lookup[interval, "absTolerance", 0.];
  relTol = Lookup[interval, "relTolerance", 0.];
  If[f < 0,
    {lower, upper} = {upper, lower};
  ];
  <|
    "center" -> N[center, 16],
    "lower" -> N[lower, 16],
    "upper" -> N[upper, 16],
    "width" -> N[width, 16],
    "allowedWidth" -> N[allowed, 16],
    "absTolerance" -> N[absTol, 16],
    "relTolerance" -> N[relTol, 16],
    "withinTolerance" -> Lookup[interval, "withinTolerance", False]
  |>
];

(* Counterterm computation also delegated to the IR module. *)

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
    subtractions_Integer, prefactor_, baseData_Association] := Module[
  {intervals, integralData, integral, counterterm, bound, heavyContribution,
   residual, loss, schemeName, status = "ok", message = "", boundInterval},
  intervals = PhysicsCLI`IR`IntegrationIntervalsForScheme[spec, opts];
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
  integralData = refinedIntegralEstimate[integrand, intervals, opts];
  integral = integralData["value"];
  If[integral === Missing["IntegrationFailure"] ||
     integral === Missing["TimedOut"],
    status = "error";
    message = If[integral === Missing["TimedOut"],
      "Timed out during heavy spectrum integration.",
      "Failed to integrate heavy spectrum for scheme."
    ];
    Return[<|
      "status" -> status,
      "scheme" -> Lookup[spec, "scheme", "unknown"],
      "message" -> message
    |>]
  ];
  heavyContribution = prefactor*integral;
  bound = heavyContribution/2.;
  counterterm = PhysicsCLI`IR`CountertermForScheme[spec, prefactor, opts];
  residual = bound - Lookup[baseData, "bound", 0.];
  loss = lossFraction[integral, Lookup[baseData, "integral", 0.]];
  schemeName = ToString[Lookup[spec, "scheme", "unknown"]];
  boundInterval = scaleIntervalAssoc[
    integralData["interval"], prefactor/2.
  ];
  <|
    "status" -> status,
    "scheme" -> schemeName,
    "parameters" -> KeyTake[spec, {"sCut", "sMin", "sMax"}],
    "heavyIntegral" -> integral,
    "heavyContribution" -> heavyContribution,
    "renormalisedBound" -> bound,
    "counterterm" -> counterterm,
    "residual" -> residual,
    "lostFraction" -> loss,
    "intervals" -> <|
      "heavyIntegral" -> Append[integralData["interval"],
        "attempts" -> integralData["attempts"]],
      "renormalisedBound" -> Append[boundInterval,
        "attempts" -> integralData["attempts"]]
    |>
  |>
];

ClearAll[aggregateSchemes];
aggregateSchemes[schemeResults_List, opts_Association, baseData_Association] :=
 Module[{success, bounds, residuals, tolerance = opts["schemeTolerance"],
   maxSpread, minBound, maxBound, consistent, counterterms, losses,
   numericLosses, baseBound, intervalBlocks, boundIntervals, widths,
   allowedWidths, withinFlags, intervalPass, baseInterval, maxWidth,
   maxAllowed},
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
  baseBound = Lookup[baseData, "bound", 0.];
  minBound = Min[bounds];
  maxBound = Max[bounds];
  maxSpread = maxBound - minBound;
  consistent = Max[Abs[bounds - baseBound]] <= tolerance;
  intervalBlocks = Lookup[success, "intervals", <||>];
  boundIntervals = Lookup[#, "renormalisedBound", <||>] & /@ intervalBlocks;
  widths = DeleteCases[
    Lookup[#, "width", Missing["NoWidth"]] & /@ boundIntervals,
    Missing["NoWidth"]
  ];
  allowedWidths = DeleteCases[
    Lookup[#, "allowedWidth", Missing["NoAllowed"]] & /@ boundIntervals,
    Missing["NoAllowed"]
  ];
  withinFlags = TrueQ /@
    (Lookup[#, "withinTolerance", False] & /@ boundIntervals);
  intervalPass = And @@ If[withinFlags === {}, {True}, withinFlags];
  baseInterval = Lookup[
    Lookup[Lookup[baseData, "intervals", <||>], "renormalisedBound", <||>],
    "withinTolerance",
    False
  ];
  maxWidth = If[widths === {}, 0., Max[widths]];
  maxAllowed = If[allowedWidths === {}, 0., Max[allowedWidths]];
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
    |>,
    "intervalCompliance" -> <|
      "allSchemesWithinTolerance" -> intervalPass,
      "baseWithinTolerance" -> TrueQ[baseInterval],
      "maxWidth" -> maxWidth,
      "maxAllowedWidth" -> maxAllowed
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

ClearAll[SanitizeJSON];
SanitizeJSON[assoc_Association] := AssociationMap[SanitizeJSON, assoc];
SanitizeJSON[list_List] := SanitizeJSON /@ list;
SanitizeJSON[val_] /; NumericQ[val] := N[val, 16];
SanitizeJSON[other_] := other;

ClearAll[main];
main[] := Module[
  {args, opts, validity, subtractions, pref, integrand, schemes, baseIntervals,
   baseRefined, baseIntegral, baseContribution, baseBound, baseBoundInterval,
   baseIntervalsAssoc, baseData, schemeResults, aggregate, userReport, payload,
   inputsPayload},
  args = parseArgs[];
  opts = mergeOptions[defaultOptions[], args];
  If[opts["schemes"] === Automatic,
    schemes = defaultSchemes[],
    schemes = opts["schemes"];
    If[!ListQ[schemes], schemes = defaultSchemes[]]
  ];
  (* Canonicalize and validate schemes via registry; keep only valid ones. *)
  schemes = Module[{res = PhysicsCLI`IR`CanonicalizeSchemeList[schemes]},
    If[Lookup[res, "Valid", {}] === {}, defaultSchemes[], Lookup[res, "Valid", {}]]
  ];
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
  baseRefined = refinedIntegralEstimate[integrand, baseIntervals, opts];
  baseIntegral = baseRefined["value"];
  If[baseIntegral === Missing["IntegrationFailure"] ||
     baseIntegral === Missing["TimedOut"],
    Print[ExportString[
      <|
        "status" -> "error",
        "message" -> If[baseIntegral === Missing["TimedOut"],
          "Timed out during base heavy spectrum integration.",
          "Failed to integrate heavy spectrum for base configuration."
        ]
      |>,
      "JSON", "Compact" -> True
    ]];
    Return[];
  ];
  baseContribution = pref*baseIntegral;
  baseBound = baseContribution/2.;
  baseBoundInterval = scaleIntervalAssoc[baseRefined["interval"], pref/2.];
  baseIntervalsAssoc = <|
    "heavyIntegral" -> Append[baseRefined["interval"],
      "attempts" -> baseRefined["attempts"]],
    "renormalisedBound" -> Append[baseBoundInterval,
      "attempts" -> baseRefined["attempts"]]
  |>;
  baseData = <|
    "integral" -> baseIntegral,
    "bound" -> baseBound,
    "contribution" -> baseContribution,
    "intervals" -> baseIntervalsAssoc
  |>;
  schemeResults = evaluateScheme[#, integrand, opts, subtractions, pref,
      baseData] & /@ schemes;
  aggregate = aggregateSchemes[schemeResults, opts, baseData];
  userReport = userEvaluator[opts["cRen"], schemeResults];
  inputsPayload = <|
    "poleStrength" -> opts["poleStrength"],
    "heavyStrength" -> opts["heavyStrength"],
    "heavyScale" -> opts["heavyScale"],
    "heavyThreshold" -> opts["heavyThreshold"],
    "growthPower" -> opts["growthPower"],
    "tailExponent" -> opts["tailExponent"],
    "integrationMax" -> If[opts["integrationMax"] === Infinity,
      "Infinity",
      opts["integrationMax"]
    ],
    "precision" -> opts["precision"],
    "accuracyGoal" -> opts["accuracyGoal"],
    "precisionGoal" -> opts["precisionGoal"],
    "maxRecursion" -> opts["maxRecursion"],
    "schemeTolerance" -> opts["schemeTolerance"],
    "intervalAbsTol" -> opts["intervalAbsTol"],
    "intervalRelTol" -> opts["intervalRelTol"],
    "intervalTimeCap" -> opts["intervalTimeCap"],
    "intervalMaxRefine" -> opts["intervalMaxRefine"],
    "intervalPrecisionBump" -> opts["intervalPrecisionBump"],
    "intervalGoalBump" -> opts["intervalGoalBump"],
    "intervalRecursionBump" -> opts["intervalRecursionBump"]
  |>;
  payload = <|
    "status" -> "ok",
    "subtractions" -> subtractions,
    "prefactor" -> pref,
    "inputs" -> inputsPayload,
    "base" -> <|
      "heavyIntegral" -> baseIntegral,
      "heavyContribution" -> baseContribution,
      "renormalisedBound" -> baseBound,
      "intervals" -> baseIntervalsAssoc
    |>,
    "schemes" -> schemeResults,
    "aggregate" -> aggregate,
    "userCoefficient" -> userReport
  |>;
  Print[ExportString[SanitizeJSON[payload], "JSON", "Compact" -> True]];
];

main[];
