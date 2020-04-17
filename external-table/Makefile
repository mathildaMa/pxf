EXTENSION = pxf
DATA = pxf--1.0.sql
MODULE_big = pxf
OBJS       = src/pxfprotocol.o src/pxfbridge.o src/pxfuriparser.o src/libchurl.o src/pxfutils.o src/pxfheaders.o src/pxffragment.o src/gpdbwritableformatter.o src/pxffilters.o
REGRESS    = setup pxf pxfinvalid

PG_CONFIG = pg_config
PGXS := $(shell $(PG_CONFIG) --pgxs)

ifndef PGXS
    $(error Make sure the Greenplum installation binaries are in your PATH. i.e. export PATH=<path to your greenplum installation>/bin:$$PATH)
endif

include $(PGXS)

SHLIB_LINK += -lcurl
