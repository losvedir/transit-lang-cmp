all: app alt

app:
	mkdir -p units
	fpc -CX -XXs -O3 -FUunits -Fimormot2 -Fumormot2/src -Flmormot2/static/x86_64-linux -Fomormot2/static/x86_64-linux -Fulgenerics app.pas 

alt:
	mkdir -p units
	fpc -CX -XXs -O3 -FUunits -Fimormot2 -Fumormot2/src -Flmormot2/static/x86_64-linux -Fomormot2/static/x86_64-linux alt.pas 

clean:
	rm -r units app alt
