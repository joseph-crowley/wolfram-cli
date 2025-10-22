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
   |>
 |>;

End[];
EndPackage[];
