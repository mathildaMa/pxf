ifndef PXF_CONF
$(error PXF_CONF is not defined)
endif

REGRESS_OPTS = --init-file=./init_file

SUBSTITUTE_COMMAND = scripts/substitute.bash

PG_CONFIG = pg_config
PGXS := $(shell $(PG_CONFIG) --pgxs)
include $(PGXS)

ifdef PXF_TEST_DEBUG
SUBSTITUTE_COMMAND += --debug
REGRESS_OPTS += --debug
endif

setup_test_dir :
	mkdir -p /tmp/pxf_automation_data

setup_script_dir :
	mkdir -p scripts/generated

setup_dirs: setup_test_dir setup_script_dir

fdw_%_schedule : setup_dirs
	$(SUBSTITUTE_COMMAND) schedules/$@
	$(pg_regress_installcheck) $(REGRESS_OPTS) --load-extension=pxf_fdw --schedule=schedules/$@

%_schedule : setup_dirs
	$(SUBSTITUTE_COMMAND) schedules/$@
	$(pg_regress_installcheck) $(REGRESS_OPTS) --load-extension=pxf --schedule=schedules/$@

FDW_%Test : setup_dirs
	$(SUBSTITUTE_COMMAND) $@
	$(pg_regress_installcheck) $(REGRESS_OPTS) --load-extension=pxf_fdw _$@

%Test : setup_dirs
	$(SUBSTITUTE_COMMAND) $@
	$(pg_regress_installcheck) $(REGRESS_OPTS) --load-extension=pxf _$@

clean :
	rm -rf /tmp/pxf_automation_data
	rm -rf sql/_*.sql expected/_*.out results/*
	if ls scripts/generated/*.bash; then \
		for script in scripts/generated/*bash; do \
			"$${script}"; \
		done; \
	fi
	if ls scripts/generated/*cleanup*.sql; then \
		for script in scripts/generated/*cleanup*sql; do \
			$(BEELINE_CMD) -f "$${script}"; \
		done; \
	fi
	if ls scripts/generated/*drop*.rb; then \
		for script in scripts/generated/*drop*.rb; do \
			$(HBASE_CMD) shell "$${PWD}/$${script}"; \
		done; \
	fi
	rm -rf scripts/generated/*
