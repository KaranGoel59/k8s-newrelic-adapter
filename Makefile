REGISTRY?=karangoel59
IMAGE?=k8s-newrelic-adapter
TEMP_DIR:=$(shell mktemp -d /tmp/$(IMAGE).XXXXXX)
OUT_DIR?=./_output
VENDOR_DOCKERIZED?=0

VERSION:=$(or ${TRAVIS_TAG},${TRAVIS_TAG},latest)
GOIMAGE=golang:1.13
GOFLAGS=-mod=vendor -tags=netgo

.PHONY: all docker-build push test build-local-image

all: test $(OUT_DIR)/adapter

src_deps=$(shell find pkg cmd -type f -name "*.go")
$(OUT_DIR)/adapter: $(src_deps)
	CGO_ENABLED=0 GOARCH=$* go build $(GOFLAGS) -o $(OUT_DIR)/$*/adapter cmd/adapter/adapter.go

docker-build: test
	cp deploy/Dockerfile $(TEMP_DIR)/Dockerfile

	docker run -v $(TEMP_DIR):/build -v $(shell pwd):/go/src/github.com/kuperiu/k8s-newrelic-adapter -e GOARCH=amd64 -e GOFLAGS="$(GOFLAGS)" -w /go/src/github.com/kuperiu/k8s-newrelic-adapter $(GOIMAGE) /bin/bash -c "\
		CGO_ENABLED=0 GO111MODULE=on go build -o /build/adapter cmd/adapter/adapter.go"

	docker build -t $(REGISTRY)/$(IMAGE):$(VERSION) $(TEMP_DIR)
	rm -rf $(TEMP_DIR)

build-local-image: $(OUT_DIR)/$(ARCH)/adapter
	sed "s|BASEIMAGE|scratch|g" deploy/Dockerfile > $(TEMP_DIR)/Dockerfile
	cp  $(OUT_DIR)/$(ARCH)/adapter $(TEMP_DIR)
	cd $(TEMP_DIR)
	docker build -t $(REGISTRY)/$(IMAGE):$(VERSION) $(TEMP_DIR)
	rm -rf $(TEMP_DIR)

push:
	docker push $(REGISTRY)/$(IMAGE):$(VERSION)

vendor: go.mod
ifeq ($(VENDOR_DOCKERIZED),1)
	docker run -it -v $(shell pwd):/src/k8s-newrelic-adapter -w /src/k8s-newrelic-adapter $(GOIMAGE) /bin/bash -c "\
		go mod vendor"
else
	go mod vendor
endif

test:
	CGO_ENABLED=0 GO111MODULE=on go test ./pkg/controller/...

clean:
	rm -rf ${OUT_DIR} vendor

# Code gen helpers
gen-apis: vendor
	hack/update-codegen.sh

verify-apis: vendor
	hack/verify-codegen.sh
