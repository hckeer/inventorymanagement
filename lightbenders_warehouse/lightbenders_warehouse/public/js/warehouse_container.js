frappe.ui.form.on("Warehouse Container", {
	refresh(frm) {
		frm.set_query("warehouse", () => ({
			filters: {
				is_group: 0,
			},
		}));
	},
});

frappe.ui.form.on("Warehouse Container Expected Content", {
	equipment_assembly(frm, cdt, cdn) {
		const row = locals[cdt][cdn];
		if (row.equipment_assembly) {
			frappe.model.set_value(cdt, cdn, "item_code", "");
		}
	},
	item_code(frm, cdt, cdn) {
		const row = locals[cdt][cdn];
		if (row.item_code) {
			frappe.model.set_value(cdt, cdn, "equipment_assembly", "");
		}
	},
});
