/**
 * Firebase Functions for Quotation PDF Generation
 */

const functions = require('firebase-functions');
const admin = require('firebase-admin');
const chromium = require('@sparticuz/chromium');
const puppeteer = require('puppeteer-core');
const cors = require('cors')({ origin: true });

const { transformQuotationData } = require('./lib/data-transformer');
const { generateQuotationHTML } = require('./lib/html-template');
const { transformInvoiceData } = require('./lib/invoice-data-transformer');
const { generateInvoiceHTML } = require('./lib/invoice-html-template');
const { transformCreditNoteData } = require('./lib/credit-note-data-transformer');
const { generateCreditNoteHTML } = require('./lib/credit-note-html-template');
const { transformPurchaseOrderData } = require('./lib/purchase-order-data-transformer');
const { generatePurchaseOrderHTML } = require('./lib/purchase-order-html-template');
const { transformDebitNoteData } = require('./lib/debit-note-data-transformer');
const { generateDebitNoteHTML } = require('./lib/debit-note-html-template');
const { transformReportData } = require('./lib/report-data-transformer');
const { generateReportHTML } = require('./lib/report-html-template');

// Initialize Firebase Admin
admin.initializeApp();

// Configure chromium for serverless
chromium.setHeadlessMode = true;
chromium.setGraphicsMode = false;

/**
 * Generate PDF from quotation data
 * POST /generatePdf
 */
exports.generatePdf = functions
  .runWith({
    memory: '1GB',
    timeoutSeconds: 120,
  })
  .https.onRequest((req, res) => {
    cors(req, res, async () => {
      // Only allow POST requests
      if (req.method !== 'POST') {
        return res.status(405).json({ error: 'Method not allowed' });
      }

      let browser = null;

      try {
        const requestData = req.body;

        if (!requestData) {
          return res.status(400).json({
            error: 'Bad Request',
            message: 'Request body is required',
          });
        }

        console.log('Received PDF generation request');

        // Transform Flutter data to template format
        const transformedData = transformQuotationData(requestData);

        console.log('Quotation Number:', transformedData.quotation.quotation_number);
        console.log('Quotation Type:', transformedData.quotation.quotation_type);

        // Generate HTML from template
        const html = generateQuotationHTML(transformedData);

        console.log('HTML generated, launching browser...');

        // Launch browser with serverless-compatible settings
        browser = await puppeteer.launch({
          args: chromium.args,
          defaultViewport: chromium.defaultViewport,
          executablePath: await chromium.executablePath(),
          headless: chromium.headless,
        });

        const page = await browser.newPage();

        // Set content and wait for it to load
        await page.setContent(html, {
          waitUntil: ['networkidle0', 'domcontentloaded'],
        });

        // Generate PDF with A4 format
        const pdfBuffer = await page.pdf({
          format: 'A4',
          printBackground: true,
          margin: {
            top: '10mm',
            right: '10mm',
            bottom: '10mm',
            left: '10mm',
          },
        });

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
      } finally {
        if (browser) {
          await browser.close();
        }
      }
    });
  });

/**
 * Preview HTML endpoint (for debugging)
 * POST /previewHtml
 */
