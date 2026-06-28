# Copyright (c) 2026, Lightbenders and contributors
# For license information, please see license.txt

import frappe
from frappe import _
from frappe.model.document import Document


class WarehouseContainer(Document):
	def validate(self):
		if not self.container_barcode:
			frappe.throw(_("Container barcode is required."))
		if not self.warehouse:
			frappe.throw(_("Link a child Warehouse for this container."))

		duplicate = frappe.db.exists(
			"Warehouse Container",
			{"container_barcode": self.container_barcode, "name": ["!=", self.name]},
		)
		if duplicate:
			frappe.throw(_("Container barcode {0} is already used.").format(self.container_barcode))

		if not self.expected_contents:
			frappe.throw(_("Add at least one expected content row."))

		for row in self.expected_contents:
			if not row.item_code and not row.equipment_assembly:
				frappe.throw(_("Each expected content row needs an Item or Equipment Assembly."))
			if row.qty <= 0:
				frappe.throw(_("Quantity must be greater than zero."))


def validate(doc, method=None):
	doc.validate()
