# Film Equipment Rental — local dev (MCP + ERPNext)
# Phone must use LAN IP for MCP — not localhost.

FLUTTER := /home/hckeer/flutter/bin/flutter
ADB := $(HOME)/Android/platform-tools/adb
LAN_IP := $(shell hostname -I | awk '{print $$1}')
MCP_URL := http://$(LAN_IP):3001

.PHONY: run run-phone build-android install analyze test deps clean devices mcp health stack-up

## Run on connected device (uses this machine's LAN IP for MCP)
run:
	$(FLUTTER) run \
		--dart-define=MCP_BASE_URL=$(MCP_URL) \
		--dart-define=MCP_API_VERSION=v1

## Same as run — explicit name for physical Android
run-phone: run

## Build debug APK with LAN MCP URL baked in
build-android:
	$(FLUTTER) build apk \
		--dart-define=MCP_BASE_URL=$(MCP_URL) \
		--dart-define=MCP_API_VERSION=v1

install: run

run-verbose:
	$(FLUTTER) run -v \
		--dart-define=MCP_BASE_URL=$(MCP_URL) \
		--dart-define=MCP_API_VERSION=v1

analyze:
	$(FLUTTER) analyze

test:
	$(FLUTTER) test

deps:
	$(FLUTTER) pub get

clean:
	$(FLUTTER) clean && $(FLUTTER) pub get

devices:
	$(FLUTTER) devices

## Start MCP server (foreground)
mcp:
	cd mcp-server && npm run dev

## Quick health check
health:
	@curl -sf http://localhost:8080/api/method/ping >/dev/null && echo "ERPNext OK" || echo "ERPNext DOWN"
	@curl -sf http://localhost:3001/health >/dev/null && echo "MCP OK ($(MCP_URL))" || echo "MCP DOWN"

## Start ERPNext docker stack
stack-up:
	cd /home/hckeer/work/erpnest/frappe_docker && \
		docker compose -f pwd.yml up -d db redis-cache redis-queue backend frontend websocket queue-short queue-long scheduler

## Wireless ADB (requires ~/Android/platform-tools — make adb-install once)
adb-install:
	curl -fsSL -o /tmp/platform-tools.zip https://dl.google.com/android/repository/platform-tools-latest-linux.zip
	unzip -qo /tmp/platform-tools.zip -d $(HOME)/Android
	@echo "Installed: $(HOME)/Android/platform-tools/adb"

adb-pair:
	@test -n "$(PAIR_CODE)" || (echo "Usage: make adb-pair PAIR_CODE=123456 [PAIR_PORT=44455]"; exit 1)
	$(ADB) pair 192.168.1.64:$(or $(PAIR_PORT),44455) $(PAIR_CODE)

adb-connect:
	$(ADB) connect 192.168.1.64:$(or $(CONNECT_PORT),38521)
	$(ADB) devices -l

adb-devices:
	$(ADB) devices -l
	$(FLUTTER) devices
