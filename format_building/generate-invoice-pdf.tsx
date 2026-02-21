import { generateInvoiceHTML } from './invoice-html-template';
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

export async function generateInvoicePDF(
  invoiceId: number,
  userId: number
): Promise<Buffer> {

  // 1️⃣ Fetch invoice
  const invoiceResult = await query(
    `SELECT i.*,
            c.customer_name, c.customer_type, c.gst_number as customer_gst, c.pan_number as customer_pan,
            c.contact_person, c.email as customer_email, c.phone as customer_phone,
            c.address_line1 as customer_address_line1, c.address_line2 as customer_address_line2,
            c.city as customer_city, c.state as customer_state, c.pincode as customer_pincode,
            c.country as customer_country,
            CASE WHEN c.gst_number IS NOT NULL AND LENGTH(c.gst_number) >= 2
                 THEN SUBSTRING(c.gst_number FROM 1 FOR 2)
                 ELSE NULL
            END as customer_state_code,
            comp.company_legal_name as company_name, comp.gstin as company_gst, comp.pan as company_pan,
            comp.address_line1 as company_address_line1, comp.address_line2 as company_address_line2,
            comp.city as company_city, comp.state as company_state, comp.pincode as company_pincode,
            comp.country as company_country,
            comp.phone as company_phone, comp.email as company_email,
            comp.website as company_website,
            comp.gst_state_code as company_state_code,
            comp.bank_name, comp.bank_account_number, comp.bank_ifsc, comp.bank_branch,
            comp.company_logo
     FROM tax_invoices i
     JOIN customers c ON i.customer_id = c.customer_id
     JOIN company_profiles comp ON i.company_id = comp.company_id
     WHERE i.invoice_id = $1 AND i.user_id = $2`,
    [invoiceId, userId]
  );

  if (invoiceResult.rows.length === 0) {
    throw new Error('Invoice not found');
  }

  // 2️⃣ Fetch items
  const itemsResult = await query(
    `SELECT * FROM tax_invoice_items
     WHERE invoice_id = $1
     ORDER BY line_number`,
    [invoiceId]
  );

  // 3️⃣ Normalize data (CRITICAL FIX)
  const invoiceData = normalizeObject(invoiceResult.rows[0]);
  const itemsData = normalizeObject(itemsResult.rows);

  // 4️⃣ Generate HTML
  const html = generateInvoiceHTML({
    invoice: invoiceData,
    items: itemsData,
  });

  // 5️⃣ Generate PDF with Puppeteer
  return await generatePDFFromHTML(html);
}
