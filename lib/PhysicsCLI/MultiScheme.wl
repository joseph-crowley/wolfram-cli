baseDir = DirectoryName[$InputFileName];
If[baseDir =!= $Failed && baseDir =!= Null,
  If[!MemberQ[$Path, baseDir], AppendTo[$Path, baseDir]];
  parentDir = FileNameJoin[{baseDir, ".."}];
  If[DirectoryQ[parentDir] && !MemberQ[$Path, parentDir],
    AppendTo[$Path, parentDir]];
];

BeginPackage["PhysicsCLI`MultiScheme`",
  {"PhysicsCLI`Utils`", "PhysicsCLI`IR`"}];

MultiSchemeDefaultOptions::usage =
  "MultiSchemeDefaultOptions[] returns the baseline option association for multi-scheme \
IR bounds.";
MultiSchemeDefaultSchemes::usage =
  "MultiSchemeDefaultSchemes[] provides the canonical scheme list used in Phase 1.";
MultiSchemeMergeOptions::usage =
  "MultiSchemeMergeOptions[defaults, overrides] overlays overrides onto defaults while \
ignoring Missing[\"Invalid\"].";
MultiSchemeValidateOptions::usage =
  "MultiSchemeValidateOptions[opts] returns <|\"valid\"->True|False,\"message\"->str|>.";
MultiSchemePrefactor::usage =
  "MultiSchemePrefactor[subtractions] returns the dispersion prefactor for the given \
subtraction count.";
MultiSchemeHeavyIntegrandFunction::usage =
  "MultiSchemeHeavyIntegrandFunction[opts, subtractions] builds the heavy spectrum \
integrand.";
MultiSchemeRefinedIntegralEstimate::usage =
  "MultiSchemeRefinedIntegralEstimate[integrand, intervals, opts] performs multi pass \
integration with adaptive tolerances.";
MultiSchemeAggregateSchemes::usage =
  "MultiSchemeAggregateSchemes[schemeResults, opts, baseData] summarises spreads, loss, \
and interval compliance.";
MultiSchemeUserEvaluator::usage =
  "MultiSchemeUserEvaluator[cRen, schemeResults] compares a supplied Wilson coefficient \
with scheme bounds.";
MultiSchemeSanitizeJSON::usage =
  "MultiSchemeSanitizeJSON[data] converts associations and lists to numeric cleaned \
forms suitable for JSON export.";
MultiSchemeEvaluatePayload::usage =
  "MultiSchemeEvaluatePayload[opts, schemeSpecs] returns the complete evaluation payload \
for the provided configuration.";

Begin["`Private`"];

MultiSchemeDefaultSchemes[] := {
  <|"scheme" -> "analytic"|>,
  <|"scheme" -> "principal_value"|>,
  <|"scheme" -> "cutoff", "sCut" -> 0.25|>,
  <|"scheme" -> "cutoff", "sCut" -> 0.15|>,
  <|"scheme" -> "excludeBelow", "sMin" -> 2.0|>,
  <|"scheme" -> "bandGap", "sMin" -> 2.0, "sMax" -> 2.8|>,
  <|"scheme" -> "bandAverage",
    "bands" -> {{2.0, 2.4}, {2.4, 2.8}, {2.8, 3.2}}|>
};

MultiSchemeDefaultOptions[] := <|
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

