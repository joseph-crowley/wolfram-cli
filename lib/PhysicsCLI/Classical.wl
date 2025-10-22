baseDir = DirectoryName[$InputFileName];
If[baseDir =!= $Failed && baseDir =!= Null,
  If[!MemberQ[$Path, baseDir], AppendTo[$Path, baseDir]];
  parentDir = FileNameJoin[{baseDir, ".."}];
  If[DirectoryQ[parentDir] && !MemberQ[$Path, parentDir], AppendTo[$Path, parentDir]];
];

BeginPackage["PhysicsCLI`Classical`", {"PhysicsCLI`Utils`"}];

ClassicalTaskSpecifications::usage = "ClassicalTaskSpecifications[] returns an Association describing CLI-accessible classical physics tasks.";
DampedOscillatorResponse::usage = "DampedOscillatorResponse[config] integrates a driven damped oscillator and returns sampled displacement.";
HelmholtzSquareSolution::usage = "HelmholtzSquareSolution[config] solves the Helmholtz equation on the unit square with Dirichlet conditions.";
StadiumBilliardSpectrum::usage = "StadiumBilliardSpectrum[config] computes eigenvalues for a stadium billiard domain.";

Begin["`Private`"];

DampedOscillatorResponse[config_Association] :=
 Module[{gammaVal = config["gamma"], omega0 = config["omega0"], force = config["force"],
   drive = config["drive"], tmax = config["tmax"], samples = config["samples"], outfile = config["out"],
   solution, grid, data},
  solution = Quiet@Check[
     WithTimingPayload[
      "damped-oscillator",
      NDSolveValue[
       {
        x''[t] + 2 gammaVal x'[t] + omega0^2 x[t] == force Cos[drive t],
        x[0] == 0,
        x'[0] == 0
       },
       x, {t, 0, tmax},
       Method -> {"EquationSimplification" -> "Residual"}
      ]
     ],
     $Failed
    ];
  If[solution === $Failed,
   EmitError["Failed to integrate damped oscillator."];
   Return[$Failed];
  ];
  grid = Table[t, {t, 0., tmax, tmax/Max[1, samples - 1]}];
  data = Table[{tval, solution["Result"][tval]}, {tval, grid}];
  <|
   "Problem" -> "Driven damped oscillator",
   "Inputs" -> <|
     "gamma" -> gammaVal,
     "omega0" -> omega0,
     "forceAmplitude" -> force,
     "driveFrequency" -> drive,
     "tmax" -> tmax,
     "samples" -> samples
   |>,
   "TimingSeconds" -> solution["Seconds"],
   "Trajectory" -> data,
   "SuggestedOutputFile" -> outfile
  |>
 ];

HelmholtzSquareSolution[config_Association] :=
 Module[{frequency = config["frequency"], waveSpeed = config["waveSpeed"], meshDensity = config["meshDensity"],
   NeedsResult, region, mesh, solver, payload, solution},
  Needs["NDSolve`FEM`"];
  region = ImplicitRegion[0 <= x <= 1 && 0 <= y <= 1, {x, y}];
  mesh = ToElementMesh[region, MaxCellMeasure -> 1/meshDensity];
  solver := NDSolveValue[
    {
     Laplacian[u[x, y], {x, y}] + (frequency/waveSpeed)^2 u[x, y] == 0,
     DirichletCondition[u[x, y] == Sin[Pi y], x == 0],
     DirichletCondition[u[x, y] == 0, x == 1 || y == 0 || y == 1]
    },
    u, Element[mesh],
    Method -> {"PDEDiscretization" -> {"FiniteElement", "MeshOptions" -> {"MaxCellMeasure" -> 1/meshDensity}}}
   ];
  payload = Quiet@Check[WithTimingPayload["helmholtz-square", solver], $Failed];
  If[payload === $Failed,
   EmitError["Failed to solve Helmholtz square problem."];
   Return[$Failed];
  ];
  solution = payload["Result"];
  <|
   "Problem" -> "Helmholtz on unit square",
   "Inputs" -> <|
     "frequency" -> frequency,
     "waveSpeed" -> waveSpeed,
     "meshDensity" -> meshDensity
   |>,
   "TimingSeconds" -> payload["Seconds"],
   "MeshElementCount" -> mesh["MeshElements"] // Length,
   "SampledField" -> Table[
     {xval, yval, solution[xval, yval]},
     {xval, 0., 1., 0.1},
     {yval, 0., 1., 0.1}
    ]
  |>
 ];

