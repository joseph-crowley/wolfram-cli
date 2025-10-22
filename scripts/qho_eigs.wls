#!/usr/bin/env wolframscript
(* qho_eigs.wls: wrapper around PhysicsCLI Quantum harmonic oscillator task. *)

scriptDir = DirectoryName[$InputFileName];
projectRoot = ExpandFileName@FileNameJoin[{scriptDir, ".."}];

cliPath = FileNameJoin[{projectRoot, "lib", "PhysicsCLI", "CLI.wl"}];
If[!FileExistsQ[cliPath],
  WriteString[$StandardError, "Missing CLI library at " <> cliPath <> "\n"];
  Exit[1];
];

Get[cliPath];
Needs["PhysicsCLI`Utils`"];

task = PhysicsCLI`CLI`TaskCatalog()["qho-spectrum"];
parsed = PhysicsCLI`Utils`ParseOptions[task["Spec"], Rest@$ScriptCommandLine];
If[Length[parsed["Warnings"]] > 0, Scan[PhysicsCLI`Utils`EmitError, parsed["Warnings"]]];
If[Length[parsed["Errors"]] > 0,
  Scan[PhysicsCLI`Utils`EmitError, parsed["Errors"]];
  Exit[1];
];

result = task["Handler"][parsed["Options"]];
If[result === $Failed, Exit[1]];

outfile = Lookup[result, "SuggestedOutputFile", "qho_energies.json"];
Export[outfile, result["Energies"], "JSON"];
PhysicsCLI`Utils`EmitText["wrote " <> outfile];
PhysicsCLI`Utils`EmitText["Preview energies: " <> ToString[Take[result["Energies"], UpTo[6]], InputForm]];
