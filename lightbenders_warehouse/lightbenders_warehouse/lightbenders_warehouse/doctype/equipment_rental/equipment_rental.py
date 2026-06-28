# Copyright (c) 2026, Lightbenders and contributors
# For license information, please see license.txt

import frappe
from frappe import _
from frappe.model.document import Document
from frappe.utils import flt, getdate

from lightbenders_warehouse.services.rental_availability import (
	assert_qty_available,
	assert_serial_available,
	get_rental_warehouse,
)


class EquipmentRental(Document):
	def before_insert(self):
		if not self.created_by:
			self.created_by = frappe.session.user

	def validate(self):
		self._validate_dates()
		self._validate_lines()
		if self.docstatus == 0 and self.status not in ("Returned", "Overdue"):
			self.status = "Draft"

	def before_submit(self):
		self._validate_availability()
		self._snapshot_daily_rates()

	def on_submit(self):
		self.db_set("status", "Active", update_modified=False)

	def on_cancel(self):
		self.db_set("status", "Cancelled", update_modified=False)

	def _validate_dates(self):
		if not self.start_date or not self.end_date:
			return
		if getdate(self.end_date) < getdate(self.start_date):
			frappe.throw(_("End Date cannot be before Start Date."))

	def _validate_lines(self):
		if not self.items:
			frappe.throw(_("Add at least one rental line."))

		for row in self.items:
			if row.line_type == "serialized":
				if not row.serial_no:
					frappe.throw(_("Serial No is required for serialized line {0}.").format(row.idx))
				serial_item = frappe.db.get_value("Serial No", row.serial_no, "item_code")
				if serial_item and serial_item != row.item_code:
					frappe.throw(
						_("Serial {0} belongs to {1}, not {2}.").format(
							row.serial_no, serial_item, row.item_code
						)
					)
				if flt(row.qty) != 1:
					row.qty = 1
			elif row.line_type == "qty":
				row.serial_no = None
				if flt(row.qty) <= 0:
					frappe.throw(_("Quantity must be greater than zero for {0}.").format(row.item_code))
			else:
				frappe.throw(_("Invalid line type on row {0}.").format(row.idx))

	def _validate_availability(self):
		warehouse = get_rental_warehouse()
		for row in self.items:
			if row.line_type == "serialized":
				assert_serial_available(
					row.serial_no,
					self.start_date,
					self.end_date,
					exclude_rental=self.name,
				)
			else:
				assert_qty_available(row.item_code, row.qty, warehouse)

	def _snapshot_daily_rates(self):
		for row in self.items:
			if row.daily_rate_snapshot:
				continue
			rate = frappe.db.get_value("Item", row.item_code, "standard_rate") or 0
			row.daily_rate_snapshot = rate

	@frappe.whitelist()
	def return_rental(self):
		if self.docstatus != 1:
			frappe.throw(_("Only submitted rentals can be returned."))
		if self.status != "Active":
			frappe.throw(_("Only Active rentals can be returned."))
		self.db_set("status", "Returned", update_modified=True)
		return {"name": self.name, "status": "Returned"}


def mark_overdue_rentals():
	"""Scheduled job: Active rentals past end_date → Overdue."""
	today = getdate()
	rentals = frappe.get_all(
		"Equipment Rental",
		filters={
			"status": "Active",
			"docstatus": 1,
			"end_date": ("<", today),
		},
		pluck="name",
	)
	for name in rentals:
		frappe.db.set_value("Equipment Rental", name, "status", "Overdue", update_modified=True)
