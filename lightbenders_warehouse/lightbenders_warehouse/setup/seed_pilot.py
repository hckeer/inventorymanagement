# Copyright (c) 2026, Lightbenders and contributors
# For license information, please see license.txt

"""Idempotent pilot seed for Phase 0 validation (implementationerp.md §0.0–0.4)."""

from __future__ import annotations

import frappe
from frappe import _

ITEM_GROUPS = [
	{"name": "Lighting", "parent": "All Item Groups"},
	{"name": "Grip/Support", "parent": "All Item Groups"},
	{"name": "Camera Support", "parent": "All Item Groups"},
	{"name": "Power", "parent": "All Item Groups"},
]

PILOT_ITEMS = [
	{"item_code": "ARRI-LAMP-HEAD", "item_name": "ARRI Lamp Head", "item_group": "Lighting"},
	{"item_code": "ARRI-LENS", "item_name": "ARRI Lens", "item_group": "Lighting"},
	{"item_code": "ARRI-DIFFUSER", "item_name": "ARRI Diffuser", "item_group": "Lighting"},
	{"item_code": "C-STAND-LEG", "item_name": "C-Stand Leg", "item_group": "Grip/Support"},
	{"item_code": "C-STAND-ARM", "item_name": "C-Stand Arm", "item_group": "Grip/Support"},
	{"item_code": "C-STAND-HEAD", "item_name": "C-Stand Head", "item_group": "Grip/Support"},
	{"item_code": "SANDBAG-25LB", "item_name": "Sandbag 25lb", "item_group": "Grip/Support", "has_serial_no": 0},
]

WAREHOUSE_TREE = [
	{"base": "Main Store", "is_group": 1, "parent": "All Warehouses"},
	{"base": "Main Store Floor", "is_group": 0, "parent": "Main Store"},
	{"base": "Containers", "is_group": 1, "parent": "Main Store"},
	{"base": "Rack Tray 04", "is_group": 0, "parent": "Containers"},
	{"base": "Grip Cart 12", "is_group": 0, "parent": "Containers"},
	{"base": "Truck 1", "is_group": 0, "parent": "Main Store"},
	{"base": "Truck 2", "is_group": 0, "parent": "Main Store"},
	{"base": "Maintenance", "is_group": 0, "parent": "Main Store"},
]

ASSEMBLIES = {
	"ARRI-LIGHT-SET": {
		"description": "ARRI light set — lamp, lens, diffuser",
		"components": [
			{"item_code": "ARRI-LAMP-HEAD", "qty": 1},
			{"item_code": "ARRI-LENS", "qty": 1},
			{"item_code": "ARRI-DIFFUSER", "qty": 1},
		],
	},
	"C-STAND-COMPLETE": {
		"description": "Complete C-stand — leg, arm, head",
		"components": [
			{"item_code": "C-STAND-LEG", "qty": 1},
			{"item_code": "C-STAND-ARM", "qty": 1},
			{"item_code": "C-STAND-HEAD", "qty": 1},
		],
	},
}

CONTAINER_SPECS = {
	"TRAY-004": {
		"label": "Light Tray 04",
		"container_type": "tray",
		"warehouse_base": "Rack Tray 04",
		"expected_contents": [
			{"item_code": "ARRI-LAMP-HEAD", "qty": 4, "tracking": "serialized"},
			{"item_code": "ARRI-LENS", "qty": 4, "tracking": "serialized"},
			{"item_code": "ARRI-DIFFUSER", "qty": 4, "tracking": "serialized"},
		],
	},
	"CART-012": {
		"label": "Grip Cart B",
		"container_type": "cart",
		"warehouse_base": "Grip Cart 12",
		"expected_contents": [
			{"item_code": "C-STAND-LEG", "qty": 4, "tracking": "serialized"},
			{"item_code": "C-STAND-ARM", "qty": 4, "tracking": "serialized"},
			{"item_code": "C-STAND-HEAD", "qty": 4, "tracking": "serialized"},
			{"equipment_assembly": "ARRI-LIGHT-SET", "qty": 2, "tracking": "serialized"},
			{"item_code": "SANDBAG-25LB", "qty": 8, "tracking": "qty_only"},
		],
	},
}

