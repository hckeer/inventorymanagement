# Copyright (c) 2026, Lightbenders and contributors
# For license information, please see license.txt

"""U0 gate tests: serial double-book + qty over-stock rejected on submit."""

from __future__ import annotations

import frappe
from frappe import _
from frappe.utils import add_days, getdate, today


def validate_rental_gates() -> dict:
	"""Create Active rental (serial + qty), verify double-book and over-qty fail."""
	customer = _ensure_test_customer()
	serial = _pick_available_serial()
	qty_item = "SANDBAG-25LB"
	warehouse = _rental_warehouse()
	_ensure_qty_stock(qty_item, warehouse, min_qty=10)

	results = {
		"customer": customer,
		"serial": serial,
		"qty_item": qty_item,
		"warehouse": warehouse,
		"checks": {},
	}

	rental_name = _create_and_submit_rental(
		customer,
		serial,
		qty_item,
		qty=1,
	)
	results["first_rental"] = rental_name
	results["checks"]["submit_serial_qty"] = "pass"

	results["checks"]["double_book_blocked"] = _expect_submit_failure(
		customer,
		serial,
		qty_item,
		qty=1,
		expected_in_message=serial,
	)

	available = frappe.db.get_value(
		"Bin",
		{"item_code": qty_item, "warehouse": warehouse},
		"actual_qty",
	) or 0
	over_qty = float(available) + 100
	results["checks"]["over_qty_blocked"] = _expect_submit_failure(
		customer,
		_pick_other_serial(serial),
		qty_item,
		qty=over_qty,
		expected_in_message=qty_item,
	)

	active = frappe.db.get_value("Equipment Rental", rental_name, "status")
	results["checks"]["first_still_active"] = "pass" if active == "Active" else f"fail: {active}"

	return results


def _ensure_qty_stock(item_code: str, warehouse: str, min_qty: float) -> None:
	from erpnext.stock.utils import get_stock_balance

	available = float(get_stock_balance(item_code, warehouse) or 0)
	if available >= min_qty:
		return

	company = frappe.db.get_single_value("Global Defaults", "default_company")
	doc = frappe.get_doc(
		{
			"doctype": "Stock Entry",
			"stock_entry_type": "Material Receipt",
			"company": company,
			"items": [
				{
					"item_code": item_code,
					"qty": min_qty - available,
					"t_warehouse": warehouse,
					"allow_zero_valuation_rate": 1,
				}
			],
		}
	)
	doc.insert(ignore_permissions=True)
	doc.submit()


def _ensure_test_customer() -> str:
	name = "RENTAL-GATE-TEST"
	if frappe.db.exists("Customer", name):
		return name
	doc = frappe.get_doc(
		{
			"doctype": "Customer",
			"customer_name": name,
			"customer_type": "Individual",
			"customer_group": "Individual",
			"territory": "All Territories",
			"id_document": "GATE-TEST-001",
		}
	)
	doc.insert(ignore_permissions=True)
	return doc.name


def _rental_warehouse() -> str:
	from lightbenders_warehouse.services.rental_availability import get_rental_warehouse

	return get_rental_warehouse()


def _pick_available_serial() -> str:
	serials = frappe.get_all(
		"Serial No",
		filters={"item_code": ("in", ["ARRI-LAMP-HEAD", "ARRI-LENS", "ARRI-DIFFUSER"])},
		pluck="name",
		limit=1,
	)
	if not serials:
		frappe.throw(_("No pilot serials found — run seed_pilot.seed_all first."))
	return serials[0]


def _pick_other_serial(exclude: str) -> str:
	serials = frappe.get_all(
		"Serial No",
		filters={
			"item_code": ("in", ["ARRI-LAMP-HEAD", "ARRI-LENS", "ARRI-DIFFUSER"]),
			"name": ("!=", exclude),
		},
		pluck="name",
		limit=1,
	)
	if not serials:
		frappe.throw(_("Need at least two serials for gate test."))
	return serials[0]


def _create_and_submit_rental(
	customer: str,
	serial: str,
	qty_item: str,
	qty: float,
) -> str:
	serial_item = frappe.db.get_value("Serial No", serial, "item_code")
	start = today()
	end = add_days(start, 7)
	doc = frappe.get_doc(
		{
			"doctype": "Equipment Rental",
			"naming_series": "RENT-.YYYY.-",
			"customer": customer,
			"start_date": start,
			"end_date": end,
			"items": [
				{
					"line_type": "serialized",
					"item_code": serial_item,
					"serial_no": serial,
					"qty": 1,
				},
				{
					"line_type": "qty",
					"item_code": qty_item,
					"qty": qty,
				},
			],
		}
	)
	doc.insert(ignore_permissions=True)
	doc.submit()
	return doc.name


def _expect_submit_failure(
	customer: str,
	serial: str,
	qty_item: str,
	qty: float,
	expected_in_message: str,
) -> str:
	serial_item = frappe.db.get_value("Serial No", serial, "item_code")
	start = today()
	end = add_days(start, 7)
	doc = frappe.get_doc(
		{
			"doctype": "Equipment Rental",
			"naming_series": "RENT-.YYYY.-",
			"customer": customer,
			"start_date": start,
			"end_date": end,
			"items": [
				{
					"line_type": "serialized",
					"item_code": serial_item,
					"serial_no": serial,
					"qty": 1,
				},
				{
					"line_type": "qty",
					"item_code": qty_item,
					"qty": qty,
				},
			],
		}
	)
	doc.insert(ignore_permissions=True)
	try:
		doc.submit()
	except frappe.ValidationError as exc:
		if expected_in_message in str(exc):
			return "pass"
		return f"fail: wrong message: {exc}"
	except Exception as exc:
		return f"fail: {type(exc).__name__}: {exc}"
	return "fail: submit succeeded unexpectedly"
