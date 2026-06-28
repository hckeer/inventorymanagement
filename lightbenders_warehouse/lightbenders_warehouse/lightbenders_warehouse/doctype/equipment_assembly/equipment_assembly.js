frappe.ui.form.on("Equipment Assembly", {
	refresh(frm) {
		frm.set_df_property("components", "cannot_add_rows", false);
	},
});
