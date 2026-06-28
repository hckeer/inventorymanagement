# Graph Report - .  (2026-06-27)

## Corpus Check
- 62 files · ~59,899 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 515 nodes · 1011 edges · 32 communities detected
- Extraction: 97% EXTRACTED · 3% INFERRED · 0% AMBIGUOUS · INFERRED: 30 edges (avg confidence: 0.84)
- Token cost: 0 input · 0 output

## Community Hubs (Navigation)
- [[_COMMUNITY_Data Layer (ReposProviders)|Data Layer (Repos/Providers)]]
- [[_COMMUNITY_Client Screens|Client Screens]]
- [[_COMMUNITY_App Shell & Routing|App Shell & Routing]]
- [[_COMMUNITY_ERPNext Warehouse Plan|ERPNext Warehouse Plan]]
- [[_COMMUNITY_Android Launcher Icons|Android Launcher Icons]]
- [[_COMMUNITY_Scanner & Shared Widgets|Scanner & Shared Widgets]]
- [[_COMMUNITY_Login & Auth Guard|Login & Auth Guard]]
- [[_COMMUNITY_Error Handler & Auth|Error Handler & Auth]]
- [[_COMMUNITY_Equipment Form|Equipment Form]]
- [[_COMMUNITY_Navigation Shell|Navigation Shell]]
- [[_COMMUNITY_Supabase Schema Plan|Supabase Schema Plan]]
- [[_COMMUNITY_Rental Form Components|Rental Form Components]]
- [[_COMMUNITY_Client List|Client List]]
- [[_COMMUNITY_DateCurrency Extensions|DateCurrency Extensions]]
- [[_COMMUNITY_Project Planning Docs|Project Planning Docs]]
- [[_COMMUNITY_Architecture Conventions|Architecture Conventions]]
- [[_COMMUNITY_Category Model|Category Model]]
- [[_COMMUNITY_RentalItem Model|RentalItem Model]]
- [[_COMMUNITY_Rental Model|Rental Model]]
- [[_COMMUNITY_Equipment Model|Equipment Model]]
- [[_COMMUNITY_UserProfile Model|UserProfile Model]]
- [[_COMMUNITY_RentalHistory Model|RentalHistory Model]]
- [[_COMMUNITY_Client Model|Client Model]]
- [[_COMMUNITY_Widget Tests|Widget Tests]]
- [[_COMMUNITY_Plugin Registrant|Plugin Registrant]]
- [[_COMMUNITY_Manual Riverpod Pattern|Manual Riverpod Pattern]]
- [[_COMMUNITY_Compile-Time Secrets|Compile-Time Secrets]]
- [[_COMMUNITY_ERPNext Migration Strategy|ERPNext Migration Strategy]]
- [[_COMMUNITY_Pinned Dependencies|Pinned Dependencies]]
- [[_COMMUNITY_Coding Guidelines|Coding Guidelines]]
- [[_COMMUNITY_Surgical Changes Rule|Surgical Changes Rule]]
- [[_COMMUNITY_Null Safety Rules|Null Safety Rules]]

## God Nodes (most connected - your core abstractions)
1. `package:flutter/material.dart` - 44 edges
2. `package:flutter_riverpod/flutter_riverpod.dart` - 40 edges
3. `../core/constants.dart` - 30 edges
4. `package:go_router/go_router.dart` - 28 edges
5. `../../widgets/app_loading.dart` - 20 edges
6. `../../widgets/app_error.dart` - 18 edges
7. `../../core/error_handler.dart` - 16 edges
8. `package:supabase_flutter/supabase_flutter.dart` - 14 edges
9. `../core/supabase_client.dart` - 14 edges
10. `../models/client.dart` - 12 edges

## Surprising Connections (you probably didn't know these)
- `package:flutter/material.dart` --semantically_similar_to--> `Flutter Logo`  [INFERRED] [semantically similar]
  /home/hckeer/work/inventorymanagement/lib/widgets/app_error.dart → android/app/src/main/res/mipmap-mdpi/ic_launcher.png
- `package:flutter/material.dart` --conceptually_related_to--> `Android App Launcher Icon`  [INFERRED]
  /home/hckeer/work/inventorymanagement/lib/widgets/app_error.dart → android/app/src/main/res/mipmap-mdpi/ic_launcher.png
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

### Community 0 - "Data Layer (Repos/Providers)"
Cohesion: 0.07
Nodes (33): ../core/constants.dart, ../core/supabase_client.dart, DashboardStats, EquipmentListNotifier, RentalListNotifier, CategoryRepository, ClientRepository, Exception (+25 more)

