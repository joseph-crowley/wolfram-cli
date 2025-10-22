baseDir = DirectoryName[$InputFileName];
If[baseDir =!= $Failed && baseDir =!= Null,
  If[!MemberQ[$Path, baseDir], AppendTo[$Path, baseDir]];
  parentDir = FileNameJoin[{baseDir, ".."}];
  If[DirectoryQ[parentDir] && !MemberQ[$Path, parentDir], AppendTo[$Path, parentDir]];
];

BeginPackage["PhysicsCLI`Quantum`", {"PhysicsCLI`Utils`"}];

QuantumTaskSpecifications::usage = "QuantumTaskSpecifications[] returns an Association describing CLI-accessible quantum physics tasks.";
QHOEigenvalues::usage = "QHOEigenvalues[config] computes low-lying eigenvalues of the one-dimensional harmonic oscillator.";
ClebschGordanTable::usage = "ClebschGordanTable[config] returns non-zero Clebsch-Gordan coefficients for given j1, j2, J.";
DiracTraceGammaPair::usage = "DiracTraceGammaPair[config] evaluates the trace of two gamma matrices via FeynCalc when available.";

Begin["`Private`"];

QHOEigenvalues[config_Association] :=
 Module[{modes = config["n"], halfSpan = config["L"], mass = config["m"], omega = config["omega"],
   outfile = Lookup[config, "out", "qho_energies.json"],
   method, eigenData, vals, funcs, payload, solver},
  solver := NDEigensystem[
    {
     - (1/(2 mass)) D[u[x], {x, 2}] + 1/2 mass omega^2 x^2 u[x],
     DirichletCondition[u[x] == 0, x == -halfSpan || x == halfSpan]
    },
    u[x], {x, -halfSpan, halfSpan}, modes,
    Method -> {"Eigensystem" -> {"Arnoldi", "MaxIterations" -> 10000}}
   ];
  eigenData = Quiet@Check[WithTimingPayload["qho-spectrum", solver], $Failed];
  If[eigenData === $Failed,
   EmitError["Failed to solve harmonic oscillator eigenproblem."];
   Return[$Failed];
  ];
  {vals, funcs} = eigenData["Result"];
  payload = <|
    "Problem" -> "QHO eigenvalues",
    "Inputs" -> <|
      "Modes" -> modes,
      "HalfWidth" -> halfSpan,
      "Mass" -> mass,
      "Frequency" -> omega
    |>,
    "TimingSeconds" -> eigenData["Seconds"],
    "Energies" -> N[vals, 12],
    "SuggestedOutputFile" -> outfile
  |>;
  payload
 ];

ClebschGordanTable[config_Association] :=
 Module[{j1 = config["j1"], j2 = config["j2"], jTot = config["J"], results},
  results = Flatten[
    Table[
     Module[{coeff = Quiet@Check[ClebschGordan[{j1, m1}, {j2, m2}, {jTot, m}], Indeterminate]},
      If[NumericQ[coeff] && coeff =!= 0,
       <|"m1" -> m1, "m2" -> m2, "m" -> m, "Coefficient" -> N[coeff, 12]|>,
       Nothing
      ]
     ],
     {m1, -j1, j1, 1},
     {m2, -j2, j2, 1},
     {m, -jTot, jTot, 1}
    ],
    2
   ];
  <|
   "Problem" -> "Clebsch-Gordan coefficients",
   "Inputs" -> <|"j1" -> j1, "j2" -> j2, "J" -> jTot|>,
   "Terms" -> results
  |>
 ];

ensureFeynCalc[] :=
 Module[{file, envPath, searchRoots, pacletFile, zipFile, installResult},
  file = Quiet@FindFile["FeynCalc`"];
  If[file === $Failed, file = Quiet@FindFile["HighEnergyPhysics`FeynCalc`"]];
  If[file === $Failed,
   envPath = Environment["FAT_TAILED_PACLET_PATH"];
   searchRoots = DeleteMissing@Flatten@{
      If[StringQ[envPath] && envPath =!= "", envPath, Nothing],
      If[DirectoryQ[parentDir], FileNameJoin[{parentDir, "paclets"}], Nothing],
      If[DirectoryQ[FileNameJoin[{parentDir, ".."}]], FileNameJoin[{parentDir, "..", "paclets"}], Nothing]
    };
   pacletFile = SelectFirst[
      Flatten[FileNames[{"FeynCalc*.paclet"}, searchRoots, Infinity]],
      FileExistsQ,
      Missing["NotFound"]
    ];
   installResult = If[pacletFile =!= Missing["NotFound"],
      Quiet@Check[PacletInstall[pacletFile, "IgnoreVersion" -> True], $Failed],
      $Failed
     ];
   If[installResult === $Failed,
    zipFile = SelectFirst[
      Flatten[FileNames[{"FeynCalc*.zip", "fclatest.zip"}, searchRoots, Infinity]],
      FileExistsQ,
      Missing["NotFound"]
     ];
    installResult = If[zipFile =!= Missing["NotFound"],
      Module[{installDir = FileNameJoin[{$UserBaseDirectory, "Applications"}]},
       If[!DirectoryQ[installDir], CreateDirectory[installDir, CreateIntermediateDirectories -> True]];
       Quiet@Check[ExtractArchive[zipFile, installDir], $Failed]
      ],
      $Failed
     ];
   ];
   If[installResult === $Failed,
    EmitError[
     "FeynCalc archive not found. Place FeynCalc.paclet or fclatest.zip under paclets/ or set FAT_TAILED_PACLET_PATH."
    ];
    Return[False];
   ];
   file = Quiet@FindFile["FeynCalc`"];
   If[file === $Failed, file = Quiet@FindFile["HighEnergyPhysics`FeynCalc`"]];
   If[file === $Failed,
    EmitError["FeynCalc installation from local archive failed."];
    Return[False];
   ];
  ];
  If[Quiet@FindFile["FeynCalc`"] =!= $Failed,
   Needs["FeynCalc`"],
   Needs["HighEnergyPhysics`FeynCalc`"]
  ];
  True
 ];

