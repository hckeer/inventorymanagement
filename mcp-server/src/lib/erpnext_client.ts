import type { AppConfig } from "./config.js";
import type {
  AssemblyComponent,
  ExpectedContentRow,
  SerialNoDoc,
  WarehouseContainerDoc,
} from "./types.js";

export class ErpnextError extends Error {
  constructor(
    message: string,
    readonly status: number,
    readonly detail?: unknown,
  ) {
    super(message);
    this.name = "ErpnextError";
  }
}

export class ErpnextClient {
  constructor(private readonly config: AppConfig) {}

  async getDocument<T>(doctype: string, name: string): Promise<T> {
    const encodedDoctype = encodeURIComponent(doctype);
    const encodedName = encodeURIComponent(name);
    return this.request<T>(
      "GET",
      `/api/resource/${encodedDoctype}/${encodedName}`,
    );
  }

  async getWarehouseContainer(
    containerBarcode: string,
  ): Promise<WarehouseContainerDoc> {
    const response = await this.getDocument<{ data: WarehouseContainerDoc }>(
      "Warehouse Container",
      containerBarcode,
    );
    return response.data;
  }

  async getAssemblyComponents(
    assemblyName: string,
  ): Promise<AssemblyComponent[]> {
    const response = await this.getDocument<{
      data: { components: Array<{ item_code: string; qty: number }> };
    }>("Equipment Assembly", assemblyName);

    return response.data.components.map((row) => ({
      item_code: row.item_code,
      qty: Number(row.qty),
    }));
  }

  async resolveLocation(barcode: string): Promise<{
    barcode: string;
    label: string;
    warehouse: string;
    container_type?: string;
    expected_contents?: ExpectedContentRow[];
  }> {
    try {
      const container = await this.getWarehouseContainer(barcode);
      return {
        barcode: container.container_barcode,
        label: container.label,
        warehouse: container.warehouse,
        container_type: container.container_type,
        expected_contents: container.expected_contents,
      };
    } catch (error) {
      if (!(error instanceof ErpnextError) || error.status !== 404) {
        throw error;
      }
    }

    const warehouse = await this.findWarehouseByBarcode(barcode);
    if (warehouse) {
      return warehouse;
    }

    throw new ErpnextError(
      `No warehouse container or warehouse found for barcode: ${barcode}`,
      404,
    );
  }

  async findWarehouseByBarcode(barcode: string): Promise<{
    barcode: string;
    label: string;
    warehouse: string;
  } | null> {
    const normalizedName = barcodeToWarehouseBaseName(barcode);
    if (normalizedName) {
      const exact = await this.findWarehouseByBaseName(normalizedName);
      if (exact) {
        return { barcode, label: exact.warehouse_name, warehouse: exact.name };
      }
    }

    const filters = JSON.stringify([
      ["Warehouse", "name", "like", `%${barcode}%`],
    ]);
    const fields = JSON.stringify(["name", "warehouse_name"]);
    const response = await this.request<{ data: Array<{ name: string; warehouse_name: string }> }>(
      "GET",
      `/api/resource/Warehouse?filters=${encodeURIComponent(filters)}&fields=${encodeURIComponent(fields)}&limit_page_length=5`,
    );

    const exact = response.data.find(
      (row) =>
        row.name === barcode ||
        row.warehouse_name === barcode ||
        row.name.replace(/\s+/g, "-").toUpperCase() === barcode.toUpperCase(),
    );
    const match = exact ?? response.data[0];
    if (!match) {
      return null;
    }

    return {
      barcode,
      label: match.warehouse_name,
      warehouse: match.name,
    };
  }

  private async findWarehouseByBaseName(
    warehouseBase: string,
  ): Promise<{ name: string; warehouse_name: string } | null> {
    const filters = JSON.stringify([
      ["Warehouse", "warehouse_name", "=", warehouseBase],
    ]);
    const fields = JSON.stringify(["name", "warehouse_name"]);
    const response = await this.request<{ data: Array<{ name: string; warehouse_name: string }> }>(
      "GET",
      `/api/resource/Warehouse?filters=${encodeURIComponent(filters)}&fields=${encodeURIComponent(fields)}&limit_page_length=1`,
    );
    return response.data[0] ?? null;
  }

