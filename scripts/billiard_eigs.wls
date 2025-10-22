#!/usr/bin/env wolframscript
(* billiard_eigs.wls: wrapper around PhysicsCLI classical stadium billiard task. *)

scriptDir = DirectoryName[$InputFileName];
projectRoot = ExpandFileName@FileNameJoin[{scriptDir, ".."}];

cliPath = FileNameJoin[{projectRoot, "lib", "PhysicsCLI", "CLI.wl"}];
If[!FileExistsQ[cliPath],
  WriteString[$StandardError, "Missing CLI library at " <> cliPath <> "\n"];
  Exit[1];
];

Get[cliPath];
Needs["PhysicsCLI`Utils`"];

task = PhysicsCLI`CLI`TaskCatalog()["stadium-billiard"];
parsed = PhysicsCLI`Utils`ParseOptions[task["Spec"], Rest@$ScriptCommandLine];
If[Length[parsed["Warnings"]] > 0, Scan[PhysicsCLI`Utils`EmitError, parsed["Warnings"]]];
If[Length[parsed["Errors"]] > 0,
  Scan[PhysicsCLI`Utils`EmitError, parsed["Errors"]];
  Exit[1];
];

result = task["Handler"][parsed["Options"]];
If[result === $Failed, Exit[1]];

Export["stadium_eigs.json", result, "JSON"];
PhysicsCLI`Utils`EmitText["Computed " <> ToString[Length[result["Eigenvalues"]], InputForm] <> " eigenvalues. Stored stadium_eigs.json."];
