# Copyright (c) 2026, Lightbenders and contributors
# For license information, please see license.txt

import frappe


def ensure_customer_id_document() -> None:
	"""Add id_document custom field on Customer (Supabase parity)."""
	fieldname = "Customer-id_document"
	if frappe.db.exists("Custom Field", fieldname):
		return

	frappe.get_doc(
		{
			"doctype": "Custom Field",
			"name": fieldname,
			"dt": "Customer",
			"fieldname": "id_document",
			"fieldtype": "Data",
			"insert_after": "customer_name",
			"label": "ID Document",
			"translatable": 0,
		}
	).insert(ignore_permissions=True)
