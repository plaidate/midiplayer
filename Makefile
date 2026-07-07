PDC ?= pdc
SIM = ~/Developer/PlaydateSDK/bin/Playdate\ Simulator.app

.PHONY: build smoke run songs clean

songs:
	mkdir -p source/songs
	python3 tools/mkmidi.py source/songs/demo.mid

source/songs/demo.mid:
	$(MAKE) songs

build: source/songs/demo.mid
	rm -rf build/source MidiPlayer.pdx
	mkdir -p build
	cp -R source build/source
	$(PDC) build/source MidiPlayer.pdx

smoke: source/songs/demo.mid
	rm -rf build/smoke MidiPlayer-smoke.pdx smoke-out
	mkdir -p build smoke-out
	cp -R source build/smoke
	printf -- '-- smoke build\nSMOKE_BUILD = true\n' > build/smoke/smokeflag.lua
	$(PDC) build/smoke MidiPlayer-smoke.pdx

run: build
	open MidiPlayer.pdx

clean:
	rm -rf build MidiPlayer.pdx MidiPlayer-smoke.pdx smoke-out
