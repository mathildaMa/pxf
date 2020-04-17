# set the concourse target default to dev
CONCOURSE ?= ud

# set the pxf-protocol-extension default branch to current branch
BRANCH ?= $(shell git rev-parse --abbrev-ref HEAD)

BUILD_PIPELINE_NAME        = pxf-protocol-extension-build_6X_STABLE
BC_PIPELINE_NAME           = pxf-protocol-extension-BC_6X_STABLE
PIVNET_PIPELINE_NAME       = pivnet_artifacts
FLY_CMD                    = /usr/local/bin/fly
FLY_OPTION_NON-INTERACTIVE =

.PHONY: set-build
set-build: set-build-pipeline

.PHONY: set-build-pipeline
set-build-pipeline:
	$(FLY_CMD) --target=$(CONCOURSE) \
		set-pipeline \
		--check-creds \
		--pipeline=$(BUILD_PIPELINE_NAME) \
		--config=pipelines/build_pipeline.yml \
		--load-vars-from=$(HOME)/workspace/gp-continuous-integration/secrets/gpdb-6X_STABLE-release-secrets.prod.yml \
		--load-vars-from=$(HOME)/workspace/gp-continuous-integration/secrets/gpdb_common-ci-secrets.yml \
		--var=pxf-protocol-extension-git-branch=6X_STABLE_pipeline \
		--var=pxf-protocol-extension-git-remote=https://github.com/greenplum-db/pxf-protocol-extension \
		--var=folder-prefix=prod/gpdb_branch \
		--var=gpdb-branch=6X_STABLE \
		${FLY_OPTION_NON-INTERACTIVE}

	@echo using the following command to unpause the pipeline:
	@echo "\t$(FLY_CMD) -t ${CONCOURSE} unpause-pipeline --pipeline ${BUILD_PIPELINE_NAME}"

.PHONY: set-BC
set-BC: set-BC-pipeline

.PHONY: set-BC-pipeline
set-BC-pipeline:
	$(FLY_CMD) --target=$(CONCOURSE) \
		set-pipeline \
		--check-creds \
		--pipeline=$(BC_PIPELINE_NAME) \
		--config=pipelines/pxf-protocol-extension_pipeline.yml \
		--load-vars-from=$(HOME)/workspace/gp-continuous-integration/secrets/gpdb-6X_STABLE-release-secrets.prod.yml \
		--load-vars-from=$(HOME)/workspace/gp-continuous-integration/secrets/gpdb_common-ci-secrets.yml \
		--var=pxf-protocol-extension-git-branch=6X_STABLE_pipeline \
		--var=pxf-protocol-extension-git-remote=https://github.com/greenplum-db/pxf-protocol-extension \
		--var=pxf-git-branch=fix_pgregress_external_table \
		--var=pxf-git-remote=https://github.com/greenplum-db/pxf \
		--var=folder-prefix=prod/gpdb_branch \
		--var=gpdb-branch=6X_STABLE \
		${FLY_OPTION_NON-INTERACTIVE}

	@echo using the following command to unpause the pipeline:
	@echo "\t$(FLY_CMD) -t ${CONCOURSE} unpause-pipeline --pipeline ${BC_PIPELINE_NAME}"

.PHONY: set-pivnet
set-pivnet: set-pivnet-pipeline

.PHONY: set-pivnet-pipeline
set-pivnet-pipeline:
	$(FLY_CMD) --target=$(CONCOURSE) \
		set-pipeline \
		--check-creds \
		--pipeline=$(PIVNET_PIPELINE_NAME) \
		--config=pipelines/get_pivnet_artifacts.yml \
		--load-vars-from=$(HOME)/workspace/gp-continuous-integration/secrets/gpdb-6X_STABLE-release-secrets.prod.yml \
		--load-vars-from=$(HOME)/workspace/gp-continuous-integration/secrets/gpdb_common-ci-secrets.yml \
		--var=pxf-protocol-extension-git-branch=6X_STABLE_pipeline \
		--var=pxf-protocol-extension-git-remote=https://github.com/greenplum-db/pxf-protocol-extension \
		${FLY_OPTION_NON-INTERACTIVE}

	@echo using the following command to unpause the pipeline:
	@echo "\t$(FLY_CMD) -t ${CONCOURSE} unpause-pipeline --pipeline ${PIVNET_PIPELINE_NAME}"

## ----------------------------------------------------------------------
## List explicit rules
## ----------------------------------------------------------------------

.PHONY: list
list:
	@sh -c "$(MAKE) -p no_targets__ 2>/dev/null | \
	awk -F':' '/^[a-zA-Z0-9][^\$$#\/\\t=]*:([^=]|$$)/ {split(\$$1,A,/ /);for(i in A)print A[i]}' | \
	grep -v Makefile | \
	grep -v '%' | \
	grep -v '__\$$' | \
	sort"

## ----------------------------------------------------------------------
## Lint targets
## ----------------------------------------------------------------------
.PHONY: check
check:
	$(MAKE) lint

.PHONY: lint
lint:
	$(MAKE) shfmt shellcheck yamllint

.PHONY: shfmt
shfmt:
	docker run --rm -v ${CURDIR}:/code mvdan/shfmt:v2.6.4 -d /code

.PHONY: shellcheck
shellcheck:
	docker run --rm -v ${CURDIR}:/code mvdan/shfmt:v2.6.4 -f /code | xargs docker run --rm -v ${CURDIR}:/code koalaman/shellcheck:v0.7.0 -e SC1090,SC1091

.PHONY: yamllint
yamllint:
	docker run --rm -v ${CURDIR}:/code cytopia/yamllint /code -c /code/.yamllint
