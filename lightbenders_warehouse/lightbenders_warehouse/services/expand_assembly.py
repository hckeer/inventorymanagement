# Copyright (c) 2026, Lightbenders and contributors
# For license information, please see license.txt

"""Assembly expansion for audit/session diff — mirrors Phase 1 MCP expand_assembly."""

from __future__ import annotations

from collections import defaultdict
from typing import Any

import frappe


def expand_assembly(rows: list[dict[str, Any]]) -> dict[str, list[dict[str, Any]]]:
	"""
	Expand expected_contents into audited vs informational lines.

	Input rows match Warehouse Container Expected Content child table dicts.
	Output:
	  audited: serialized lines only, assemblies expanded to component items
	  informational: qty_only lines for UI (excluded from diff per V1)
	"""
	audited_qty: dict[str, float] = defaultdict(float)
	informational: list[dict[str, Any]] = []

	for row in rows:
		tracking = row.get("tracking") or "serialized"
		qty = float(row.get("qty") or 0)
		if qty <= 0:
			continue

		if tracking == "qty_only":
			item_code = row.get("item_code")
			if item_code:
				informational.append({"item_code": item_code, "qty": qty, "tracking": "qty_only"})
			continue

		if row.get("equipment_assembly"):
			for component in _assembly_components(row["equipment_assembly"]):
				audited_qty[component["item_code"]] += component["qty"] * qty
		elif row.get("item_code"):
			audited_qty[row["item_code"]] += qty

	audited = [
		{"item_code": item_code, "qty": qty}
		for item_code, qty in sorted(audited_qty.items())
	]
	return {"audited": audited, "informational": informational}


def expand_container(container_barcode: str) -> dict[str, list[dict[str, Any]]]:
	doc = frappe.get_doc("Warehouse Container", container_barcode)
	return expand_assembly([row.as_dict() for row in doc.expected_contents])


def _assembly_components(assembly_name: str) -> list[dict[str, Any]]:
	doc = frappe.get_doc("Equipment Assembly", assembly_name)
	return [{"item_code": row.item_code, "qty": float(row.qty)} for row in doc.components]
