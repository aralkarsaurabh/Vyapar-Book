/**
 * PDF Generator
 * Uses regular puppeteer for local development, puppeteer-core with @sparticuz/chromium for serverless
 */

// Detect if running in serverless environment
const isServerless = !!(process.env.AWS_LAMBDA_FUNCTION_NAME || process.env.VERCEL);

let puppeteer;
let chromium;

if (isServerless) {
  // Serverless: use puppeteer-core with @sparticuz/chromium
  puppeteer = require('puppeteer-core');
  chromium = require('@sparticuz/chromium');
  chromium.setHeadlessMode = true;
  chromium.setGraphicsMode = false;
} else {
  // Local development: use regular puppeteer (comes with bundled Chromium)
  puppeteer = require('puppeteer');
}

/**
 * Get browser launch options based on environment
 */
async function getBrowserOptions() {
  if (isServerless) {
    return {
      args: chromium.args,
      defaultViewport: chromium.defaultViewport,
      executablePath: await chromium.executablePath(),
      headless: chromium.headless,
    };
  }

  // Local development options
  return {
    headless: 'new',
    args: ['--no-sandbox', '--disable-setuid-sandbox'],
  };
}

/**
 * Generate PDF from HTML content
 * @param {string} html - HTML content to convert to PDF
 * @returns {Promise<Buffer>} - PDF buffer
 */
async function generatePDFFromHTML(html) {
  let browser = null;

  try {
    const options = await getBrowserOptions();
    browser = await puppeteer.launch(options);

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

    return pdfBuffer;
  } catch (error) {
    console.error('Error generating PDF:', error);
    throw error;
  } finally {
    if (browser) {
      await browser.close();
    }
  }
}

/**
 * Generate PDF with custom options
 * @param {string} html - HTML content
 * @param {object} options - PDF options
 * @returns {Promise<Buffer>} - PDF buffer
 */
async function generatePDFWithOptions(html, options = {}) {
  let browser = null;

  try {
    const browserOptions = await getBrowserOptions();
    browser = await puppeteer.launch(browserOptions);

    const page = await browser.newPage();

    await page.setContent(html, {
      waitUntil: ['networkidle0', 'domcontentloaded'],
    });

    const defaultOptions = {
      format: 'A4',
      printBackground: true,
      margin: {
        top: '10mm',
        right: '10mm',
        bottom: '10mm',
        left: '10mm',
      },
    };

    const pdfBuffer = await page.pdf({
      ...defaultOptions,
      ...options,
    });

    return pdfBuffer;
  } catch (error) {
    console.error('Error generating PDF:', error);
    throw error;
  } finally {
    if (browser) {
      await browser.close();
    }
  }
}

module.exports = {
  generatePDFFromHTML,
  generatePDFWithOptions,
};
