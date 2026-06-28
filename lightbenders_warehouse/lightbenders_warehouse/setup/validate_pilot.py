# Copyright (c) 2026, Lightbenders and contributors
# Phase 0 validation helpers (implementationerp.md §0.5)

from __future__ import annotations

import frappe
from frappe.utils import flt

from lightbenders_warehouse.services.expand_assembly import expand_container


def validate_pilot() -> dict:
	"""Run Phase 0 checks that do not require MCP (desk + Stock Balance API)."""
	results = {
		"containers_exist": _check_containers(),
		"assemblies_exist": _check_assemblies(),
		"tray_stock_balance": _stock_balance_for_container("TRAY-004"),
		"cart_stock_balance": _stock_balance_for_container("CART-012"),
		"tray_expanded_expected": expand_container("TRAY-004"),
		"cart_expanded_expected": expand_container("CART-012"),
	}
	results["passed"] = all(
		[
			results["containers_exist"],
			results["assemblies_exist"],
			bool(results["tray_stock_balance"]),
			bool(results["cart_stock_balance"]),
		]
	)
	return results


def _check_containers() -> bool:
	return bool(frappe.db.exists("Warehouse Container", "TRAY-004")) and bool(
		frappe.db.exists("Warehouse Container", "CART-012")
	)


def _check_assemblies() -> bool:
	return bool(frappe.db.exists("Equipment Assembly", "ARRI-LIGHT-SET")) and bool(
		frappe.db.exists("Equipment Assembly", "C-STAND-COMPLETE")
	)


def _stock_balance_for_container(container_barcode: str) -> dict[str, float]:
	doc = frappe.get_doc("Warehouse Container", container_barcode)
	warehouse = doc.warehouse
	balances: dict[str, float] = {}

	for row in frappe.db.sql(
		"""
		select item_code, sum(actual_qty) as qty
		from `tabStock Ledger Entry`
		where warehouse = %s and is_cancelled = 0
		group by item_code
		having sum(actual_qty) > 0
		""",
		warehouse,
		as_dict=True,
	):
		balances[row.item_code] = flt(row.qty)

	return balances
