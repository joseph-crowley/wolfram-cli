#!/usr/bin/env wolframscript
(* partition_fn.wls: wrapper around PhysicsCLI Analysis task with file-based spectrum input. *)

scriptDir = DirectoryName[$InputFileName];
projectRoot = ExpandFileName@FileNameJoin[{scriptDir, ".."}];

cliPath = FileNameJoin[{projectRoot, "lib", "PhysicsCLI", "CLI.wl"}];
If[!FileExistsQ[cliPath],
  WriteString[$StandardError, "Missing CLI library at " <> cliPath <> "\n"];
  Exit[1];
];

Get[cliPath];
Needs["PhysicsCLI`Utils`"];

task = PhysicsCLI`CLI`TaskCatalog()["partition-function"];
customSpec = Join[task["Spec"], <|"in" -> <|"Type" -> "String", "Default" -> "qho_energies.json", "Description" -> "JSON spectrum file"|>|>];

parsed = PhysicsCLI`Utils`ParseOptions[customSpec, Rest@$ScriptCommandLine];
If[Length[parsed["Warnings"]] > 0, Scan[PhysicsCLI`Utils`EmitError, parsed["Warnings"]]];
If[Length[parsed["Errors"]] > 0,
  Scan[PhysicsCLI`Utils`EmitError, parsed["Errors"]];
  Exit[1];
];

infile = parsed["Options"]["in"];
energies = Quiet@Check[Import[infile, "JSON"], $Failed];
If[energies === $Failed,
  PhysicsCLI`Utils`EmitError["Failed to read spectrum from " <> infile];
  Exit[1];
];

options = Association[parsed["Options"], "spectrum" -> N[Flatten[{energies}]]];
result = task["Handler"][options];
PhysicsCLI`Utils`EmitJSON[result];
