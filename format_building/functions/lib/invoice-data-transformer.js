/**
 * Invoice Data Transformer
 * Converts Flutter's camelCase data format to template's snake_case format
 */

function transformInvoiceData(flutterData) {
  const invoice = flutterData.invoice || flutterData;
  const items = flutterData.items || flutterData.lineItems || [];

  return {
    invoice: transformInvoice(invoice),
    items: items.map(transformLineItem)
  };
}

function transformInvoice(i) {
  return {
    // Basic Info
    invoice_id: i.id || i.invoiceId,
    invoice_number: i.invoiceNumber || i.invoice_number,
    reference_number: i.referenceNumber || i.reference_number,
    invoice_date: i.invoiceDate || i.invoice_date,
    due_date: i.dueDate || i.due_date,
    invoice_type: i.invoiceType || i.invoice_type || 'GST',
    place_of_supply: i.placeOfSupply || i.place_of_supply,

    // Customer Info (from customerDetails or direct)
    customer_name: i.customerName || i.customerDetails?.customerName || i.customer_name,
    customer_type: i.customerDetails?.customerType || i.customer_type,
    customer_gst: i.customerDetails?.gstNumber || i.customer_gst,
    customer_pan: i.customerDetails?.panNumber || i.customer_pan,
    customer_email: i.customerDetails?.email || i.customer_email,
    customer_phone: i.customerDetails?.phoneNumber || i.customer_phone,
    customer_address_line1: i.customerDetails?.addressLine1 || i.customer_address_line1,
    customer_address_line2: i.customerDetails?.addressLine2 || i.customer_address_line2,
    customer_city: i.customerDetails?.city || i.customer_city,
    customer_state: i.customerDetails?.state || i.customer_state,
    customer_pincode: i.customerDetails?.pinCode || i.customer_pincode,
    customer_country: i.customerDetails?.country || i.customer_country,
    customer_state_code: getStateCodeFromGst(i.customerDetails?.gstNumber) ||
                         getStateCode(i.customerDetails?.state) ||
                         i.customer_state_code,

    // Company Info (from companyDetails or direct)
    company_name: i.companyDetails?.companyLegalName || i.company_name,
    company_gst: i.companyDetails?.gstin || i.company_gst,
    company_pan: i.companyDetails?.pan || i.company_pan,
    company_email: i.companyDetails?.emailAddress || i.companyDetails?.email || i.company_email,
    company_phone: i.companyDetails?.phoneNumber || i.companyDetails?.phone || i.company_phone,
    company_website: i.companyDetails?.website || i.company_website,
    company_address_line1: i.companyDetails?.addressLine1 || i.company_address_line1,
    company_address_line2: i.companyDetails?.addressLine2 || i.company_address_line2,
    company_city: i.companyDetails?.city || i.company_city,
    company_state: i.companyDetails?.state || i.company_state,
    company_pincode: i.companyDetails?.pinCode || i.company_pincode,
    company_country: i.companyDetails?.country || i.company_country,
    company_state_code: getStateCode(i.companyDetails?.state) || i.company_state_code,
    company_logo: formatLogoUrl(i.companyDetails?.logoBase64 || i.companyDetails?.companyLogo || i.company_logo),

    // Bank Details
    bank_name: i.bankDetails?.bankName || i.bank_name,
    bank_account_number: i.bankDetails?.accountNumber || i.bank_account_number,
    bank_ifsc: i.bankDetails?.ifscCode || i.bank_ifsc,
    bank_branch: i.bankDetails?.branchName || i.bank_branch,

    // Totals
    subtotal: i.subtotal || 0,
    discount_amount: i.discountAmount || i.discount_amount || 0,
    cgst_total: i.cgstTotal || i.cgst_total || 0,
    sgst_total: i.sgstTotal || i.sgst_total || 0,
    igst_total: i.igstTotal || i.igst_total || 0,
    tax_total: i.taxTotal || i.tax_total || 0,
    grand_total: i.grandTotal || i.grand_total || 0,

    // Additional
    notes: i.notes,
    terms_and_conditions: i.termsAndConditions || i.terms_and_conditions
  };
}

