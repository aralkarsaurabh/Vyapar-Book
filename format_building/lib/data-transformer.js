/**
 * Data Transformer
 * Converts Flutter's camelCase data format to template's snake_case format
 */

function transformQuotationData(flutterData) {
  const quotation = flutterData.quotation || flutterData;
  const items = flutterData.items || flutterData.lineItems || [];

  return {
    quotation: transformQuotation(quotation),
    items: items.map(transformLineItem)
  };
}

function transformQuotation(q) {
  return {
    // Basic Info
    quotation_id: q.id || q.quotationId,
    quotation_number: q.quotationNumber || q.quotation_number,
    quotation_date: q.quotationDate || q.quotation_date,
    valid_until: q.validUntilDate || q.valid_until,
    quotation_type: q.quotationType || q.quotation_type || 'GST',
    place_of_supply: q.placeOfSupply || q.place_of_supply,

    // Customer Info (from customerDetails or direct)
    customer_name: q.customerName || q.customerDetails?.customerName || q.customer_name,
    customer_type: q.customerDetails?.customerType || q.customer_type,
    customer_gst: q.customerDetails?.gstNumber || q.customer_gst,
    customer_pan: q.customerDetails?.panNumber || q.customer_pan,
    customer_email: q.customerDetails?.email || q.customer_email,
    customer_phone: q.customerDetails?.phoneNumber || q.customer_phone,
    customer_address_line1: q.customerDetails?.addressLine1 || q.customer_address_line1,
    customer_address_line2: q.customerDetails?.addressLine2 || q.customer_address_line2,
    customer_city: q.customerDetails?.city || q.customer_city,
    customer_state: q.customerDetails?.state || q.customer_state,
    customer_pincode: q.customerDetails?.pinCode || q.customer_pincode,
    customer_country: q.customerDetails?.country || q.customer_country,
    customer_state_code: getStateCodeFromGst(q.customerDetails?.gstNumber) ||
                         getStateCode(q.customerDetails?.state) ||
                         q.customer_state_code,

    // Company Info (from companyDetails or direct)
    company_name: q.companyDetails?.companyLegalName || q.company_name,
    company_gst: q.companyDetails?.gstin || q.company_gst,
    company_pan: q.companyDetails?.pan || q.company_pan,
    company_email: q.companyDetails?.emailAddress || q.companyDetails?.email || q.company_email,
    company_phone: q.companyDetails?.phoneNumber || q.companyDetails?.phone || q.company_phone,
    company_website: q.companyDetails?.website || q.company_website,
    company_address_line1: q.companyDetails?.addressLine1 || q.company_address_line1,
    company_address_line2: q.companyDetails?.addressLine2 || q.company_address_line2,
    company_city: q.companyDetails?.city || q.company_city,
    company_state: q.companyDetails?.state || q.company_state,
    company_pincode: q.companyDetails?.pinCode || q.company_pincode,
    company_country: q.companyDetails?.country || q.company_country,
    company_state_code: getStateCode(q.companyDetails?.state) || q.company_state_code,
    company_logo: formatLogoUrl(q.companyDetails?.logoBase64 || q.companyDetails?.companyLogo || q.company_logo),

    // Bank Details
    bank_name: q.bankDetails?.bankName || q.bank_name,
    bank_account_number: q.bankDetails?.accountNumber || q.bank_account_number,
    bank_ifsc: q.bankDetails?.ifscCode || q.bank_ifsc,
    bank_branch: q.bankDetails?.branchName || q.bank_branch,

    // Totals
    subtotal: q.subtotal || 0,
    discount_amount: q.discountAmount || q.discount_amount || 0,
    cgst_total: q.cgstTotal || q.cgst_total || 0,
    sgst_total: q.sgstTotal || q.sgst_total || 0,
    igst_total: q.igstTotal || q.igst_total || 0,
    tax_total: q.taxTotal || q.tax_total || 0,
    grand_total: q.grandTotal || q.grand_total || 0,

    // Additional
    notes: q.notes,
    terms_and_conditions: q.termsAndConditions || q.terms_and_conditions
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
  transformQuotationData,
  transformQuotation,
  transformLineItem,
  getStateCode,
  getStateCodeFromGst,
  formatLogoUrl
};
