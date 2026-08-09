# Graph Report - inventorymanagement  (2026-08-09)

## Corpus Check
- 132 files · ~8,677,407 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 895 nodes · 1253 edges · 41 communities detected
- Extraction: 90% EXTRACTED · 10% INFERRED · 0% AMBIGUOUS · INFERRED: 122 edges (avg confidence: 0.81)
- Token cost: 0 input · 0 output

## Community Hubs (Navigation)
- [[_COMMUNITY_Community 0|Community 0]]
- [[_COMMUNITY_Community 1|Community 1]]
- [[_COMMUNITY_Community 2|Community 2]]
- [[_COMMUNITY_Community 3|Community 3]]
- [[_COMMUNITY_Community 4|Community 4]]
- [[_COMMUNITY_Community 5|Community 5]]
- [[_COMMUNITY_Community 6|Community 6]]
- [[_COMMUNITY_Community 7|Community 7]]
- [[_COMMUNITY_Community 8|Community 8]]
- [[_COMMUNITY_Community 9|Community 9]]
- [[_COMMUNITY_Community 10|Community 10]]
- [[_COMMUNITY_Community 11|Community 11]]
- [[_COMMUNITY_Community 12|Community 12]]
- [[_COMMUNITY_Community 13|Community 13]]
- [[_COMMUNITY_Community 14|Community 14]]
- [[_COMMUNITY_Community 15|Community 15]]
- [[_COMMUNITY_Community 16|Community 16]]
- [[_COMMUNITY_Community 17|Community 17]]
- [[_COMMUNITY_Community 18|Community 18]]
- [[_COMMUNITY_Community 19|Community 19]]
- [[_COMMUNITY_Community 20|Community 20]]
- [[_COMMUNITY_Community 21|Community 21]]
- [[_COMMUNITY_Community 22|Community 22]]
- [[_COMMUNITY_Community 23|Community 23]]
- [[_COMMUNITY_Community 24|Community 24]]
- [[_COMMUNITY_Community 25|Community 25]]
- [[_COMMUNITY_Community 26|Community 26]]
- [[_COMMUNITY_Community 27|Community 27]]
- [[_COMMUNITY_Community 28|Community 28]]
- [[_COMMUNITY_Community 29|Community 29]]
- [[_COMMUNITY_Community 30|Community 30]]
- [[_COMMUNITY_Community 32|Community 32]]
- [[_COMMUNITY_Community 33|Community 33]]
- [[_COMMUNITY_Community 35|Community 35]]
- [[_COMMUNITY_Community 36|Community 36]]
- [[_COMMUNITY_Community 37|Community 37]]
- [[_COMMUNITY_Community 38|Community 38]]
- [[_COMMUNITY_Community 40|Community 40]]
- [[_COMMUNITY_Community 41|Community 41]]
- [[_COMMUNITY_Community 60|Community 60]]
- [[_COMMUNITY_Community 61|Community 61]]

## God Nodes (most connected - your core abstractions)
1. `package:flutter/material.dart` - 27 edges
2. `package:flutter_riverpod/flutter_riverpod.dart` - 24 edges
3. `package:go_router/go_router.dart` - 18 edges
4. `../core/error_handler.dart` - 15 edges
5. `ErpnextClient` - 14 edges
6. `ErpnextSessionClient` - 14 edges
7. `../core/mcp_client.dart` - 12 edges
8. `seed_all()` - 12 edges
9. `Flutter Logo` - 12 edges
10. `EquipmentRental` - 11 edges

## Surprising Connections (you probably didn't know these)
- `package:flutter/material.dart` --semantically_similar_to--> `Flutter Logo`  [INFERRED] [semantically similar]
  lib/widgets/app_error.dart → android/app/src/main/res/mipmap-mdpi/ic_launcher.png
- `package:flutter/material.dart` --conceptually_related_to--> `Android App Launcher Icon`  [INFERRED]
  lib/widgets/app_error.dart → android/app/src/main/res/mipmap-mdpi/ic_launcher.png
- `Manual Riverpod providers (no codegen)` --semantically_similar_to--> `Manual Riverpod providers (no codegen)`  [INFERRED] [semantically similar]
  plan.md → CLAUDE.md
- `--dart-define secrets (no flutter_dotenv)` --semantically_similar_to--> `--dart-define compile-time secrets`  [INFERRED] [semantically similar]
  plan.md → CLAUDE.md
- `Layered lib/ architecture (core/models/repos/providers/screens/widgets)` --semantically_similar_to--> `Folder structure rule (core/models/repos/providers/screens/widgets)`  [INFERRED] [semantically similar]
  plan.md → CLAUDE.md

