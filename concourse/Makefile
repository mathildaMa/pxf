# set the concourse target default to dev
CONCOURSE ?= ud

# set the pxf-protocol-extension default branch to current branch
BRANCH ?= $(shell git rev-parse --abbrev-ref HEAD)

BUILD_PIPELINE_NAME        = pxf-build-GP6
BC_5X_PIPELINE_NAME        = pgregress_external_table_5X_STABLE
BC_6X_PIPELINE_NAME        = pgregress_external_table_6X_STABLE
PIVNET_PIPELINE_NAME       = pivnet_artifacts
NUM_GPDB5_VERSIONS        ?= 11
NUM_GPDB6_VERSIONS        ?=  9
FLY_CMD                    = fly
DEPLOY_CMD                 = ./deploy
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
		--var=pxf-git-branch=${BRANCH} \
		--var=folder-prefix=prod/gpdb_branch \
		--var=gpdb-branch=6X_STABLE \
		${FLY_OPTION_NON-INTERACTIVE}

	@echo using the following command to unpause the pipeline:
	@echo "\t$(FLY_CMD) -t ${CONCOURSE} unpause-pipeline --pipeline ${BUILD_PIPELINE_NAME}"

.PHONY: set-BC-5X
set-BC-5X: set-BC-5X-pipeline

.PHONY: set-BC-5X-pipeline
set-BC-5X-pipeline:
	@$(DEPLOY_CMD) --output /tmp/pgregress_5x_generated.yml \
	--num_gpdb5_versions 11 \
	--pipeline_name $(BC_5X_PIPELINE_NAME) \
	--template external-table-tpl.yml dev 5x

	@echo using the following command to unpause the pipeline:
	@echo "\t$(FLY_CMD) -t ${CONCOURSE} unpause-pipeline --pipeline ${BC_5X_PIPELINE_NAME}"

.PHONY: set-BC-6X
set-BC-6X: set-BC-6X-pipeline

.PHONY: set-BC-6X-pipeline
set-BC-6X-pipeline:
	@$(DEPLOY_CMD) --output /tmp/pgregress_6x_generated.yml \
	--num_gpdb6_versions 9 \
	--pipeline_name $(BC_6X_PIPELINE_NAME) \
	--template external-table-tpl.yml dev 6x

	@echo using the following command to unpause the pipeline:
	@echo "\t$(FLY_CMD) -t ${CONCOURSE} unpause-pipeline --pipeline ${BC_6X_PIPELINE_NAME}"

.PHONY: set-pivnet
set-pivnet: set-pivnet-pipeline

.PHONY: set-pivnet-pipeline
set-pivnet-pipeline:
	@$(DEPLOY_CMD) --num_gpdb5_versions 11 --num_gpdb6_versions 9 \
		--pipeline_name $(PIVNET_PIPELINE_NAME) --pipeline_type pivnet \
		--output /tmp/get_pivnet_artifacts.yml \
		--template get_pivnet_artifacts-tpl.yml dev 5x

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