DiracTraceGammaPair[config_Association] :=
 Module[{muLabel = config["muLabel"], nuLabel = config["nuLabel"], ok, expr, reduced, metricSyms, formatted},
  ok = ensureFeynCalc[];
  If[TrueQ[ok],
   Quiet@Check[
     ToExpression["FeynCalc`$LoadFeynArts"] = False;
     ToExpression["FeynCalc`$LoadPhi"] = False;
     ToExpression["FeynCalc`$LoadTARCER"] = False,
     Null
    ];
   Quiet@Check[
     ToExpression["HighEnergyPhysics`FeynCalc`$LoadFeynArts"] = False;
     ToExpression["HighEnergyPhysics`FeynCalc`$LoadPhi"] = False;
     ToExpression["HighEnergyPhysics`FeynCalc`$LoadTARCER"] = False,
     Null
    ];
   expr = ToExpression["HighEnergyPhysics`FeynCalc`DiracTrace"][
      ToExpression["HighEnergyPhysics`FeynCalc`GA"][Symbol[muLabel]] .
      ToExpression["HighEnergyPhysics`FeynCalc`GA"][Symbol[nuLabel]]
     ];
   reduced = ToExpression["HighEnergyPhysics`FeynCalc`DiracSimplify"][expr];
   metricSyms = {
      ToExpression["HighEnergyPhysics`FeynCalc`MetricTensor"],
      ToExpression["FeynCalc`MetricTensor"],
      MetricTensor
     };
   formatted = reduced /. {
      metricSyms[[1]][a_, b_] :> MetricTensor[a, b],
      metricSyms[[2]][a_, b_] :> MetricTensor[a, b]
     };
   <|
    "Problem" -> "Dirac gamma trace",
    "Inputs" -> <|"MuLabel" -> muLabel, "NuLabel" -> nuLabel|>,
    "Result" -> ToString[formatted, InputForm],
    "Method" -> "FeynCalc"
   |>,
   <|
    "Problem" -> "Dirac gamma trace",
    "Inputs" -> <|"MuLabel" -> muLabel, "NuLabel" -> nuLabel|>,
    "Result" -> "4 * g(" <> muLabel <> "," <> nuLabel <> ")",
    "Method" -> "Analytic Clifford trace (FeynCalc unavailable)"
   |>
  ]
 ];

QuantumTaskSpecifications[] :=
 <|
  "qho-spectrum" -> <|
    "Description" -> "Compute low-lying eigenvalues of the one-dimensional harmonic oscillator using finite elements.",
    "Spec" -> <|
      "n" -> <|"Type" -> "PositiveInteger", "Default" -> 6, "Description" -> "Number of eigenmodes"|>,
      "L" -> <|"Type" -> "PositiveReal", "Default" -> 8., "Description" -> "Half-width of the domain"|>,
      "m" -> <|"Type" -> "PositiveReal", "Default" -> 1., "Description" -> "Particle mass"|>,
      "omega" -> <|"Type" -> "PositiveReal", "Default" -> 1., "Description" -> "Angular frequency"|>,
      "out" -> <|"Type" -> "String", "Default" -> "qho_energies.json", "Description" -> "Optional JSON output path"|>
    |>,
    "Handler" -> QHOEigenvalues
   |>,
  "clebsch-gordan" -> <|
    "Description" -> "Tabulate non-zero Clebsch-Gordan coefficients.",
    "Spec" -> <|
      "j1" -> <|"Type" -> "PositiveReal", "Default" -> 0.5, "Description" -> "First angular momentum"|>,
      "j2" -> <|"Type" -> "PositiveReal", "Default" -> 0.5, "Description" -> "Second angular momentum"|>,
      "J" -> <|"Type" -> "PositiveReal", "Default" -> 1., "Description" -> "Coupled total angular momentum"|>
    |>,
    "Handler" -> ClebschGordanTable
   |>,
  "dirac-trace" -> <|
    "Description" -> "Evaluate DiracTrace[GA[mu] GA[nu]] using FeynCalc when available.",
    "Spec" -> <|
      "muLabel" -> <|"Type" -> "String", "Default" -> "mu", "Description" -> "Symbol label for the first index"|>,
      "nuLabel" -> <|"Type" -> "String", "Default" -> "nu", "Description" -> "Symbol label for the second index"|>
    |>,
    "Handler" -> DiracTraceGammaPair
   |>
 |>;

End[];
EndPackage[];
