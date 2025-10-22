#!/usr/bin/env wolframscript
(* levi_civita_check.wls: compute (a cross b)_i via LeviCivitaTensor components. *)

a = Array[ax, 3];
b = Array[bx, 3];
eps = LeviCivitaTensor[3];
c[i_] := Sum[eps[[i, j, k]] a[[j]] b[[k]], {j, 1, 3}, {k, 1, 3}];
Print[Table[c[i], {i, 1, 3}] // InputForm];
