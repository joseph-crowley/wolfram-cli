# Simple helpers for running CLI smoke tests and example scripts.

SHELL := /bin/bash
WL := wolframscript

.PHONY: all smoke qho helmholtz billiards fourier partition physics clean

all: smoke

smoke:
	$(WL) -file scripts/smoke_tests.wls

qho:
	$(WL) -file scripts/qho_eigs.wls --n=6 --L=8 --m=1 --omega=1

helmholtz:
	$(WL) -file scripts/helmholtz_square.wls

billiards:
	$(WL) -file scripts/billiard_eigs.wls --modes=6 --meshMax=0.03

fourier:
	$(WL) -file physics_cli.wls --task=fourier-gaussian --mu=0 --sigma=1 --params='[-1,1]' --t=0

partition:
	$(WL) -file physics_cli.wls --task=partition-function --beta=1 --spectrum='[0.5,1.5,2.5]'

physics:
	$(WL) -file physics_cli.wls --task=qho-spectrum --n=4 --L=8 --m=1 --omega=1

clean:
	rm -f *.csv *.json *.png *.pdf
