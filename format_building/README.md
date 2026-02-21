# Quotation PDF API

Serverless API for generating quotation PDFs using Puppeteer and Chromium.

## Structure

```
format_building/
├── api/
│   └── generate-pdf.js    # Vercel serverless function
├── lib/
│   ├── data-transformer.js # Converts Flutter data to template format
│   ├── html-template.js    # HTML template generator
│   └── pdf-generator.js    # Puppeteer PDF generator
├── server.js               # Express server (local development)
├── package.json
├── vercel.json             # Vercel deployment config
└── README.md
```

## Local Development

1. Install dependencies:
   ```bash
   cd format_building
   npm install
   ```

2. Start the server:
   ```bash
   npm start
   ```

3. Server runs at `http://localhost:3000`

## API Endpoints

### Generate PDF
```
POST /api/generate-pdf
Content-Type: application/json

Body: Quotation data from Flutter app
Response: PDF binary
```

### Preview HTML (Debug)
```
POST /api/preview-html
Content-Type: application/json

Body: Quotation data from Flutter app
Response: HTML content
```

## Deploy to Vercel

1. Install Vercel CLI:
   ```bash
   npm install -g vercel
   ```

2. Deploy:
   ```bash
   cd format_building
   vercel
   ```

3. For production:
   ```bash
   vercel --prod
   ```

## Flutter Integration

```dart
Future<Uint8List> fetchQuotationPdf(Quotation quotation) async {
  final response = await http.post(
    Uri.parse('https://your-api.vercel.app/api/generate-pdf'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode(quotation.toMap()),
  );

  if (response.statusCode == 200) {
    return response.bodyBytes;
  }
  throw Exception('Failed to generate PDF');
}
```

## Data Transformation

The API automatically transforms Flutter's camelCase format to template's snake_case format:

| Flutter | Template |
|---------|----------|
| `quotationType` | `quotation_type` |
| `companyDetails.state` | `company_state` |
| `customerDetails.state` | `customer_state` |
| `cgstRate` | `cgst_rate` |
| `taxableAmount` | `taxable_amount` |
