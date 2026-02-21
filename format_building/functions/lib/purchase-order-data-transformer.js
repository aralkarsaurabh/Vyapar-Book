/**
 * Purchase Order Data Transformer
 * Converts Flutter's camelCase data format to template's snake_case format
 */

function transformPurchaseOrderData(flutterData) {
  const po = flutterData.purchaseOrder || flutterData.po || flutterData;
  const items = flutterData.items || flutterData.lineItems || [];

  return {
    po: transformPurchaseOrder(po),
    items: items.map(transformLineItem)
  };
}

function transformPurchaseOrder(po) {
  return {
    // Basic Info
    po_id: po.id || po.poId,
    po_number: po.poNumber || po.po_number,
    po_date: po.poDate || po.po_date,
    delivery_date: po.expectedDeliveryDate || po.deliveryDate || po.delivery_date,
    status: po.status,

    // Place of Supply
    place_of_supply: po.placeOfSupply || po.place_of_supply,

    // Reference (if created from quotation)
    against_quotation_id: po.againstQuotationId || po.against_quotation_id,
    against_quotation_number: po.againstQuotationNumber || po.against_quotation_number,

    // Vendor Info (from vendorDetails or direct)
    vendor_name: po.vendorName || po.vendorDetails?.companyName || po.vendor_name,
    vendor_gst: po.vendorDetails?.gstNumber || po.vendorGst || po.vendor_gst,
    vendor_pan: po.vendorDetails?.panNumber || po.vendor_pan,
    vendor_email: po.vendorDetails?.email || po.vendor_email,
    vendor_phone: po.vendorDetails?.phoneNumber || po.vendor_phone,
    vendor_address_line_1: po.vendorDetails?.addressLine1 || po.vendorDetails?.address || po.vendor_address_line_1,
    vendor_address_line_2: po.vendorDetails?.addressLine2 || po.vendor_address_line_2,
    vendor_city: po.vendorDetails?.city || po.vendor_city,
    vendor_state: po.vendorDetails?.state || po.vendorState || po.vendor_state,
    vendor_pincode: po.vendorDetails?.pinCode || po.vendor_pincode,
    vendor_country: po.vendorDetails?.country || po.vendor_country,
    vendor_state_code: getStateCodeFromGst(po.vendorDetails?.gstNumber || po.vendorGst) ||
                       getStateCode(po.vendorDetails?.state || po.vendorState) ||
                       po.vendor_state_code,

    // Company Info (from companyDetails or direct)
    company_legal_name: po.companyDetails?.companyLegalName || po.company_legal_name || po.company_name,
    trade_name: po.companyDetails?.tradeName || po.trade_name,
    gstin: po.companyDetails?.gstin || po.gstin || po.company_gst,
    company_pan: po.companyDetails?.pan || po.company_pan,
    company_email: po.companyDetails?.emailAddress || po.companyDetails?.email || po.company_email,
    company_phone: po.companyDetails?.phoneNumber || po.companyDetails?.phone || po.company_phone,
    company_website: po.companyDetails?.website || po.company_website,
    company_address_line_1: po.companyDetails?.addressLine1 || po.company_address_line_1,
    company_address_line_2: po.companyDetails?.addressLine2 || po.company_address_line_2,
    company_city: po.companyDetails?.city || po.company_city,
    company_state: po.companyDetails?.state || po.companyState || po.company_state,
    company_pincode: po.companyDetails?.pinCode || po.company_pincode,
    company_country: po.companyDetails?.country || po.company_country,
    gst_state_code: getStateCode(po.companyDetails?.state || po.companyState) || po.gst_state_code,
    company_logo: formatLogoUrl(po.companyDetails?.logoBase64 || po.companyDetails?.companyLogo || po.company_logo),

    // Totals
    subtotal: po.subtotal || 0,
    discount_amount: po.discountAmount || po.discount_amount || 0,
    cgst_total: po.cgstTotal || po.cgst_total || 0,
    sgst_total: po.sgstTotal || po.sgst_total || 0,
    igst_total: po.igstTotal || po.igst_total || 0,
    tax_total: po.taxTotal || po.tax_total || 0,
    grand_total: po.grandTotal || po.grand_total || 0,

    // Additional
    notes: po.notes,
    terms_and_conditions: po.termsAndConditions || po.terms_and_conditions
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
  transformPurchaseOrderData,
  transformPurchaseOrder,
  transformLineItem,
  getStateCode,
  getStateCodeFromGst,
  formatLogoUrl
};
