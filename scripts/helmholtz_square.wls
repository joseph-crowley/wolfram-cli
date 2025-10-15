#!/usr/bin/env wolframscript
(* helmholtz_square.wls: solve Helmholtz equation on the unit square with Dirichlet data. *)

Needs["NDSolve`FEM`"];

Ω = ImplicitRegion[0 <= x <= 1 && 0 <= y <= 1, {x, y}];
mesh = ToElementMesh[Ω, MaxCellMeasure -> 1/300];
ω = 25.;
c = 1.;
k = ω/c;

u = NDSolveValue[
  {
    Laplacian[u[x, y], {x, y}] + k^2 u[x, y] == 0,
    DirichletCondition[u[x, y] == Sin[Pi y], x == 0],
    DirichletCondition[u[x, y] == 0, x == 1 || y == 0 || y == 1]
  },
  u, Element[mesh],
  Method -> {"PDEDiscretization" -> {"FiniteElement", "MeshOptions" -> {"MaxCellMeasure" -> 1/300}}}
];

file = "helmholtz.png";
Export[file,
  DensityPlot[u[x, y], {x, 0, 1}, {y, 0, 1},
    PlotRange -> All,
    ColorFunction -> "AvocadoColors",
    FrameLabel -> {"x", "y"},
    PlotLegends -> Automatic
  ]
];

Print["mesh elements: ", mesh["MeshElements"] // Length // InputForm];
Print["exported ", file];