StadiumBilliardSpectrum[config_Association] :=
 Module[{modeCount = config["modes"], meshMax = config["meshMax"], arcRadius = config["radius"],
   region, mesh, eigensystem, payload, eigenvals, eigenfuncs},
  Needs["NDSolve`FEM`"];
  region = RegionUnion[
    Disk[{-0.5, 0}, arcRadius],
    Rectangle[{-0.5, -arcRadius}, {0.5, arcRadius}],
    Disk[{0.5, 0}, arcRadius]
   ];
  mesh = ToElementMesh[region, MaxCellMeasure -> meshMax];
  eigensystem :=
   NDEigensystem[
    {
     -Laplacian[u[x, y], {x, y}],
     DirichletCondition[u[x, y] == 0, True]
    },
    u[x, y], Element[mesh], modeCount,
    Method -> {"Eigensystem" -> {"Arnoldi", "MaxIterations" -> 6000}}
   ];
  payload = Quiet@Check[WithTimingPayload["stadium-billiard", eigensystem], $Failed];
  If[payload === $Failed,
   EmitError["Failed to solve stadium billiard eigenproblem."];
   Return[$Failed];
  ];
  {eigenvals, eigenfuncs} = payload["Result"];
  <|
   "Problem" -> "Stadium billiard spectrum",
   "Inputs" -> <|
     "modes" -> modeCount,
     "meshMax" -> meshMax,
     "radius" -> arcRadius
   |>,
   "TimingSeconds" -> payload["Seconds"],
   "Eigenvalues" -> N[eigenvals, 10],
   "SampledModes" -> Table[
     <|
      "Mode" -> k,
      "Grid" -> Table[
        {xval, yval, eigenfuncs[[k]][xval, yval]},
        {xval, -1.5, 1.5, 0.15},
        {yval, -arcRadius, arcRadius, 0.15}
       ]
     |>,
     {k, 1, Min[3, Length[eigenfuncs]]}
    ]
  |>
 ];

ClassicalTaskSpecifications[] :=
 <|
  "damped-oscillator" -> <|
    "Description" -> "Integrate a driven damped oscillator and return sampled state history.",
    "Spec" -> <|
      "gamma" -> <|"Type" -> "PositiveReal", "Default" -> 0.1, "Description" -> "Damping coefficient"|>,
      "omega0" -> <|"Type" -> "PositiveReal", "Default" -> 1., "Description" -> "Natural frequency"|>,
      "force" -> <|"Type" -> "Real", "Default" -> 1., "Description" -> "Driving force amplitude"|>,
      "drive" -> <|"Type" -> "PositiveReal", "Default" -> 1., "Description" -> "Driving frequency"|>,
      "tmax" -> <|"Type" -> "PositiveReal", "Default" -> 50., "Description" -> "End time"|>,
      "samples" -> <|"Type" -> "PositiveInteger", "Default" -> 2001, "Description" -> "Number of time samples"|>,
      "out" -> <|"Type" -> "String", "Default" -> "oscillator.csv", "Description" -> "Optional CSV output path"|>
    |>,
    "Handler" -> DampedOscillatorResponse
   |>,
  "helmholtz-square" -> <|
    "Description" -> "Solve the Helmholtz equation on the unit square with Dirichlet boundary conditions.",
    "Spec" -> <|
      "frequency" -> <|"Type" -> "PositiveReal", "Default" -> 25., "Description" -> "Angular frequency"|>,
      "waveSpeed" -> <|"Type" -> "PositiveReal", "Default" -> 1., "Description" -> "Wave propagation speed"|>,
      "meshDensity" -> <|"Type" -> "PositiveReal", "Default" -> 300., "Description" -> "Inverse cell size control"|>
    |>,
    "Handler" -> HelmholtzSquareSolution
   |>,
  "stadium-billiard" -> <|
    "Description" -> "Compute Dirichlet eigenvalues in a stadium billiard domain.",
    "Spec" -> <|
      "modes" -> <|"Type" -> "PositiveInteger", "Default" -> 8, "Description" -> "Number of eigenmodes"|>,
      "meshMax" -> <|"Type" -> "PositiveReal", "Default" -> 0.03, "Description" -> "Maximum mesh cell measure"|>,
      "radius" -> <|"Type" -> "PositiveReal", "Default" -> 0.5, "Description" -> "Arc radius"|>
    |>,
    "Handler" -> StadiumBilliardSpectrum
   |>
 |>;

End[];
EndPackage[];