exports.previewHtml = functions
  .runWith({
    memory: '256MB',
    timeoutSeconds: 30,
  })
  .https.onRequest((req, res) => {
    cors(req, res, async () => {
      if (req.method !== 'POST') {
        return res.status(405).json({ error: 'Method not allowed' });
      }

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
  });

/**
 * Generate Invoice PDF from invoice data
 * POST /generateInvoicePdf
 */
exports.generateInvoicePdf = functions
  .runWith({
    memory: '1GB',
    timeoutSeconds: 120,
  })
  .https.onRequest((req, res) => {
    cors(req, res, async () => {
      // Only allow POST requests
      if (req.method !== 'POST') {
        return res.status(405).json({ error: 'Method not allowed' });
      }

      let browser = null;

      try {
        const requestData = req.body;

        if (!requestData) {
          return res.status(400).json({
            error: 'Bad Request',
            message: 'Request body is required',
          });
        }

        console.log('Received Invoice PDF generation request');

        // Transform Flutter data to template format
        const transformedData = transformInvoiceData(requestData);

        console.log('Invoice Number:', transformedData.invoice.invoice_number);
        console.log('Invoice Type:', transformedData.invoice.invoice_type);

        // Generate HTML from template
        const html = generateInvoiceHTML(transformedData);

        console.log('HTML generated, launching browser...');

        // Launch browser with serverless-compatible settings
        browser = await puppeteer.launch({
          args: chromium.args,
          defaultViewport: chromium.defaultViewport,
          executablePath: await chromium.executablePath(),
          headless: chromium.headless,
        });

        const page = await browser.newPage();

        // Set content and wait for it to load
        await page.setContent(html, {
          waitUntil: ['networkidle0', 'domcontentloaded'],
        });

        // Generate PDF with A4 format
        const pdfBuffer = await page.pdf({
          format: 'A4',
          printBackground: true,
          margin: {
            top: '10mm',
            right: '10mm',
            bottom: '10mm',
            left: '10mm',
          },
        });

        console.log('Invoice PDF generated successfully, size:', pdfBuffer.length, 'bytes');

        // Set response headers
        const filename = `${transformedData.invoice.invoice_number || 'invoice'}.pdf`.replace(/\//g, '-');

        res.set({
          'Content-Type': 'application/pdf',
          'Content-Disposition': `attachment; filename="${filename}"`,
          'Content-Length': pdfBuffer.length,
        });

        // Send PDF buffer
        res.send(pdfBuffer);

      } catch (error) {
        console.error('Error generating Invoice PDF:', error);
        res.status(500).json({
          error: 'Internal Server Error',
          message: error.message || 'Failed to generate Invoice PDF',
        });
      } finally {
        if (browser) {
          await browser.close();
        }
      }
    });
  });

/**
 * Preview Invoice HTML endpoint (for debugging)
 * POST /previewInvoiceHtml
 */
exports.previewInvoiceHtml = functions
  .runWith({
    memory: '256MB',
    timeoutSeconds: 30,
  })
  .https.onRequest((req, res) => {
    cors(req, res, async () => {
      if (req.method !== 'POST') {
        return res.status(405).json({ error: 'Method not allowed' });
      }

      try {
        const requestData = req.body;

        if (!requestData) {
          return res.status(400).json({
            error: 'Bad Request',
            message: 'Request body is required',
          });
        }

        // Transform data
        const transformedData = transformInvoiceData(requestData);

        // Generate HTML
        const html = generateInvoiceHTML(transformedData);

        // Return HTML for preview
        res.set('Content-Type', 'text/html');
        res.send(html);

      } catch (error) {
        console.error('Error generating Invoice HTML preview:', error);
        res.status(500).json({
          error: 'Internal Server Error',
          message: error.message || 'Failed to generate Invoice HTML',
        });
      }
    });
  });
/**
 * Generate Credit Note PDF from credit note data
 * POST /generateCreditNotePdf
 */
exports.generateCreditNotePdf = functions
  .runWith({
    memory: '1GB',
    timeoutSeconds: 120,
  })
  .https.onRequest((req, res) => {
    cors(req, res, async () => {
      // Only allow POST requests
      if (req.method !== 'POST') {
        return res.status(405).json({ error: 'Method not allowed' });
      }

      let browser = null;

      try {
        const requestData = req.body;

        if (!requestData) {
          return res.status(400).json({
            error: 'Bad Request',
            message: 'Request body is required',
          });
        }

        console.log('Received Credit Note PDF generation request');

        // Transform Flutter data to template format
        const transformedData = transformCreditNoteData(requestData);

        console.log('Credit Note Number:', transformedData.creditNote.credit_note_number);

        // Generate HTML from template
        const html = generateCreditNoteHTML(transformedData);

        console.log('HTML generated, launching browser...');

        // Launch browser with serverless-compatible settings
        browser = await puppeteer.launch({
          args: chromium.args,
          defaultViewport: chromium.defaultViewport,
          executablePath: await chromium.executablePath(),
          headless: chromium.headless,
        });

        const page = await browser.newPage();

        // Set content and wait for it to load
        await page.setContent(html, {
          waitUntil: ['networkidle0', 'domcontentloaded'],
        });

        // Generate PDF with A4 format
        const pdfBuffer = await page.pdf({
          format: 'A4',
          printBackground: true,
          margin: {
            top: '10mm',
            right: '10mm',
            bottom: '10mm',
            left: '10mm',
          },
        });

        console.log('Credit Note PDF generated successfully, size:', pdfBuffer.length, 'bytes');

        // Set response headers
        const filename = `${transformedData.creditNote.credit_note_number || 'credit-note'}.pdf`.replace(/\//g, '-');

        res.set({
          'Content-Type': 'application/pdf',
          'Content-Disposition': `attachment; filename="${filename}"`,
          'Content-Length': pdfBuffer.length,
        });

        // Send PDF buffer
        res.send(pdfBuffer);

      } catch (error) {
        console.error('Error generating Credit Note PDF:', error);
        res.status(500).json({
          error: 'Internal Server Error',
          message: error.message || 'Failed to generate Credit Note PDF',
        });
      } finally {
        if (browser) {
          await browser.close();
        }
      }
    });
  });

/**
 * Preview Credit Note HTML endpoint (for debugging)
 * POST /previewCreditNoteHtml
 */
exports.previewCreditNoteHtml = functions
  .runWith({
    memory: '256MB',
    timeoutSeconds: 30,
  })
  .https.onRequest((req, res) => {
    cors(req, res, async () => {
      if (req.method !== 'POST') {
        return res.status(405).json({ error: 'Method not allowed' });
      }

      try {
        const requestData = req.body;

        if (!requestData) {
          return res.status(400).json({
            error: 'Bad Request',
            message: 'Request body is required',
          });
        }

        // Transform data
        const transformedData = transformCreditNoteData(requestData);

        // Generate HTML
        const html = generateCreditNoteHTML(transformedData);

        // Return HTML for preview
        res.set('Content-Type', 'text/html');
        res.send(html);

      } catch (error) {
        console.error('Error generating Credit Note HTML preview:', error);
        res.status(500).json({
          error: 'Internal Server Error',
          message: error.message || 'Failed to generate Credit Note HTML',
        });
      }
    });
  });

/**
 * Generate Purchase Order PDF from purchase order data
 * POST /generatePurchaseOrderPdf
 */
exports.generatePurchaseOrderPdf = functions
  .runWith({
    memory: '1GB',
    timeoutSeconds: 120,
  })
  .https.onRequest((req, res) => {
    cors(req, res, async () => {
      // Only allow POST requests
      if (req.method !== 'POST') {
        return res.status(405).json({ error: 'Method not allowed' });
      }

      let browser = null;

      try {
        const requestData = req.body;

        if (!requestData) {
          return res.status(400).json({
            error: 'Bad Request',
            message: 'Request body is required',
          });
        }

        console.log('Received Purchase Order PDF generation request');

        // Transform Flutter data to template format
        const transformedData = transformPurchaseOrderData(requestData);

        console.log('Purchase Order Number:', transformedData.po.po_number);

        // Generate HTML from template
        const html = generatePurchaseOrderHTML(transformedData);

        console.log('HTML generated, launching browser...');

        // Launch browser with serverless-compatible settings
        browser = await puppeteer.launch({
          args: chromium.args,
          defaultViewport: chromium.defaultViewport,
          executablePath: await chromium.executablePath(),
          headless: chromium.headless,
        });

        const page = await browser.newPage();

        // Set content and wait for it to load
        await page.setContent(html, {
          waitUntil: ['networkidle0', 'domcontentloaded'],
        });

        // Generate PDF with A4 format
        const pdfBuffer = await page.pdf({
          format: 'A4',
          printBackground: true,
          margin: {
            top: '10mm',
            right: '10mm',
            bottom: '10mm',
            left: '10mm',
          },
        });

        console.log('Purchase Order PDF generated successfully, size:', pdfBuffer.length, 'bytes');

        // Set response headers
        const filename = `${transformedData.po.po_number || 'purchase-order'}.pdf`.replace(/\//g, '-');

        res.set({
          'Content-Type': 'application/pdf',
          'Content-Disposition': `attachment; filename="${filename}"`,
          'Content-Length': pdfBuffer.length,
        });

        // Send PDF buffer
        res.send(pdfBuffer);

      } catch (error) {
        console.error('Error generating Purchase Order PDF:', error);
        res.status(500).json({
          error: 'Internal Server Error',
          message: error.message || 'Failed to generate Purchase Order PDF',
        });
      } finally {
        if (browser) {
          await browser.close();
        }
      }
    });
  });

/**
 * Preview Purchase Order HTML endpoint (for debugging)
 * POST /previewPurchaseOrderHtml
 */
exports.previewPurchaseOrderHtml = functions
  .runWith({
    memory: '256MB',
    timeoutSeconds: 30,
  })
  .https.onRequest((req, res) => {
    cors(req, res, async () => {
      if (req.method !== 'POST') {
        return res.status(405).json({ error: 'Method not allowed' });
      }

      try {
        const requestData = req.body;

        if (!requestData) {
          return res.status(400).json({
            error: 'Bad Request',
            message: 'Request body is required',
          });
        }

        // Transform data
        const transformedData = transformPurchaseOrderData(requestData);

        // Generate HTML
        const html = generatePurchaseOrderHTML(transformedData);

        // Return HTML for preview
        res.set('Content-Type', 'text/html');
        res.send(html);

      } catch (error) {
        console.error('Error generating Purchase Order HTML preview:', error);
        res.status(500).json({
          error: 'Internal Server Error',
          message: error.message || 'Failed to generate Purchase Order HTML',
        });
      }
    });
  });

/**
 * Generate Debit Note PDF from debit note data
 * POST /generateDebitNotePdf
 */
exports.generateDebitNotePdf = functions
  .runWith({
    memory: '1GB',
    timeoutSeconds: 120,
  })
  .https.onRequest((req, res) => {
    cors(req, res, async () => {
      // Only allow POST requests
      if (req.method !== 'POST') {
        return res.status(405).json({ error: 'Method not allowed' });
      }

      let browser = null;

      try {
        const requestData = req.body;

        if (!requestData) {
          return res.status(400).json({
            error: 'Bad Request',
            message: 'Request body is required',
          });
        }

        console.log('Received Debit Note PDF generation request');

        // Transform Flutter data to template format
        const transformedData = transformDebitNoteData(requestData);

        console.log('Debit Note Number:', transformedData.debitNote.debit_note_number);

        // Generate HTML from template
        const html = generateDebitNoteHTML(transformedData);

        console.log('HTML generated, launching browser...');

        // Launch browser with serverless-compatible settings
        browser = await puppeteer.launch({
          args: chromium.args,
          defaultViewport: chromium.defaultViewport,
          executablePath: await chromium.executablePath(),
          headless: chromium.headless,
        });

        const page = await browser.newPage();

        // Set content and wait for it to load
        await page.setContent(html, {
          waitUntil: ['networkidle0', 'domcontentloaded'],
        });

        // Generate PDF with A4 format
        const pdfBuffer = await page.pdf({
          format: 'A4',
          printBackground: true,
          margin: {
            top: '10mm',
            right: '10mm',
            bottom: '10mm',
            left: '10mm',
          },
        });

        console.log('Debit Note PDF generated successfully, size:', pdfBuffer.length, 'bytes');

        // Set response headers
        const filename = `${transformedData.debitNote.debit_note_number || 'debit-note'}.pdf`.replace(/\//g, '-');

        res.set({
          'Content-Type': 'application/pdf',
          'Content-Disposition': `attachment; filename="${filename}"`,
          'Content-Length': pdfBuffer.length,
        });

        // Send PDF buffer
        res.send(pdfBuffer);

      } catch (error) {
        console.error('Error generating Debit Note PDF:', error);
        res.status(500).json({
          error: 'Internal Server Error',
          message: error.message || 'Failed to generate Debit Note PDF',
        });
      } finally {
        if (browser) {
          await browser.close();
        }
      }
    });
  });

/**
 * Preview Debit Note HTML endpoint (for debugging)
 * POST /previewDebitNoteHtml
 */
exports.previewDebitNoteHtml = functions
  .runWith({
    memory: '256MB',
    timeoutSeconds: 30,
  })
  .https.onRequest((req, res) => {
    cors(req, res, async () => {
      if (req.method !== 'POST') {
        return res.status(405).json({ error: 'Method not allowed' });
      }

      try {
        const requestData = req.body;

        if (!requestData) {
          return res.status(400).json({
            error: 'Bad Request',
            message: 'Request body is required',
          });
        }

        // Transform data
        const transformedData = transformDebitNoteData(requestData);

        // Generate HTML
        const html = generateDebitNoteHTML(transformedData);

        // Return HTML for preview
        res.set('Content-Type', 'text/html');
        res.send(html);

      } catch (error) {
        console.error('Error generating Debit Note HTML preview:', error);
        res.status(500).json({
          error: 'Internal Server Error',
          message: error.message || 'Failed to generate Debit Note HTML',
        });
      }
    });
  });

/**
 * Generate Report PDF from report data
 * POST /generateReportPdf
 * Supports: sales_register, purchase_register, outstanding_receivables,
 *           outstanding_payables, customer_wise_sales, vendor_wise_purchases
 */
exports.generateReportPdf = functions
  .runWith({
    memory: '1GB',
    timeoutSeconds: 120,
  })
  .https.onRequest((req, res) => {
    cors(req, res, async () => {
      // Only allow POST requests
      if (req.method !== 'POST') {
        return res.status(405).json({ error: 'Method not allowed' });
      }

      let browser = null;

      try {
        const requestData = req.body;

        if (!requestData) {
          return res.status(400).json({
            error: 'Bad Request',
            message: 'Request body is required',
          });
        }

        console.log('Received Report PDF generation request, type:', requestData.reportType);

        // Transform Flutter data to template format
        const transformedData = transformReportData(requestData);

        console.log('Report Type:', transformedData.report_type);
        console.log('Report Title:', transformedData.metadata.title);
        console.log('Orientation:', transformedData.metadata.orientation);
        console.log('Items count:', transformedData.items.length);

        // Generate HTML from template
        const html = generateReportHTML(transformedData);

        console.log('HTML generated, launching browser...');

        // Launch browser with serverless-compatible settings
        browser = await puppeteer.launch({
          args: chromium.args,
          defaultViewport: chromium.defaultViewport,
          executablePath: await chromium.executablePath(),
          headless: chromium.headless,
        });

        const page = await browser.newPage();

        // Set content and wait for it to load
        await page.setContent(html, {
          waitUntil: ['networkidle0', 'domcontentloaded'],
        });

        // Generate PDF - landscape or portrait based on report type
        const isLandscape = transformedData.metadata.orientation === 'landscape';
        const pdfBuffer = await page.pdf({
          format: 'A4',
          landscape: isLandscape,
          printBackground: true,
          margin: {
            top: '10mm',
            right: '10mm',
            bottom: '10mm',
            left: '10mm',
          },
        });

        console.log('Report PDF generated successfully, size:', pdfBuffer.length, 'bytes');

        // Set response headers
        const filename = `${transformedData.metadata.title || 'report'}.pdf`.replace(/[\s\/]/g, '-');

        res.set({
          'Content-Type': 'application/pdf',
          'Content-Disposition': `attachment; filename="${filename}"`,
          'Content-Length': pdfBuffer.length,
        });

        // Send PDF buffer
        res.send(pdfBuffer);

      } catch (error) {
        console.error('Error generating Report PDF:', error);
        res.status(500).json({
          error: 'Internal Server Error',
          message: error.message || 'Failed to generate Report PDF',
        });
      } finally {
        if (browser) {
          await browser.close();
        }
      }
    });
  });

/**
 * Preview Report HTML endpoint (for debugging)
 * POST /previewReportHtml
 */
exports.previewReportHtml = functions
  .runWith({
    memory: '256MB',
    timeoutSeconds: 30,
  })
  .https.onRequest((req, res) => {
    cors(req, res, async () => {
      if (req.method !== 'POST') {
        return res.status(405).json({ error: 'Method not allowed' });
      }

      try {
        const requestData = req.body;

        if (!requestData) {
          return res.status(400).json({
            error: 'Bad Request',
            message: 'Request body is required',
          });
        }

        // Transform data
        const transformedData = transformReportData(requestData);

        // Generate HTML
        const html = generateReportHTML(transformedData);

        // Return HTML for preview
        res.set('Content-Type', 'text/html');
        res.send(html);

      } catch (error) {
        console.error('Error generating Report HTML preview:', error);
        res.status(500).json({
          error: 'Internal Server Error',
          message: error.message || 'Failed to generate Report HTML',
        });
      }
    });
  });

/**
 * Health check endpoint
 * GET /health
 */
exports.health = functions.https.onRequest((req, res) => {
  cors(req, res, () => {
    res.json({
      status: 'healthy',
      timestamp: new Date().toISOString(),
      service: 'Quotation, Invoice, Credit Note, Purchase Order, Debit Note & Report PDF API',
    });
  });
});