# Barcode = Serial No name (implementationerp.md §Core Concepts)
CONTAINER_SERIALS = {
	"Rack Tray 04": {
		"ARRI-LAMP-HEAD": ["LB-LAMP-0001", "LB-LAMP-0002", "LB-LAMP-0003", "LB-LAMP-0004"],
		"ARRI-LENS": ["LB-LENS-0001", "LB-LENS-0002", "LB-LENS-0003", "LB-LENS-0004"],
		"ARRI-DIFFUSER": ["LB-DIFF-0001", "LB-DIFF-0002", "LB-DIFF-0003", "LB-DIFF-0004"],
	},
	"Grip Cart 12": {
		"C-STAND-LEG": [f"LB-CS-LEG-{i:03d}" for i in range(1, 5)],
		"C-STAND-ARM": [f"LB-CS-ARM-{i:03d}" for i in range(1, 5)],
		"C-STAND-HEAD": [f"LB-CS-HEAD-{i:03d}" for i in range(1, 5)],
		"ARRI-LAMP-HEAD": ["LB-LAMP-0101", "LB-LAMP-0102"],
		"ARRI-LENS": ["LB-LENS-0101", "LB-LENS-0102"],
		"ARRI-DIFFUSER": ["LB-DIFF-0101", "LB-DIFF-0102"],
	},
}


def seed_all(company: str | None = None) -> dict:
	"""Run full Phase 0 pilot seed. Safe to re-run."""
	company = company or _resolve_company()
	frappe.only_for(("System Manager", "Stock Manager"))

	_ensure_stock_settings()
	ensure_item_groups()
	ensure_items(company)
	ensure_warehouses(company)
	ensure_assemblies()
	ensure_containers(company)
	receipt = ensure_opening_receipt(company)
	transfers = ensure_container_transfers(company)

	frappe.db.commit()
	return {
		"company": company,
		"opening_receipt": receipt,
		"container_transfers": transfers,
	}


def _ensure_stock_settings() -> None:
	"""ERPNext v16 requires serial/batch bundle setting for Stock Entry with serials."""
	settings = frappe.get_single("Stock Settings")
	if not settings.enable_serial_and_batch_no_for_item:
		settings.enable_serial_and_batch_no_for_item = 1
		settings.save(ignore_permissions=True)


def _resolve_company() -> str:
	default = frappe.db.get_single_value("Global Defaults", "default_company")
	if default:
		return default
	companies = frappe.get_all("Company", pluck="name", limit=1)
	if not companies:
		frappe.throw(_("Create a Company before running pilot seed."))
	return companies[0]


def _company_abbr(company: str) -> str:
	return frappe.get_cached_value("Company", company, "abbr")


def _warehouse_name(base: str, abbr: str) -> str:
	return f"{base} - {abbr}"


def _receipt_warehouse(abbr: str) -> str:
	return _warehouse_name("Main Store Floor", abbr)


def ensure_item_groups() -> None:
	for group in ITEM_GROUPS:
		if frappe.db.exists("Item Group", group["name"]):
			continue
		doc = frappe.get_doc(
			{
				"doctype": "Item Group",
				"item_group_name": group["name"],
				"is_group": 0,
				"parent_item_group": group["parent"],
			}
		)
		doc.insert(ignore_permissions=True)


def ensure_items(company: str) -> None:
	for spec in PILOT_ITEMS:
		if frappe.db.exists("Item", spec["item_code"]):
			continue
		has_serial = spec.get("has_serial_no", 1)
		doc = frappe.get_doc(
			{
				"doctype": "Item",
				"item_code": spec["item_code"],
				"item_name": spec["item_name"],
				"item_group": spec["item_group"],
				"stock_uom": "Nos",
				"is_stock_item": 1,
				"has_serial_no": has_serial,
				"maintain_stock": 1,
			}
		)
		doc.insert(ignore_permissions=True)


def ensure_warehouses(company: str) -> None:
	abbr = _company_abbr(company)
	for wh in WAREHOUSE_TREE:
		full_name = _warehouse_name(wh["base"], abbr)
		if frappe.db.exists("Warehouse", full_name):
			continue

		parent = wh["parent"]
		if parent:
			parent = _warehouse_name(parent, abbr)

		doc = frappe.get_doc(
			{
				"doctype": "Warehouse",
				"warehouse_name": wh["base"],
				"is_group": wh["is_group"],
				"company": company,
				"parent_warehouse": parent,
			}
		)
		doc.insert(ignore_permissions=True)


