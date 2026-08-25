# AVENTURINE — screen colour picker
# Plain make, no autotools, no meson.

PREFIX  ?= /usr
DESTDIR ?=
VALAC   ?= valac

APPID = io.github.sudomegas.aventurine

PKGS  = --pkg gtk4 --pkg gio-2.0 --pkg gdk-pixbuf-2.0 --pkg posix
FLAGS = -X -lm -X -O2 -X -w

SRC = $(wildcard src/*.vala) $(wildcard src/source/*.vala)

# The test binary links the units that can be exercised without a display.
# export.vala pulls in GTK for its file dialog, but the formatting functions
# the tests call never touch it and gtk_init is never reached.
TEST_SRC = tests/convert-test.vala \
           src/colour.vala src/convert.vala src/contrast.vala \
           src/ramp.vala src/names.vala src/history.vala src/export.vala
TEST_PKGS = --pkg gtk4 --pkg gio-2.0 --pkg posix

# The portal backend is pure GIO, so it can be tested headlessly against a mock
# portal on a private session bus. No display and no desktop are involved.
PORTAL_SRC = tests/portal-test.vala \
             src/colour.vala src/convert.vala src/names.vala \
             src/source/colour-source.vala src/source/portal-source.vala
PORTAL_PKGS = --pkg gio-2.0

all: aventurine

aventurine: $(SRC)
	$(VALAC) $(PKGS) $(FLAGS) -o aventurine $(SRC)

run: aventurine
	./aventurine

test: convert-test
	./convert-test

convert-test: $(TEST_SRC)
	$(VALAC) $(TEST_PKGS) $(FLAGS) -o convert-test $(TEST_SRC)

mock-portal: tests/mock-portal.vala
	$(VALAC) --pkg gio-2.0 $(FLAGS) -o mock-portal tests/mock-portal.vala

portal-test: $(PORTAL_SRC)
	$(VALAC) $(PORTAL_PKGS) $(FLAGS) -o portal-test $(PORTAL_SRC)

# Needs dbus-run-session and gdbus, both from the dbus package.
test-portal: mock-portal portal-test
	@sh tests/run-portal-test.sh

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
	rm -f aventurine convert-test mock-portal portal-test

.PHONY: all run test test-portal install uninstall clean
