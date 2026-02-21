/**
 * Purchase Order HTML Template
 * Generates HTML for PDF conversion
 */

function safeText(value) {
  if (value === null || value === undefined) return '';
  if (typeof value === 'string') return value;
  if (typeof value === 'number') return String(value);
  return String(value);
}

// Format date as DD-MMM-YYYY
function formatDate(dateValue) {
  if (!dateValue) return '';

  let date;
  if (typeof dateValue === 'string') {
    date = new Date(dateValue);
  } else if (dateValue instanceof Date) {
    date = dateValue;
  } else if (dateValue._seconds) {
    // Firestore Timestamp
    date = new Date(dateValue._seconds * 1000);
  } else {
    return '';
  }

  if (isNaN(date.getTime())) return '';

  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  const day = String(date.getDate()).padStart(2, '0');
  const month = months[date.getMonth()];
  const year = date.getFullYear();

  return `${day}-${month}-${year}`;
}

// Indian number formatting (lakhs, crores)
function formatINRForPDF(amount) {
  const num = Number(amount) || 0;
  const [integer, decimal] = num.toFixed(2).split('.');
  const lastThree = integer.slice(-3);
  const otherDigits = integer.slice(0, -3);
  const formatted =
    otherDigits.length > 0
      ? otherDigits.replace(/\B(?=(\d{2})+(?!\d))/g, ',') + ',' + lastThree
      : lastThree;
  return `${formatted}.${decimal}`;
}

// Convert amount to words (Indian system)
function amountToWords(amount) {
  if (!amount || amount === 0) return 'Zero Rupees Only';

  const ones = ['', 'One', 'Two', 'Three', 'Four', 'Five', 'Six', 'Seven', 'Eight', 'Nine',
    'Ten', 'Eleven', 'Twelve', 'Thirteen', 'Fourteen', 'Fifteen', 'Sixteen', 'Seventeen', 'Eighteen', 'Nineteen'];
  const tens = ['', '', 'Twenty', 'Thirty', 'Forty', 'Fifty', 'Sixty', 'Seventy', 'Eighty', 'Ninety'];

  function convertLessThanThousand(num) {
    if (num === 0) return '';
    if (num < 20) return ones[num];
    if (num < 100) {
      return tens[Math.floor(num / 10)] + (num % 10 !== 0 ? ' ' + ones[num % 10] : '');
    }
    return ones[Math.floor(num / 100)] + ' Hundred' + (num % 100 !== 0 ? ' ' + convertLessThanThousand(num % 100) : '');
  }

  const rupees = Math.floor(amount);
  const paise = Math.round((amount - rupees) * 100);

  if (rupees === 0) {
    return 'Zero Rupees and ' + convertLessThanThousand(paise) + ' Paise Only';
  }

  let result = '';

  // Crores
  if (rupees >= 10000000) {
    result += convertLessThanThousand(Math.floor(rupees / 10000000)) + ' Crore ';
  }

  // Lakhs
  const lakhs = Math.floor((rupees % 10000000) / 100000);
  if (lakhs > 0) {
    result += convertLessThanThousand(lakhs) + ' Lakh ';
  }

  // Thousands
  const thousands = Math.floor((rupees % 100000) / 1000);
  if (thousands > 0) {
    result += convertLessThanThousand(thousands) + ' Thousand ';
  }

  // Hundreds and below
  const remainder = rupees % 1000;
  if (remainder > 0) {
    result += convertLessThanThousand(remainder);
  }

  result = 'Indian Rupees ' + result.trim();

  if (paise > 0) {
    result += ' and ' + convertLessThanThousand(paise) + ' Paise';
  }

  return result + ' Only';
}

