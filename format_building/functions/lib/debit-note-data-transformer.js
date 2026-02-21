/**
 * Debit Note Data Transformer
 * Converts Flutter's camelCase data format to template's snake_case format
 */

function transformDebitNoteData(flutterData) {
  const debitNote = flutterData.debitNote || flutterData;
  const items = flutterData.items || flutterData.lineItems || [];

  return {
    debitNote: transformDebitNote(debitNote),
    items: items.map(transformLineItem)
  };
}

function transformDebitNote(dn) {
  return {
    // Basic Info
    debit_note_id: dn.id || dn.debitNoteId,
    debit_note_number: dn.debitNoteNumber || dn.debit_note_number,
    debit_note_date: dn.debitNoteDate || dn.debit_note_date,

    // Original Bill Reference
    original_bill_id: dn.againstBillId || dn.originalBillId || dn.original_bill_id,
    original_bill_number: dn.againstBillNumber || dn.originalBillNumber || dn.original_bill_number,
    original_bill_date: dn.originalBillDate || dn.original_bill_date,

    // Reason
    reason: formatReason(dn.reason),
    reason_code: dn.reason || dn.reason_code,
    reason_notes: dn.reasonNotes || dn.reason_notes,

    // Place of Supply
    place_of_supply: dn.placeOfSupply || dn.place_of_supply,

    // Vendor Info (from vendorDetails or direct)
    vendor_name: dn.vendorName || dn.vendorDetails?.vendorName || dn.vendor_name,
    vendor_vyapar_id: dn.vendorVyaparId || dn.vendorDetails?.linkedVyaparId || dn.vendor_vyapar_id,
    vendor_gst: dn.vendorDetails?.gstNumber || dn.vendorGst || dn.vendor_gst,
    vendor_pan: dn.vendorDetails?.panNumber || dn.vendor_pan,
    vendor_email: dn.vendorDetails?.email || dn.vendor_email,
    vendor_phone: dn.vendorDetails?.phoneNumber || dn.vendor_phone,
    vendor_address_line1: dn.vendorDetails?.addressLine1 || dn.vendor_address_line1,
    vendor_address_line2: dn.vendorDetails?.addressLine2 || dn.vendor_address_line2,
    vendor_city: dn.vendorDetails?.city || dn.vendor_city,
    vendor_state: dn.vendorDetails?.state || dn.vendorState || dn.vendor_state,
    vendor_pincode: dn.vendorDetails?.pinCode || dn.vendor_pincode,
    vendor_country: dn.vendorDetails?.country || dn.vendor_country,
    vendor_state_code: getStateCodeFromGst(dn.vendorDetails?.gstNumber || dn.vendorGst) ||
                       getStateCode(dn.vendorDetails?.state || dn.vendorState) ||
                       dn.vendor_state_code,

    // Company Info (from companyDetails or direct)
    company_name: dn.companyDetails?.companyLegalName || dn.company_name,
    company_gst: dn.companyDetails?.gstin || dn.company_gst,
    company_pan: dn.companyDetails?.pan || dn.company_pan,
    company_email: dn.companyDetails?.emailAddress || dn.companyDetails?.email || dn.company_email,
    company_phone: dn.companyDetails?.phoneNumber || dn.companyDetails?.phone || dn.company_phone,
    company_website: dn.companyDetails?.website || dn.company_website,
    company_address_line1: dn.companyDetails?.addressLine1 || dn.company_address_line1,
    company_address_line2: dn.companyDetails?.addressLine2 || dn.company_address_line2,
    company_city: dn.companyDetails?.city || dn.company_city,
    company_state: dn.companyDetails?.state || dn.companyState || dn.company_state,
    company_pincode: dn.companyDetails?.pinCode || dn.company_pincode,
    company_country: dn.companyDetails?.country || dn.company_country,
    company_state_code: getStateCode(dn.companyDetails?.state || dn.companyState) || dn.company_state_code,
    company_logo: formatLogoUrl(dn.companyDetails?.logoBase64 || dn.companyDetails?.companyLogo || dn.company_logo),

    // Totals
    subtotal: dn.subtotal || 0,
    cgst_total: dn.cgstTotal || dn.cgst_total || 0,
    sgst_total: dn.sgstTotal || dn.sgst_total || 0,
    igst_total: dn.igstTotal || dn.igst_total || 0,
    tax_total: dn.taxTotal || dn.tax_total || 0,
    grand_total: dn.grandTotal || dn.grand_total || 0,

    // Additional
    notes: dn.notes
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
    'Goods Damaged': 'Goods Damaged',
    'Short Receipt': 'Short Receipt',
    'Quality Issue': 'Quality Issue',
    'Other': 'Other',
    // Also handle camelCase variants
    'goodsDamaged': 'Goods Damaged',
    'shortReceipt': 'Short Receipt',
    'qualityIssue': 'Quality Issue',
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
  transformDebitNoteData,
  transformDebitNote,
  transformLineItem,
  getStateCode,
  getStateCodeFromGst,
  formatLogoUrl,
  formatReason
};
