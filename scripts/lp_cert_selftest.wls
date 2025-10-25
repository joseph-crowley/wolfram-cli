#!/usr/bin/env wolframscript
(*
  LinearOptimization certification self-test.
  Solves a small LP and emits primal, dual, gap, and residual diagnostics.
*)

SetDirectory[DirectoryName[$InputFileName]];

ClearAll[solveLP];
solveLP[] := Module[{x, y, cons, vars, res, primal, pmin, dmax, dual, gap,
  ineqs, eqs, mu, nu, eqResidual, ineqViolation, compSlack},
  cons = {x + y <= 1, x >= 0, y >= 0};
  vars = {x, y};
  res = LinearOptimization[-x - y, cons, vars,
    {"PrimalMinimizer", "PrimalMinimumValue", "DualMaximumValue",
     "DualMaximizer", "DualityGap"}];
  {primal, pmin, dmax, dual, gap} = res;
  eqs = Select[cons, Head[#] === Equal &];
  ineqs = Select[cons, Or[Head[#] === LessEqual, Head[#] === GreaterEqual] &];
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
  Print[ExportString[
    <|
      "status" -> "ok",
      "primal" -> N[primal],
      "primalMinimum" -> N[pmin],
      "dualMaximum" -> N[dmax],
      "dualityGap" -> N[gap],
      "dualInequality" -> mu,
      "dualEquality" -> nu,
      "kkt" -> <|
        "equalityResidual" -> eqResidual,
        "inequalityViolation" -> ineqViolation,
        "complementarySlackness" -> compSlack
      |>
    |>, "JSON", "Compact" -> True
  ]]
];

solveLP[];

