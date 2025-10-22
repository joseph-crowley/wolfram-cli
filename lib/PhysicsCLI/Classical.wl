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

solveHelmholtzFiniteDifference[frequency_, waveSpeed_, meshDensity_] :=
 Module[{pointsPerDim, nx, ny, hx, hy, k, interiorCount, idx, rhsVec, yCoord, leftBoundary, coeffX, coeffY,
   centerCoeff, matrixRules = {}, row, solveTime, solutionVec, grid, sampleStep = 0.1, sample, residuals},
  pointsPerDim = Max[Round[meshDensity/10], 25];
  nx = pointsPerDim + 2;
  ny = pointsPerDim + 2;
  hx = 1./(nx - 1);
  hy = 1./(ny - 1);
  k = frequency/waveSpeed;
  interiorCount = pointsPerDim^2;
  idx[i_, j_] := (j - 2)*pointsPerDim + (i - 1);
  rhsVec = ConstantArray[0., interiorCount];
  yCoord[j_] := (j - 1)*hy;
  leftBoundary[j_] := Sin[Pi*yCoord[j]];
  coeffX = 1./hx^2;
  coeffY = 1./hy^2;
  centerCoeff = -2.*coeffX - 2.*coeffY + k^2;
  Do[
   row = idx[i, j];
   matrixRules = Append[matrixRules, {row, row} -> centerCoeff];
   If[i + 1 <= nx - 1,
    matrixRules = Append[matrixRules, {row, idx[i + 1, j]} -> coeffX]];
   If[i - 1 >= 2,
    matrixRules = Append[matrixRules, {row, idx[i - 1, j]} -> coeffX],
    rhsVec[[row]] -= coeffX*leftBoundary[j]
    ];
   If[j + 1 <= ny - 1,
    matrixRules = Append[matrixRules, {row, idx[i, j + 1]} -> coeffY]];
   If[j - 1 >= 2,
    matrixRules = Append[matrixRules, {row, idx[i, j - 1]} -> coeffY]];
   ,
   {j, 2, ny - 1}, {i, 2, nx - 1}
   ];
  {solveTime, solutionVec} = AbsoluteTiming[
    LinearSolve[
      SparseArray[matrixRules, {interiorCount, interiorCount}],
      rhsVec
     ]
    ];
  grid = ConstantArray[0., {nx, ny}];
  Do[grid[[1, j]] = leftBoundary[j], {j, 1, ny}];
  Do[
   grid[[i, j]] = solutionVec[[idx[i, j]]],
   {j, 2, ny - 1}, {i, 2, nx - 1}
   ];
  sample = Table[
    With[{xVal = x, yVal = y,
      xi = Clip[1 + Round[x*(nx - 1)], {1, nx}],
      yi = Clip[1 + Round[y*(ny - 1)], {1, ny}]},
     {xVal, yVal, grid[[xi, yi]]}
     ],
    {x, 0., 1., sampleStep}, {y, 0., 1., sampleStep}
    ];
  residuals = Flatten@Table[
     ((grid[[i + 1, j]] - 2 grid[[i, j]] + grid[[i - 1, j]])/hx^2 +
       (grid[[i, j + 1]] - 2 grid[[i, j]] + grid[[i, j - 1]])/hy^2 +
       k^2 grid[[i, j]]),
     {i, 2, nx - 1}, {j, 2, ny - 1}
     ];
  <|
   "Grid" -> grid,
   "SampledField" -> sample,
   "PointsPerAxis" -> pointsPerDim,
   "SolveSeconds" -> solveTime,
   "ResidualRMS" -> Sqrt[Mean[residuals^2]],
  "ResidualMax" -> Max[Abs[residuals]],
   "Residuals" -> residuals
  |>
 ];

HelmholtzSquareSolution[config_Association] :=
 Module[{frequency = config["frequency"], waveSpeed = config["waveSpeed"], meshDensity = config["meshDensity"],
   result},
  result = solveHelmholtzFiniteDifference[frequency, waveSpeed, meshDensity];
  <|
   "Problem" -> "Helmholtz on unit square",
   "Inputs" -> <|
     "frequency" -> frequency,
     "waveSpeed" -> waveSpeed,
     "meshDensity" -> meshDensity,
     "GridPointsPerAxis" -> result["PointsPerAxis"]
   |>,
   "TimingSeconds" -> result["SolveSeconds"],
   "ResidualRMS" -> result["ResidualRMS"],
   "ResidualMax" -> result["ResidualMax"],
   "SampledField" -> result["SampledField"]
  |>
 ];

HelmholtzSquareSweep[config_Association] :=
 Module[{frequency = config["frequency"], waveSpeed = config["waveSpeed"], densities = config["densities"],
   results},
  results = Table[
    Module[{sol = solveHelmholtzFiniteDifference[frequency, waveSpeed, density]},
     <|
       "meshDensity" -> density,
       "GridPointsPerAxis" -> sol["PointsPerAxis"],
       "SolveSeconds" -> sol["SolveSeconds"],
       "ResidualRMS" -> sol["ResidualRMS"],
       "ResidualMax" -> sol["ResidualMax"]
     |>
    ],
    {density, densities}
    ];
  <|
   "Problem" -> "Helmholtz mesh-density sweep",
   "Inputs" -> <|
     "frequency" -> frequency,
     "waveSpeed" -> waveSpeed
   |>,
   "Results" -> results
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
  "helmholtz-sweep" -> <|
    "Description" -> "Evaluate Helmholtz residuals across multiple mesh densities.",
    "Spec" -> <|
      "frequency" -> <|"Type" -> "PositiveReal", "Default" -> 25., "Description" -> "Angular frequency"|>,
      "waveSpeed" -> <|"Type" -> "PositiveReal", "Default" -> 1., "Description" -> "Wave propagation speed"|>,
      "densities" -> <|"Type" -> "RealVector", "Required" -> True, "Description" -> "JSON array of mesh density targets"|>
    |>,
    "Handler" -> HelmholtzSquareSweep
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
