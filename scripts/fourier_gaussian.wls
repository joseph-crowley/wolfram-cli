#!/usr/bin/env wolframscript
(* fourier_gaussian.wls: wrapper around PhysicsCLI Analysis task. *)

scriptDir = DirectoryName[$InputFileName];
projectRoot = ExpandFileName@FileNameJoin[{scriptDir, ".."}];

cliPath = FileNameJoin[{projectRoot, "lib", "PhysicsCLI", "CLI.wl"}];
If[!FileExistsQ[cliPath],
  WriteString[$StandardError, "Missing CLI library at " <> cliPath <> "\n"];
  Exit[1];
];

Get[cliPath];
Needs["PhysicsCLI`Utils`"];

task = PhysicsCLI`CLI`TaskCatalog()["fourier-gaussian"];
parsed = PhysicsCLI`Utils`ParseOptions[task["Spec"], Rest@$ScriptCommandLine];
If[Length[parsed["Warnings"]] > 0, Scan[PhysicsCLI`Utils`EmitError, parsed["Warnings"]]];
If[Length[parsed["Errors"]] > 0,
  Scan[PhysicsCLI`Utils`EmitError, parsed["Errors"]];
  Exit[1];
];

result = task["Handler"][parsed["Options"]];
PhysicsCLI`Utils`EmitJSON[result];
