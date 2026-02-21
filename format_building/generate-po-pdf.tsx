import { generatePurchaseOrderHTML } from './purchase-order-html-template';
import { generatePDFFromHTML } from './puppeteer-helper';
import { query } from '@/lib/db';

function normalizeValue(value: any) {
  if (typeof value === 'bigint') return Number(value);
  if (value instanceof Date) return value.toISOString();
  if (typeof value === 'string' && !isNaN(Number(value))) {
    return Number(value);
  }
  return value;
}

function normalizeObject<T>(obj: T): T {
  return JSON.parse(
    JSON.stringify(obj, (_, value) => normalizeValue(value))
  );
}

export async function generatePurchaseOrderPDF(
  poId: number,
  userId: number
): Promise<Buffer> {

  // 1️⃣ Fetch purchase order
  const poResult = await query(
    `SELECT po.*,
            v.vendor_name, v.vendor_type, v.gst_number as vendor_gst, v.pan_number as vendor_pan,
            v.contact_person as vendor_contact_person, v.email as vendor_email, v.phone as vendor_phone,
            v.address_line1 as vendor_address_line_1, v.address_line2 as vendor_address_line_2,
            v.city as vendor_city, v.state as vendor_state, v.pincode as vendor_pincode,
            v.place_of_supply as vendor_place_of_supply,
            comp.company_legal_name, comp.trade_name, comp.gstin, comp.pan,
            comp.address_line1 as company_address_line_1, comp.address_line2 as company_address_line_2,
            comp.city as company_city, comp.state as company_state, comp.pincode as company_pincode,
            comp.phone as company_phone, comp.email as company_email,
            comp.bank_name, comp.bank_account_number, comp.bank_ifsc, comp.bank_branch,
            comp.company_logo
     FROM purchase_orders po
     JOIN vendors v ON po.vendor_id = v.vendor_id
     JOIN company_profiles comp ON po.company_id = comp.company_id
     WHERE po.po_id = $1 AND po.user_id = $2`,
    [poId, userId]
  );

  if (poResult.rows.length === 0) {
    throw new Error('Purchase order not found');
  }

  // 2️⃣ Fetch items
  const itemsResult = await query(
    `SELECT * FROM purchase_order_items
     WHERE po_id = $1
     ORDER BY line_number`,
    [poId]
  );

  // 3️⃣ Normalize data (CRITICAL FIX)
  const poData = normalizeObject(poResult.rows[0]);
  const itemsData = normalizeObject(itemsResult.rows);

  // 4️⃣ Generate HTML
  const html = generatePurchaseOrderHTML({
    po: poData,
    items: itemsData,
  });

  // 5️⃣ Generate PDF with Puppeteer
  return await generatePDFFromHTML(html);
}
