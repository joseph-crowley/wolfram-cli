#!/usr/bin/env wolframscript
(* smoke_tests.wls: verification suite exercising PhysicsCLI library tasks. *)

root = DirectoryName[$InputFileName];
projectRoot = ExpandFileName@FileNameJoin[{root, ".."}];
cliPath = FileNameJoin[{projectRoot, "lib", "PhysicsCLI", "CLI.wl"}];
If[!FileExistsQ[cliPath],
  WriteString[$StandardError, "Missing CLI library at " <> cliPath <> "\n"];
  Exit[1];
];

Get[cliPath];
Needs["PhysicsCLI`Utils`"];

registry = PhysicsCLI`CLI`TaskCatalog[];

fourierTest := Module[{task, result, expr},
  task = registry["fourier-gaussian"];
  result = task["Handler"][<|"mu" -> 0., "sigma" -> 1., "params" -> {-1., 1.}, "t" -> 0.|>];
  expr = ToExpression[result["Result"]];
  Simplify[expr == Sqrt[2 Pi]]
];

partitionTest := Module[{task, result},
  task = registry["partition-function"];
  result = task["Handler"][<|"beta" -> 1., "spectrum" -> {0., 1., 2.}|>];
  Abs[result["PartitionFunction"] - (1 + E^-1 + E^-2)] < 10^-10
];

qhoTest := Module[{task, result},
  task = registry["qho-spectrum"];
  result = task["Handler"][<|"n" -> 4, "L" -> 8., "m" -> 1., "omega" -> 1., "out" -> "skip.json"|>];
  Abs[result["Energies"][[1]] - 0.5] < 5*10^-4
];

dampedTest := Module[{task, result},
  task = registry["damped-oscillator"];
  result = task["Handler"][<|"gamma" -> 0.1, "omega0" -> 1., "force" -> 1., "drive" -> 1., "tmax" -> 10., "samples" -> 101, "out" -> "skip.csv"|>];
  Length[result["Trajectory"]] == 101
];

tests = {
  VerificationTest[fourierTest, True, TestID -> "fourier-gaussian"],
  VerificationTest[partitionTest, True, TestID -> "partition-function"],
  VerificationTest[qhoTest, True, TestID -> "qho-spectrum"],
  VerificationTest[dampedTest, True, TestID -> "damped-oscillator"]
};

report = TestReport[tests];
failureList = report["FailureTests"];
If[MatchQ[failureList, Missing[__]], failureList = {}];
failures = Length[failureList];
Scan[
  Function[test,
    Print["FAIL ", test["TestID"], " expected=", test["ExpectedOutput"], " got=", test["ActualOutput"]]
  ],
  failureList
];
Print["tests run=", Length[tests], " failures=", failures];
Exit[If[failures == 0, 0, 1]];