## Hyperedges (group relationships)
- **Atomic rental creation flow** — plan_create_rental_rpc, plan_rental_repository, plan_rentals_table, plan_rental_items_table, plan_equipment_table [EXTRACTED 1.00]
- **Layered Flutter application architecture** — plan_layered_architecture, claude_folder_structure, plan_manual_riverpod_providers, plan_gorouter_navigation [INFERRED 0.85]
- **V1 damage tracking via rental_items.damage_notes** — plan_damage_notes, plan_rental_items_table, plan_damage_reports_table [EXTRACTED 1.00]
- **Flutter Logo Visual Composition** — ic_launcher_light_cyan_shape, ic_launcher_medium_blue_shape, ic_launcher_dark_navy_shape, ic_launcher_blue_color_palette, ic_launcher_black_background [EXTRACTED 0.95]
- **Android Multi-Density Launcher Icon Asset** — ic_launcher_android_launcher_icon, ic_launcher_mipmap_xxhdpi_bucket, ic_launcher_flutter_framework_logo [INFERRED 0.87]
- **Flutter Logo Geometric Composition** — ic_launcher_top_parallelogram, ic_launcher_middle_parallelogram, ic_launcher_bottom_triangle [EXTRACTED 1.00]
- **Flutter Logo Visual Composition** — ic_launcher_flutter_logo, ic_launcher_light_blue_wing, ic_launcher_dark_blue_fold, ic_launcher_geometric_f_mark [EXTRACTED 0.95]
- **Flutter Logo Visual Composition** — ic_launcher_flutter_logo, ic_launcher_upper_parallelogram, ic_launcher_lower_folded_shape, ic_launcher_black_background [EXTRACTED 1.00]
- **Flutter Logo Visual Composition** — ic_launcher_flutter_logo, ic_launcher_upper_parallelogram, ic_launcher_middle_parallelogram, ic_launcher_dark_blue_fold, ic_launcher_black_background [EXTRACTED 1.00]
- **Dispatch/Return MCP session workflow** — implementationerp_start_session, implementationerp_scan_serial, implementationerp_end_session, implementationerp_confirm_session, implementationerp_expand_assembly [EXTRACTED 1.00]
- **VPS scanner stack (iPad → MCP → ERPNext)** — implementationerp_scanner_web, implementationerp_mcp_server, implementationerp_erpnext_vps, implementationerp_vps_mcp_architecture [EXTRACTED 1.00]
- **Configurable container expected contents model** — implementationerp_warehouse_container_doctype, implementationerp_expected_contents, implementationerp_equipment_assembly_doctype, implementationerp_expand_assembly, implementationerp_qty_only_tracking [EXTRACTED 1.00]

## Communities

### Community 0 - "Community 0"
Cohesion: 0.02
Nodes (126): ../core/constants.dart, ../../core/extensions.dart, copyWith, _mapErpStatus, Rental, toString, ClientListNotifier, build (+118 more)

### Community 1 - "Community 1"
Cohesion: 0.03
Nodes (78): ../core/error_handler.dart, ../core/mcp_client.dart, CategoryListNotifier, DashboardStats, Exception, RentalListNotifier, AuthRepository, Exception (+70 more)

### Community 2 - "Community 2"
Cohesion: 0.05
Nodes (41): createAppConfigFromEnv(), registerRoutes(), createAuthMiddleware(), extractDetailText(), httpStatusForCode(), mapErpnextError(), loadConfig(), loadConfigOrNull() (+33 more)

### Community 3 - "Community 3"
Cohesion: 0.04
Nodes (54): _AppShell, _AuthNotifier, build, CheckinScannerScreen, CheckoutScannerScreen, ClientFormScreen, EquipmentFormScreen, GoRouter (+46 more)

### Community 4 - "Community 4"
Cohesion: 0.07
Nodes (21): auditContainer(), buildRemark(), ConfirmBlockedError, confirmSession(), diffExpectedVsActual(), reconcileScannedVsExpected(), endSession(), barcodeToWarehouseBaseName() (+13 more)

### Community 5 - "Community 5"
Cohesion: 0.04
Nodes (43): app.dart, build, _buildTheme, FilmRentalApp, IconThemeData, main, ProviderScope, TextStyle (+35 more)

### Community 6 - "Community 6"
Cohesion: 0.08
Nodes (42): audit_container (MCP tool), Quick audit scan mode, Barcode = Serial No identity, Container = child Warehouse, confirm_session (MCP tool), Dispatch scan mode (scan every serial), end_session (MCP tool), Equipment Assembly DocType (+34 more)

