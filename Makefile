BIN=fireworq
SHELL=/bin/bash -O globstar
BUILD_OUTPUT=.
TEST_OUTPUT=.
GO=go
PRERELEASE=SNAPSHOT
BUILD=$$(git describe --always)
TEST_ARGS=-parallel 1 -timeout 60s

all: build

test: build test_deps
	{ ${GO} test ${TEST_ARGS} -race -v ./...; echo $$? > status.tmp; } | tee >(go-junit-report > ${TEST_OUTPUT}/junit_output.xml)
	exit $$(cat status.tmp)

cover: build test_deps
	TEST_ARGS="${TEST_ARGS}" script/cover ${TEST_OUTPUT}/profile.cov
	test -z "$$COVERALLS_TOKEN" || goveralls -coverprofile=${TEST_OUTPUT}/profile.cov -service=travis-ci
	${GO} tool cover -html=${TEST_OUTPUT}/profile.cov -o ${TEST_OUTPUT}/coverage.html
	gocover-cobertura < ${TEST_OUTPUT}/profile.cov > ${TEST_OUTPUT}/coverage.xml

build: deps generate
	${GO} build -race -ldflags "-X main.Build=$(BUILD) -X main.Prerelease=DEBUG" -o ${BUILD_OUTPUT}/$(BIN) .
	${GO} run script/gendoc/gendoc.go config > doc/config.md

release: clean deps credits generate
	CGO_ENABLED=0 ${GO} build -ldflags "-X main.Build=$(BUILD) -X main.Prerelease=$(PRERELEASE)" -o ${BUILD_OUTPUT}/$(BIN) .

credits:
	${GO} run script/genauthors/genauthors.go > AUTHORS
	script/credits > CREDITS

generate:
	touch AUTHORS
	touch CREDITS
	${GO} generate -x ./...

deps:
	glide install
	${GO} get github.com/jteeuwen/go-bindata/...
	${GO} get github.com/golang/mock/mockgen

test_deps:
	${GO} get github.com/jpillora/go-tcp-proxy/cmd/tcp-proxy
	${GO} get github.com/jstemmer/go-junit-report
	${GO} get golang.org/x/tools/cmd/cover
	${GO} get github.com/wadey/gocovmerge
	${GO} get github.com/t-yuki/gocover-cobertura
	${GO} get github.com/mattn/goveralls

lint:
	${GO} get github.com/golang/lint/golint
	${GO} vet ./...
	for d in $$(${GO} list ./...); do \
	  golint --set_exit_status "$$d" || exit $$? ; \
	done
	for f in $$(${GO} list -f '{{$$p := .}}{{range $$f := .GoFiles}}{{$$p.Dir}}/{{$$f}} {{end}} {{range $$f := .TestGoFiles}}{{$$p.Dir}}/{{$$f}} {{end}}' ./... | xargs); do \
	  test -z "$$(gofmt -d -s "$$f" | tee /dev/stderr)" || exit $$? ; \
	done

clean:
	rm -f **/bindata.go **/mock_*.go assets.go
	rm -f junit_output.xml profile.cov coverage.html coverage.xml
	rm -f $(BIN)
	${GO} clean

.PHONY: all test cover build release credits generate deps test_deps lint clean
