import { formatDate, amountToWords } from '@/lib/format';

function safeText(value: any): string {
  if (value === null || value === undefined) return '';
  if (typeof value === 'string') return value;
  if (typeof value === 'number') return String(value);
  return String(value);
}

// PDF-specific INR formatter using "Rs." instead of ₹ symbol
function formatINRForPDF(amount: number): string {
  const [integer, decimal] = amount.toFixed(2).split('.');
  const lastThree = integer.slice(-3);
  const otherDigits = integer.slice(0, -3);
  const formatted =
    otherDigits.length > 0
      ? otherDigits.replace(/\B(?=(\d{2})+(?!\d))/g, ',') + ',' + lastThree
      : lastThree;
  return `Rs. ${formatted}.${decimal}`;
}

interface CreditNoteData {
  creditNote: any;
  items: any[];
}

export function generateCreditNoteHTML({ creditNote, items }: CreditNoteData): string {
  const isIntraState = creditNote.company_state === creditNote.customer_state;

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

  return `
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Credit Note - ${safeText(creditNote.credit_note_number)}</title>
  <style>
    * {
      margin: 0;
      padding: 0;
      box-sizing: border-box;
    }

    body {
      font-family: Arial, Helvetica, sans-serif;
      font-size: 9pt;
      line-height: 1.3;
      color: #000;
      padding: 20px;
    }

    .header {
      display: flex;
      justify-content: space-between;
      margin-bottom: 10px;
    }

    .header-left {
      font-size: 16pt;
      font-weight: bold;
    }

    .original-invoice-box {
      background-color: #f0f8ff;
      border: 1px solid #0066cc;
      padding: 8px;
      margin-bottom: 10px;
      font-size: 8pt;
    }

    .reason-box {
      background-color: #fff9e6;
      border: 1px solid #ffcc00;
      padding: 8px;
      margin-bottom: 10px;
      font-size: 8pt;
    }

    .main-box {
      border: 1px solid #000;
      margin-bottom: 10px;
    }

    .main-box-row {
      display: flex;
      border-bottom: 1px solid #000;
    }

    .main-box-row:last-child {
      border-bottom: none;
    }

    .main-box-left {
      width: 50%;
      padding: 8px;
      border-right: 1px solid #000;
    }

    .main-box-right {
      width: 50%;
      display: flex;
      flex-direction: column;
    }

    .company-name {
      font-size: 11pt;
      font-weight: bold;
      margin-bottom: 3px;
    }

    .company-details {
      font-size: 8pt;
      line-height: 1.3;
    }

    .section-label {
      font-size: 8pt;
      font-weight: bold;
      margin-top: 8px;
      margin-bottom: 3px;
    }

    .section-divider {
      border-bottom: 1px solid #000;
      padding-bottom: 8px;
      margin-bottom: 8px;
    }

    .grid-row {
      display: flex;
      border-bottom: 1px solid #000;
      height: 28px;
      min-height: 28px;
      max-height: 28px;
    }

    .grid-row:last-child {
      border-bottom: none;
    }

    .grid-cell {
      padding: 5px 8px;
      font-size: 8pt;
      display: flex;
      align-items: center;
      overflow: hidden;
    }

    .grid-cell-label {
      width: 50%;
      font-weight: normal;
      border-right: 1px solid #000;
    }

    .grid-cell-value {
      width: 50%;
    }

    .table {
      width: 100%;
      border: 1px solid #000;
      border-collapse: collapse;
      margin-bottom: 10px;
    }

    .table th,
    .table td {
      border: 1px solid #000;
      padding: 5px;
      font-size: 8pt;
      text-align: center;
    }

    .table th {
      font-weight: bold;
      background-color: #fff;
    }

    .table-cell-left {
      text-align: left;
    }

    .table-cell-right {
      text-align: right;
    }

    .gst-subrow {
      text-align: right;
      font-size: 8pt;
      padding-right: 20px;
    }

    .amount-words-box {
      border: 1px solid #000;
      border-bottom: none;
      padding: 5px 8px;
      display: flex;
      justify-content: space-between;
    }

    .amount-words-label {
      font-size: 8pt;
    }

    .amount-words-value {
      font-size: 9pt;
      font-weight: bold;
    }

    .tax-table {
      width: 100%;
      border: 1px solid #000;
      border-collapse: collapse;
      margin-bottom: 10px;
    }

    .tax-table th,
    .tax-table td {
      border: 1px solid #000;
      padding: 5px;
      font-size: 8pt;
      text-align: center;
    }

    .tax-table th {
      font-weight: bold;
    }

    .footer-section {
      display: flex;
      margin-top: 10px;
    }

    .footer-left {
      width: 60%;
      font-size: 8pt;
      padding-right: 10px;
    }

    .footer-right {
      width: 40%;
      text-align: right;
      font-size: 8pt;
    }

    .signature-line {
      margin-top: 60px;
      font-weight: bold;
    }

    .footer-note {
      text-align: center;
      font-size: 8pt;
      margin-top: 10px;
      font-weight: bold;
    }

    @media print {
      body {
        padding: 10px;
      }
    }
  </style>
</head>
<body>
  <!-- Header -->
  <div class="header">
    <div class="header-left">Credit Note</div>
  </div>

  <!-- Original Invoice Reference -->
  <div class="original-invoice-box">
    <strong>Original Invoice Reference:</strong> ${safeText(creditNote.original_invoice_number)} dated ${formatDate(creditNote.original_invoice_date)}
  </div>

  <!-- Reason for Credit Note -->
  <div class="reason-box">
    <strong>Reason for Credit Note:</strong> ${safeText(creditNote.reason)}
  </div>

  <!-- Main Box: Company/Customer Details + Credit Note Fields -->
  <div class="main-box">
    <div class="main-box-row">
      <!-- Left: Company and Customer Details -->
      <div class="main-box-left">
        <div class="section-divider">
          <div class="company-name">${safeText(creditNote.company_name)}</div>
          <div class="company-details">
            ${creditNote.company_address_line1 ? `${safeText(creditNote.company_address_line1)}<br>` : ''}
            ${creditNote.company_address_line2 ? `${safeText(creditNote.company_address_line2)}<br>` : ''}
            ${creditNote.company_city ? `${safeText(creditNote.company_city)}, ` : ''}${safeText(creditNote.company_state)}${creditNote.company_pincode ? ` - ${safeText(creditNote.company_pincode)}` : ''}<br>
            GSTIN/UIN: ${safeText(creditNote.company_gst) || 'N/A'}<br>
            State Name: ${safeText(creditNote.company_state)}
          </div>
        </div>

        <div>
          <div class="section-label">Customer (Bill to)</div>
          <div class="company-name">${safeText(creditNote.customer_name)}</div>
          <div class="company-details">
            ${creditNote.customer_address_line1 ? `${safeText(creditNote.customer_address_line1)}<br>` : ''}
            ${creditNote.customer_address_line2 ? `${safeText(creditNote.customer_address_line2)}<br>` : ''}
            ${creditNote.customer_city ? `${safeText(creditNote.customer_city)}, ` : ''}${safeText(creditNote.customer_state)}${creditNote.customer_pincode ? ` - ${safeText(creditNote.customer_pincode)}` : ''}<br>
            ${creditNote.customer_gst ? `GSTIN/UIN: ${safeText(creditNote.customer_gst)}<br>` : ''}
            State Name: ${safeText(creditNote.customer_state)}
          </div>
        </div>
      </div>

      <!-- Right: Credit Note Details Grid -->
      <div class="main-box-right">
        <div class="grid-row">
          <div class="grid-cell grid-cell-label">Credit Note No.</div>
          <div class="grid-cell grid-cell-value">${safeText(creditNote.credit_note_number)}</div>
        </div>
        <div class="grid-row">
          <div class="grid-cell grid-cell-label">Dated</div>
          <div class="grid-cell grid-cell-value">${formatDate(creditNote.credit_note_date)}</div>
        </div>
        <div class="grid-row">
          <div class="grid-cell grid-cell-label">Original Invoice No.</div>
          <div class="grid-cell grid-cell-value">${safeText(creditNote.original_invoice_number)}</div>
        </div>
        <div class="grid-row">
          <div class="grid-cell grid-cell-label">Original Invoice Date</div>
          <div class="grid-cell grid-cell-value">${formatDate(creditNote.original_invoice_date)}</div>
        </div>
        <div class="grid-row">
          <div class="grid-cell grid-cell-label">Place of Supply</div>
          <div class="grid-cell grid-cell-value">${safeText(creditNote.place_of_supply)}</div>
        </div>
      </div>
    </div>
  </div>

  <!-- Line Items Table -->
  <table class="table">
    <thead>
      <tr>
        <th style="width: 5%;">Sl<br>No.</th>
        <th style="width: 35%;">Description of Goods</th>
        <th style="width: 10%;">HSN/SAC</th>
        <th style="width: 10%;">Quantity</th>
        <th style="width: 10%;">Rate</th>
        <th style="width: 5%;">per</th>
        <th style="width: 25%;">Amount</th>
      </tr>
    </thead>
    <tbody>
      ${items.map((item, index) => {
        const itemHtml = `
        <tr>
          <td>${index + 1}</td>
          <td class="table-cell-left"><strong>${safeText(item.item_description)}</strong></td>
          <td>${safeText(item.hsn_sac_code) || ''}</td>
          <td>${safeText(item.quantity)} ${safeText(item.unit_of_measure || 'No')}</td>
          <td class="table-cell-right">${formatINRForPDF(Number(item.rate))}</td>
          <td>${safeText(item.unit_of_measure || 'No')}</td>
          <td class="table-cell-right">${formatINRForPDF(Number(item.taxable_amount))}</td>
        </tr>`;

        // Add CGST/SGST or IGST as sub-rows
        let gstRows = '';
        if (isIntraState && Number(item.cgst_amount || 0) > 0) {
          gstRows += `
        <tr>
          <td></td>
          <td colspan="5" class="gst-subrow"><em>CGST</em></td>
          <td class="table-cell-right">${formatINRForPDF(Number(item.cgst_amount))}</td>
        </tr>
        <tr>
          <td></td>
          <td colspan="5" class="gst-subrow"><em>SGST</em></td>
          <td class="table-cell-right">${formatINRForPDF(Number(item.sgst_amount))}</td>
        </tr>`;
        } else if (!isIntraState && Number(item.igst_amount || 0) > 0) {
          gstRows += `
        <tr>
          <td></td>
          <td colspan="5" class="gst-subrow"><em>IGST</em></td>
          <td class="table-cell-right">${formatINRForPDF(Number(item.igst_amount))}</td>
        </tr>`;
        }

        return itemHtml + gstRows;
      }).join('')}
      <tr style="font-weight: bold;">
        <td></td>
        <td class="table-cell-right" colspan="2">Total</td>
        <td>${items.reduce((sum, item) => sum + Number(item.quantity || 0), 0)} No</td>
        <td colspan="2"></td>
        <td class="table-cell-right">${formatINRForPDF(Number(creditNote.grand_total))}</td>
      </tr>
    </tbody>
  </table>

  <!-- Amount in Words -->
  <div class="amount-words-box">
    <div>
      <span class="amount-words-label">Amount (in words)</span><br>
      <span class="amount-words-value">${amountToWords(Number(creditNote.grand_total))}</span>
    </div>
    <div class="amount-words-label" style="align-self: flex-end;">E. & O.E</div>
  </div>

  <!-- Tax Breakdown Table (HSN-wise Summary) -->
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
        <th>Rate</th>
        <th>Amount</th>
      </tr>
    </thead>
    <tbody>
      ${Object.entries(taxBreakdown).map(([hsn, data]) => `
      <tr>
        <td>${hsn}</td>
        <td class="table-cell-right">${formatINRForPDF(data.taxable)}</td>
        ${isIntraState ? `
        <td>${data.cgst_rate}%</td>
        <td class="table-cell-right">${formatINRForPDF(data.cgst_amount)}</td>
        <td>${data.sgst_rate}%</td>
        <td class="table-cell-right">${formatINRForPDF(data.sgst_amount)}</td>
        ` : `
        <td>${data.igst_rate}%</td>
        <td class="table-cell-right">${formatINRForPDF(data.igst_amount)}</td>
        <td></td>
        <td></td>
        `}
        <td class="table-cell-right">${formatINRForPDF(data.total_tax)}</td>
      </tr>
      `).join('')}
      <tr style="font-weight: bold;">
        <td>Total</td>
        <td class="table-cell-right">${formatINRForPDF(Number(creditNote.subtotal))}</td>
        ${isIntraState ? `
        <td></td>
        <td class="table-cell-right">${formatINRForPDF(Number(creditNote.cgst_total))}</td>
        <td></td>
        <td class="table-cell-right">${formatINRForPDF(Number(creditNote.sgst_total))}</td>
        ` : `
        <td></td>
        <td class="table-cell-right">${formatINRForPDF(Number(creditNote.igst_total))}</td>
        <td></td>
        <td></td>
        `}
        <td class="table-cell-right">${formatINRForPDF(Number(creditNote.tax_total))}</td>
      </tr>
    </tbody>
  </table>

  <!-- Tax Amount in Words -->
  <div style="font-size: 8pt; margin-bottom: 10px;">
    <strong>Tax Amount (in words) :</strong> ${amountToWords(Number(creditNote.tax_total))}
  </div>

  <!-- Footer Section -->
  <div class="footer-section">
    <div class="footer-left">
      <strong>Declaration</strong><br>
      This credit note is issued against the original invoice mentioned above.
      ${creditNote.notes ? `<br><br><strong>Notes:</strong><br>${safeText(creditNote.notes)}` : ''}
    </div>
    <div class="footer-right">
      for <strong>${safeText(creditNote.company_name)}</strong>
      <div class="signature-line">Authorised Signatory</div>
    </div>
  </div>

  <!-- Computer Generated Credit Note -->
  <div class="footer-note">This is a Computer Generated Credit Note</div>
</body>
</html>
  `.trim();
}