### Community 7 - "Community 7"
Cohesion: 0.07
Nodes (35): Android Launcher Icon (ic_launcher.png), Android Mipmap Resource, Android Platform, Android App Launcher Icon, Solid Black Background, Three-Shade Blue Palette, Bottom Dark Blue Triangle, CineRent Android App (+27 more)

### Community 8 - "Community 8"
Cohesion: 0.06
Nodes (33): build, _buildActions, _buildChatLog, _buildHeader, _buildModeRow, _buildScanDock, Color, Container (+25 more)

### Community 9 - "Community 9"
Cohesion: 0.09
Nodes (19): EquipmentRental, mark_overdue_rentals(), Scheduled job: Active rentals past end_date → Overdue., assert_qty_available(), assert_serial_available(), get_rental_warehouse(), Default rental warehouse: Main Store Floor - {company_abbr}., Return rental name if serial is double-booked for overlapping Active dates. (+11 more)

### Community 10 - "Community 10"
Cohesion: 0.14
Nodes (26): bindShellEvents(), boot(), escapeHtml(), focusScanInput(), formatGapList(), handleConfirm(), handleEndSession(), handleScan() (+18 more)

### Community 11 - "Community 11"
Cohesion: 0.09
Nodes (13): constants.dart, dart:convert, ErpnextSessionClient, error_handler.dart, clearToken, McpApiException, McpClient, _request (+5 more)

### Community 12 - "Community 12"
Cohesion: 0.17
Nodes (21): _all_pilot_serials(), _company_abbr(), execute(), ensure_assemblies(), ensure_container_transfers(), ensure_containers(), ensure_item_groups(), ensure_items() (+13 more)

### Community 13 - "Community 13"
Cohesion: 0.12
Nodes (23): AuthRepository, categories table, clients table, create_rental Supabase RPC, daily_rate_snapshot on rental_items, damage_notes on rental_items, damage_reports table (cut in v2), EquipmentRepository (+15 more)

### Community 14 - "Community 14"
Cohesion: 0.13
Nodes (6): Document, EquipmentAssemblyComponent, EquipmentAssembly, EquipmentRentalItem, WarehouseContainerExpectedContent, WarehouseContainer

### Community 15 - "Community 15"
Cohesion: 0.16
Nodes (11): EquipmentDetail, EquipmentSerial, EquipmentListNotifier, EquipmentDetail, EquipmentRepository, Exception, _mapRentalStatus, ../models/equipment.dart (+3 more)

### Community 16 - "Community 16"
Cohesion: 0.18
Nodes (10): WarehouseAuditedLine, WarehouseAuditResult, WarehouseConfirmResult, WarehouseInformationalLine, WarehouseItemQtyGap, WarehouseMovedItem, WarehouseScannedSerial, WarehouseScanResult (+2 more)

### Community 17 - "Community 17"
Cohesion: 0.27
Nodes (9): _assembly_components(), expand_assembly(), expand_container(), Expand expected_contents into audited vs informational lines.  	Input rows match, _check_assemblies(), _check_containers(), Run Phase 0 checks that do not require MCP (desk + Stock Balance API)., _stock_balance_for_container() (+1 more)

### Community 18 - "Community 18"
Cohesion: 0.22
Nodes (8): capitalize, RegExp, toCurrency, toDisplayDate, toDisplayDateTime, toShortDate, toTitleCase, package:intl/intl.dart

### Community 19 - "Community 19"
Cohesion: 0.22
Nodes (9): Flutter/Dart Conventions section, No speculative code beyond plan.md V1, Simplicity First guideline, Film Equipment Inventory App, Flutter + Supabase Stack, V1 Scope, V2 Deferred Features, Flutter getting started resources (+1 more)

### Community 20 - "Community 20"
Cohesion: 0.52
Nodes (6): barcode(), common_name(), detailed_common_name(), main(), make_sheet(), sql_rows()

### Community 21 - "Community 21"
Cohesion: 0.4
Nodes (2): migrationFileName(), schemaSql()

### Community 22 - "Community 22"
Cohesion: 0.33
Nodes (6): error_handler.dart for Supabase errors, Folder structure rule (core/models/repos/providers/screens/widgets), error_handler.dart unified Supabase errors, flutter_model skill, GoRouter navigation with ShellRoute, Layered lib/ architecture (core/models/repos/providers/screens/widgets)

### Community 23 - "Community 23"
Cohesion: 0.4
Nodes (4): copyWith, deriveItemStatus, Equipment, toString

### Community 24 - "Community 24"
Cohesion: 0.4
Nodes (3): ensure_customer_id_document(), Add id_document custom field on Customer (Supabase parity)., after_install()

### Community 25 - "Community 25"
Cohesion: 0.5
Nodes (3): Category, copyWith, toString

