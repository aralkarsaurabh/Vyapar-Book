/**
 * Report Data Transformer
 * Converts Flutter's camelCase data format to template's snake_case format
 * Handles all 6 report types via a single transformer
 */

const REPORT_METADATA = {
  sales_register: {
    title: 'Sales Register',
    subtitle: 'All invoices with date, customer, amount and GST breakdown',
    orientation: 'landscape',
    columns: [
      { key: 'date', header: 'Date', align: 'left', format: 'date' },
      { key: 'invoice_number', header: 'Invoice No', align: 'left', format: 'text' },
      { key: 'customer_name', header: 'Customer', align: 'left', format: 'text' },
      { key: 'taxable_amount', header: 'Taxable Amt', align: 'right', format: 'currency' },
      { key: 'cgst', header: 'CGST', align: 'right', format: 'currency' },
      { key: 'sgst', header: 'SGST', align: 'right', format: 'currency' },
      { key: 'igst', header: 'IGST', align: 'right', format: 'currency' },
      { key: 'total', header: 'Total', align: 'right', format: 'currency' },
    ],
    has_date_range: true,
  },
  purchase_register: {
    title: 'Purchase Register',
    subtitle: 'All recorded purchase bills with vendor, amount and GST breakdown',
    orientation: 'landscape',
    columns: [
      { key: 'date', header: 'Date', align: 'left', format: 'date' },
      { key: 'bill_number', header: 'Bill No', align: 'left', format: 'text' },
      { key: 'vendor_name', header: 'Vendor', align: 'left', format: 'text' },
      { key: 'taxable_amount', header: 'Taxable Amt', align: 'right', format: 'currency' },
      { key: 'cgst', header: 'CGST', align: 'right', format: 'currency' },
      { key: 'sgst', header: 'SGST', align: 'right', format: 'currency' },
      { key: 'igst', header: 'IGST', align: 'right', format: 'currency' },
      { key: 'total', header: 'Total', align: 'right', format: 'currency' },
    ],
    has_date_range: true,
  },
  outstanding_receivables: {
    title: 'Outstanding Receivables',
    subtitle: 'Unpaid invoices grouped by customer',
    orientation: 'portrait',
    columns: [
      { key: 'customer_name', header: 'Customer', align: 'left', format: 'text' },
      { key: 'total_invoiced', header: 'Total Invoiced', align: 'right', format: 'currency' },
      { key: 'amount_received', header: 'Amount Received', align: 'right', format: 'currency' },
      { key: 'outstanding', header: 'Outstanding', align: 'right', format: 'currency' },
      { key: 'invoice_count', header: 'Invoices', align: 'center', format: 'number' },
    ],
    has_date_range: false,
  },
  outstanding_payables: {
    title: 'Outstanding Payables',
    subtitle: 'Unpaid bills grouped by vendor',
    orientation: 'portrait',
    columns: [
      { key: 'vendor_name', header: 'Vendor', align: 'left', format: 'text' },
      { key: 'total_billed', header: 'Total Billed', align: 'right', format: 'currency' },
      { key: 'amount_paid', header: 'Amount Paid', align: 'right', format: 'currency' },
      { key: 'outstanding', header: 'Outstanding', align: 'right', format: 'currency' },
      { key: 'bill_count', header: 'Bills', align: 'center', format: 'number' },
    ],
    has_date_range: false,
  },
  customer_wise_sales: {
    title: 'Customer-wise Sales',
    subtitle: 'Sales breakdown per customer',
    orientation: 'portrait',
    columns: [
      { key: 'customer_name', header: 'Customer', align: 'left', format: 'text' },
      { key: 'invoice_count', header: 'Invoices', align: 'center', format: 'number' },
      { key: 'sales_amount', header: 'Sales Amount', align: 'right', format: 'currency' },
      { key: 'gst_amount', header: 'GST', align: 'right', format: 'currency' },
      { key: 'total_amount', header: 'Total', align: 'right', format: 'currency' },
    ],
    has_date_range: true,
  },
  vendor_wise_purchases: {
    title: 'Vendor-wise Purchases',
    subtitle: 'Purchase breakdown per vendor',
    orientation: 'portrait',
    columns: [
      { key: 'vendor_name', header: 'Vendor', align: 'left', format: 'text' },
      { key: 'bill_count', header: 'Bills', align: 'center', format: 'number' },
      { key: 'purchase_amount', header: 'Purchase Amount', align: 'right', format: 'currency' },
      { key: 'gst_amount', header: 'GST', align: 'right', format: 'currency' },
      { key: 'total_amount', header: 'Total', align: 'right', format: 'currency' },
    ],
    has_date_range: true,
  },
  receivables_aging: {
    title: 'Receivables Aging',
    subtitle: 'Overdue analysis of unpaid invoices by aging buckets',
    orientation: 'landscape',
    columns: [
      { key: 'customer_name', header: 'Customer', align: 'left', format: 'text' },
      { key: 'total_outstanding', header: 'Total Outstanding', align: 'right', format: 'currency' },
      { key: 'current', header: 'Current (Not Due)', align: 'right', format: 'currency' },
      { key: 'overdue_1_to_30', header: '1-30 Days', align: 'right', format: 'currency' },
      { key: 'overdue_31_to_60', header: '31-60 Days', align: 'right', format: 'currency' },
      { key: 'overdue_60_plus', header: '60+ Days', align: 'right', format: 'currency' },
      { key: 'invoice_count', header: 'Invoices', align: 'center', format: 'number' },
    ],
    has_date_range: false,
  },
  payables_aging: {
    title: 'Payables Aging',
    subtitle: 'Overdue analysis of unpaid bills by aging buckets',
    orientation: 'landscape',
    columns: [
      { key: 'vendor_name', header: 'Vendor', align: 'left', format: 'text' },
      { key: 'total_outstanding', header: 'Total Outstanding', align: 'right', format: 'currency' },
      { key: 'current', header: 'Current (Not Due)', align: 'right', format: 'currency' },
      { key: 'overdue_1_to_30', header: '1-30 Days', align: 'right', format: 'currency' },
      { key: 'overdue_31_to_60', header: '31-60 Days', align: 'right', format: 'currency' },
      { key: 'overdue_60_plus', header: '60+ Days', align: 'right', format: 'currency' },
      { key: 'bill_count', header: 'Bills', align: 'center', format: 'number' },
    ],
    has_date_range: false,
  },
  gst_summary: {
    title: 'GST Summary',
    subtitle: 'Output GST vs Input GST - Net tax liability',
    orientation: 'portrait',
    columns: [
      { key: 'description', header: 'Tax Component', align: 'left', format: 'text' },
      { key: 'output_amount', header: 'Output (Sales)', align: 'right', format: 'currency' },
      { key: 'input_amount', header: 'Input (Purchases)', align: 'right', format: 'currency' },
      { key: 'net_amount', header: 'Net Payable', align: 'right', format: 'currency' },
    ],
    has_date_range: true,
  },
  gstr1: {
    title: 'GSTR-1 Sales Report',
    subtitle: 'B2B and B2C sales breakdown for GSTR-1 filing',
    orientation: 'landscape',
    columns: [
      { key: 'section', header: 'Section', align: 'left', format: 'text' },
      { key: 'customer_gstin', header: 'GSTIN', align: 'left', format: 'text' },
      { key: 'invoice_number', header: 'Invoice No', align: 'left', format: 'text' },
      { key: 'customer_name', header: 'Customer', align: 'left', format: 'text' },
      { key: 'taxable_amount', header: 'Taxable Amt', align: 'right', format: 'currency' },
      { key: 'cgst', header: 'CGST', align: 'right', format: 'currency' },
      { key: 'sgst', header: 'SGST', align: 'right', format: 'currency' },
      { key: 'igst', header: 'IGST', align: 'right', format: 'currency' },
      { key: 'total', header: 'Total', align: 'right', format: 'currency' },
    ],
    has_date_range: true,
  },
  gstr3b: {
    title: 'GSTR-3B Summary',
    subtitle: 'Summary return format for GSTR-3B filing',
    orientation: 'landscape',
    columns: [
      { key: 'nature', header: 'Nature of Supplies', align: 'left', format: 'text' },
      { key: 'taxable_value', header: 'Total Taxable Value', align: 'right', format: 'currency' },
      { key: 'igst', header: 'Integrated Tax', align: 'right', format: 'currency' },
      { key: 'cgst', header: 'Central Tax', align: 'right', format: 'currency' },
      { key: 'sgst', header: 'State/UT Tax', align: 'right', format: 'currency' },
    ],
    has_date_range: true,
  },
};

