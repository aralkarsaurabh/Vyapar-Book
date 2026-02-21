import { generateCreditNoteHTML } from './credit-note-html-template';
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

export async function generateCreditNotePDF(
  creditNoteId: number,
  userId: number
): Promise<Buffer> {

  // 1️⃣ Fetch credit note
  const creditNoteResult = await query(
    `SELECT cn.*,
            c.customer_name, c.customer_type, c.gst_number as customer_gst, c.pan_number as customer_pan,
            c.contact_person, c.email as customer_email, c.phone as customer_phone,
            c.address_line1 as customer_address_line1, c.address_line2 as customer_address_line2,
            c.city as customer_city, c.state as customer_state, c.pincode as customer_pincode,
            c.country as customer_country,
            comp.company_legal_name as company_name, comp.gstin as company_gst, comp.pan as company_pan,
            comp.address_line1 as company_address_line1, comp.address_line2 as company_address_line2,
            comp.city as company_city, comp.state as company_state, comp.pincode as company_pincode,
            comp.country as company_country,
            comp.phone as company_phone, comp.email as company_email,
            comp.website as company_website,
            comp.company_logo,
            inv.invoice_number as original_invoice_number,
            inv.invoice_date as original_invoice_date
     FROM credit_notes cn
     JOIN customers c ON cn.customer_id = c.customer_id
     JOIN company_profiles comp ON cn.company_id = comp.company_id
     LEFT JOIN tax_invoices inv ON cn.original_invoice_id = inv.invoice_id
     WHERE cn.credit_note_id = $1 AND cn.user_id = $2`,
    [creditNoteId, userId]
  );

  if (creditNoteResult.rows.length === 0) {
    throw new Error('Credit note not found');
  }

  // 2️⃣ Fetch items
  const itemsResult = await query(
    `SELECT * FROM credit_note_items
     WHERE credit_note_id = $1
     ORDER BY line_number`,
    [creditNoteId]
  );

  // 3️⃣ Normalize data
  const creditNoteData = normalizeObject(creditNoteResult.rows[0]);
  const itemsData = normalizeObject(itemsResult.rows);

  // 4️⃣ Generate HTML
  const html = generateCreditNoteHTML({
    creditNote: creditNoteData,
    items: itemsData,
  });

  // 5️⃣ Generate PDF with Puppeteer
  return await generatePDFFromHTML(html);
}
