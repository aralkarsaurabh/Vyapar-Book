/**
 * Credit Note Data Transformer
 * Converts Flutter's camelCase data format to template's snake_case format
 */

function transformCreditNoteData(flutterData) {
  const creditNote = flutterData.creditNote || flutterData;
  const items = flutterData.items || flutterData.lineItems || [];

  return {
    creditNote: transformCreditNote(creditNote),
    items: items.map(transformLineItem)
  };
}

function transformCreditNote(cn) {
  return {
    // Basic Info
    credit_note_id: cn.id || cn.creditNoteId,
    credit_note_number: cn.creditNoteNumber || cn.credit_note_number,
    credit_note_date: cn.creditNoteDate || cn.credit_note_date,

    // Original Invoice Reference
    original_invoice_id: cn.againstInvoiceId || cn.originalInvoiceId || cn.original_invoice_id,
    original_invoice_number: cn.againstInvoiceNumber || cn.originalInvoiceNumber || cn.original_invoice_number,
    original_invoice_date: cn.originalInvoiceDate || cn.original_invoice_date,

    // Reason
    reason: formatReason(cn.reason),
    reason_code: cn.reason || cn.reason_code,

    // Place of Supply
    place_of_supply: cn.placeOfSupply || cn.place_of_supply,

    // Customer Info (from customerDetails or direct)
    customer_name: cn.customerName || cn.customerDetails?.customerName || cn.customer_name,
    customer_type: cn.customerDetails?.customerType || cn.customer_type,
    customer_gst: cn.customerDetails?.gstNumber || cn.customerGst || cn.customer_gst,
    customer_pan: cn.customerDetails?.panNumber || cn.customer_pan,
    customer_email: cn.customerDetails?.email || cn.customer_email,
    customer_phone: cn.customerDetails?.phoneNumber || cn.customer_phone,
    customer_address_line1: cn.customerDetails?.addressLine1 || cn.customer_address_line1,
    customer_address_line2: cn.customerDetails?.addressLine2 || cn.customer_address_line2,
    customer_city: cn.customerDetails?.city || cn.customer_city,
    customer_state: cn.customerDetails?.state || cn.customerState || cn.customer_state,
    customer_pincode: cn.customerDetails?.pinCode || cn.customer_pincode,
    customer_country: cn.customerDetails?.country || cn.customer_country,
    customer_state_code: getStateCodeFromGst(cn.customerDetails?.gstNumber || cn.customerGst) ||
                         getStateCode(cn.customerDetails?.state || cn.customerState) ||
                         cn.customer_state_code,

    // Company Info (from companyDetails or direct)
    company_name: cn.companyDetails?.companyLegalName || cn.company_name,
    company_gst: cn.companyDetails?.gstin || cn.company_gst,
    company_pan: cn.companyDetails?.pan || cn.company_pan,
    company_email: cn.companyDetails?.emailAddress || cn.companyDetails?.email || cn.company_email,
    company_phone: cn.companyDetails?.phoneNumber || cn.companyDetails?.phone || cn.company_phone,
    company_website: cn.companyDetails?.website || cn.company_website,
    company_address_line1: cn.companyDetails?.addressLine1 || cn.company_address_line1,
    company_address_line2: cn.companyDetails?.addressLine2 || cn.company_address_line2,
    company_city: cn.companyDetails?.city || cn.company_city,
    company_state: cn.companyDetails?.state || cn.companyState || cn.company_state,
    company_pincode: cn.companyDetails?.pinCode || cn.company_pincode,
    company_country: cn.companyDetails?.country || cn.company_country,
    company_state_code: getStateCode(cn.companyDetails?.state || cn.companyState) || cn.company_state_code,
    company_logo: formatLogoUrl(cn.companyDetails?.logoBase64 || cn.companyDetails?.companyLogo || cn.company_logo),

    // Totals
    subtotal: cn.subtotal || 0,
    cgst_total: cn.cgstTotal || cn.cgst_total || 0,
    sgst_total: cn.sgstTotal || cn.sgst_total || 0,
    igst_total: cn.igstTotal || cn.igst_total || 0,
    tax_total: cn.taxTotal || cn.tax_total || 0,
    grand_total: cn.grandTotal || cn.grand_total || 0,

    // Additional
    notes: cn.notes
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

// Format reason code to human-readable text
function formatReason(reason) {
  const reasons = {
    'goodsReturned': 'Goods Returned',
    'discountGiven': 'Discount Given',
    'overchargeCorrection': 'Overcharge Correction',
    'other': 'Other'
  };
  return reasons[reason] || reason || 'Not Specified';
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
  transformCreditNoteData,
  transformCreditNote,
  transformLineItem,
  getStateCode,
  getStateCodeFromGst,
  formatLogoUrl,
  formatReason
};
