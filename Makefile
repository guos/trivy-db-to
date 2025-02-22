PKG = github.com/k1LoW/trivy-db-to
COMMIT = $$(git describe --tags --always)
OSNAME=${shell uname -s}
ifeq ($(OSNAME),Darwin)
	DATE = $$(gdate --utc '+%Y-%m-%d_%H:%M:%S')
else
	DATE = $$(date --utc '+%Y-%m-%d_%H:%M:%S')
endif

export GO111MODULE=on

BUILD_LDFLAGS = -X $(PKG).commit=$(COMMIT) -X $(PKG).date=$(DATE)

TEST_MYSQL_DSN = mysql://root:mypass@127.0.0.1:33357/trivydb
TEST_POSTGRES_DSN = pg://postgres:pgpass@127.0.0.1:35432/trivydb?sslmode=disable

default: test

ci: depsdev test integration

test:
	go test ./... -coverprofile=coverage.out -covermode=count

sec:
	gosec ./...

lint:
	golangci-lint run ./...

doc:
	tbls doc -f -c docs/tbls-mysql.yml
	tbls doc -f -c docs/tbls-postgres.yml

integration: build
	./trivy-db-to $(TEST_MYSQL_DSN)
	usql $(TEST_MYSQL_DSN) -c "SELECT COUNT(*) FROM vulnerabilities;"
	usql $(TEST_MYSQL_DSN) -c "SELECT COUNT(*) FROM vulnerabilities;" | grep '[0-9]\{5\}'
	usql $(TEST_MYSQL_DSN) -c "SELECT COUNT(*) FROM vulnerability_advisories;"
	usql $(TEST_MYSQL_DSN) -c "SELECT COUNT(*) FROM vulnerability_advisories;" | grep '[0-9]\{6\}'
	./trivy-db-to $(TEST_POSTGRES_DSN)
	usql $(TEST_POSTGRES_DSN) -c "SELECT COUNT(*) FROM vulnerabilities;"
	usql $(TEST_POSTGRES_DSN) -c "SELECT COUNT(*) FROM vulnerabilities;" | grep '[0-9]\{5\}'
	usql $(TEST_POSTGRES_DSN) -c "SELECT COUNT(*) FROM vulnerability_advisories;"
	usql $(TEST_POSTGRES_DSN) -c "SELECT COUNT(*) FROM vulnerability_advisories;" | grep '[0-9]\{6\}'

build:
	go build -ldflags="$(BUILD_LDFLAGS)"

depsdev:
	go install github.com/Songmu/ghch/cmd/ghch@v0.10.2
	go install github.com/xo/usql@v0.9.5
	go install github.com/Songmu/gocredits/cmd/gocredits@v0.2.0
	go install github.com/securego/gosec/cmd/gosec@master

prerelease:
	git pull origin --tag
	ghch -w -N ${VER}
	gocredits . > CREDITS
	git add CHANGELOG.md CREDITS
	git commit -m'Bump up version number'
	git tag ${VER}

release:
	git push origin main --tag
	goreleaser --rm-dist

.PHONY: default test
