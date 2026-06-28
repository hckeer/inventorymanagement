app_name = "lightbenders_warehouse"
app_title = "Lightbenders Warehouse"
app_publisher = "Lightbenders"
app_description = "Warehouse containers, equipment assemblies, and pilot inventory seed for film equipment rental."
app_email = "ops@lightbenders.com"
app_license = "MIT"
app_version = "0.1.0"

required_apps = ["erpnext"]

# DocTypes ship as JSON in-repo; no transactional fixtures (Items/Warehouses use seed script).
fixtures = []

doctype_js = {
	"Warehouse Container": "public/js/warehouse_container.js",
}

after_install = "lightbenders_warehouse.setup.install.after_install"

doc_events = {
	"Equipment Assembly": {
		"validate": "lightbenders_warehouse.lightbenders_warehouse.doctype.equipment_assembly.equipment_assembly.validate",
	},
	"Warehouse Container": {
		"validate": "lightbenders_warehouse.lightbenders_warehouse.doctype.warehouse_container.warehouse_container.validate",
	},
}

scheduler_events = {
	"daily": [
		"lightbenders_warehouse.lightbenders_warehouse.doctype.equipment_rental.equipment_rental.mark_overdue_rentals",
	],
}
