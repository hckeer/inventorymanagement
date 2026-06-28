import { ErpnextError } from "./erpnext_client.js";

export class ErpnextSessionClient {
  constructor(
    private readonly baseUrl: string,
    private readonly sid: string,
  ) {}

  async listResource<T>(
    doctype: string,
    params: {
      fields?: string[];
      filters?: unknown[][];
      limit?: number;
      orderBy?: string;
    } = {},
  ): Promise<T[]> {
    const search = new URLSearchParams();
    if (params.fields?.length) {
      search.set("fields", JSON.stringify(params.fields));
    }
    if (params.filters?.length) {
      search.set("filters", JSON.stringify(params.filters));
    }
    if (params.limit !== undefined) {
      search.set("limit_page_length", String(params.limit));
    }
    if (params.orderBy) {
      search.set("order_by", params.orderBy);
    }

    const encodedDoctype = encodeURIComponent(doctype);
    const query = search.toString();
    const path = `/api/resource/${encodedDoctype}${query ? `?${query}` : ""}`;
    const response = await this.request<{ data: T[] }>("GET", path);
    return response.data;
  }

  async getResource<T>(doctype: string, name: string): Promise<T> {
    const encodedDoctype = encodeURIComponent(doctype);
    const encodedName = encodeURIComponent(name);
    const response = await this.request<{ data: T }>(
      "GET",
      `/api/resource/${encodedDoctype}/${encodedName}`,
    );
    return response.data;
  }

  async getCount(doctype: string, filters: unknown[][] = []): Promise<number> {
    const params = new URLSearchParams({
      doctype,
      filters: JSON.stringify(filters),
    });
    const response = await this.request<{ message: number }>(
      "GET",
      `/api/method/frappe.client.get_count?${params.toString()}`,
    );
    return Number(response.message ?? 0);
  }

  async createResource<T>(doctype: string, data: Record<string, unknown>): Promise<T> {
    const encodedDoctype = encodeURIComponent(doctype);
    const response = await this.request<{ data: T }>("POST", `/api/resource/${encodedDoctype}`, {
      data,
    });
    return response.data;
  }

  async updateResource<T>(
    doctype: string,
    name: string,
    data: Record<string, unknown>,
  ): Promise<T> {
    const encodedDoctype = encodeURIComponent(doctype);
    const encodedName = encodeURIComponent(name);
    const response = await this.request<{ data: T }>(
      "PUT",
      `/api/resource/${encodedDoctype}/${encodedName}`,
      { data },
    );
    return response.data;
  }

  async callMethod<T>(method: string, params: Record<string, string> = {}): Promise<T> {
    const search = new URLSearchParams(params);
    const query = search.toString();
    const path = `/api/method/${method}${query ? `?${query}` : ""}`;
    const response = await this.request<{ message: T }>("GET", path);
    return response.message;
  }

  async resolveCompany(): Promise<string> {
    const fromDefaults = await this.callMethod<string>(
      "frappe.client.get_single_value",
      {
        doctype: "Global Defaults",
        field: "default_company",
      },
    );
    if (fromDefaults) {
      return fromDefaults;
    }

    const companies = await this.listResource<{ name: string }>("Company", {
      fields: ["name"],
      limit: 1,
    });
    const company = companies[0]?.name;
    if (!company) {
      throw new ErpnextError("No company configured in ERPNext", 500);
    }
    return company;
  }

  async resolveRentalWarehouse(company?: string): Promise<string> {
    const resolvedCompany = company ?? (await this.resolveCompany());
    const abbr = await this.getResource<{ abbr: string }>("Company", resolvedCompany);
    const warehouse = `Main Store Floor - ${abbr.abbr}`;
    const exists = await this.listResource<{ name: string }>("Warehouse", {
      fields: ["name"],
      filters: [["Warehouse", "name", "=", warehouse]],
      limit: 1,
    });
    if (!exists.length) {
      throw new ErpnextError(
        `Rental warehouse ${warehouse} not found. Run pilot seed or create Main Store Floor.`,
        422,
      );
    }
    return warehouse;
  }

  async getStockBalance(itemCode: string, warehouse: string): Promise<number> {
    const balance = await this.callMethod<number>("erpnext.stock.utils.get_stock_balance", {
      item_code: itemCode,
      warehouse,
    });
    return Number(balance ?? 0);
  }

  async submitDocument(doctype: string, name: string): Promise<void> {
    const doc = await this.getResource<Record<string, unknown>>(doctype, name);
    await this.request("POST", "/api/method/frappe.client.submit", { doc });
  }

  async runDocMethod<T>(
    doctype: string,
    name: string,
    method: string,
  ): Promise<T> {
    const encodedDoctype = encodeURIComponent(doctype);
    const encodedName = encodeURIComponent(name);
    const response = await this.request<{ data?: T; message?: T }>(
      "POST",
      `/api/resource/${encodedDoctype}/${encodedName}?run_method=${encodeURIComponent(method)}`,
    );
    return (response.data ?? response.message) as T;
  }

  private async request<T>(method: string, path: string, body?: unknown): Promise<T> {
    const url = `${this.baseUrl}${path}`;
    const headers: Record<string, string> = {
      Accept: "application/json",
      Cookie: `sid=${this.sid}`,
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
