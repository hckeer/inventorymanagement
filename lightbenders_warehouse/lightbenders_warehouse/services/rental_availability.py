# Copyright (c) 2026, Lightbenders and contributors
# For license information, please see license.txt

"""Availability checks for Equipment Rental submit (serial overlap + qty stock)."""

from __future__ import annotations

import frappe
from frappe import _
from frappe.utils import flt, getdate

from erpnext.stock.utils import get_stock_balance


def resolve_company(company: str | None = None) -> str:
	if company:
		return company
	default = frappe.db.get_single_value("Global Defaults", "default_company")
	if default:
		return default
	companies = frappe.get_all("Company", pluck="name", limit=1)
	if not companies:
		frappe.throw(_("Create a Company before using Equipment Rental."))
	return companies[0]


def get_rental_warehouse(company: str | None = None) -> str:
	"""Default rental warehouse: Main Store Floor - {company_abbr}."""
	company = resolve_company(company)
	abbr = frappe.get_cached_value("Company", company, "abbr")
	warehouse = f"Main Store Floor - {abbr}"
	if not frappe.db.exists("Warehouse", warehouse):
		frappe.throw(
			_("Rental warehouse {0} not found. Run pilot seed or create Main Store Floor.").format(
				warehouse
			)
		)
	return warehouse


def serial_on_active_rental(
	serial_no: str,
	start_date,
	end_date,
	exclude_rental: str | None = None,
) -> str | None:
	"""Return rental name if serial is double-booked for overlapping Active dates."""
	start = getdate(start_date)
	end = getdate(end_date)
	filters = {
		"status": "Active",
		"docstatus": 1,
		"start_date": ("<=", end),
		"end_date": (">=", start),
	}
	rentals = frappe.get_all(
		"Equipment Rental",
		filters=filters,
		pluck="name",
	)
	for rental_name in rentals:
		if exclude_rental and rental_name == exclude_rental:
			continue
		if frappe.db.exists(
			"Equipment Rental Item",
			{
				"parent": rental_name,
				"parenttype": "Equipment Rental",
				"line_type": "serialized",
				"serial_no": serial_no,
			},
		):
			return rental_name
	return None


def assert_serial_available(
	serial_no: str,
	start_date,
	end_date,
	exclude_rental: str | None = None,
) -> None:
	conflict = serial_on_active_rental(serial_no, start_date, end_date, exclude_rental)
	if conflict:
		frappe.throw(
			_("Serial {0} is on active rental {1} for overlapping dates.").format(
				serial_no, conflict
			),
			title=_("Serial Already Rented"),
		)


def assert_qty_available(
	item_code: str,
	qty: float,
	warehouse: str | None = None,
) -> None:
	warehouse = warehouse or get_rental_warehouse()
	available = flt(get_stock_balance(item_code, warehouse))
	requested = flt(qty)
	if requested > available:
		frappe.throw(
			_("Insufficient stock for {0}: requested {1}, available {2} in {3}.").format(
				item_code, requested, available, warehouse
			),
			title=_("Insufficient Qty"),
		)
