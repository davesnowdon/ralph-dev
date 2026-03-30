.PHONY: install lint typecheck test check \
       rpp-install rpp-lint rpp-typecheck rpp-test \
       sandbox-lint sandbox-fmt-check sandbox-test

# ── ralph-plus-plus ────────────────────────────────────────
rpp-install:
	$(MAKE) -C ralph-plus-plus install

rpp-lint:
	$(MAKE) -C ralph-plus-plus lint

rpp-typecheck:
	$(MAKE) -C ralph-plus-plus typecheck

rpp-test:
	$(MAKE) -C ralph-plus-plus test

# ── ralph-sandbox ──────────────────────────────────────────
sandbox-lint:
	$(MAKE) -C ralph-sandbox lint

sandbox-fmt-check:
	$(MAKE) -C ralph-sandbox fmt-check

sandbox-test:
	$(MAKE) -C ralph-sandbox test

# ── Unified targets ────────────────────────────────────────
install: rpp-install

lint: rpp-lint sandbox-lint sandbox-fmt-check

typecheck: rpp-typecheck

test: rpp-test sandbox-test

check: lint typecheck test
