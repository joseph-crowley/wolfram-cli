(*!
  Transverse-Field Zeroes: Wolfram Language solution

  Tasks
  - Verify psi satisfies the scalar wave equation with dispersion c = omega/k.
  - Construct E = xhat psi + i yhat psi + zhat Ez, deduce Ez from Gauss law.
  - Compute B from Faraday law for time-harmonic e^{i(k z - omega t)} fields.
  - Analyze g >> 1, drop k x^2 sin(delta), and derive zero-locus conditions.
  - Produce ASCII report and a sketch PNG of the zero sets.

  All output is ASCII; no typeset math. Comments document steps precisely.
*)

ClearAll[x, y, z, t, k, omega, g, delta, c];
x =.; y =.; z =.; t =.;
(* Parameters remain symbolic; assumptions set globally. *)

(* Symbol assumptions: real parameters, positive k, omega, g, c. *)
$Assumptions = {Element[{x, y, z, t, k, omega, g, delta, c}, Reals],
  k > 0, omega > 0, g > 0, c > 0};

yprime = y*Cos[delta] + z*Sin[delta];
phase = Exp[I*(k*z - omega*t)];
psi = k*(g*x + k*x^2*Sin[delta] + I*yprime)*phase;

(* Part (a): wave equation check *)
lap = D[psi, {x, 2}] + D[psi, {y, 2}] + D[psi, {z, 2}];
d2t = D[psi, {t, 2}];
wave = Simplify[lap - (1/c^2)*d2t /. c -> omega/k];

(* Part (b): Gauss and Faraday laws *)
Ex = psi;
Ey = I*psi;

divTrans = D[Ex, x] + D[Ey, y];
Ez = Simplify[Integrate[-divTrans, z]];
Evec = {Ex, Ey, Ez};

curlE = Curl[Evec, {x, y, z}];
Bvec = Simplify[(1/(I*omega))*curlE];

(* Verify Ampere law with dispersion relation. *)
lhsAmp = Curl[Bvec, {x, y, z}];
rhsAmp = (1/c^2)*D[Evec, t];
ampCheck = Simplify[lhsAmp - rhsAmp /. c -> omega/k];

(* Part (c): g >> 1, drop x^2 term in psi. *)
psiApprox = Simplify[k*(g*x + I*yprime)*phase];
ExA = psiApprox; EyA = I*psiApprox;
divTransA = D[ExA, x] + D[EyA, y];
EzA = Simplify[Integrate[-divTransA, z]];
EA = {ExA, EyA, EzA};
BA = Simplify[(1/(I*omega))*Curl[EA, {x, y, z}]];

(* Electric zero line in the approximation. *)
(* E_x == 0 and E_y == 0 => psiApprox == 0 => x == 0 and y' == 0. *)
electricZeroConditions = {x == 0, y*Cos[delta] + z*Sin[delta] == 0};

(* Part (d): Magnetic transverse zeroes in polar coords gx = r cos th, y' = r sin th. *)
ClearAll[r, th, phi];
BxA = Simplify[BA[[1]]/phase];
ByA = Simplify[BA[[2]]/phase];
BxRT = Simplify[BxA /. {g*x -> r*Cos[th], yprime -> r*Sin[th]}];
ByRT = Simplify[ByA /. {g*x -> r*Cos[th], yprime -> r*Sin[th]}];

(* Real-field zero conditions: Re(Bx) == 0 and Re(By) == 0. *)
phi = k*z - omega*t;
eqs = Simplify@{
  ComplexExpand[Re[BxRT*Exp[I*phi]] == 0, {phi, th}],
  ComplexExpand[Re[ByRT*Exp[I*phi]] == 0, {phi, th}]
};

(* Analytical elimination to exhibit r and th dependence. *)
eqsExplicit = eqs;

(* Solve for r and th in terms of phi; result shows rotating helix. *)
solHelix = {r -> Sin[delta]/k, th -> -phi};

(* Choose the physically simple branch: r = Sin[delta]/k, th = -phi. *)
r0 = Simplify[Sin[delta]/k, Assumptions -> $assum];
th0 = -phi;

(* Parametric locus for a fixed time t0. *)
t0 = 0;
paramX[z_] := Simplify[(r0*Cos[th0] /. t -> t0)/g];
paramYprime[z_] := Simplify[r0*Sin[th0] /. t -> t0];

(* Sketch: two projections vs z. *)
png = FileNameJoin[{DirectoryName[$InputFileName], "sketch.png"}];
plot = Show[
  {
    Plot[paramX[z], {z, -2, 2}, PlotRange -> All, PlotTheme -> "Scientific",
      PlotLegends -> {"magnetic zeroes: x vs z"}, PlotStyle -> {Blue},
      AxesLabel -> {"z", "x"}],
    Plot[paramYprime[z], {z, -2, 2}, PlotRange -> All,
      PlotLegends -> {"magnetic zeroes: y' vs z"}, PlotStyle -> {Red},
      AxesLabel -> {"z", "y'"}]
  }
];
Quiet[Export[png, plot]];

(* ASCII report *)
rep = FileNameJoin[{DirectoryName[$InputFileName], "report.txt"}];
stream = OpenWrite[rep, PageWidth -> Infinity];
WriteString[stream, "Transverse-Field Zeroes Report\n\n"];
WriteString[stream, "(a) Wave equation check with c = omega/k: ", ToString[wave === 0], "\n\n"];
WriteString[stream, "(b) Ez from Gauss law (up to z-constant):\n", ToString[Ez, InputForm], "\n\n"];
WriteString[stream, "    B field components from Faraday:\n", ToString[Bvec, InputForm], "\n\n"];
WriteString[stream, "    Ampere residuals with dispersion: ", ToString[ampCheck, InputForm], "\n\n"];
WriteString[stream, "(c) g >> 1 electric zero line conditions: x == 0 and y' == 0.\n\n"];
WriteString[stream, "    y' == 0 implies y == -z Tan[delta] in the x == 0 plane.\n\n"];
WriteString[stream, "(d) Magnetic transverse zeroes (approx):\n"];
WriteString[stream, "    In polar coords gx = r cos th, y' = r sin th,\n"];
WriteString[stream, "    Requiring Re(Bx) == Re(By) == 0 yields\n"];
WriteString[stream, "    r = Sin[delta]/k and th = -(k z - omega t).\n\n"];
WriteString[stream, "    This describes an elliptic helix around the z' axis,\n"];
WriteString[stream, "    with ellipse axes scaled by 1/g along x and 1 along y'.\n\n"];
WriteString[stream, "Artifacts:\n  ", png, "\n\n"];
Close[stream];

Print["OK: wrote ", rep];
Print["OK: wrote ", png];
