# Common two-stage CMotive self-host build.
# Platform Makefiles define CC, CFLAGS, EXEEXT and SELFHOST_LIBS first.

BUILD_DIR ?= build
BIN_DIR ?= $(BUILD_DIR)/bin
EXEEXT ?=
PREFIX ?= /usr/local
LDFLAGS ?=
SELFHOST_LIBS ?= -pthread -lm

BOOTSTRAP_SRC := bootstrap/c/cmotive_bootstrap.c
FRONTEND_SRC := src/frontend/selfhost/CMotiveFrontend.CMOT
FRONTEND_SUPPORT := src/frontend/selfhost/cmotive_frontend_support.h
CONVERTER_SRC := src/tools/CToCMotive.CMOT
CONVERTER_SUPPORT := src/tools/c2cmotive_support.h

BOOTSTRAP_DIR := $(BUILD_DIR)/bootstrap
STAGE1_DIR := $(BUILD_DIR)/stage1
SELFHOST_DIR := $(BUILD_DIR)/selfhost
STAGE0 := $(BOOTSTRAP_DIR)/cmotive-stage0$(EXEEXT)
STAGE1_C := $(SELFHOST_DIR)/CMotiveFrontend.stage1.c
STAGE1 := $(STAGE1_DIR)/cmotive$(EXEEXT)
STAGE1_PP := $(STAGE1_DIR)/cmotivepp$(EXEEXT)
STAGE2_C := $(SELFHOST_DIR)/CMotiveFrontend.stage2.c
STAGE3_C := $(SELFHOST_DIR)/CMotiveFrontend.stage3.c
CMOTIVE := $(BIN_DIR)/cmotive$(EXEEXT)
CMOTIVEPP := $(BIN_DIR)/cmotivepp$(EXEEXT)
CMOTIVEPLUS := $(BIN_DIR)/cmotive++$(EXEEXT)
CMOTIVESYMS := $(BIN_DIR)/CMotiveSymsToDebugFile$(EXEEXT)
CONVERTER_C := $(SELFHOST_DIR)/CToCMotive.c
C2CMOTIVE := $(BIN_DIR)/c2cmotive$(EXEEXT)
TOOL_BINS := $(CMOTIVE) $(CMOTIVEPP) $(CMOTIVEPLUS) $(CMOTIVESYMS) $(C2CMOTIVE)

.PHONY: all bootstrap stage1 clean install test full-test selfhost-check \
        converter-test examples language verify-all package

all: $(TOOL_BINS)

bootstrap: $(STAGE0)
stage1: $(STAGE1) $(STAGE1_PP)

$(BOOTSTRAP_DIR) $(STAGE1_DIR) $(SELFHOST_DIR) $(BIN_DIR):
	mkdir -p $@

$(STAGE0): $(BOOTSTRAP_SRC) | $(BOOTSTRAP_DIR)
	$(CC) $(CFLAGS) -o $@ $(BOOTSTRAP_SRC) $(LDFLAGS)

$(STAGE1_C): $(STAGE0) $(FRONTEND_SRC) $(FRONTEND_SUPPORT) | $(SELFHOST_DIR)
	CMOTIVE_CC="$(CC)" $(STAGE0) --emit-c $(FRONTEND_SRC) -o $@

$(STAGE1): $(STAGE1_C) $(FRONTEND_SUPPORT) | $(STAGE1_DIR)
	$(CC) $(CFLAGS) -I. -Ilib/Sys -o $@ $(STAGE1_C) $(LDFLAGS) $(SELFHOST_LIBS)

$(STAGE1_PP): $(STAGE1) | $(STAGE1_DIR)
	cp $(STAGE1) $@
	chmod +x $@ 2>/dev/null || true

$(STAGE2_C): $(STAGE1) $(FRONTEND_SRC) $(FRONTEND_SUPPORT) | $(SELFHOST_DIR)
	CMOTIVE_CC="$(CC)" $(STAGE1) --emit-c $(FRONTEND_SRC) -o $@

$(CMOTIVE): $(STAGE2_C) $(FRONTEND_SUPPORT) | $(BIN_DIR)
	$(CC) $(CFLAGS) -I. -Ilib/Sys -o $@ $(STAGE2_C) $(LDFLAGS) $(SELFHOST_LIBS)

$(CMOTIVEPP): $(CMOTIVE) | $(BIN_DIR)
	cp $(CMOTIVE) $@
	chmod +x $@ 2>/dev/null || true

$(CMOTIVEPLUS): $(CMOTIVE) | $(BIN_DIR)
	cp $(CMOTIVE) $@
	chmod +x $@ 2>/dev/null || true

$(CMOTIVESYMS): $(CMOTIVE) | $(BIN_DIR)
	cp $(CMOTIVE) $@
	chmod +x $@ 2>/dev/null || true

$(CONVERTER_C): $(CMOTIVE) $(CONVERTER_SRC) $(CONVERTER_SUPPORT) | $(SELFHOST_DIR)
	CMOTIVE_CC="$(CC)" $(CMOTIVE) --emit-c $(CONVERTER_SRC) -o $@

$(C2CMOTIVE): $(CONVERTER_C) $(CONVERTER_SUPPORT) | $(BIN_DIR)
	$(CC) $(CFLAGS) -I. -Ilib/Sys -o $@ $(CONVERTER_C) $(LDFLAGS) $(SELFHOST_LIBS)

$(STAGE3_C): $(CMOTIVE) $(FRONTEND_SRC) $(FRONTEND_SUPPORT) | $(SELFHOST_DIR)
	CMOTIVE_CC="$(CC)" $(CMOTIVE) --emit-c $(FRONTEND_SRC) -o $@

selfhost-check: all $(STAGE1_PP) $(STAGE3_C)
	cmp $(STAGE1_C) $(STAGE2_C)
	cmp $(STAGE2_C) $(STAGE3_C)
	sh scripts/verify_selfhost.sh $(STAGE1_DIR) $(BIN_DIR) "$(EXEEXT)"

converter-test: all
	sh scripts/run_converter_tests.sh $(BIN_DIR) "$(EXEEXT)"

test: all selfhost-check
	sh scripts/run_tests.sh $(BIN_DIR) "$(EXEEXT)"
	sh scripts/run_converter_tests.sh $(BIN_DIR) "$(EXEEXT)"

full-test: all selfhost-check
	sh scripts/run_tests.sh $(BIN_DIR) "$(EXEEXT)" --full
	sh scripts/run_converter_tests.sh $(BIN_DIR) "$(EXEEXT)"

examples: all
	sh scripts/run_examples.sh $(BIN_DIR) "$(EXEEXT)"

language: all
	sh scripts/validate_language_files.sh $(BIN_DIR) "$(EXEEXT)"

verify-all: full-test examples language

package: all
	sh scripts/package_release.sh --root . --out dist

install: all
	mkdir -p $(DESTDIR)$(PREFIX)/bin
	cp $(CMOTIVE) $(DESTDIR)$(PREFIX)/bin/cmotive$(EXEEXT)
	cp $(CMOTIVEPP) $(DESTDIR)$(PREFIX)/bin/cmotivepp$(EXEEXT)
	cp $(CMOTIVEPLUS) $(DESTDIR)$(PREFIX)/bin/cmotive++$(EXEEXT)
	cp $(CMOTIVESYMS) $(DESTDIR)$(PREFIX)/bin/CMotiveSymsToDebugFile$(EXEEXT)
	cp $(C2CMOTIVE) $(DESTDIR)$(PREFIX)/bin/c2cmotive$(EXEEXT)

clean:
	rm -rf $(BUILD_DIR) dist
