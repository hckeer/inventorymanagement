# Copyright (c) 2026, Lightbenders and contributors
# For license information, please see license.txt

import frappe
from frappe import _
from frappe.model.document import Document


class EquipmentAssembly(Document):
	def validate(self):
		if not self.components:
			frappe.throw(_("Add at least one component row."))

		seen = set()
		for row in self.components:
			if not row.item_code:
				frappe.throw(_("Each component row requires an Item."))
			if row.item_code in seen:
				frappe.throw(_("Duplicate component item {0}.").format(row.item_code))
			seen.add(row.item_code)
			if row.qty <= 0:
				frappe.throw(_("Quantity must be greater than zero for {0}.").format(row.item_code))


def validate(doc, method=None):
	doc.validate()
