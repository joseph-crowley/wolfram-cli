# Simple helpers for running CLI smoke tests and example scripts.

SHELL := /bin/bash
WL := wolframscript

.PHONY: all smoke qofit helmholtz billiards clean

all: smoke

smoke:
	$(WL) -file scripts/smoke_tests.wls

qho:
	$(WL) -file scripts/qho_eigs.wls --n=6 --L=8 --m=1 --omega=1

helmholtz:
	$(WL) -file scripts/helmholtz_square.wls

billiards:
	$(WL) -file scripts/billiard_eigs.wls --m 6 --h 0.03

clean:
	rm -f *.csv *.json *.png *.pdf