### Community 1 - "Client Screens"
Cohesion: 0.09
Nodes (40): ../../core/error_handler.dart, build, ClientDetailScreen, Container, _InfoCard, _InfoRow, Padding, Scaffold (+32 more)

### Community 2 - "App Shell & Routing"
Cohesion: 0.1
Nodes (37): ../../core/extensions.dart, build, Column, Container, _DetailRow, EquipmentDetailScreen, Function, _HistoryEntryTile (+29 more)

### Community 3 - "ERPNext Warehouse Plan"
Cohesion: 0.08
Nodes (42): audit_container (MCP tool), Quick audit scan mode, Barcode = Serial No identity, Container = child Warehouse, confirm_session (MCP tool), Dispatch scan mode (scan every serial), end_session (MCP tool), Equipment Assembly DocType (+34 more)

### Community 4 - "Android Launcher Icons"
Cohesion: 0.07
Nodes (35): Android Launcher Icon (ic_launcher.png), Android Mipmap Resource, Android Platform, Android App Launcher Icon, Solid Black Background, Three-Shade Blue Palette, Bottom Dark Blue Triangle, CineRent Android App (+27 more)

### Community 5 - "Scanner & Shared Widgets"
Cohesion: 0.1
Nodes (26): build, dispose, _onDetect, Positioned, Scaffold, ScannerScreen, _ScannerScreenState, AppEmpty (+18 more)

### Community 6 - "Login & Auth Guard"
Cohesion: 0.12
Nodes (27): AuthGuard, _BrandHeader, build, Column, dispose, _friendlyError, initState, LoginScreen (+19 more)

### Community 7 - "Error Handler & Auth"
Cohesion: 0.11
Nodes (18): app.dart, _handleAuthException, _handlePostgrestException, handleSupabaseError, build, _buildTheme, FilmRentalApp, IconThemeData (+10 more)

### Community 8 - "Equipment Form"
Cohesion: 0.16
Nodes (22): build, _ClientSection, Color, Column, Container, _DateChip, dispose, _EquipmentItemTile (+14 more)

### Community 9 - "Navigation Shell"
Cohesion: 0.17
Nodes (21): _AppShell, _AuthNotifier, build, ClientFormScreen, EquipmentFormScreen, GoRouter, RentalFormScreen, Scaffold (+13 more)

### Community 10 - "Supabase Schema Plan"
Cohesion: 0.12
Nodes (23): AuthRepository, categories table, clients table, create_rental Supabase RPC, daily_rate_snapshot on rental_items, damage_notes on rental_items, damage_reports table (cut in v2), EquipmentRepository (+15 more)

### Community 11 - "Rental Form Components"
Cohesion: 0.2
Nodes (17): build, _DateButton, dispose, GestureDetector, Icon, InputDecoration, ListView, Padding (+9 more)

### Community 12 - "Client List"
Cohesion: 0.27
Nodes (8): ClientListNotifier, build, ClientTile, _initials, InkWell, SizedBox, ../models/client.dart, ../repositories/client_repository.dart

### Community 13 - "DateCurrency Extensions"
Cohesion: 0.36
Nodes (8): capitalize, RegExp, toCurrency, toDisplayDate, toDisplayDateTime, toShortDate, toTitleCase, package:intl/intl.dart

### Community 14 - "Project Planning Docs"
Cohesion: 0.22
Nodes (9): Flutter/Dart Conventions section, No speculative code beyond plan.md V1, Simplicity First guideline, Film Equipment Inventory App, Flutter + Supabase Stack, V1 Scope, V2 Deferred Features, Flutter getting started resources (+1 more)

### Community 15 - "Architecture Conventions"
Cohesion: 0.33
Nodes (6): error_handler.dart for Supabase errors, Folder structure rule (core/models/repos/providers/screens/widgets), error_handler.dart unified Supabase errors, flutter_model skill, GoRouter navigation with ShellRoute, Layered lib/ architecture (core/models/repos/providers/screens/widgets)

### Community 16 - "Category Model"
Cohesion: 0.6
Nodes (3): Category, copyWith, toString

### Community 17 - "RentalItem Model"
Cohesion: 0.6
Nodes (3): copyWith, RentalItem, toString

### Community 18 - "Rental Model"
Cohesion: 0.6
Nodes (3): copyWith, Rental, toString

### Community 19 - "Equipment Model"
Cohesion: 0.6
Nodes (3): copyWith, Equipment, toString

### Community 20 - "UserProfile Model"
Cohesion: 0.6
Nodes (3): copyWith, toString, UserProfile

### Community 21 - "RentalHistory Model"
Cohesion: 0.6
Nodes (3): copyWith, RentalHistoryEntry, toString

