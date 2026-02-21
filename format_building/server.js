/**
 * Quotation PDF API Server
 * Express server for generating quotation PDFs
 */

const express = require('express');
const cors = require('cors');
const { transformQuotationData } = require('./lib/data-transformer');
const { generateQuotationHTML } = require('./lib/html-template');
const { generatePDFFromHTML } = require('./lib/pdf-generator');

const app = express();
const PORT = process.env.PORT || 3001;

// Middleware
app.use(cors());
app.use(express.json({ limit: '10mb' }));

// Health check endpoint
app.get('/', (req, res) => {
  res.json({
    status: 'ok',
    message: 'Quotation PDF API is running',
    endpoints: {
      generatePdf: 'POST /api/generate-pdf',
      health: 'GET /health',
    },
  });
});

app.get('/health', (req, res) => {
  res.json({ status: 'healthy', timestamp: new Date().toISOString() });
});

/**
 * Generate PDF endpoint
 * POST /api/generate-pdf
 *
 * Request body should contain quotation data from Flutter app
 */
app.post('/api/generate-pdf', async (req, res) => {
  try {
    const requestData = req.body;

    if (!requestData) {
      return res.status(400).json({
        error: 'Bad Request',
        message: 'Request body is required',
      });
    }

    console.log('Received PDF generation request');
    console.log('=== RAW REQUEST DATA ===');
    console.log('quotationType:', requestData.quotationType);
    console.log('cgstTotal:', requestData.cgstTotal);
    console.log('sgstTotal:', requestData.sgstTotal);
    console.log('igstTotal:', requestData.igstTotal);
    console.log('companyDetails?.state:', requestData.companyDetails?.state);
    console.log('customerDetails?.state:', requestData.customerDetails?.state);
    if (requestData.lineItems?.length > 0) {
      console.log('First lineItem tax:', {
        gstPercentage: requestData.lineItems[0].gstPercentage,
        cgstAmount: requestData.lineItems[0].cgstAmount,
        sgstAmount: requestData.lineItems[0].sgstAmount,
        igstAmount: requestData.lineItems[0].igstAmount,
      });
    }
    console.log('========================');

    // Transform Flutter data to template format
    const transformedData = transformQuotationData(requestData);

    const isIntraState = transformedData.quotation.company_state === transformedData.quotation.customer_state;

    console.log('Data transformed successfully');
    console.log('Quotation Number:', transformedData.quotation.quotation_number);
    console.log('Quotation Type:', transformedData.quotation.quotation_type);
    console.log('Company State:', transformedData.quotation.company_state);
    console.log('Customer State:', transformedData.quotation.customer_state);
    console.log('Is Intra-State:', isIntraState);
    console.log('Items count:', transformedData.items.length);
    console.log('Tax Totals - CGST:', transformedData.quotation.cgst_total, 'SGST:', transformedData.quotation.sgst_total, 'IGST:', transformedData.quotation.igst_total);
    console.log('Company Logo present:', !!transformedData.quotation.company_logo);

    // Log first item tax details if available
    if (transformedData.items.length > 0) {
      const firstItem = transformedData.items[0];
      console.log('First item tax:', {
        taxable: firstItem.taxable_amount,
        cgst: firstItem.cgst_amount,
        sgst: firstItem.sgst_amount,
        igst: firstItem.igst_amount
      });
    }

    // Generate HTML from template
    const html = generateQuotationHTML(transformedData);

    console.log('HTML generated successfully');

    // Generate PDF from HTML
    const pdfBuffer = await generatePDFFromHTML(html);

    console.log('PDF generated successfully, size:', pdfBuffer.length, 'bytes');

    // Set response headers
    const filename = `${transformedData.quotation.quotation_number || 'quotation'}.pdf`.replace(/\//g, '-');

    res.set({
      'Content-Type': 'application/pdf',
      'Content-Disposition': `attachment; filename="${filename}"`,
      'Content-Length': pdfBuffer.length,
    });

    // Send PDF buffer
    res.send(pdfBuffer);

  } catch (error) {
    console.error('Error generating PDF:', error);
    res.status(500).json({
      error: 'Internal Server Error',
      message: error.message || 'Failed to generate PDF',
    });
  }
});

/**
 * Preview HTML endpoint (for debugging)
 * POST /api/preview-html
 */
app.post('/api/preview-html', (req, res) => {
  try {
    const requestData = req.body;

    if (!requestData) {
      return res.status(400).json({
        error: 'Bad Request',
        message: 'Request body is required',
      });
    }

    // Transform data
    const transformedData = transformQuotationData(requestData);

    // Generate HTML
    const html = generateQuotationHTML(transformedData);

    // Return HTML for preview
    res.set('Content-Type', 'text/html');
    res.send(html);

  } catch (error) {
    console.error('Error generating HTML preview:', error);
    res.status(500).json({
      error: 'Internal Server Error',
      message: error.message || 'Failed to generate HTML',
    });
  }
});

// Start server
app.listen(PORT, () => {
  console.log(`
╔════════════════════════════════════════════════════════════╗
║          Quotation PDF API Server                          ║
╠════════════════════════════════════════════════════════════╣
║  Server running on: http://localhost:${PORT}                  ║
║                                                            ║
║  Endpoints:                                                ║
║    POST /api/generate-pdf  - Generate PDF from quotation   ║
║    POST /api/preview-html  - Preview HTML (for debugging)  ║
║    GET  /health            - Health check                  ║
╚════════════════════════════════════════════════════════════╝
  `);
});

module.exports = app;