def ensure_assemblies() -> None:
	for name, spec in ASSEMBLIES.items():
		if frappe.db.exists("Equipment Assembly", name):
			continue
		doc = frappe.get_doc(
			{
				"doctype": "Equipment Assembly",
				"assembly_name": name,
				"description": spec["description"],
				"components": spec["components"],
			}
		)
		doc.insert(ignore_permissions=True)


def ensure_containers(company: str) -> None:
	abbr = _company_abbr(company)
	for barcode, spec in CONTAINER_SPECS.items():
		if frappe.db.exists("Warehouse Container", barcode):
			continue
		doc = frappe.get_doc(
			{
				"doctype": "Warehouse Container",
				"container_barcode": barcode,
				"label": spec["label"],
				"container_type": spec["container_type"],
				"warehouse": _warehouse_name(spec["warehouse_base"], abbr),
				"expected_contents": spec["expected_contents"],
			}
		)
		doc.insert(ignore_permissions=True)


def ensure_opening_receipt(company: str) -> str | None:
	"""Material Receipt all pilot serials into Main Store."""
	abbr = _company_abbr(company)
	main_store = _receipt_warehouse(abbr)

	serials = _all_pilot_serials()
	missing = [s for s in serials if not frappe.db.exists("Serial No", s)]
	if not missing:
		return None

	for serial in missing:
		item_code = _item_for_serial(serial)
		frappe.get_doc(
			{
				"doctype": "Serial No",
				"serial_no": serial,
				"item_code": item_code,
				"company": company,
			}
		).insert(ignore_permissions=True)

	items_by_code: dict[str, list[str]] = {}
	for serial in serials:
		item_code = _item_for_serial(serial)
		items_by_code.setdefault(item_code, []).append(serial)

	entry = frappe.get_doc(
		{
			"doctype": "Stock Entry",
			"stock_entry_type": "Material Receipt",
			"company": company,
			"to_warehouse": main_store,
			"items": [
				{
					"item_code": item_code,
					"qty": len(serial_list),
					"t_warehouse": main_store,
					"use_serial_batch_fields": 1,
					"serial_no": "\n".join(serial_list),
					"allow_zero_valuation_rate": 1,
				}
				for item_code, serial_list in items_by_code.items()
			],
		}
	)
	entry.insert(ignore_permissions=True)
	entry.submit()
	return entry.name


def ensure_container_transfers(company: str) -> list[str]:
	"""Material Transfer serials from Main Store into container warehouses."""
	abbr = _company_abbr(company)
	main_store = _receipt_warehouse(abbr)

	created: list[str] = []
	for warehouse_base, item_map in CONTAINER_SERIALS.items():
		warehouse = _warehouse_name(warehouse_base, abbr)
		if _serials_already_in_warehouse(warehouse, item_map):
			continue

		items = []
		for item_code, serial_list in item_map.items():
			items.append(
				{
					"item_code": item_code,
					"qty": len(serial_list),
					"s_warehouse": main_store,
					"t_warehouse": warehouse,
					"use_serial_batch_fields": 1,
					"serial_no": "\n".join(serial_list),
					"allow_zero_valuation_rate": 1,
				}
			)

		entry = frappe.get_doc(
			{
				"doctype": "Stock Entry",
				"stock_entry_type": "Material Transfer",
				"company": company,
				"items": items,
			}
		)
		entry.insert(ignore_permissions=True)
		entry.submit()
		created.append(entry.name)

	return created


def _all_pilot_serials() -> list[str]:
	serials: list[str] = []
	for item_map in CONTAINER_SERIALS.values():
		for serial_list in item_map.values():
			serials.extend(serial_list)
	return sorted(set(serials))


def _item_for_serial(serial: str) -> str:
	prefix_map = {
		"LB-LAMP-": "ARRI-LAMP-HEAD",
		"LB-LENS-": "ARRI-LENS",
		"LB-DIFF-": "ARRI-DIFFUSER",
		"LB-CS-LEG-": "C-STAND-LEG",
		"LB-CS-ARM-": "C-STAND-ARM",
		"LB-CS-HEAD-": "C-STAND-HEAD",
	}
	for prefix, item_code in prefix_map.items():
		if serial.startswith(prefix):
			return item_code
	frappe.throw(_("Cannot map serial {0} to an item.").format(serial))


def _serials_already_in_warehouse(warehouse: str, item_map: dict[str, list[str]]) -> bool:
	for serial_list in item_map.values():
		for serial in serial_list:
			wh = frappe.db.get_value("Serial No", serial, "warehouse")
			if wh != warehouse:
				return False
	return True
