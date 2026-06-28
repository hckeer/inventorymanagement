# Copyright (c) 2026, Lightbenders and contributors
# For license information, please see license.txt

import frappe

from lightbenders_warehouse.setup.custom_fields import ensure_customer_id_document


def after_install():
	ensure_customer_id_document()
	frappe.logger().info(
		"lightbenders_warehouse installed. Run seed: "
		"bench --site SITE execute lightbenders_warehouse.setup.seed_pilot.seed_all"
	)
