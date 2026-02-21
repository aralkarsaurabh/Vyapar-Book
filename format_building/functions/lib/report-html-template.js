/**
 * Report HTML Template
 * Generates professional HTML for all report types
 * Rendered to PDF via Puppeteer
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
  return `₹${formatted}.${decimal}`;
}

function formatCellValue(value, format) {
  switch (format) {
    case 'currency':
      return formatINRForPDF(value);
    case 'date':
      return formatDate(value);
    case 'number':
      return String(Number(value) || 0);
    case 'text':
    default:
      return safeText(value);
  }
}

function calculateTotals(items, columns) {
  const totals = {};
  columns.forEach(col => {
    if (col.format === 'currency' || col.format === 'number') {
      totals[col.key] = items.reduce((sum, item) => sum + (Number(item[col.key]) || 0), 0);
    } else {
      totals[col.key] = null;
    }
  });
  // First text column gets "TOTAL" label
  const firstTextCol = columns.find(col => col.format === 'text' || col.format === 'date');
  if (firstTextCol) {
    totals[firstTextCol.key] = 'TOTAL';
  }
  return totals;
}

function generateReportHTML({ report_type, metadata, company, bank, date_range, items }) {
  const columns = metadata.columns;
  const isLandscape = metadata.orientation === 'landscape';
  const totals = calculateTotals(items, columns);

  // Calculate column widths
  const colCount = columns.length;
  const textCols = columns.filter(c => c.format === 'text' || c.format === 'date').length;
  const numCols = colCount - textCols;
  // Give text columns more space
  const textColWidth = Math.max(15, Math.floor(60 / Math.max(textCols, 1)));
  const numColWidth = Math.max(8, Math.floor((100 - textColWidth * textCols) / Math.max(numCols, 1)));

  // Build header row
  const headerCells = columns.map(col => {
    const width = (col.format === 'text' || col.format === 'date') ? textColWidth : numColWidth;
    return `<th style="width:${width}%; text-align:${col.align};">${col.header}</th>`;
  }).join('');

  // Build data rows
  const dataRows = items.map((item, index) => {
    const cells = columns.map(col => {
      const value = formatCellValue(item[col.key], col.format);
      return `<td style="text-align:${col.align};">${value}</td>`;
    }).join('');
    return `<tr class="${index % 2 === 1 ? 'alt-row' : ''}">${cells}</tr>`;
  }).join('');

  // Build totals row
  const totalCells = columns.map(col => {
    const val = totals[col.key];
    if (val === null || val === undefined) {
      return `<td></td>`;
    }
    if (val === 'TOTAL') {
      return `<td style="text-align:${col.align}; font-weight:bold;">${val}</td>`;
    }
    const formatted = col.format === 'currency' ? formatINRForPDF(val) : String(val);
    return `<td style="text-align:${col.align}; font-weight:bold;">${formatted}</td>`;
  }).join('');

  // Date range text
  let periodText = '';
  if (metadata.has_date_range && date_range) {
    periodText = `Period: ${formatDate(date_range.start_date)} to ${formatDate(date_range.end_date)}`;
  } else {
    periodText = `As on ${formatDate(new Date().toISOString())}`;
  }

  // Company address
  const addressParts = [
    company.address_line1,
    company.address_line2,
    [company.city, company.state, company.pincode].filter(Boolean).join(', '),
  ].filter(Boolean);

  return `
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>${metadata.title}</title>
  <style>
    @page {
      size: ${isLandscape ? 'A4 landscape' : 'A4'};
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

    .report-page {
      width: 100%;
      max-width: ${isLandscape ? '297mm' : '210mm'};
      margin: 0 auto;
    }

    /* Company Header */
    .company-header {
      display: flex;
      align-items: center;
      border: 1px solid #000;
      padding: 0;
    }

    .logo-box {
      width: 70px;
      min-height: 70px;
      display: flex;
      align-items: center;
      justify-content: center;
      border-right: 1px solid #000;
      padding: 4px;
      background: #fff;
    }

    .logo-box img {
      max-width: 100%;
      max-height: 62px;
      object-fit: contain;
    }

    .logo-placeholder {
      width: 100%;
      height: 62px;
      background: linear-gradient(135deg, #E67E22 0%, #F39C12 50%, #E67E22 100%);
      display: flex;
      align-items: center;
      justify-content: center;
    }

    .logo-triangle {
      width: 0;
      height: 0;
      border-left: 18px solid transparent;
      border-right: 18px solid transparent;
      border-bottom: 30px solid #fff;
    }

    .company-info {
      flex: 1;
      padding: 8px 12px;
    }

    .company-name {
      font-size: 14px;
      font-weight: bold;
      margin-bottom: 2px;
    }

    .company-details {
      font-size: 9px;
      line-height: 1.4;
      color: #333;
    }

    /* Report Title Section */
    .report-title-section {
      border: 1px solid #000;
      border-top: none;
      text-align: center;
      padding: 8px;
      background: #f8f9fa;
    }

    .report-title {
      font-size: 16px;
      font-weight: bold;
      margin-bottom: 2px;
    }

    .report-subtitle {
      font-size: 9px;
      color: #666;
      margin-bottom: 4px;
    }

    .report-period {
      font-size: 10px;
      font-weight: 600;
    }

    /* Data Table */
    .report-table {
      width: 100%;
      border-collapse: collapse;
      border: 1px solid #000;
      border-top: none;
    }

    .report-table th {
      background: #e9ecef;
      border: 1px solid #000;
      padding: 6px 8px;
      font-size: 9px;
      font-weight: bold;
      white-space: nowrap;
    }

    .report-table td {
      border: 1px solid #ccc;
      border-left: 1px solid #000;
      border-right: 1px solid #000;
      padding: 5px 8px;
      font-size: 9px;
    }

    .report-table tbody tr:last-child td {
      border-bottom: 1px solid #000;
    }

    .alt-row {
      background: #fafafa;
    }

    .report-table tfoot td {
      border: 1px solid #000;
      padding: 6px 8px;
      font-size: 9px;
      font-weight: bold;
      background: #f0f0f0;
    }

    /* Summary Section */
    .summary-section {
      border: 1px solid #000;
      border-top: none;
      padding: 8px 12px;
      display: flex;
      justify-content: space-between;
      align-items: center;
      font-size: 9px;
    }

    .summary-left {
      color: #666;
    }

    .summary-right {
      font-weight: bold;
    }

    /* Footer */
    .report-footer {
      border: 1px solid #000;
      border-top: none;
      display: flex;
      justify-content: space-between;
      padding: 6px 12px;
      font-size: 8px;
      color: #666;
      background: #fafafa;
    }

    .computer-note {
      text-align: center;
      font-size: 9px;
      padding: 5px;
      border: 1px solid #000;
      border-top: none;
    }

    /* Bank Details */
    .bank-section {
      border: 1px solid #000;
      border-top: none;
      padding: 8px 12px;
      font-size: 9px;
    }

    .bank-title {
      font-weight: bold;
      font-size: 9px;
      margin-bottom: 4px;
    }

    .bank-grid {
      display: flex;
      gap: 24px;
    }

    .bank-item {
      display: flex;
      gap: 4px;
    }

    .bank-label {
      color: #666;
    }

    .bank-value {
      font-weight: 600;
    }

    /* Empty state */
    .empty-state {
      text-align: center;
      padding: 40px;
      color: #999;
      font-size: 12px;
      border: 1px solid #000;
      border-top: none;
    }

    @media print {
      body { -webkit-print-color-adjust: exact; print-color-adjust: exact; }
      .logo-placeholder { background: linear-gradient(135deg, #E67E22 0%, #F39C12 50%, #E67E22 100%) !important; }
      .alt-row { background: #fafafa !important; }
      .report-table th { background: #e9ecef !important; }
      .report-table tfoot td { background: #f0f0f0 !important; }
      .report-title-section { background: #f8f9fa !important; }
    }
  </style>
</head>
<body>
  <div class="report-page">
    <!-- Company Header -->
    <div class="company-header">
      <div class="logo-box">
        ${company.logo
          ? `<img src="${safeText(company.logo)}" alt="Company Logo" />`
          : `<div class="logo-placeholder"><div class="logo-triangle"></div></div>`
        }
      </div>
      <div class="company-info">
        <div class="company-name">${safeText(company.company_name)}</div>
        <div class="company-details">
          ${addressParts.map(p => safeText(p)).join('<br>')}
          ${company.gstin ? `<br>GSTIN: ${safeText(company.gstin)}` : ''}
          ${company.pan ? ` | PAN: ${safeText(company.pan)}` : ''}
          ${company.email ? `<br>Email: ${safeText(company.email)}` : ''}
          ${company.phone ? ` | Phone: ${safeText(company.phone)}` : ''}
          ${company.website ? ` | Web: ${safeText(company.website)}` : ''}
        </div>
      </div>
    </div>

    <!-- Report Title -->
    <div class="report-title-section">
      <div class="report-title">${metadata.title}</div>
      <div class="report-subtitle">${metadata.subtitle}</div>
      <div class="report-period">${periodText}</div>
    </div>

    ${items.length === 0 ? `
    <div class="empty-state">No data found for the selected period.</div>
    ` : `
    <!-- Data Table -->
    <table class="report-table">
      <thead>
        <tr>${headerCells}</tr>
      </thead>
      <tbody>
        ${dataRows}
      </tbody>
      <tfoot>
        <tr>${totalCells}</tr>
      </tfoot>
    </table>

    <!-- Summary -->
    <div class="summary-section">
      <div class="summary-left">Total Records: ${items.length}</div>
      <div class="summary-right">Generated on ${formatDate(new Date().toISOString())}</div>
    </div>
    `}

    ${(bank && (bank.bank_name || bank.account_number)) || (company.bank_name || company.bank_account_number) ? `
    <!-- Bank Details -->
    <div class="bank-section">
      <div class="bank-title">Bank Details:</div>
      <div class="bank-grid">
        ${(bank?.bank_name || company.bank_name) ? `<div class="bank-item"><span class="bank-label">Bank:</span> <span class="bank-value">${safeText(bank?.bank_name || company.bank_name)}</span></div>` : ''}
        ${(bank?.account_number || company.bank_account_number) ? `<div class="bank-item"><span class="bank-label">A/c No:</span> <span class="bank-value">${safeText(bank?.account_number || company.bank_account_number)}</span></div>` : ''}
        ${(bank?.ifsc_code || company.bank_ifsc) ? `<div class="bank-item"><span class="bank-label">IFSC:</span> <span class="bank-value">${safeText(bank?.ifsc_code || company.bank_ifsc)}</span></div>` : ''}
        ${(bank?.branch_name || company.bank_branch) ? `<div class="bank-item"><span class="bank-label">Branch:</span> <span class="bank-value">${safeText(bank?.branch_name || company.bank_branch)}</span></div>` : ''}
      </div>
    </div>
    ` : ''}

    <!-- Footer -->
    <div class="report-footer">
      <div>This report is generated from VyaparBook</div>
      <div>${safeText(company.company_name)}</div>
    </div>

    <div class="computer-note">This is a Computer Generated Report</div>
  </div>
</body>
</html>`.trim();
}

module.exports = {
  generateReportHTML,
  formatDate,
  formatINRForPDF,
  safeText,
  formatCellValue,
  calculateTotals,
};