function transformReportData(flutterData) {
  const reportType = flutterData.reportType;
  const metadata = REPORT_METADATA[reportType];

  if (!metadata) {
    throw new Error(`Unknown report type: ${reportType}`);
  }

  return {
    report_type: reportType,
    metadata: metadata,
    company: transformCompanyDetails(flutterData.companyDetails || {}),
    bank: transformBankDetails(flutterData.companyDetails?.bankDetails || flutterData.bankDetails),
    date_range: transformDateRange(flutterData.dateRange),
    items: (flutterData.items || []).map(item => transformReportItem(item, reportType)),
  };
}

function transformCompanyDetails(cd) {
  return {
    company_name: cd.companyLegalName || cd.company_name || '',
    gstin: cd.gstin || cd.gstNumber || '',
    pan: cd.pan || '',
    email: cd.emailAddress || cd.email || '',
    phone: cd.phoneNumber || cd.phone || '',
    website: cd.website || '',
    address_line1: cd.addressLine1 || cd.address_line1 || '',
    address_line2: cd.addressLine2 || cd.address_line2 || '',
    city: cd.city || '',
    state: cd.state || '',
    pincode: cd.pinCode || cd.pincode || '',
    country: cd.country || 'India',
    logo: formatLogoUrl(cd.logoBase64 || cd.companyLogo || cd.logo),
    // Bank details
    bank_name: cd.bankName || cd.bank_name || '',
    bank_account_number: cd.accountNumber || cd.bank_account_number || '',
    bank_ifsc: cd.ifscCode || cd.bank_ifsc || '',
    bank_branch: cd.branchName || cd.bank_branch || '',
  };
}