MultiSchemeMergeOptions[defaults_Association, overrides_Association] := Module[
  {result = defaults},
  KeyValueMap[
    If[#2 =!= Missing["Invalid"], result[#1] = #2] &,
    overrides
  ];
  result
];

MultiSchemeValidateOptions[opts_Association] := Module[
  {subtractions = Round[Lookup[opts, "subtractions", 2]]},
  If[subtractions =!= 2,
    Return[<|"valid" -> False,
      "message" -> "Only two subtractions are supported."|>]
  ];
  If[Lookup[opts, "heavyThreshold", 0.] <= 0,
    Return[<|"valid" -> False,
      "message" -> "heavyThreshold must be positive."|>]
  ];
  If[Lookup[opts, "tailExponent", 0.] <=
      Lookup[opts, "growthPower", 0.] + 2,
    Return[<|"valid" -> False,
      "message" -> "tailExponent must exceed growthPower + 2."|>]
  ];
  If[Lookup[opts, "integrationMax", Infinity] =!= Infinity &&
      Lookup[opts, "integrationMax", Infinity] <=
        Lookup[opts, "heavyThreshold", 0.],
    Return[<|"valid" -> False,
      "message" -> "integrationMax must exceed heavyThreshold."|>]
  ];
  If[Lookup[opts, "schemeTolerance", 0.] <= 0,
    Return[<|"valid" -> False,
      "message" -> "schemeTolerance must be positive."|>]
  ];
  <|"valid" -> True, "message" -> "OK"|>
];

MultiSchemePrefactor[subtractions_Integer] :=
  If[subtractions === 2, 2./Pi, Missing["Unsupported"]];

MultiSchemeHeavyIntegrandFunction[opts_Association, subtractions_Integer] := Module[
  {threshold = N[Lookup[opts, "heavyThreshold", 0.]],
   strength = N[Lookup[opts, "heavyStrength", 1.]],
   scale = N[Lookup[opts, "heavyScale", 1.]],
   growth = N[Lookup[opts, "growthPower", 0.]],
   tail = N[Lookup[opts, "tailExponent", 0.]]},
  Function[{x},
    If[x <= threshold,
      0.,
      With[{y = x - threshold},
        strength*(y^growth)/(1. + y/scale)^tail/
          x^(subtractions + 1)
      ]
    ]
  ]
];

ClearAll[multiSchemeIntegrateIntervals];
multiSchemeIntegrateIntervals[integrand_, intervals_List, opts_Association,
    override_: <||>] := Module[
  {prec, acc, goal, rec, timeCap, sum = 0., res, interval},
  prec = Lookup[override, "precision",
    Lookup[opts, "precision", 60]];
  acc = Lookup[override, "accuracyGoal",
    Lookup[opts, "accuracyGoal", 12]];
  goal = Lookup[override, "precisionGoal",
    Lookup[opts, "precisionGoal", 12]];
  rec = Lookup[override, "maxRecursion",
    Lookup[opts, "maxRecursion", 12]];
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
    If[res === Missing["IntegrationFailure"] ||
       res === Missing["TimedOut"],
      Return[res]
    ];
    sum += res,
    {current, intervals}
  ];
  sum
];