### Community 22 - "Client Model"
Cohesion: 0.6
Nodes (3): Client, copyWith, toString

### Community 23 - "Widget Tests"
Cohesion: 0.67
Nodes (2): main, package:flutter_test/flutter_test.dart

### Community 24 - "Plugin Registrant"
Cohesion: 0.5
Nodes (1): GeneratedPluginRegistrant

### Community 25 - "Manual Riverpod Pattern"
Cohesion: 0.67
Nodes (3): Manual Riverpod providers (no codegen), Manual Riverpod providers (no codegen), Rationale: manual Riverpod over codegen

### Community 26 - "Compile-Time Secrets"
Cohesion: 0.67
Nodes (3): --dart-define compile-time secrets, --dart-define secrets (no flutter_dotenv), Rationale: --dart-define over flutter_dotenv

### Community 27 - "ERPNext Migration Strategy"
Cohesion: 0.67
Nodes (3): ERPNext long-term primary backend, Flutter + Supabase interim (office rentals), Rationale: validate ERPNext warehouse before migrating rentals

### Community 28 - "Pinned Dependencies"
Cohesion: 1.0
Nodes (2): Pinned dependency versions (no ^), Rationale: pinned dependency versions

### Community 29 - "Coding Guidelines"
Cohesion: 1.0
Nodes (2): Goal-Driven Execution guideline, Think Before Coding guideline

### Community 37 - "Surgical Changes Rule"
Cohesion: 1.0
Nodes (1): Surgical Changes guideline

### Community 38 - "Null Safety Rules"
Cohesion: 1.0
Nodes (1): Null safety rules

## Ambiguous Edges - Review These
- `Flutter + Supabase interim (office rentals)` → `ERPNext long-term primary backend`  [AMBIGUOUS]
  implementationerp.md · relation: replaces

## Knowledge Gaps
- **54 isolated node(s):** `Flutter + Supabase Stack`, `V2 Deferred Features`, `Pinned dependency versions (no ^)`, `categories table`, `GoRouter navigation with ShellRoute` (+49 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **Thin community `Widget Tests`** (4 nodes): `widget_test.dart`, `main`, `package:flutter_test/flutter_test.dart`, `widget_test.dart`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Plugin Registrant`** (4 nodes): `GeneratedPluginRegistrant.java`, `GeneratedPluginRegistrant`, `.registerWith()`, `GeneratedPluginRegistrant.java`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Pinned Dependencies`** (2 nodes): `Pinned dependency versions (no ^)`, `Rationale: pinned dependency versions`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Coding Guidelines`** (2 nodes): `Goal-Driven Execution guideline`, `Think Before Coding guideline`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Surgical Changes Rule`** (1 nodes): `Surgical Changes guideline`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Null Safety Rules`** (1 nodes): `Null safety rules`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **What is the exact relationship between `Flutter + Supabase interim (office rentals)` and `ERPNext long-term primary backend`?**
  _Edge tagged AMBIGUOUS (relation: replaces) - confidence is low._
- **Why does `package:flutter/material.dart` connect `Scanner & Shared Widgets` to `Data Layer (Repos/Providers)`, `Client Screens`, `App Shell & Routing`, `Android Launcher Icons`, `Login & Auth Guard`, `Error Handler & Auth`, `Equipment Form`, `Navigation Shell`, `Rental Form Components`, `Client List`?**
  _High betweenness centrality (0.232) - this node is a cross-community bridge._
- **Why does `package:flutter_riverpod/flutter_riverpod.dart` connect `Error Handler & Auth` to `Data Layer (Repos/Providers)`, `Client Screens`, `App Shell & Routing`, `Login & Auth Guard`, `Equipment Form`, `Navigation Shell`, `Rental Form Components`, `Client List`?**
  _High betweenness centrality (0.100) - this node is a cross-community bridge._
- **Why does `../core/constants.dart` connect `Data Layer (Repos/Providers)` to `Client Screens`, `App Shell & Routing`, `Scanner & Shared Widgets`, `Error Handler & Auth`, `Equipment Form`, `Rental Form Components`?**
  _High betweenness centrality (0.062) - this node is a cross-community bridge._
- **Are the 2 inferred relationships involving `package:flutter/material.dart` (e.g. with `Flutter Logo` and `Android App Launcher Icon`) actually correct?**
  _`package:flutter/material.dart` has 2 INFERRED edges - model-reasoned connections that need verification._
- **What connects `Flutter + Supabase Stack`, `V2 Deferred Features`, `Pinned dependency versions (no ^)` to the rest of the system?**
  _54 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Data Layer (Repos/Providers)` be split into smaller, more focused modules?**
  _Cohesion score 0.07 - nodes in this community are weakly interconnected._