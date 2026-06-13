# Film Equipment Rental — Run Commands
# Usage: make run | make schema | make build-android

# Supabase credentials (compile-time constants via --dart-define)
SUPABASE_URL := https://mtusxullmgsjxhpsnhwy.supabase.co
SUPABASE_ANON_KEY := sb_publishable__CyWJEN4gcBn2pVBDlTEAg_p94GSczW

.PHONY: run build-android schema clean

## Run on connected Android device (physical phone)
run:
	flutter run \
		--dart-define=SUPABASE_URL=$(SUPABASE_URL) \
		--dart-define=SUPABASE_ANON_KEY=$(SUPABASE_ANON_KEY)

## Build APK for physical Android testing
build-android:
	flutter build apk \
		--dart-define=SUPABASE_URL=$(SUPABASE_URL) \
		--dart-define=SUPABASE_ANON_KEY=$(SUPABASE_ANON_KEY) \
		--release

## Install APK on connected device
install:
	flutter install \
		--dart-define=SUPABASE_URL=$(SUPABASE_URL) \
		--dart-define=SUPABASE_ANON_KEY=$(SUPABASE_ANON_KEY)

## Run with verbose output for debugging
run-verbose:
	flutter run -v \
		--dart-define=SUPABASE_URL=$(SUPABASE_URL) \
		--dart-define=SUPABASE_ANON_KEY=$(SUPABASE_ANON_KEY)

## Check app for issues without running
analyze:
	flutter analyze

## Run tests
test:
	flutter test

## Get dependencies
deps:
	flutter pub get

## Clean build artifacts
clean:
	flutter clean && flutter pub get

## Print connected devices
devices:
	flutter devices

## NOTE: schema target — apply this SQL to your Supabase project
## Go to: https://supabase.com/dashboard/project/mtusxullmgsjxhpsnhwy/sql/new
## Paste contents of: supabase/schema.sql
schema:
	@echo "Apply schema manually:"
	@echo "1. Open https://supabase.com/dashboard/project/mtusxullmgsjxhpsnhwy/sql/new"
	@echo "2. Paste the contents of supabase/schema.sql"
	@echo "3. Click Run"