MultiSchemeRefinedIntegralEstimate[integrand_, intervals_List,
    opts_Association] := Module[
  {absTol = Lookup[opts, "intervalAbsTol", 1.*^-10],
   relTol = Lookup[opts, "intervalRelTol", 1.*^-6],
   maxRefine = Lookup[opts, "intervalMaxRefine", 3],
   precBump = Lookup[opts, "intervalPrecisionBump", 10],
   goalBump = Lookup[opts, "intervalGoalBump", 2],
   recBump = Lookup[opts, "intervalRecursionBump", 2],
   attempts = {}, baseRes, refineLevel, res, success = False, last = Missing[
     "NotSet"], allowedWidth = Infinity, diff = Infinity,
   center = 0., width = 0., finalAllowed = Infinity, values = {}},
  baseRes = multiSchemeIntegrateIntervals[integrand, intervals, opts];
  If[baseRes === Missing["IntegrationFailure"] ||
     baseRes === Missing["TimedOut"],
    Return[<|
      "value" -> baseRes,
      "interval" -> <||>,
      "attempts" -> {},
      "success" -> False
    |>]
  ];
  AppendTo[attempts, <|"level" -> 0, "value" -> N[baseRes, 16]|>];
  AppendTo[values, N[baseRes, 16]];
  center = N[baseRes, 16];
  Do[
    refineLevel = level;
    res = multiSchemeIntegrateIntervals[integrand, intervals, opts, <|
        "precision" -> Lookup[opts, "precision", 60] + level*precBump,
        "accuracyGoal" -> Lookup[opts, "accuracyGoal", 12] + level*goalBump,
        "precisionGoal" -> Lookup[opts, "precisionGoal", 12] + level*goalBump,
        "maxRecursion" -> Lookup[opts, "maxRecursion", 12] + level*recBump,
        "intervalTimeCap" -> Lookup[opts, "intervalTimeCap", 60.]*
          (1 + 0.5*level)
      |>];
    If[res === Missing["IntegrationFailure"] ||
       res === Missing["TimedOut"],
      AppendTo[attempts, <|"level" -> refineLevel, "value" -> res|>];
      Continue[];
    ];
    AppendTo[attempts,
      <|"level" -> refineLevel, "value" -> N[res, 16]|>];
    AppendTo[values, N[res, 16]];
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
    {level, 1, maxRefine}
  ];
  If[!TrueQ[success],
    center = Last[values];
    If[Length[values] >= 2,
      diff = Abs[values[[-1]] - values[[-2]]];
      finalAllowed = absTol +
        relTol*Max[Abs[center], Abs[values[[-2]]], 1.*^-40];
      width = Min[finalAllowed, 2.*diff];
      success = diff <= finalAllowed/2.,
      finalAllowed = absTol +
        relTol*Max[Abs[center], 1.*^-40];
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

MultiSchemeScaleIntervalAssoc[interval_Association, factor_] := Module[
  {f = N[factor, 16], center, lower, upper, width, allowed,
   absTol, relTol},
  center = f*Lookup[interval, "center", 0.];
  lower = f*Lookup[interval, "lower", 0.];
  upper = f*Lookup[interval, "upper", 0.];
  width = Abs[f]*Lookup[interval, "width", 0.];
  allowed = Abs[f]*Lookup[interval, "allowedWidth", 0.];
  absTol = Abs[f]*Lookup[interval, "absTolerance", 0.];
  relTol = Lookup[interval, "relTolerance", 0.];
  If[f < 0, {lower, upper} = {upper, lower}];
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

MultiSchemeLossFraction[integral_, base_] := Module[{},
  If[base <= 0,
    "NotEvaluated",
    N[Max[0., 1. - integral/base], 16]
  ]
];

MultiSchemeEvaluateScheme[spec_Association, integrand_, opts_Association,
    subtractions_Integer, prefactor_, baseData_Association] := Module[
  {intervals, integralData, integral, counterterm, bound, heavyContribution,
   residual, loss, schemeName, status = "ok", message = "",
   boundInterval},
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
  integralData = MultiSchemeRefinedIntegralEstimate[integrand, intervals, opts];
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
  loss = MultiSchemeLossFraction[integral, Lookup[baseData, "integral", 0.]];
  schemeName = ToString[Lookup[spec, "scheme", "unknown"]];
  boundInterval = MultiSchemeScaleIntervalAssoc[
    integralData["interval"], prefactor/2.
  ];
  <|
    "status" -> status,
    "scheme" -> schemeName,
    "parameters" -> KeyTake[spec, {"sCut", "sMin", "sMax", "bands"}],
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

MultiSchemeAggregateSchemes[schemeResults_List, opts_Association,
    baseData_Association] := Module[
  {success, bounds, residuals, tolerance = Lookup[opts, "schemeTolerance",
      1.*^-11], maxSpread, minBound, maxBound, consistent, counterterms,
   losses, numericLosses, baseBound, intervalBlocks, boundIntervals, widths,
   allowedWidths, withinFlags, intervalPass, baseInterval, maxWidth,
   maxAllowed},
  success = Select[schemeResults,
    Lookup[#, "status", ""] === "ok" &];
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
  boundIntervals = Lookup[#, "renormalisedBound", <||>] & /@
    intervalBlocks;
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
    Lookup[Lookup[baseData, "intervals", <||>],
      "renormalisedBound", <||>],
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
      "maxCounterterm" ->
        Max[counterterms /. {Missing[__] -> 0.}],
      "minCounterterm" ->
        Min[counterterms /. {Missing[__] -> 0.}]
    |>,
    "lossStatistics" -> <|
      "maxLoss" ->
        If[numericLosses === {}, "NotEvaluated", Max[numericLosses]],
      "minLoss" ->
        If[numericLosses === {}, "NotEvaluated", Min[numericLosses]]
    |>,
    "intervalCompliance" -> <|
      "allSchemesWithinTolerance" -> intervalPass,
      "baseWithinTolerance" -> TrueQ[baseInterval],
      "maxWidth" -> maxWidth,
      "maxAllowedWidth" -> maxAllowed
    |>
  |>
];

MultiSchemeUserEvaluator[cRen_, schemeResults_List] := Module[
  {numeric = NumericQ[cRen], filtered, evaluations},
  If[!numeric,
    Return[<|
      "provided" -> "NotProvided",
      "schemeEvaluations" -> {}
    |>]
  ];
  filtered = Select[schemeResults,
    Lookup[#, "status", ""] === "ok" &];
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

MultiSchemeSanitizeJSON[assoc_Association] := AssociationMap[MultiSchemeSanitizeJSON, assoc];
MultiSchemeSanitizeJSON[list_List] := MultiSchemeSanitizeJSON /@ list;
MultiSchemeSanitizeJSON[Infinity] := "Infinity";
MultiSchemeSanitizeJSON[-Infinity] := "-Infinity";
MultiSchemeSanitizeJSON[DirectedInfinity[_]] := "Infinity";
MultiSchemeSanitizeJSON[ComplexInfinity] := "ComplexInfinity";
MultiSchemeSanitizeJSON[Missing[__]] := "Missing";
MultiSchemeSanitizeJSON[val_] /; NumericQ[val] := N[val, 16];
MultiSchemeSanitizeJSON[other_] := other;

multiSchemeCanonicalSchemes[schemes_] := Module[{list = schemes, canonical},
  If[list === Automatic, list = MultiSchemeDefaultSchemes[]];
  If[!ListQ[list], list = MultiSchemeDefaultSchemes[]];
  canonical = PhysicsCLI`IR`CanonicalizeSchemeList[list];
  If[Lookup[canonical, "Valid", {}] === {},
    MultiSchemeDefaultSchemes[],
    Lookup[canonical, "Valid"]
  ]
];

multiSchemeComputeBaseData[opts_Association, subtractions_Integer,
    prefactor_, integrand_] := Module[
  {baseIntervals, baseRefined, baseIntegral, baseContribution,
   baseBound, baseBoundInterval, baseIntervalsAssoc},
  baseIntervals = {{N[Lookup[opts, "heavyThreshold", 0.]],
     Lookup[opts, "integrationMax", Infinity]}};
  baseRefined = MultiSchemeRefinedIntegralEstimate[integrand, baseIntervals, opts];
  baseIntegral = baseRefined["value"];
  If[baseIntegral === Missing["IntegrationFailure"] ||
     baseIntegral === Missing["TimedOut"],
    Return[<|"status" -> "error",
      "message" -> If[baseIntegral === Missing["TimedOut"],
        "Timed out during base heavy spectrum integration.",
        "Failed to integrate heavy spectrum for base configuration."
      ]|>]
  ];
  baseContribution = prefactor*baseIntegral;
  baseBound = baseContribution/2.;
  baseBoundInterval = MultiSchemeScaleIntervalAssoc[
    baseRefined["interval"], prefactor/2.
  ];
  baseIntervalsAssoc = <|
    "heavyIntegral" -> Append[baseRefined["interval"],
      "attempts" -> baseRefined["attempts"]],
    "renormalisedBound" -> Append[baseBoundInterval,
      "attempts" -> baseRefined["attempts"]]
  |>;
  <|
    "status" -> "ok",
    "integral" -> baseIntegral,
    "bound" -> baseBound,
    "contribution" -> baseContribution,
    "intervals" -> baseIntervalsAssoc,
    "refined" -> baseRefined
  |>
];

multiSchemeBuildInputsPayload[opts_Association] := <|
  "poleStrength" -> Lookup[opts, "poleStrength"],
  "heavyStrength" -> Lookup[opts, "heavyStrength"],
  "heavyScale" -> Lookup[opts, "heavyScale"],
  "heavyThreshold" -> Lookup[opts, "heavyThreshold"],
  "growthPower" -> Lookup[opts, "growthPower"],
  "tailExponent" -> Lookup[opts, "tailExponent"],
  "integrationMax" ->
    If[Lookup[opts, "integrationMax"] === Infinity,
      "Infinity",
      Lookup[opts, "integrationMax"]
    ],
  "precision" -> Lookup[opts, "precision"],
  "accuracyGoal" -> Lookup[opts, "accuracyGoal"],
  "precisionGoal" -> Lookup[opts, "precisionGoal"],
  "maxRecursion" -> Lookup[opts, "maxRecursion"],
  "schemeTolerance" -> Lookup[opts, "schemeTolerance"],
  "intervalAbsTol" -> Lookup[opts, "intervalAbsTol"],
  "intervalRelTol" -> Lookup[opts, "intervalRelTol"],
  "intervalTimeCap" -> Lookup[opts, "intervalTimeCap"],
  "intervalMaxRefine" -> Lookup[opts, "intervalMaxRefine"],
  "intervalPrecisionBump" -> Lookup[opts, "intervalPrecisionBump"],
  "intervalGoalBump" -> Lookup[opts, "intervalGoalBump"],
  "intervalRecursionBump" -> Lookup[opts, "intervalRecursionBump"]
|>;

MultiSchemeEvaluatePayload[opts_Association, schemeSpecs_: Automatic] := Module[
  {validity, schemes, subtractions, pref, integrand, baseData,
   baseAssoc, schemeResults, aggregate, userReport, payload},
  validity = MultiSchemeValidateOptions[opts];
  If[!TrueQ[validity["valid"]],
    Return[<|"status" -> "error", "message" -> validity["message"]|>]
  ];
  schemes = multiSchemeCanonicalSchemes[schemeSpecs];
  subtractions = Round[Lookup[opts, "subtractions", 2]];
  pref = MultiSchemePrefactor[subtractions];
  If[!NumericQ[pref],
    Return[<|
      "status" -> "error",
      "message" -> "Unsupported subtraction count."
    |>]
  ];
  integrand = MultiSchemeHeavyIntegrandFunction[opts, subtractions];
  baseData = multiSchemeComputeBaseData[opts, subtractions, pref, integrand];
  If[Lookup[baseData, "status", ""] =!= "ok",
    Return[baseData]
  ];
  baseAssoc = KeyDrop[baseData, {"status", "refined"}];
  schemeResults = MultiSchemeEvaluateScheme[#, integrand, opts,
      subtractions, pref, baseAssoc] & /@ schemes;
  aggregate = MultiSchemeAggregateSchemes[schemeResults, opts, baseAssoc];
  userReport = MultiSchemeUserEvaluator[Lookup[opts, "cRen"], schemeResults];
  payload = <|
    "status" -> "ok",
    "subtractions" -> subtractions,
    "prefactor" -> pref,
    "inputs" -> multiSchemeBuildInputsPayload[opts],
    "base" -> <|
      "heavyIntegral" -> baseAssoc["integral"],
      "heavyContribution" -> baseAssoc["contribution"],
      "renormalisedBound" -> baseAssoc["bound"],
      "intervals" -> Lookup[baseAssoc, "intervals", <||>]
    |>,
    "schemes" -> schemeResults,
    "aggregate" -> aggregate,
    "userCoefficient" -> userReport
  |>;
  payload
];

End[];
EndPackage[];
