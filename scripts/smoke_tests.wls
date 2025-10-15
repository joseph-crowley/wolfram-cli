#!/usr/bin/env wolframscript
(* smoke_tests.wls: quick verification tests for CLI workflows. Exits non-zero on failure. *)

tests = {
  VerificationTest[Integrate[Sin[x], {x, 0, Pi}], 2],
  VerificationTest[Residue[(z^2 + 1)/(z - I)^3, {z, I}], 1]
};

results = tests /. TestResultObject[assoc_] :> assoc;
failures = Count[Lookup[results, "Outcome", "Failure"], "Failure"];
Print["tests run=", Length[tests], " failures=", failures];
Exit[If[failures == 0, 0, 1]];
