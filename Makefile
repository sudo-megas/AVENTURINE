# AVENTURINE — screen colour picker
# Plain make, no autotools, no meson.

PREFIX  ?= /usr
DESTDIR ?=
VALAC   ?= valac

APPID = io.github.sudomegas.aventurine

PKGS  = --pkg gtk4 --pkg gio-2.0 --pkg gdk-pixbuf-2.0
FLAGS = -X -lm -X -O2 -X -w

SRC = $(wildcard src/*.vala) $(wildcard src/source/*.vala)

# The test binary links only the pure-logic units, so it needs no GTK at all.
TEST_SRC = tests/convert-test.vala \
           src/colour.vala src/convert.vala src/contrast.vala \
           src/ramp.vala src/names.vala
TEST_PKGS = --pkg gio-2.0

all: aventurine

aventurine: $(SRC)
	$(VALAC) $(PKGS) $(FLAGS) -o aventurine $(SRC)

run: aventurine
	./aventurine

test: convert-test
	./convert-test

convert-test: $(TEST_SRC)
	$(VALAC) $(TEST_PKGS) $(FLAGS) -o convert-test $(TEST_SRC)

install: aventurine
	install -Dm755 aventurine $(DESTDIR)$(PREFIX)/bin/aventurine
	install -Dm644 data/$(APPID).desktop $(DESTDIR)$(PREFIX)/share/applications/$(APPID).desktop
	install -Dm644 data/$(APPID).svg $(DESTDIR)$(PREFIX)/share/icons/hicolor/scalable/apps/$(APPID).svg
	install -Dm644 data/style.css $(DESTDIR)$(PREFIX)/share/aventurine/style.css
	install -Dm644 LICENSE $(DESTDIR)$(PREFIX)/share/licenses/aventurine/LICENSE

uninstall:
	rm -f $(DESTDIR)$(PREFIX)/bin/aventurine
	rm -f $(DESTDIR)$(PREFIX)/share/applications/$(APPID).desktop
	rm -f $(DESTDIR)$(PREFIX)/share/icons/hicolor/scalable/apps/$(APPID).svg
	rm -f $(DESTDIR)$(PREFIX)/share/aventurine/style.css
	rm -f $(DESTDIR)$(PREFIX)/share/licenses/aventurine/LICENSE
	rmdir --ignore-fail-on-non-empty $(DESTDIR)$(PREFIX)/share/aventurine 2>/dev/null || true
	rmdir --ignore-fail-on-non-empty $(DESTDIR)$(PREFIX)/share/licenses/aventurine 2>/dev/null || true

clean:
	rm -f aventurine convert-test

.PHONY: all run test install uninstall clean