  async getStockBalanceByItem(warehouse: string): Promise<Record<string, number>> {
    const filters = JSON.stringify([
      ["Serial No", "warehouse", "=", warehouse],
      ["Serial No", "status", "!=", "Delivered"],
    ]);
    const fields = JSON.stringify(["name", "item_code"]);
    const response = await this.request<{ data: SerialNoDoc[] }>(
      "GET",
      `/api/resource/Serial No?filters=${encodeURIComponent(filters)}&fields=${encodeURIComponent(fields)}&limit_page_length=5000`,
    );

    const balances: Record<string, number> = {};
    for (const serial of response.data) {
      balances[serial.item_code] = (balances[serial.item_code] ?? 0) + 1;
    }
    return balances;
  }

  async getSerialNo(serial: string): Promise<SerialNoDoc> {
    const response = await this.getDocument<{ data: SerialNoDoc }>(
      "Serial No",
      serial,
    );
    return response.data;
  }

  async createMaterialTransfer(input: {
    company: string;
    sourceWarehouse: string;
    destWarehouse: string;
    serials: Array<{ item_code: string; serial: string }>;
    remark?: string;
  }): Promise<string> {
    const grouped = new Map<string, string[]>();
    for (const entry of input.serials) {
      const list = grouped.get(entry.item_code) ?? [];
      list.push(entry.serial);
      grouped.set(entry.item_code, list);
    }

    const items = [...grouped.entries()].map(([itemCode, serialList]) => ({
      item_code: itemCode,
      qty: serialList.length,
      s_warehouse: input.sourceWarehouse,
      t_warehouse: input.destWarehouse,
      use_serial_batch_fields: 1,
      serial_no: serialList.join("\n"),
      allow_zero_valuation_rate: 1,
    }));

    const response = await this.request<{ data: { name: string } }>(
      "POST",
      "/api/resource/Stock Entry",
      {
        doctype: "Stock Entry",
        stock_entry_type: "Material Transfer",
        company: input.company,
        remarks: input.remark,
        items,
      },
    );

    const stockEntryName = response.data.name;
    await this.submitDocument("Stock Entry", stockEntryName);
    return stockEntryName;
  }

  async resolveCompany(): Promise<string> {
    if (this.config.company) {
      return this.config.company;
    }

    const response = await this.request<{ message: string }>(
      "GET",
      "/api/method/frappe.client.get_single_value?doctype=Global%20Defaults&field=default_company",
    );
    if (response.message) {
      return response.message;
    }

    const companies = await this.request<{ data: Array<{ name: string }> }>(
      "GET",
      "/api/resource/Company?fields=%5B%22name%22%5D&limit_page_length=1",
    );
    const company = companies.data[0]?.name;
    if (!company) {
      throw new ErpnextError("No company configured in ERPNext", 500);
    }
    return company;
  }

  private async submitDocument(doctype: string, name: string): Promise<void> {
    await this.request(
      "POST",
      `/api/method/frappe.client.submit`,
      { doc: { doctype, name } },
    );
  }

  private async request<T>(
    method: string,
    path: string,
    body?: unknown,
  ): Promise<T> {
    const url = `${this.config.erpnextUrl}${path}`;
    const headers: Record<string, string> = {
      Authorization: `token ${this.config.erpnextApiKey}:${this.config.erpnextApiSecret}`,
      Accept: "application/json",
    };

    const init: RequestInit = { method, headers };
    if (body !== undefined) {
      headers["Content-Type"] = "application/json";
      init.body = JSON.stringify(body);
    }

    const response = await fetch(url, init);
    const text = await response.text();
    let payload: unknown = null;
    if (text) {
      try {
        payload = JSON.parse(text);
      } catch {
        payload = text;
      }
    }

    if (!response.ok) {
      const detail =
        typeof payload === "object" && payload !== null
          ? (payload as { message?: string; exc?: string }).message ??
            (payload as { exc?: string }).exc
          : text;
      throw new ErpnextError(
        detail || `ERPNext request failed (${response.status})`,
        response.status,
        payload,
      );
    }

    return payload as T;
  }
}

function barcodeToWarehouseBaseName(barcode: string): string | null {
  const truckMatch = /^TRUCK-(\d+)$/i.exec(barcode.trim());
  if (truckMatch) {
    return `Truck ${truckMatch[1]}`;
  }
  return null;
}
