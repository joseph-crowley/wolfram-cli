#!/usr/bin/env wolframscript

(* physics_cli.wls: unified Wolfram CLI front-end for graduate physics tasks. *)

root = DirectoryName[$InputFileName];
If[root === $Failed || root === Null,
  root = Directory[];
];

libPath = FileNameJoin[{root, "lib", "PhysicsCLI", "CLI.wl"}];
If[!FileExistsQ[libPath],
  WriteString[$StandardError, "Unable to locate CLI library at " <> libPath <> "\n"];
  Exit[1];
];

Get[libPath];

PhysicsCLI`CLI`RunFromCommandLine[];