function generatePurchaseOrderHTML({ po, items }) {
  const isIntraState = po.company_state === po.vendor_state;
  const taxBreakdown = {};

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

  const totalQuantity = items.reduce((sum, item) => sum + Number(item.quantity || 0), 0);
  const MAX_ROWS = 12;
  const emptyRows = Math.max(0, MAX_ROWS - items.length);

  // Generate item rows
  const itemRows = items.map((item, index) => {
    const unit = safeText(item.unit_of_measure || 'Nos');
    const qty = Number(item.quantity || 0);

    return `
        <div class="item-row">
          <div class="col-sl">${index + 1}</div>
          <div class="col-desc">
            <span class="item-name">${safeText(item.item_description)}</span>
            ${item.description ? `<br><span class="item-batch">${safeText(item.description)}</span>` : ''}
          </div>
          <div class="col-hsn">${safeText(item.hsn_sac_code) || ''}</div>
          <div class="col-qty qty-bold">${qty} ${unit}</div>
          <div class="col-rate">${formatINRForPDF(Number(item.rate))}</div>
          <div class="col-per">${unit}</div>
          <div class="col-amt">${formatINRForPDF(Number(item.taxable_amount))}</div>
        </div>`;
  }).join('');

  // Generate empty rows
  const emptyRowsHTML = Array.from({ length: emptyRows }).map(() => `
        <div class="item-row">
          <div class="col-sl"></div>
          <div class="col-desc"></div>
          <div class="col-hsn"></div>
          <div class="col-qty"></div>
          <div class="col-rate"></div>
          <div class="col-per"></div>
          <div class="col-amt"></div>
        </div>`).join('');

  // Generate GST rows
  let gstRows = '';
  if (isIntraState && Number(po.cgst_total) > 0) {
    gstRows = `
        <div class="item-row gst-row">
          <div class="col-sl"></div>
          <div class="col-desc" style="text-align:right;"><span class="gst-label">Input CGST</span></div>
          <div class="col-hsn"></div>
          <div class="col-qty"></div>
          <div class="col-rate"></div>
          <div class="col-per"></div>
          <div class="col-amt">${formatINRForPDF(Number(po.cgst_total))}</div>
        </div>
        <div class="item-row gst-row">
          <div class="col-sl"></div>
          <div class="col-desc" style="text-align:right;"><span class="gst-label">Input SGST</span></div>
          <div class="col-hsn"></div>
          <div class="col-qty"></div>
          <div class="col-rate"></div>
          <div class="col-per"></div>
          <div class="col-amt">${formatINRForPDF(Number(po.sgst_total))}</div>
        </div>`;
  } else if (!isIntraState && Number(po.igst_total) > 0) {
    gstRows = `
        <div class="item-row gst-row">
          <div class="col-sl"></div>
          <div class="col-desc" style="text-align:right;"><span class="gst-label">Input IGST</span></div>
          <div class="col-hsn"></div>
          <div class="col-qty"></div>
          <div class="col-rate"></div>
          <div class="col-per"></div>
          <div class="col-amt">${formatINRForPDF(Number(po.igst_total))}</div>
        </div>`;
  }

  // Generate tax table rows
  const taxTableRows = Object.entries(taxBreakdown).map(([hsn, data]) => `
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
        </tr>`).join('');

  // Generate tax table
  const taxTable = `
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
        ${taxTableRows}
        <tr style="font-weight:bold;">
          <td>Total</td>
          <td class="text-right">${formatINRForPDF(Number(po.subtotal))}</td>
          ${isIntraState ? `
          <td></td>
          <td class="text-right">${formatINRForPDF(Number(po.cgst_total))}</td>
          <td></td>
          <td class="text-right">${formatINRForPDF(Number(po.sgst_total))}</td>
          ` : `
          <td></td>
          <td class="text-right">${formatINRForPDF(Number(po.igst_total))}</td>
          `}
          <td class="text-right">${formatINRForPDF(Number(po.tax_total))}</td>
        </tr>
      </tbody>
    </table>

    <div class="tax-words">
      <strong>Tax Amount (in words) :</strong> ${amountToWords(Number(po.tax_total))}
    </div>`;

  return `
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Purchase Order - ${safeText(po.po_number)}</title>
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

    .title {
      text-align: center;
      font-size: 16px;
      font-weight: bold;
      padding: 10px 0;
      border-bottom: 1px solid #000;
    }

    .main-box {
      border: 1px solid #000;
      border-top: none;
    }

    .main-row {
      display: flex;
    }

    .left-col {
      width: 50%;
      border-right: 1px solid #000;
    }

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

    .consignee-section {
      padding: 8px;
      border-bottom: 1px solid #000;
    }

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

    .w25 { width: 25%; }
    .w50 { width: 50%; }
    .w100 { width: 100%; }

    .items-section {
      border: 1px solid #000;
      border-top: none;
      border-right: none;
    }

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

    .items-body {
      min-height: 200px;
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

    .col-sl { flex: 0 0 4%; text-align: center; justify-content: center; }
    .col-desc { flex: 0 0 28%; text-align: left; display: block !important; }
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
      color: #666;
      font-style: italic;
      display: block;
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

    .gst-label {
      font-style: italic;
    }

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

    .grand-total {
      font-size: 12px;
      font-weight: bold;
    }

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

    .tax-words {
      font-size: 9px;
      padding: 4px 8px;
      border: 1px solid #000;
      border-top: none;
    }

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
    <div class="title">Purchase Order</div>

    <div class="main-box">
      <div class="main-row">
        <div class="left-col">
          <div class="company-header">
            <div class="logo-box">
              ${po.company_logo
                ? `<img src="${safeText(po.company_logo)}" alt="Company Logo" />`
                : `<div class="logo-placeholder"><div class="logo-triangle"></div></div>`
              }
            </div>
            <div class="company-info">
              <div class="company-name">${safeText(po.company_legal_name || po.trade_name)}</div>
              ${po.company_address_line_1 ? `<div>${safeText(po.company_address_line_1)}</div>` : ''}
              ${po.company_city ? `<div>${safeText(po.company_city)}</div>` : ''}
              <div>GSTIN/UIN: ${safeText(po.gstin) || 'N/A'}</div>
              <div>State: ${safeText(po.company_state)}${po.gst_state_code ? `, Code: ${safeText(po.gst_state_code)}` : ''}</div>
            </div>
          </div>

          <div class="consignee-section">
            <div class="buyer-label">Supplier (Ship from)</div>
            <div class="buyer-name">${safeText(po.vendor_name)}</div>
            <div class="buyer-details">
              ${po.vendor_address_line_1 ? `${safeText(po.vendor_address_line_1)}<br>` : ''}
              ${po.vendor_gst ? `GSTIN/UIN: ${safeText(po.vendor_gst)}<br>` : ''}
              State: ${safeText(po.vendor_state)}${po.vendor_state_code ? `, Code: ${safeText(po.vendor_state_code)}` : ''}
            </div>
          </div>

          <div class="buyer-section">
            <div class="buyer-label">Vendor (Bill from)</div>
            <div class="buyer-name">${safeText(po.vendor_name)}</div>
            <div class="buyer-details">
              ${po.vendor_address_line_1 ? `${safeText(po.vendor_address_line_1)}<br>` : ''}
              ${po.vendor_gst ? `GSTIN/UIN: ${safeText(po.vendor_gst)}<br>` : ''}
              State: ${safeText(po.vendor_state)}${po.vendor_state_code ? `, Code: ${safeText(po.vendor_state_code)}` : ''}
            </div>
          </div>
        </div>

        <div class="right-col">
          <div class="detail-row">
            <div class="detail-cell w25">PO Number</div>
            <div class="detail-cell w25">${safeText(po.po_number)}</div>
            <div class="detail-cell w25">Dated</div>
            <div class="detail-cell w25">${formatDate(po.po_date)}</div>
          </div>
          <div class="detail-row">
            <div class="detail-cell w25">Delivery Date</div>
            <div class="detail-cell w25">${po.delivery_date ? formatDate(po.delivery_date) : ''}</div>
            <div class="detail-cell w50">Mode/Terms of Payment</div>
          </div>
          <div class="detail-row">
            <div class="detail-cell w25">Reference No.</div>
            <div class="detail-cell w25"></div>
            <div class="detail-cell w50">Other Reference(s)</div>
          </div>
          <div class="detail-row">
            <div class="detail-cell w25">Supplier's Order No.</div>
            <div class="detail-cell w25"></div>
            <div class="detail-cell w25">Dated</div>
            <div class="detail-cell w25"></div>
          </div>
          <div class="detail-row">
            <div class="detail-cell w25">Destination</div>
            <div class="detail-cell w25">${safeText(po.place_of_supply) || ''}</div>
            <div class="detail-cell w25">Delivery Note</div>
            <div class="detail-cell w25"></div>
          </div>
          <div class="detail-row" style="min-height:25px;">
            <div class="detail-cell w100">Terms of Delivery</div>
          </div>
        </div>
      </div>
    </div>

    <div class="items-section">
      <div class="items-header">
        <div class="col-sl">Sl<br>No.</div>
        <div class="col-desc">Description of Goods</div>
        <div class="col-hsn">HSN/SAC</div>
        <div class="col-qty">Quantity</div>
        <div class="col-rate">Rate</div>
        <div class="col-per">per</div>
        <div class="col-amt">Amount</div>
      </div>

      <div class="items-body">
        ${itemRows}
        ${emptyRowsHTML}
        ${gstRows}
      </div>

      <div class="total-row">
        <div class="col-sl"></div>
        <div class="col-desc" style="text-align:right;">Total</div>
        <div class="col-hsn"></div>
        <div class="col-qty qty-bold">${totalQuantity} Nos</div>
        <div class="col-rate"></div>
        <div class="col-per"></div>
        <div class="col-amt grand-total">₹ ${formatINRForPDF(Number(po.grand_total))}</div>
      </div>
    </div>

    <div class="amount-words">
      <div class="amount-words-left">
        Amount Chargeable (in words)<br>
        <span class="amount-words-value">${amountToWords(Number(po.grand_total))}</span>
      </div>
      <div class="amount-words-right">E. & O.E</div>
    </div>

    ${taxTable}

    <div class="footer">
      <div class="footer-left">
        <strong>Declaration</strong><br>
        This purchase order shows the actual price of goods.
        ${po.notes ? `<br><br><strong>Notes:</strong><br>${safeText(po.notes)}` : ''}
        ${po.terms_and_conditions ? `<br><br><strong>Terms:</strong><br>${safeText(po.terms_and_conditions)}` : ''}
      </div>
      <div class="footer-right">
        <div>for <strong>${safeText(po.company_legal_name || po.trade_name)}</strong></div>
        <div class="signature">Authorised Signatory</div>
      </div>
    </div>

    <div class="computer-note">This is a Computer Generated Purchase Order</div>
  </div>
</body>
</html>`.trim();
}

module.exports = {
  generatePurchaseOrderHTML,
  formatDate,
  formatINRForPDF,
  amountToWords,
  safeText
};