function transformBankDetails(bd) {
  if (!bd) return null;
  return {
    bank_name: bd.bankName || bd.bank_name || '',
    account_number: bd.accountNumber || bd.account_number || '',
    ifsc_code: bd.ifscCode || bd.ifsc_code || '',
    branch_name: bd.branchName || bd.branch_name || '',
  };
}

function transformDateRange(dr) {
  if (!dr) return null;
  return {
    start_date: dr.startDate || dr.start_date,
    end_date: dr.endDate || dr.end_date,
  };
}

function transformReportItem(item, reportType) {
  switch (reportType) {
    case 'sales_register':
      return {
        date: item.invoiceDate || item.date,
        invoice_number: item.invoiceNumber || item.invoice_number || '',
        customer_name: item.customerName || item.customer_name || '',
        taxable_amount: Number(item.taxableAmount || item.taxable_amount) || 0,
        cgst: Number(item.cgst) || 0,
        sgst: Number(item.sgst) || 0,
        igst: Number(item.igst) || 0,
        total: Number(item.total) || 0,
      };

    case 'purchase_register':
      return {
        date: item.billDate || item.date,
        bill_number: item.billNumber || item.bill_number || '',
        vendor_name: item.vendorName || item.vendor_name || '',
        taxable_amount: Number(item.taxableAmount || item.taxable_amount) || 0,
        cgst: Number(item.cgst) || 0,
        sgst: Number(item.sgst) || 0,
        igst: Number(item.igst) || 0,
        total: Number(item.total) || 0,
      };

    case 'outstanding_receivables':
      return {
        customer_name: item.customerName || item.customer_name || '',
        total_invoiced: Number(item.totalInvoiced || item.total_invoiced) || 0,
        amount_received: Number(item.amountReceived || item.amount_received) || 0,
        outstanding: Number(item.outstanding) || 0,
        invoice_count: Number(item.invoiceCount || item.invoice_count) || 0,
      };

    case 'outstanding_payables':
      return {
        vendor_name: item.vendorName || item.vendor_name || '',
        total_billed: Number(item.totalBilled || item.total_billed) || 0,
        amount_paid: Number(item.amountPaid || item.amount_paid) || 0,
        outstanding: Number(item.outstanding) || 0,
        bill_count: Number(item.billCount || item.bill_count) || 0,
      };

    case 'customer_wise_sales':
      return {
        customer_name: item.customerName || item.customer_name || '',
        invoice_count: Number(item.invoiceCount || item.invoice_count) || 0,
        sales_amount: Number(item.salesAmount || item.sales_amount) || 0,
        gst_amount: Number(item.gstAmount || item.gst_amount) || 0,
        total_amount: Number(item.totalAmount || item.total_amount) || 0,
      };

    case 'vendor_wise_purchases':
      return {
        vendor_name: item.vendorName || item.vendor_name || '',
        bill_count: Number(item.billCount || item.bill_count) || 0,
        purchase_amount: Number(item.purchaseAmount || item.purchase_amount) || 0,
        gst_amount: Number(item.gstAmount || item.gst_amount) || 0,
        total_amount: Number(item.totalAmount || item.total_amount) || 0,
      };

    case 'receivables_aging':
      return {
        customer_name: item.customerName || item.customer_name || '',
        total_outstanding: Number(item.totalOutstanding || item.total_outstanding) || 0,
        current: Number(item.current) || 0,
        overdue_1_to_30: Number(item.overdue1to30 || item.overdue_1_to_30) || 0,
        overdue_31_to_60: Number(item.overdue31to60 || item.overdue_31_to_60) || 0,
        overdue_60_plus: Number(item.overdue60plus || item.overdue_60_plus) || 0,
        invoice_count: Number(item.invoiceCount || item.invoice_count) || 0,
      };

    case 'payables_aging':
      return {
        vendor_name: item.vendorName || item.vendor_name || '',
        total_outstanding: Number(item.totalOutstanding || item.total_outstanding) || 0,
        current: Number(item.current) || 0,
        overdue_1_to_30: Number(item.overdue1to30 || item.overdue_1_to_30) || 0,
        overdue_31_to_60: Number(item.overdue31to60 || item.overdue_31_to_60) || 0,
        overdue_60_plus: Number(item.overdue60plus || item.overdue_60_plus) || 0,
        bill_count: Number(item.billCount || item.bill_count) || 0,
      };

    case 'gst_summary':
      return {
        description: item.description || '',
        output_amount: Number(item.outputAmount || item.output_amount) || 0,
        input_amount: Number(item.inputAmount || item.input_amount) || 0,
        net_amount: Number(item.netAmount || item.net_amount) || 0,
      };

    case 'gstr1':
      return {
        section: item.section || '',
        customer_gstin: item.customerGstin || item.customer_gstin || '',
        invoice_number: item.invoiceNumber || item.invoice_number || '',
        invoice_date: item.invoiceDate || item.invoice_date || '',
        customer_name: item.customerName || item.customer_name || '',
        taxable_amount: Number(item.taxableAmount || item.taxable_amount) || 0,
        cgst: Number(item.cgst) || 0,
        sgst: Number(item.sgst) || 0,
        igst: Number(item.igst) || 0,
        total: Number(item.total) || 0,
      };

    case 'gstr3b':
      return {
        nature: item.nature || '',
        taxable_value: Number(item.taxableValue || item.taxable_value) || 0,
        igst: Number(item.igst) || 0,
        cgst: Number(item.cgst) || 0,
        sgst: Number(item.sgst) || 0,
      };

    default:
      return item;
  }
}

// Format logo as data URL if it's base64 encoded
function formatLogoUrl(logo) {
  if (!logo) return null;
  if (logo.startsWith('data:') || logo.startsWith('http')) {
    return logo;
  }
  if (logo.startsWith('/9j/')) {
    return `data:image/jpeg;base64,${logo}`;
  } else if (logo.startsWith('iVBOR')) {
    return `data:image/png;base64,${logo}`;
  } else if (logo.startsWith('R0lGOD')) {
    return `data:image/gif;base64,${logo}`;
  }
  return `data:image/png;base64,${logo}`;
}

module.exports = {
  transformReportData,
  transformCompanyDetails,
  transformBankDetails,
  transformDateRange,
  transformReportItem,
  formatLogoUrl,
  REPORT_METADATA,
};
