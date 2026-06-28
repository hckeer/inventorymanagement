# Copyright (c) 2026, Lightbenders and contributors
# For license information, please see license.txt

import frappe

from lightbenders_warehouse.setup.seed_pilot import seed_all


def execute():
	seed_all()
