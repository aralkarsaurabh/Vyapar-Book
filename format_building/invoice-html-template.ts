import { formatDate, amountToWords } from '@/lib/format';

function safeText(value: any): string {
  if (value === null || value === undefined) return '';
  if (typeof value === 'string') return value;
  if (typeof value === 'number') return String(value);
  return String(value);
}

// PDF-specific INR formatter with Indian number formatting
function formatINRForPDF(amount: number): string {
  const [integer, decimal] = amount.toFixed(2).split('.');
  const lastThree = integer.slice(-3);
  const otherDigits = integer.slice(0, -3);
  const formatted =
    otherDigits.length > 0
      ? otherDigits.replace(/\B(?=(\d{2})+(?!\d))/g, ',') + ',' + lastThree
      : lastThree;
  return `${formatted}.${decimal}`;
}

interface InvoiceData {
  invoice: any;
  items: any[];
}

export function generateInvoiceHTML({ invoice, items }: InvoiceData): string {
  const isIntraState = invoice.company_state === invoice.customer_state;

  // Calculate tax breakdown by HSN/SAC
  const taxBreakdown: { [key: string]: { taxable: number; cgst_rate: number; cgst_amount: number; sgst_rate: number; sgst_amount: number; igst_rate: number; igst_amount: number; total_tax: number } } = {};

  items.forEach(item => {
    const hsn = safeText(item.hsn_sac_code) || 'N/A';
    if (!taxBreakdown[hsn]) {
      taxBreakdown[hsn] = {
        taxable: 0,
        cgst_rate: Number(item.cgst_rate || 0),
        cgst_amount: 0,
        sgst_rate: Number(item.sgst_rate || 0),
        sgst_amount: 0,
        igst_rate: Number(item.igst_rate || 0),
        igst_amount: 0,
        total_tax: 0
      };
    }
    taxBreakdown[hsn].taxable += Number(item.taxable_amount || 0);
    taxBreakdown[hsn].cgst_amount += Number(item.cgst_amount || 0);
    taxBreakdown[hsn].sgst_amount += Number(item.sgst_amount || 0);
    taxBreakdown[hsn].igst_amount += Number(item.igst_amount || 0);
    taxBreakdown[hsn].total_tax += Number(item.cgst_amount || 0) + Number(item.sgst_amount || 0) + Number(item.igst_amount || 0);
  });

  // Calculate total quantity
  const totalQuantity = items.reduce((sum, item) => sum + Number(item.quantity || 0), 0);

  // Max rows for items table - filler rows ensure continuous vertical borders
  const MAX_ROWS = 15;
  const emptyRows = Math.max(0, MAX_ROWS - items.length);

  return `
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Tax Invoice - ${safeText(invoice.invoice_number)}</title>
  <style>
    @page {
      size: A4;
      margin: 10mm;
    }

    * {
      margin: 0;
      padding: 0;
      box-sizing: border-box;
    }

    body {
      font-family: Arial, Helvetica, sans-serif;
      font-size: 10px;
      line-height: 1.3;
      color: #000;
      background: #fff;
    }

    .invoice-page {
      width: 100%;
      max-width: 210mm;
      margin: 0 auto;
    }

    /* Title */
    .title {
      text-align: center;
      font-size: 16px;
      font-weight: bold;
      padding: 10px 0;
      border-bottom: 1px solid #000;
    }

    /* Main Box */
    .main-box {
      border: 1px solid #000;
      border-top: none;
    }

    .main-row {
      display: flex;
    }

    /* Left Column */
    .left-col {
      width: 50%;
      border-right: 1px solid #000;
    }

    /* Company Header with Logo */
    .company-header {
      display: flex;
      padding: 0;
      border-bottom: 1px solid #000;
    }

    .logo-box {
      width: 70px;
      min-height: 80px;
      display: flex;
      align-items: center;
      justify-content: center;
      border-right: 1px solid #000;
      padding: 4px;
      background: #fff;
    }

    .logo-box img {
      max-width: 100%;
      max-height: 72px;
      object-fit: contain;
    }

    .logo-placeholder {
      width: 100%;
      height: 72px;
      background: linear-gradient(135deg, #E67E22 0%, #F39C12 50%, #E67E22 100%);
      display: flex;
      align-items: center;
      justify-content: center;
    }

    .logo-triangle {
      width: 0;
      height: 0;
      border-left: 20px solid transparent;
      border-right: 20px solid transparent;
      border-bottom: 35px solid #fff;
    }

    .company-info {
      flex: 1;
      padding: 6px 8px;
      font-size: 9px;
      line-height: 1.4;
    }

    .company-name {
      font-size: 11px;
      font-weight: bold;
      margin-bottom: 1px;
    }

    /* Consignee Section */
    .consignee-section {
      padding: 8px;
      border-bottom: 1px solid #000;
    }

    /* Buyer Section */
    .buyer-section {
      padding: 8px;
    }

    .buyer-label {
      font-size: 10px;
      font-weight: normal;
      margin-bottom: 2px;
    }

    .buyer-name {
      font-size: 11px;
      font-weight: bold;
      margin-bottom: 2px;
    }

    .buyer-details {
      font-size: 9px;
      line-height: 1.4;
    }

    /* Right Column - Invoice Details */
    .right-col {
      width: 50%;
    }

    .detail-row {
      display: flex;
      border-bottom: 1px solid #000;
      min-height: 18px;
    }

    .detail-row:last-child {
      border-bottom: none;
    }

    .detail-cell {
      display: flex;
      align-items: center;
      padding: 2px 5px;
      font-size: 9px;
      border-right: 1px solid #000;
    }

    .detail-cell:last-child {
      border-right: none;
    }

    /* For column widths */
    .w25 { width: 25%; }
    .w50 { width: 50%; }
    .w100 { width: 100%; }

    /* Items Section - container draws left/bottom borders only, cells own vertical borders */
    .items-section {
      border: 1px solid #000;
      border-top: none;
      border-right: none; /* Last column draws the right border */
    }

    /* Items Header */
    .items-header {
      display: flex;
      border-bottom: 1px solid #000;
      background: #fff;
    }

    .items-header > div {
      padding: 4px 3px;
      font-size: 9px;
      font-weight: bold;
      text-align: center;
      border-right: 1px solid #000;
    }

    /* Last column draws right outer border - NO exceptions */

    /* Items Body - NO horizontal borders between items */
    .items-body {
      min-height: 250px;
    }

    .item-row {
      display: flex;
      min-height: 20px;
    }

    .item-row > div {
      display: flex;
      align-items: center;
      align-self: stretch;
      padding: 3px 3px;
      font-size: 9px;
      border-right: 1px solid #000;
    }

    /* Last column draws right outer border - NO exceptions */

    /* Column widths for items - using flex for consistent sizing */
    .col-sl { flex: 0 0 4%; text-align: center; justify-content: center; }
    .col-desc { flex: 0 0 28%; text-align: left; }
    .col-hsn { flex: 0 0 10%; text-align: center; justify-content: center; }
    .col-qty { flex: 0 0 14%; text-align: right; justify-content: flex-end; }
    .col-rate { flex: 0 0 14%; text-align: right; justify-content: flex-end; }
    .col-per { flex: 0 0 8%; text-align: center; justify-content: center; }
    .col-amt { flex: 0 0 22%; text-align: right; justify-content: flex-end; }

    .item-name {
      font-weight: bold;
    }

    .item-batch {
      font-size: 8px;
      margin-left: 10px;
    }

    .qty-bold {
      font-weight: bold;
    }

    .gst-row {
      min-height: 20px;
    }

    .gst-row > div {
      padding: 2px 3px;
    }

    /* gst-row inherits border-right from .item-row > div */

    .gst-label {
      font-style: italic;
    }

    /* Total Row */
    .total-row {
      display: flex;
      align-items: stretch;
      min-height: 26px;
      border-top: 1px solid #000;
    }

    .total-row > div {
      display: flex;
      align-items: center;
      padding: 4px 3px;
      font-size: 9px;
      font-weight: bold;
      border-right: 1px solid #000;
    }

    /* Last column draws right outer border - NO exceptions */

    .grand-total {
      font-size: 12px;
      font-weight: bold;
    }

    /* Amount in Words */
    .amount-words {
      display: flex;
      justify-content: space-between;
      border: 1px solid #000;
      border-top: none;
      padding: 5px 8px;
    }

    .amount-words-left {
      font-size: 9px;
    }

    .amount-words-value {
      font-weight: bold;
    }

    .amount-words-right {
      font-size: 9px;
      align-self: flex-end;
    }

    /* Tax Table */
    .tax-table {
      width: 100%;
      border-collapse: collapse;
      border: 1px solid #000;
      border-top: none;
    }

    .tax-table th,
    .tax-table td {
      border: 1px solid #000;
      padding: 3px 4px;
      font-size: 8px;
      text-align: center;
    }

    .tax-table th {
      font-weight: bold;
    }

    .text-right {
      text-align: right !important;
    }

    /* Tax Amount in Words */
    .tax-words {
      font-size: 9px;
      padding: 4px 8px;
      border: 1px solid #000;
      border-top: none;
    }

    /* Footer */
    .footer {
      display: flex;
      border: 1px solid #000;
      border-top: none;
    }

    .footer-left {
      width: 60%;
      padding: 8px;
      font-size: 8px;
      border-right: 1px solid #000;
      line-height: 1.4;
    }

    .footer-right {
      width: 40%;
      padding: 8px;
      text-align: right;
      font-size: 9px;
      display: flex;
      flex-direction: column;
      justify-content: space-between;
      min-height: 60px;
    }

    .signature {
      font-weight: bold;
    }

    .computer-note {
      text-align: center;
      font-size: 9px;
      padding: 5px;
      border: 1px solid #000;
      border-top: none;
    }

    @media print {
      body { -webkit-print-color-adjust: exact; print-color-adjust: exact; }
      .logo-placeholder { background: linear-gradient(135deg, #E67E22 0%, #F39C12 50%, #E67E22 100%) !important; }
    }
  </style>
</head>
<body>
  <div class="invoice-page">
    <!-- Title -->
    <div class="title">Tax Invoice</div>

    <!-- Main Box -->
    <div class="main-box">
      <div class="main-row">
        <!-- Left Column: Company + Consignee + Buyer -->
        <div class="left-col">
          <!-- Company Header with Logo -->
          <div class="company-header">
            <div class="logo-box">
              ${invoice.company_logo
                ? `<img src="${safeText(invoice.company_logo)}" alt="Company Logo" />`
                : `<div class="logo-placeholder"><div class="logo-triangle"></div></div>`
              }
            </div>
            <div class="company-info">
              <div class="company-name">${safeText(invoice.company_name)}</div>
              ${invoice.company_address_line1 ? `<div>${safeText(invoice.company_address_line1)},</div>` : ''}
              ${invoice.company_address_line2 ? `<div>${safeText(invoice.company_address_line2)}</div>` : ''}
              ${invoice.company_city ? `<div>${safeText(invoice.company_city)}</div>` : ''}
              <div>GSTIN/UIN: ${safeText(invoice.company_gst) || 'N/A'}</div>
              <div>State Name : ${safeText(invoice.company_state)}, Code : ${safeText(invoice.company_state_code) || ''}</div>
              ${invoice.company_email ? `<div>E-Mail : ${safeText(invoice.company_email)}</div>` : ''}
            </div>
          </div>

          <!-- Consignee (Ship to) Section -->
          <div class="consignee-section">
            <div class="buyer-label">Consignee (Ship to)</div>
            <div class="buyer-name">${safeText(invoice.customer_name)}</div>
            <div class="buyer-details">
              ${invoice.customer_address_line1 ? `${safeText(invoice.customer_address_line1)}<br>` : ''}
              ${invoice.customer_address_line2 ? `${safeText(invoice.customer_address_line2)}<br>` : ''}
              ${invoice.customer_city ? `${safeText(invoice.customer_city)}<br>` : ''}
              ${invoice.customer_gst ? `GSTIN/UIN : ${safeText(invoice.customer_gst)}<br>` : ''}
              State Name : ${safeText(invoice.customer_state)}, Code : ${safeText(invoice.customer_state_code) || ''}
            </div>
          </div>

          <!-- Buyer (Bill to) Section -->
          <div class="buyer-section">
            <div class="buyer-label">Buyer (Bill to)</div>
            <div class="buyer-name">${safeText(invoice.customer_name)}</div>
            <div class="buyer-details">
              ${invoice.customer_address_line1 ? `${safeText(invoice.customer_address_line1)}<br>` : ''}
              ${invoice.customer_address_line2 ? `${safeText(invoice.customer_address_line2)}<br>` : ''}
              ${invoice.customer_city ? `${safeText(invoice.customer_city)}<br>` : ''}
              ${invoice.customer_gst ? `GSTIN/UIN : ${safeText(invoice.customer_gst)}<br>` : ''}
              State Name : ${safeText(invoice.customer_state)}, Code : ${safeText(invoice.customer_state_code) || ''}
            </div>
          </div>
        </div>

        <!-- Right Column: Invoice Details -->
        <div class="right-col">
          <div class="detail-row">
            <div class="detail-cell w25">Invoice No.</div>
            <div class="detail-cell w25">${safeText(invoice.invoice_number)}</div>
            <div class="detail-cell w25">Dated</div>
            <div class="detail-cell w25">${formatDate(invoice.invoice_date)}</div>
          </div>
          <div class="detail-row">
            <div class="detail-cell w25">Delivery Note</div>
            <div class="detail-cell w25"></div>
            <div class="detail-cell w50">Mode/Terms of Payment</div>
          </div>
          <div class="detail-row">
            <div class="detail-cell w25">Supplier's Ref.</div>
            <div class="detail-cell w25"></div>
            <div class="detail-cell w50">Other Reference(s)</div>
          </div>
          <div class="detail-row">
            <div class="detail-cell w25">Buyer's Order No.</div>
            <div class="detail-cell w25"></div>
            <div class="detail-cell w25">Dated</div>
            <div class="detail-cell w25"></div>
          </div>
          <div class="detail-row">
            <div class="detail-cell w25">Despatch Document No.</div>
            <div class="detail-cell w25"></div>
            <div class="detail-cell w25">Delivery Note Date</div>
            <div class="detail-cell w25"></div>
          </div>
          <div class="detail-row">
            <div class="detail-cell w25">Despatched through</div>
            <div class="detail-cell w25"></div>
            <div class="detail-cell w25">Destination</div>
            <div class="detail-cell w25">${safeText(invoice.place_of_supply) || ''}</div>
          </div>
          <div class="detail-row" style="min-height:25px;">
            <div class="detail-cell w100">Terms of Delivery</div>
          </div>
        </div>
      </div>
    </div>

    <!-- Items Section -->
    <div class="items-section">
      <!-- Header -->
      <div class="items-header">
        <div class="col-sl">Sl<br>No.</div>
        <div class="col-desc">Description of Goods</div>
        <div class="col-hsn">HSN/SAC</div>
        <div class="col-qty">Quantity</div>
        <div class="col-rate">Rate</div>
        <div class="col-per">per</div>
        <div class="col-amt">Amount</div>
      </div>

      <!-- Body -->
      <div class="items-body">
        ${items.map((item, index) => {
    const unit = safeText(item.unit_of_measure || 'Nos');
    const qty = Number(item.quantity || 0);

    return `
        <div class="item-row">
          <div class="col-sl">${index + 1}</div>
          <div class="col-desc">
            <span class="item-name">${safeText(item.item_description)}</span>
            ${item.batch_number ? `<br><span class="item-batch">Batch : ${safeText(item.batch_number)}</span>` : ''}
          </div>
          <div class="col-hsn">${safeText(item.hsn_sac_code) || ''}</div>
          <div class="col-qty qty-bold">${qty} ${unit}</div>
          <div class="col-rate">${formatINRForPDF(Number(item.rate))}</div>
          <div class="col-per">${unit}</div>
          <div class="col-amt">${formatINRForPDF(Number(item.taxable_amount))}</div>
        </div>`;
  }).join('')}

        <!-- Filler rows to maintain continuous vertical borders -->
        ${Array.from({ length: emptyRows }).map(() => `
        <div class="item-row">
          <div class="col-sl"></div>
          <div class="col-desc"></div>
          <div class="col-hsn"></div>
          <div class="col-qty"></div>
          <div class="col-rate"></div>
          <div class="col-per"></div>
          <div class="col-amt"></div>
        </div>
        `).join('')}

        <!-- Output CGST/SGST rows at the end -->
        ${invoice.invoice_type === 'GST' && isIntraState ? `
        <div class="item-row gst-row">
          <div class="col-sl"></div>
          <div class="col-desc" style="text-align:right;"><span class="gst-label">Output CGST</span></div>
          <div class="col-hsn"></div>
          <div class="col-qty"></div>
          <div class="col-rate"></div>
          <div class="col-per"></div>
          <div class="col-amt">${formatINRForPDF(Number(invoice.cgst_total))}</div>
        </div>
        <div class="item-row gst-row">
          <div class="col-sl"></div>
          <div class="col-desc" style="text-align:right;"><span class="gst-label">Output SGST</span></div>
          <div class="col-hsn"></div>
          <div class="col-qty"></div>
          <div class="col-rate"></div>
          <div class="col-per"></div>
          <div class="col-amt">${formatINRForPDF(Number(invoice.sgst_total))}</div>
        </div>
        ` : ''}

        ${invoice.invoice_type === 'GST' && !isIntraState ? `
        <div class="item-row gst-row">
          <div class="col-sl"></div>
          <div class="col-desc" style="text-align:right;"><span class="gst-label">Output IGST</span></div>
          <div class="col-hsn"></div>
          <div class="col-qty"></div>
          <div class="col-rate"></div>
          <div class="col-per"></div>
          <div class="col-amt">${formatINRForPDF(Number(invoice.igst_total))}</div>
        </div>
        ` : ''}
      </div>

      <!-- Total Row -->
      <div class="total-row">
        <div class="col-sl"></div>
        <div class="col-desc" style="text-align:right;">Total</div>
        <div class="col-hsn"></div>
        <div class="col-qty qty-bold">${totalQuantity} Nos</div>
        <div class="col-rate"></div>
        <div class="col-per"></div>
        <div class="col-amt grand-total">₹ ${formatINRForPDF(Number(invoice.grand_total))}</div>
      </div>
    </div>

    <!-- Amount in Words -->
    <div class="amount-words">
      <div class="amount-words-left">
        Amount Chargeable (in words)<br>
        <span class="amount-words-value">${amountToWords(Number(invoice.grand_total))}</span>
      </div>
      <div class="amount-words-right">E. & O.E</div>
    </div>

    <!-- Tax Summary Table -->
    ${invoice.invoice_type === 'GST' ? `
    <table class="tax-table">
      <thead>
        <tr>
          <th rowspan="2">HSN/SAC</th>
          <th rowspan="2">Taxable<br>Value</th>
          ${isIntraState ? `
          <th colspan="2">Central Tax</th>
          <th colspan="2">State Tax</th>
          ` : `
          <th colspan="2">Integrated Tax</th>
          `}
          <th rowspan="2">Total<br>Tax Amount</th>
        </tr>
        <tr>
          <th>Rate</th>
          <th>Amount</th>
          ${isIntraState ? `
          <th>Rate</th>
          <th>Amount</th>
          ` : ''}
        </tr>
      </thead>
      <tbody>
        ${Object.entries(taxBreakdown).map(([hsn, data]) => `
        <tr>
          <td>${hsn}</td>
          <td class="text-right">${formatINRForPDF(data.taxable)}</td>
          ${isIntraState ? `
          <td>${data.cgst_rate}%</td>
          <td class="text-right">${formatINRForPDF(data.cgst_amount)}</td>
          <td>${data.sgst_rate}%</td>
          <td class="text-right">${formatINRForPDF(data.sgst_amount)}</td>
          ` : `
          <td>${data.igst_rate}%</td>
          <td class="text-right">${formatINRForPDF(data.igst_amount)}</td>
          `}
          <td class="text-right">${formatINRForPDF(data.total_tax)}</td>
        </tr>
        `).join('')}
        <tr style="font-weight:bold;">
          <td>Total</td>
          <td class="text-right">${formatINRForPDF(Number(invoice.subtotal))}</td>
          ${isIntraState ? `
          <td></td>
          <td class="text-right">${formatINRForPDF(Number(invoice.cgst_total))}</td>
          <td></td>
          <td class="text-right">${formatINRForPDF(Number(invoice.sgst_total))}</td>
          ` : `
          <td></td>
          <td class="text-right">${formatINRForPDF(Number(invoice.igst_total))}</td>
          `}
          <td class="text-right">${formatINRForPDF(Number(invoice.tax_total))}</td>
        </tr>
      </tbody>
    </table>

    <!-- Tax Amount in Words -->
    <div class="tax-words">
      <strong>Tax Amount (in words) :</strong> ${amountToWords(Number(invoice.tax_total))}
    </div>
    ` : ''}

    <!-- Footer -->
    <div class="footer">
      <div class="footer-left">
        <strong>Declaration</strong><br>
        We declare that this invoice shows the actual price of the goods described and that all particulars are true and correct.
        ${invoice.notes ? `<br><br><strong>Notes:</strong><br>${safeText(invoice.notes)}` : ''}
      </div>
      <div class="footer-right">
        <div>for <strong>${safeText(invoice.company_name)}</strong></div>
        <div class="signature">Authorised Signatory</div>
      </div>
    </div>

    <!-- Computer Generated Note -->
    <div class="computer-note">This is a Computer Generated Invoice</div>
  </div>
</body>
</html>
  `.trim();
}