### Community 26 - "Community 26"
Cohesion: 0.5
Nodes (3): copyWith, RentalItem, toString

### Community 27 - "Community 27"
Cohesion: 0.5
Nodes (3): copyWith, toString, UserProfile

### Community 28 - "Community 28"
Cohesion: 0.5
Nodes (3): copyWith, RentalHistoryEntry, toString

### Community 29 - "Community 29"
Cohesion: 0.5
Nodes (3): Client, copyWith, toString

### Community 30 - "Community 30"
Cohesion: 0.5
Nodes (3): handleAppError, humanizeError, mcp_client.dart

### Community 32 - "Community 32"
Cohesion: 0.67
Nodes (2): main, package:flutter_test/flutter_test.dart

### Community 33 - "Community 33"
Cohesion: 0.67
Nodes (1): GeneratedPluginRegistrant

### Community 35 - "Community 35"
Cohesion: 0.67
Nodes (3): Manual Riverpod providers (no codegen), Manual Riverpod providers (no codegen), Rationale: manual Riverpod over codegen

### Community 36 - "Community 36"
Cohesion: 0.67
Nodes (3): --dart-define compile-time secrets, --dart-define secrets (no flutter_dotenv), Rationale: --dart-define over flutter_dotenv

### Community 37 - "Community 37"
Cohesion: 0.67
Nodes (3): ERPNext long-term primary backend, Flutter + Supabase interim (office rentals), Rationale: validate ERPNext warehouse before migrating rentals

### Community 38 - "Community 38"
Cohesion: 1.0
Nodes (1): RentalLineInput

### Community 40 - "Community 40"
Cohesion: 1.0
Nodes (2): Pinned dependency versions (no ^), Rationale: pinned dependency versions

### Community 41 - "Community 41"
Cohesion: 1.0
Nodes (2): Goal-Driven Execution guideline, Think Before Coding guideline

### Community 60 - "Community 60"
Cohesion: 1.0
Nodes (1): Surgical Changes guideline

### Community 61 - "Community 61"
Cohesion: 1.0
Nodes (1): Null safety rules

## Ambiguous Edges - Review These
- `Flutter + Supabase interim (office rentals)` → `ERPNext long-term primary backend`  [AMBIGUOUS]
  implementationerp.md · relation: replaces

## Knowledge Gaps
- **435 isolated node(s):** `_AuthNotifier`, `_AppShell`, `GoRouter`, `CheckoutScannerScreen`, `CheckinScannerScreen` (+430 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **Thin community `Community 21`** (6 nodes): `schema_contract.test.ts`, `legacyCleanupMigration()`, `migrationFileName()`, `productOperationsMigration()`, `rentalLifecycleMigration()`, `schemaSql()`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 32`** (3 nodes): `main`, `package:flutter_test/flutter_test.dart`, `widget_test.dart`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 33`** (3 nodes): `GeneratedPluginRegistrant.java`, `GeneratedPluginRegistrant`, `.registerWith()`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 38`** (2 nodes): `RentalLineInput`, `rental_line_input.dart`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 40`** (2 nodes): `Pinned dependency versions (no ^)`, `Rationale: pinned dependency versions`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 41`** (2 nodes): `Goal-Driven Execution guideline`, `Think Before Coding guideline`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 60`** (1 nodes): `Surgical Changes guideline`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 61`** (1 nodes): `Null safety rules`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **What is the exact relationship between `Flutter + Supabase interim (office rentals)` and `ERPNext long-term primary backend`?**
  _Edge tagged AMBIGUOUS (relation: replaces) - confidence is low._
- **Why does `Text` connect `Community 2` to `Community 0`, `Community 11`, `Community 4`?**
  _High betweenness centrality (0.252) - this node is a cross-community bridge._
- **Why does `package:flutter/material.dart` connect `Community 5` to `Community 0`, `Community 1`, `Community 3`, `Community 7`, `Community 8`?**
  _High betweenness centrality (0.194) - this node is a cross-community bridge._
- **Why does `loginToErpnext()` connect `Community 2` to `Community 4`?**
  _High betweenness centrality (0.151) - this node is a cross-community bridge._
- **Are the 2 inferred relationships involving `package:flutter/material.dart` (e.g. with `Flutter Logo` and `Android App Launcher Icon`) actually correct?**
  _`package:flutter/material.dart` has 2 INFERRED edges - model-reasoned connections that need verification._
- **What connects `_AuthNotifier`, `_AppShell`, `GoRouter` to the rest of the system?**
  _435 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Community 0` be split into smaller, more focused modules?**
  _Cohesion score 0.02 - nodes in this community are weakly interconnected._