function transformLineItem(item) {
  return {
    line_number: item.lineNumber || item.line_number,
    item_description: item.title || item.itemDescription || item.item_description,
    description: item.description,
    hsn_sac_code: item.hsnSacCode || item.hsn_sac_code,
    quantity: Number(item.quantity) || 0,
    unit_of_measure: item.unitOfMeasure || item.unit_of_measure || 'Nos',
    rate: Number(item.rate) || 0,
    taxable_amount: Number(item.taxableAmount || item.taxable_amount) || 0,

    // Tax breakdown
    gst_percentage: Number(item.gstPercentage || item.gst_percentage) || 0,
    cgst_rate: Number(item.cgstRate || item.cgst_rate) || 0,
    cgst_amount: Number(item.cgstAmount || item.cgst_amount) || 0,
    sgst_rate: Number(item.sgstRate || item.sgst_rate) || 0,
    sgst_amount: Number(item.sgstAmount || item.sgst_amount) || 0,
    igst_rate: Number(item.igstRate || item.igst_rate) || 0,
    igst_amount: Number(item.igstAmount || item.igst_amount) || 0,

    total: Number(item.total) || 0
  };
}

// State codes for GST
const STATE_CODES = {
  'Andaman and Nicobar Islands': '35',
  'Andhra Pradesh': '37',
  'Arunachal Pradesh': '12',
  'Assam': '18',
  'Bihar': '10',
  'Chandigarh': '04',
  'Chhattisgarh': '22',
  'Dadra and Nagar Haveli and Daman and Diu': '26',
  'Delhi': '07',
  'Goa': '30',
  'Gujarat': '24',
  'Haryana': '06',
  'Himachal Pradesh': '02',
  'Jammu and Kashmir': '01',
  'Jharkhand': '20',
  'Karnataka': '29',
  'Kerala': '32',
  'Ladakh': '38',
  'Lakshadweep': '31',
  'Madhya Pradesh': '23',
  'Maharashtra': '27',
  'Manipur': '14',
  'Meghalaya': '17',
  'Mizoram': '15',
  'Nagaland': '13',
  'Odisha': '21',
  'Puducherry': '34',
  'Punjab': '03',
  'Rajasthan': '08',
  'Sikkim': '11',
  'Tamil Nadu': '33',
  'Telangana': '36',
  'Tripura': '16',
  'Uttar Pradesh': '09',
  'Uttarakhand': '05',
  'West Bengal': '19',
};

function getStateCode(stateName) {
  if (!stateName) return null;
  return STATE_CODES[stateName] || null;
}

// Format logo as data URL if it's base64 encoded
function formatLogoUrl(logo) {
  if (!logo) return null;
  // If already a data URL or http URL, return as-is
  if (logo.startsWith('data:') || logo.startsWith('http')) {
    return logo;
  }
  // Assume it's base64 encoded, add data URL prefix
  // Try to detect image type from base64 header
  if (logo.startsWith('/9j/')) {
    return `data:image/jpeg;base64,${logo}`;
  } else if (logo.startsWith('iVBOR')) {
    return `data:image/png;base64,${logo}`;
  } else if (logo.startsWith('R0lGOD')) {
    return `data:image/gif;base64,${logo}`;
  }
  // Default to PNG
  return `data:image/png;base64,${logo}`;
}

function getStateCodeFromGst(gstNumber) {
  if (!gstNumber || gstNumber.length < 2) return null;
  return gstNumber.substring(0, 2);
}

module.exports = {
  transformInvoiceData,
  transformInvoice,
  transformLineItem,
  getStateCode,
  getStateCodeFromGst,
  formatLogoUrl
};
