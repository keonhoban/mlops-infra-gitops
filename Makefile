.PHONY: help optional-on optional-off proof-core proof-optional audit \
	reseal-dev reseal-prod rotate-aws-dev rotate-aws-prod rotate-ss-key

help:
	@echo "Available commands:"
	@echo "  make optional-on        - Attach Optional layer"
	@echo "  make optional-off       - Detach Optional layer"
	@echo "  make proof-core         - Generate Core-only proof (snapshot)"
	@echo "  make proof-optional     - Generate Optional-on proof (snapshot)"
	@echo "  make audit              - Full audit dump"
	@echo "  make reseal-dev         - Reseal SealedSecrets (dev)"
	@echo "  make reseal-prod        - Reseal SealedSecrets (prod)"
	@echo "  make rotate-aws-dev     - Rotate AWS credentials secret (dev)"
	@echo "  make rotate-aws-prod    - Rotate AWS credentials secret (prod)"
	@echo "  make rotate-ss-key      - Rotate SealedSecrets controller key"

optional-on:
	./ops/toggle/optional_on.sh

optional-off:
	./ops/toggle/optional_off.sh

proof-core:
	./ops/proof/proof_core_only.sh

proof-optional:
	./ops/proof/proof_optional_on.sh

audit:
	./ops/proof/audit_dump.sh

reseal-dev:
	bash ./ops/security/re-seal.sh dev

reseal-prod:
	bash ./ops/security/re-seal.sh prod

rotate-aws-dev:
	bash ./ops/security/rotate-aws-credentials.sh dev

rotate-aws-prod:
	bash ./ops/security/rotate-aws-credentials.sh prod

rotate-ss-key:
	bash ./ops/security/rotate-controller-key.sh
