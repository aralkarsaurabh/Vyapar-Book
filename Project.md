# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

VyaparBook is a Flutter desktop/mobile application for invoice and quotation management with GST tax compliance for Indian small-medium businesses. Uses Firebase for backend services. The tagline is "Vyapar ka Digital Hisaab" (Digital accounting for business).

## Build & Run Commands

```bash
flutter pub get          # Install dependencies
flutter run -d windows   # Run on Windows desktop
flutter run -d chrome    # Run on web
flutter build windows    # Build Windows release
flutter analyze          # Run static analysis
flutter clean            # Clean build artifacts
```

## Architecture

### Tech Stack
- **Framework**: Flutter (Dart SDK ^3.10.4)
- **Backend**: Firebase (Auth, Firestore)
- **Routing**: GoRouter with ShellRoute for dashboard layout
- **PDF**: Cloud Functions with Puppeteer (see `format_building/functions/`)

### Theme & Colors
AppColors in `lib/config/themes.dart`:
- **Primary**: `primary`, `primaryLight`, `primaryDark` (blue tones)
- **Neutral**: `background`, `surface`, `border`
- **Text**: `textPrimary`, `textSecondary`, `textOnPrimary`
- **Status**: `success` (green), `error` (red), `warning` (amber), `info` (sky blue)

### Directory Structure
```
lib/
├── config/          # Router and theme configuration
├── screens/         # UI screens organized by feature (auth/, customers/, invoices/, quotations/, purchase_orders/, vendors/, profile/)
├── services/        # Firebase/business logic (one service per entity)
├── widgets/         # Reusable components (app_sidebar.dart)
└── main.dart        # App entry with Firebase initialization

format_building/functions/   # Firebase Cloud Functions for PDF generation
├── index.js                 # Function endpoints (generatePdf, generateInvoicePdf)
└── lib/                     # HTML templates and data transformers
```

### Key Patterns

**Service Layer**: Each entity (Customer, Invoice, Quotation) has a dedicated service class handling Firestore CRUD operations. Services are instantiated directly in widgets (no DI).

**Document Numbering**: Format is `PREFIX/TYPE/YYYY-YY/NNN` where PREFIX is company initials (e.g., "TPL" for "Triroop Pvt Ltd"). See `getCompanyInitials()` in services.

**GST Tax Calculations**: LineItem model calculates CGST/SGST (intra-state) or IGST (inter-state) based on company vs customer state comparison.

**Quotation to Invoice Conversion**: Quotations can be converted to invoices. The `convertedToInvoice` flag prevents re-conversion, and `referenceNumber` links to original quotation.

**PDF Generation**: Flutter app calls Firebase Cloud Functions which use Puppeteer to render HTML templates to PDF. Templates are in `format_building/functions/lib/`.

**List Screens with Pagination**: Customers, Invoices, and Quotations screens use client-side pagination on Firestore streams:
- Data fetched via `StreamBuilder` with real-time updates
- Paginated locally with `_currentPage` and `_itemsPerPage` (default: 10)
- Pattern: fetch all → slice with `sublist(startIndex, endIndex)`
- Pagination controls at bottom of table (prev/next buttons, page indicator, item count)

**Vyapar ID**: Unique human-readable identifier for each user (Zerodha-style):
- Format: 3 letters + 4 digits (e.g., "ABC1234", "TPL0001")
- Generated automatically during signup via `_generateMsmeId()` in AuthService
- Uniqueness checked by querying existing users before assignment
- Stored in user document as `msmeId` field
- Migration: Existing users get ID generated on next login
- Displayed prominently in Profile screen
- Used for B2B document sharing between registered users

**B2B Document Sharing (Vyapar Ecosystem)**:
- Users can send quotations/invoices to other registered VyaparBook users via Vyapar ID
- List screens (Quotations, Invoices) have toggle: "Created" | "Received"
- "Created" shows documents user created; "Received" shows documents sent to user
- View screens have "Send to Vyapar User" button that opens search dialog
- Search by Vyapar ID shows company name, contact name, then send button
- Firestore collection: `sharedDocuments` stores shared document snapshots
- Key files: `lib/services/shared_document_service.dart`, `lib/widgets/send_to_user_dialog.dart`
- View received screens: `view_received_quotation_screen.dart`, `view_received_invoice_screen.dart`

**Purchase Orders Module**:
- PurchaseOrder model with status flow: draft → sent → acknowledged → fulfilled/cancelled
- Document numbering format: `PREFIX/PO/YYYY-YY/NNN`
- List screen with Created/Received toggle (same pattern as quotations/invoices)
- "Convert to PO" button on received quotations pre-fills form with line items
- Send to vendor via Vyapar ID (vendor must have linkedUserId)
- Key files: `lib/services/purchase_order_service.dart`, `lib/screens/purchase_orders/`
- PO to Invoice conversion planned (vendor creates invoice against received PO)

**Accounting Foundation** (Infrastructure - no UI):
- Chart of Accounts with 18-20 pre-created system accounts on first login
- Account types: Asset, Liability, Income, Expense, Equity
- JournalEntry model for double-entry bookkeeping (every transaction has debits = credits)
- Accounts auto-initialized in AuthService.signIn() for new users
- Bank accounts from CompanyProfile auto-synced to chart of accounts
- Helper methods for recording: sales invoice, payment received, purchase bill, payment made, credit note, debit note
- Report helpers: getTotalReceivables(), getTotalPayables(), getGSTSummary()
- Firestore collections: `accounts`, `journalEntries`

**Software Update System**: Auto-checks GitHub releases for new versions:
- Release repo: `https://github.com/trirooppvtltd/msme_tool_release`
- Uses GitHub API to fetch latest release info
- Compares semantic versions (major.minor.patch)
- Shows "Check for Updates" in sidebar with badge when update available
- Update dialog displays version comparison, release notes, download link
- Key files: `lib/services/update_service.dart`, `lib/widgets/update_dialog.dart`

### Important Files
- `lib/config/themes.dart` - AppColors and AppTheme definitions
- `lib/config/router.dart` - All routes with auth guards
- `lib/services/auth_service.dart` - Authentication, user management, Vyapar ID generation
- `lib/services/quotation_service.dart` - LineItem model shared by invoices
- `lib/services/invoice_service.dart` - Invoice model and tax calculations
- `lib/services/shared_document_service.dart` - B2B document sharing service
- `lib/services/purchase_order_service.dart` - PurchaseOrder model and service
- `lib/services/accounting_service.dart` - Chart of accounts and journal entries
- `lib/models/account.dart` - Account model for chart of accounts
- `lib/models/journal_entry.dart` - JournalEntry model for double-entry bookkeeping
- `lib/screens/customers/customers_screen.dart` - Customer list with pagination
- `lib/screens/invoices/invoices_screen.dart` - Invoice list with Created/Received toggle
- `lib/screens/quotations/quotations_screen.dart` - Quotation list with Created/Received toggle
- `lib/screens/purchase_orders/purchase_orders_screen.dart` - PO list with Created/Received toggle
- `lib/screens/profile/profile_screen.dart` - Company profile with Vyapar ID display
- `lib/services/update_service.dart` - Software update checker (GitHub releases)
- `lib/widgets/update_dialog.dart` - Update notification dialog
- `lib/widgets/send_to_user_dialog.dart` - Dialog for sending documents to Vyapar users
- `lib/screens/about/about_screen.dart` - About software page with vision, roadmap, license
- `format_building/functions/index.js` - PDF generation endpoints

## Firebase Deployment

```bash
cd format_building/functions
npm install
firebase deploy --only functions
```

## Windows Installer

Uses Inno Setup with `msme_tool.iss` configuration file.

---

## Future Roadmap: Complete B2B Ecosystem & Accounting

This section documents the planned evolution of VyaparBook from a document management tool to a full-fledged B2B accounting platform competing with Zoho Books and Tally.

### Vision

Transform VyaparBook into a complete business operating system with:
1. **B2B Ecosystem** - Seamless document exchange between registered users
2. **Double-Entry Accounting** - Proper bookkeeping without user complexity
3. **GST Compliance** - Ready-to-file reports for GSTR-1, GSTR-3B
4. **Cash Flow Management** - Aging reports, payment tracking

### Complete B2B Transaction Cycle

```
SELLER (Vendor)                         BUYER (Customer)
───────────────                         ─────────────────

1. Creates Quotation ──────────────→ Receives Quotation
                                              │
                                              ↓
                                       "Add as Vendor"
                                              │
                                              ↓
2. Receives PO ←────────────────── Creates Purchase Order
        │                            (against quotation)
        ↓
3. Creates Invoice ────────────────→ Receives Invoice
                                              │
        ┌────────────────────────────────────┘
        ↓
4. Credit Note ←─────────────────── Debit Note
   (if returns/                      (requests credit for
    discount given)                   damaged goods)
        │
        ↓
5. Payment Received ←────────────── Payment Made
```

### Document Relationship Matrix

| You receive...     | Sender is your... | Your next action        |
|--------------------|-------------------|-------------------------|
| Quotation          | Vendor            | Create Purchase Order   |
| Invoice            | Vendor            | Make Payment            |
| Purchase Order     | Customer          | Create Invoice          |
| Credit Note        | Vendor            | Adjust payable balance  |
| Debit Note         | Customer          | Issue Credit Note       |

---

### New Modules Required

#### 1. Vendors Module
- **Dual approach**: Manual entry OR Vyapar ID lookup
- **Vyapar ID approach**: Search by ID → fetch company details → add as vendor
- **Data model**: Snapshot with `linkedVyaparId` for optional refresh
- **Auto-add**: "Add sender as Vendor" when receiving quotation
- **Fields**: Company name, contact, GST, address, payment terms, credit limit

#### 2. Purchase Orders
- Created by buyer, sent to vendor
- Can be created "against" a received quotation (like quotation → invoice conversion)
- Vendor receives in their "Received" tab
- Document number format: `PREFIX/PO/YYYY-YY/NNN`

#### 3. Credit Notes (Issued by Seller)
- Linked to original invoice
- Reasons: Goods returned, discount given, overcharge correction
- GST impact: Reduces output GST liability
- Accounting: DR Sales Return, DR GST Payable, CR Accounts Receivable

#### 4. Debit Notes (Issued by Buyer)
- Linked to received invoice
- Reasons: Damaged goods, short receipt, quality issues
- GST impact: Reduces input GST credit
- Accounting: DR Accounts Payable, CR Purchase Return, CR GST Input

---

### Double-Entry Accounting System

#### Core Principle
Every transaction has a "from where" and "to where". Users perform **business actions**, system creates **accounting entries** silently.

```
USER ACTION                    SYSTEM CREATES (Hidden)
───────────                    ───────────────────────
"Create Invoice"        →      Journal entry with debits/credits
"Record Payment"        →      Journal entry with debits/credits
"Create Credit Note"    →      Journal entry with debits/credits
```

#### Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    USER INTERFACE                        │
│  (Invoice, Payment, Credit Note - Simple Forms)          │
└─────────────────────────┬───────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────┐
│               ACCOUNTING ENGINE (Hidden)                 │
│                                                          │
│  DocumentType + Action → Predefined Entry Rules          │
│                                                          │
│  createInvoice()     → salesEntryRule()                  │
│  recordPayment()     → paymentEntryRule()                │
│  createCreditNote()  → creditNoteEntryRule()             │
└─────────────────────────┬───────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────┐
│                  JOURNAL ENTRIES                         │
│            (Stored in Firestore, never shown)            │
└─────────────────────────┬───────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────┐
│                     REPORTS                              │
│   (Sales Report, GST Report, Outstanding, P&L)           │
│         User sees results, not the entries               │
└─────────────────────────────────────────────────────────┘
```

#### Automatic Journal Entry Rules

| User Action | Debit | Credit |
|-------------|-------|--------|
| Create Invoice | Accounts Receivable | Sales, GST Output |
| Record Payment (from customer) | Cash/Bank | Accounts Receivable |
| Create Credit Note | Sales Return, GST Output | Accounts Receivable |
| Accept Received Invoice | Purchases, GST Input | Accounts Payable |
| Make Payment (to vendor) | Accounts Payable | Cash/Bank |
| Create Debit Note | Accounts Payable | Purchase Return, GST Input |

---

### Chart of Accounts (Pre-Created)

**18-20 accounts auto-created on signup. User never creates accounts manually.**

#### Assets (What you own / owed to you)
| Account Name | Purpose |
|--------------|---------|
| Cash | Physical cash in hand |
| Bank - [From Profile] | Auto-created from company profile bank details |
| Accounts Receivable | Money customers owe you |
| GST Input (CGST) | CGST credit from purchases |
| GST Input (SGST) | SGST credit from purchases |
| GST Input (IGST) | IGST credit from inter-state purchases |

#### Liabilities (What you owe)
| Account Name | Purpose |
|--------------|---------|
| Accounts Payable | Money you owe to vendors |
| GST Output (CGST) | CGST collected on sales |
| GST Output (SGST) | SGST collected on sales |
| GST Output (IGST) | IGST collected on inter-state sales |

#### Income (Money coming in)
| Account Name | Purpose |
|--------------|---------|
| Sales | Revenue from invoices |
| Sales Return | Goods returned by customers (contra) |
| Other Income | Interest, discounts received, etc. |

#### Expenses (Money going out)
| Account Name | Purpose |
|--------------|---------|
| Purchases | Cost of goods/services bought |
| Purchase Return | Goods returned to vendors (contra) |
| Discount Given | Discounts offered to customers |
| Bank Charges | Bank fees, transaction charges |
| Other Expenses | Miscellaneous expenses |

#### Equity
| Account Name | Purpose |
|--------------|---------|
| Owner's Capital | Initial investment / retained earnings |

**Dynamic Accounts**: Bank accounts auto-created when user adds bank details in company profile.

---

### Payment Recording

#### Split/Partial Payments
Single payment can be split across multiple modes (Cash + Bank):

```
Payment for Invoice #001: ₹10,000

Payment Breakup:
├── Cash:              ₹2,000
├── HDFC Bank - 1234:  ₹8,000
└── ICICI Bank - 5678: ₹0
                       ────────
Total:                 ₹10,000 ✓
```

#### Journal Entry for Split Payment
```
Debit:  Cash                    ₹2,000
Debit:  Bank - HDFC 1234        ₹8,000
Credit: Accounts Receivable     ₹10,000
```

#### Bank Accounts from Company Profile
- Bank ledger accounts auto-created from company profile bank details
- Payment UI shows only user's actual banks (not generic "Bank Account")
- When user adds/updates bank in profile, sync to chart of accounts

#### Credit Period & Due Date
- Invoice includes "Credit Period" field (0, 7, 15, 30, 45, 60 days)
- Due Date auto-calculated: Invoice Date + Credit Period
- Enables aging calculations

---

### Reports (15-17 Total)

#### Sales & Revenue
| Report | What it shows |
|--------|---------------|
| Sales Register | All invoices with date, customer, amount, GST, payment status |
| Sales Summary | Total sales by period (daily/weekly/monthly/yearly) |
| Customer-wise Sales | Sales breakdown per customer |

#### Purchases & Expenses
| Report | What it shows |
|--------|---------------|
| Purchase Register | All bills/received invoices |
| Purchase Summary | Total purchases by period |
| Vendor-wise Purchases | Purchase breakdown per vendor |

#### Receivables & Payables
| Report | What it shows |
|--------|---------------|
| Outstanding Receivables | Unpaid invoices, who owes how much |
| Outstanding Payables | Unpaid bills, what you owe to whom |
| Receivables Aging | Overdue analysis by aging buckets |
| Payables Aging | Overdue analysis for your payments |

#### Tax & Compliance
| Report | What it shows |
|--------|---------------|
| GST Report | CGST/SGST/IGST collected vs paid (for GSTR-3B) |
| GST Sales Summary | B2B, B2C breakdown (for GSTR-1) |

#### Financial Statements
| Report | What it shows |
|--------|---------------|
| Profit & Loss | Income - Expenses = Profit/Loss |
| Balance Sheet | Assets, Liabilities, Equity snapshot |
| Trial Balance | All accounts with debit/credit totals |

#### Transaction Reports
| Report | What it shows |
|--------|---------------|
| Ledger Report | All transactions for a specific account |
| Cash Book | All cash transactions |
| Bank Book | All bank transactions (per bank account) |
| Day Book | All transactions on a specific date |

---

### Aging Reports

#### Aging Buckets
| Bucket | Meaning | Suggested Action |
|--------|---------|------------------|
| Current (Not Due) | Invoice date + credit period not passed | No action |
| 1-30 Days Overdue | Payment due date passed by up to 30 days | Gentle reminder |
| 31-60 Days Overdue | Significantly overdue | Follow-up call |
| 60+ Days Overdue | Critical | Escalation needed |

#### Receivables Aging Report Format
```
Customer        Total      Current    1-30 Days   31-60 Days   60+ Days
                           (Not Due)   Overdue     Overdue      Overdue
─────────────────────────────────────────────────────────────────────────
Triroop Pvt     ₹45,000    ₹20,000    ₹15,000     ₹10,000      ₹0
ABC Corp        ₹32,000    ₹0         ₹12,000     ₹8,000       ₹12,000 ⚠️
─────────────────────────────────────────────────────────────────────────
TOTAL           ₹77,000    ₹20,000    ₹27,000     ₹18,000      ₹12,000
                           (26%)      (35%)       (23%)        (16%)
```

#### Aging Calculation Logic
```dart
String getAgingBucket(Invoice invoice) {
  final dueDate = invoice.invoiceDate.add(
    Duration(days: invoice.creditPeriodDays ?? 0)
  );
  final today = DateTime.now();
  final daysOverdue = today.difference(dueDate).inDays;

  if (daysOverdue <= 0) return 'current';
  if (daysOverdue <= 30) return '1-30';
  if (daysOverdue <= 60) return '31-60';
  return '60+';
}
```

---

### Data Integrity & Multi-Tenancy

#### Golden Rule
Every document has `userId`, every query filters by `userId`, Firestore security rules enforce it.

#### Document Structure
```javascript
{
  id: "entry_001",
  userId: "firebase_uid_abc123",  // MANDATORY on every document
  type: "journal_entry",
  // ... other fields
}
```

#### Firestore Security Rules
```javascript
match /journalEntries/{entryId} {
  allow read: if request.auth.uid == resource.data.userId;
  allow create: if request.auth.uid == request.resource.data.userId;
  allow update, delete: if request.auth.uid == resource.data.userId;
}
```

#### Query-Level Filtering
```dart
Stream<List<JournalEntry>> getJournalEntries() {
  return _firestore
      .collection('journalEntries')
      .where('userId', isEqualTo: _auth.currentUser!.uid)  // ALWAYS
      .orderBy('date', descending: true)
      .snapshots();
}
```

#### Atomic Operations
Use Firestore batch writes for multi-document operations:
```dart
Future<void> createInvoiceWithAccounting(Invoice invoice) async {
  final batch = _firestore.batch();

  // 1. Create invoice
  batch.set(invoiceRef, invoice.toMap());

  // 2. Create journal entry
  batch.set(entryRef, journalEntry.toMap());

  // 3. Update customer balance
  batch.update(customerRef, {'outstandingBalance': FieldValue.increment(amount)});

  // ALL OR NOTHING
  await batch.commit();
}
```

#### Optimistic Locking
For critical updates, use version field to prevent race conditions:
```dart
await _firestore.runTransaction((transaction) async {
  final doc = await transaction.get(invoiceRef);
  if (doc.data()['version'] != invoice.version) {
    throw Exception('Document modified. Please refresh.');
  }
  transaction.update(invoiceRef, {...invoice.toMap(), 'version': invoice.version + 1});
});
```

---

### Implementation Phases

#### Phase 1: Vendors Foundation
**Goal**: Enable vendor management and complete B2B relationship tracking

| Task | Description |
|------|-------------|
| 1.1 | Create `Vendor` model (similar to Customer) |
| 1.2 | Create `VendorService` with CRUD operations |
| 1.3 | Create Vendors list screen with pagination |
| 1.4 | Create Add/Edit/View Vendor screens |
| 1.5 | Add Vyapar ID lookup in Add Vendor screen |
| 1.6 | Add "Add as Vendor" button on received quotation screen |
| 1.7 | Add Vendors to sidebar navigation |
| 1.8 | Update router with vendor routes |

**Files to create**:
- `lib/services/vendor_service.dart`
- `lib/screens/vendors/vendors_screen.dart`
- `lib/screens/vendors/add_vendor_screen.dart`
- `lib/screens/vendors/edit_vendor_screen.dart`
- `lib/screens/vendors/view_vendor_screen.dart`

#### Phase 2: Purchase Orders
**Goal**: Enable purchase workflow with vendors

| Task | Description |
|------|-------------|
| 2.1 | Create `PurchaseOrder` model |
| 2.2 | Create `PurchaseOrderService` with CRUD and sharing |
| 2.3 | Create Purchase Orders list screen with Created/Received toggle |
| 2.4 | Create Create/Edit/View Purchase Order screens |
| 2.5 | Add "Convert to PO" on received quotation screen |
| 2.6 | Add View Received PO screen for vendors |
| 2.7 | Create PO PDF template in Cloud Functions |
| 2.8 | Update router and sidebar |

**Files to create**:
- `lib/services/purchase_order_service.dart`
- `lib/screens/purchase_orders/` (all CRUD screens)
- `format_building/functions/lib/po-template.js`

#### Phase 3: Accounting Foundation
**Goal**: Set up chart of accounts and journal entry infrastructure

| Task | Description |
|------|-------------|
| 3.1 | Create `Account` model (name, type, subType, balance) |
| 3.2 | Create `JournalEntry` model (date, entries[], reference) |
| 3.3 | Create `AccountingService` for account and entry management |
| 3.4 | Create account initialization on user signup (18-20 default accounts) |
| 3.5 | Sync bank accounts from company profile to chart of accounts |
| 3.6 | Create Firestore indexes for accounting queries |
| 3.7 | Set up Firestore security rules for accounting collections |

**Files to create**:
- `lib/services/accounting_service.dart`
- `lib/models/account.dart`
- `lib/models/journal_entry.dart`

**Firestore collections**:
- `accounts` - Chart of accounts per user
- `journalEntries` - All accounting entries

#### Phase 4: Invoice Accounting Integration
**Goal**: Auto-generate journal entries for invoices

| Task | Description |
|------|-------------|
| 4.1 | Create entry rule for invoice creation |
| 4.2 | Modify `InvoiceService.createInvoice()` to create journal entry |
| 4.3 | Add credit period field to invoice form |
| 4.4 | Calculate and store due date on invoice |
| 4.5 | Update invoice model with `paymentStatus` (unpaid/partial/paid) |
| 4.6 | Display payment status on invoice list and view screens |

**Entry rule for invoice**:
```
DR: Accounts Receivable (grandTotal)
CR: Sales (subtotal)
CR: GST Output CGST (cgstAmount)
CR: GST Output SGST (sgstAmount)
CR: GST Output IGST (igstAmount)
```

#### Phase 5: Payment Recording
**Goal**: Enable payment tracking with split payment support

| Task | Description |
|------|-------------|
| 5.1 | Create `Payment` model (invoiceId, amounts[], date, note) |
| 5.2 | Add payment recording to `AccountingService` |
| 5.3 | Create "Record Payment" dialog/screen |
| 5.4 | Implement split payment UI (Cash + multiple banks) |
| 5.5 | Auto-update invoice payment status on payment recording |
| 5.6 | Create payment history view on invoice detail screen |
| 5.7 | Handle partial payments (₹5,000 of ₹10,000) |

**Entry rule for payment**:
```
DR: Cash/Bank (amount per mode)
CR: Accounts Receivable (total amount)
```

**Files to create**:
- `lib/models/payment.dart`
- `lib/widgets/record_payment_dialog.dart`

#### Phase 6: Purchase Accounting
**Goal**: Account for purchases/bills from vendors

| Task | Description |
|------|-------------|
| 6.1 | Create "Accept/Record" action on received invoice |
| 6.2 | Create entry rule for purchase recording |
| 6.3 | Create "Make Payment" for vendor bills |
| 6.4 | Track payables per vendor |
| 6.5 | Update received invoice status (recorded/paid) |

**Entry rule for purchase**:
```
DR: Purchases (subtotal)
DR: GST Input CGST/SGST/IGST (tax amounts)
CR: Accounts Payable (grandTotal)
```

**Entry rule for vendor payment**:
```
DR: Accounts Payable (amount)
CR: Cash/Bank (amount per mode)
```

#### Phase 7: Credit Notes
**Goal**: Handle sales returns and adjustments

| Task | Description |
|------|-------------|
| 7.1 | Create `CreditNote` model (linked to invoice) |
| 7.2 | Create `CreditNoteService` |
| 7.3 | Create Credit Notes list screen |
| 7.4 | Create Credit Note form (select invoice, items, reason) |
| 7.5 | Create entry rule for credit note |
| 7.6 | Adjust customer receivable balance |
| 7.7 | Create Credit Note PDF template |
| 7.8 | Send credit note to customer via Vyapar ID |

**Entry rule for credit note**:
```
DR: Sales Return (subtotal)
DR: GST Output (tax amounts)
CR: Accounts Receivable (grandTotal)
```

**Files to create**:
- `lib/services/credit_note_service.dart`
- `lib/screens/credit_notes/` (all screens)

#### Phase 8: Debit Notes
**Goal**: Handle purchase returns and vendor adjustments

| Task | Description |
|------|-------------|
| 8.1 | Create `DebitNote` model (linked to received invoice) |
| 8.2 | Create `DebitNoteService` |
| 8.3 | Create Debit Notes list screen |
| 8.4 | Create Debit Note form (select bill, items, reason) |
| 8.5 | Create entry rule for debit note |
| 8.6 | Adjust vendor payable balance |
| 8.7 | Send debit note to vendor via Vyapar ID |

**Entry rule for debit note**:
```
DR: Accounts Payable (grandTotal)
CR: Purchase Return (subtotal)
CR: GST Input (tax amounts)
```

**Files to create**:
- `lib/services/debit_note_service.dart`
- `lib/screens/debit_notes/` (all screens)

#### Phase 9: Basic Reports
**Goal**: Provide essential business reports

| Task | Description |
|------|-------------|
| 9.1 | Create Reports screen with report list |
| 9.2 | Create Sales Register report |
| 9.3 | Create Purchase Register report |
| 9.4 | Create Outstanding Receivables report |
| 9.5 | Create Outstanding Payables report |
| 9.6 | Create Customer-wise Sales report |
| 9.7 | Create Vendor-wise Purchases report |
| 9.8 | Add date range filters to all reports |
| 9.9 | Add export to PDF/Excel functionality |

**Files to create**:
- `lib/screens/reports/reports_screen.dart`
- `lib/screens/reports/sales_register_report.dart`
- `lib/screens/reports/purchase_register_report.dart`
- `lib/screens/reports/outstanding_receivables_report.dart`
- `lib/screens/reports/outstanding_payables_report.dart`
- `lib/services/report_service.dart`

#### Phase 10: Aging Reports
**Goal**: Enable cash flow management with aging analysis

| Task | Description |
|------|-------------|
| 10.1 | Create aging calculation utility |
| 10.2 | Create Receivables Aging report with buckets |
| 10.3 | Create Payables Aging report with buckets |
| 10.4 | Add aging summary to dashboard |
| 10.5 | Add overdue indicators on invoice list |
| 10.6 | Add follow-up reminders for overdue invoices |

**Aging buckets**: Current, 1-30 days, 31-60 days, 60+ days

**Files to create**:
- `lib/utils/aging_calculator.dart`
- `lib/screens/reports/receivables_aging_report.dart`
- `lib/screens/reports/payables_aging_report.dart`

#### Phase 11: GST Reports
**Goal**: Provide GST compliance reports for filing

| Task | Description |
|------|-------------|
| 11.1 | Create GST Summary report (Output vs Input) |
| 11.2 | Create GSTR-1 format report (B2B, B2C breakdown) |
| 11.3 | Create GSTR-3B format report |
| 11.4 | Add HSN-wise summary |
| 11.5 | Add party-wise GST summary |
| 11.6 | Export in GST portal compatible format |

**Files to create**:
- `lib/screens/reports/gst_summary_report.dart`
- `lib/screens/reports/gstr1_report.dart`
- `lib/screens/reports/gstr3b_report.dart`

#### Phase 12: Financial Statements
**Goal**: Complete accounting with standard financial reports

| Task | Description |
|------|-------------|
| 12.1 | Create Ledger Report (transactions per account) |
| 12.2 | Create Cash Book report |
| 12.3 | Create Bank Book report (per bank) |
| 12.4 | Create Day Book report |
| 12.5 | Create Trial Balance report |
| 12.6 | Create Profit & Loss statement |
| 12.7 | Create Balance Sheet |

**Files to create**:
- `lib/screens/reports/ledger_report.dart`
- `lib/screens/reports/cash_book_report.dart`
- `lib/screens/reports/bank_book_report.dart`
- `lib/screens/reports/trial_balance_report.dart`
- `lib/screens/reports/profit_loss_report.dart`
- `lib/screens/reports/balance_sheet_report.dart`

#### Phase 13: Dashboard Enhancement
**Goal**: Provide business insights at a glance

| Task | Description |
|------|-------------|
| 13.1 | Create dashboard home screen |
| 13.2 | Add sales summary widget (today/week/month) |
| 13.3 | Add receivables summary widget |
| 13.4 | Add payables summary widget |
| 13.5 | Add aging alert widget (overdue items) |
| 13.6 | Add recent transactions widget |
| 13.7 | Add GST liability widget |
| 13.8 | Add quick action buttons |

**Files to create**:
- `lib/screens/dashboard/dashboard_home.dart`
- `lib/widgets/dashboard/` (various widgets)

---

### Firestore Collections (Final Structure)

```
users/{userId}                    # User auth data, Vyapar ID
companyProfiles/{userId}          # Company details, bank accounts
customers/{customerId}            # Customer master
vendors/{vendorId}                # Vendor master
quotations/{quotationId}          # Quotations created
invoices/{invoiceId}              # Invoices created
purchaseOrders/{poId}             # Purchase orders created
creditNotes/{creditNoteId}        # Credit notes issued
debitNotes/{debitNoteId}          # Debit notes issued
sharedDocuments/{sharedDocId}     # B2B shared documents
accounts/{accountId}              # Chart of accounts
journalEntries/{entryId}          # All accounting entries
payments/{paymentId}              # Payment records
```

### Security Rules Pattern

All collections follow the same pattern:
```javascript
match /{collection}/{docId} {
  allow read, write: if request.auth.uid == resource.data.userId;
}
```

---

### Competitive Advantage

| Feature | Tally | Zoho Books | VyaparBook |
|---------|-------|------------|------------|
| Double-entry accounting | ✓ | ✓ | ✓ (Phase 3+) |
| GST compliance | ✓ | ✓ | ✓ |
| B2B Ecosystem | ✗ | ✗ | ✓ (Unique) |
| Document sharing via ID | ✗ | ✗ | ✓ (Unique) |
| Cross-platform (Desktop + Mobile) | Partial | ✓ | ✓ |
| Offline-first | ✓ | ✗ | Planned |
| Pricing | ₹₹₹ | ₹₹ | ₹ |

The B2B Ecosystem is VyaparBook's unique differentiator - no competitor offers seamless document exchange between registered users via a simple ID lookup.

---

## Detailed Phase Explanations

This section provides in-depth documentation for each implementation phase, including UI mockups, data models, user flows, and behind-the-scenes logic.

---

### Phase 1: Vendors Foundation (Detailed)

#### What We're Building
A complete vendor management system - mirror of what we have for customers, but for people/companies you **buy from**.

#### Why This Comes First
Before we can do purchase orders, bills, or payments to vendors - we need to know **who** our vendors are. Just like we needed customers before creating invoices.

#### User Experience

**Manual Entry:**
```
Sidebar: [Vendors]

Vendors Screen:
┌─────────────────────────────────────────────────────────────┐
│ Vendors                              [+ Add Vendor]         │
├─────────────────────────────────────────────────────────────┤
│ Company         Contact      GST Number      Actions        │
├─────────────────────────────────────────────────────────────┤
│ ABC Suppliers   Rahul Shah   27AABCU9603R1ZM [View][Edit]   │
│ XYZ Traders     Priya Patel  24AALFX1234P1Z5 [View][Edit]   │
└─────────────────────────────────────────────────────────────┘
```

**Vyapar ID Lookup (The Magic):**
```
Add Vendor Screen:
┌─────────────────────────────────────────────────────────────┐
│ Add Vendor                                                  │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│ ○ Enter Manually                                            │
│ ● Search by Vyapar ID                                       │
│                                                             │
│ Vyapar ID: [ABC1234      ] [Search]                         │
│                                                             │
│ ┌─────────────────────────────────────────────────────────┐ │
│ │ ✓ Found on VyaparBook                                   │ │
│ │                                                         │ │
│ │ Company:   ABC Suppliers Pvt Ltd                        │ │
│ │ Contact:   Rahul Shah                                   │ │
│ │ GST:       27AABCU9603R1ZM                              │ │
│ │ Address:   Mumbai, Maharashtra                          │ │
│ │                                                         │ │
│ │ [Add as Vendor]                                         │ │
│ └─────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

**From Received Quotation:**
```
View Received Quotation:
┌─────────────────────────────────────────────────────────────┐
│ Quotation from: Triroop Pvt Ltd (TPL1234)                   │
│                                                             │
│ [Add as Vendor]  [Convert to PO]  [Download PDF]            │
│                                                             │
│ ... quotation details ...                                   │
└─────────────────────────────────────────────────────────────┘
```

#### Data Model
```dart
class Vendor {
  String? id;
  String userId;           // Owner of this vendor record
  String companyName;
  String contactName;
  String? email;
  String? phone;
  String? gstNumber;
  String? pan;
  String address;
  String city;
  String state;
  String? pincode;

  // Vyapar Link (if added via Vyapar ID)
  String? linkedVyaparId;  // e.g., "ABC1234"
  String? linkedUserId;    // Firebase UID of vendor
  DateTime? linkedAt;      // When was link created

  // Business terms
  int? defaultCreditDays;  // Default payment terms
  double? creditLimit;     // Max outstanding allowed

  // Computed (from accounting)
  double outstandingBalance; // What we owe them

  DateTime createdAt;
  DateTime? updatedAt;
}
```

#### What Happens Behind the Scenes
- Vendor stored in `vendors` collection with your `userId`
- If linked via Vyapar ID, we store snapshot + reference
- No accounting entries yet (vendors are just a master list)

---

### Phase 2: Purchase Orders (Detailed)

#### What We're Building
The ability to create and send purchase orders to vendors - your formal request to buy goods/services.

#### Why This Comes After Vendors
You can't create a PO without selecting a vendor. Phase 1 gives us the vendor list.

#### The B2B Flow
```
You receive quotation from Vendor
        ↓
You like the terms
        ↓
You create Purchase Order (against that quotation)
        ↓
PO sent to Vendor via Vyapar ID
        ↓
Vendor sees PO in their "Received" tab
        ↓
Vendor creates Invoice against your PO
```

#### User Experience

**Creating PO (Fresh):**
```
Create Purchase Order:
┌─────────────────────────────────────────────────────────────┐
│ New Purchase Order                                          │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│ Vendor: [ABC Suppliers ▼]                                   │
│ PO Date: [01-Feb-2025]                                      │
│ Expected Delivery: [15-Feb-2025]                            │
│                                                             │
│ Items:                                                      │
│ ┌─────────────────────────────────────────────────────────┐ │
│ │ Item          Qty    Rate      GST      Amount          │ │
│ │ Raw Material  100    ₹50       18%      ₹5,900          │ │
│ │ [+ Add Item]                                            │ │
│ └─────────────────────────────────────────────────────────┘ │
│                                                             │
│ Subtotal: ₹5,000                                            │
│ GST: ₹900                                                   │
│ Total: ₹5,900                                               │
│                                                             │
│ [Save as Draft]  [Create PO]                                │
└─────────────────────────────────────────────────────────────┘
```

**Creating PO from Received Quotation:**
```
View Received Quotation:

[Convert to Purchase Order]
        ↓
All items auto-populated from quotation
You can adjust quantities if needed
        ↓
PO created with reference to original quotation
```

**PO List Screen:**
```
Purchase Orders                    [Created ⟷ Received]

Created Mode:                      Received Mode:
(POs you sent to vendors)          (POs customers sent to you)
```

#### Data Model
```dart
class PurchaseOrder {
  String? id;
  String userId;
  String poNumber;              // TPL/PO/2025-26/001
  DateTime poDate;
  DateTime? expectedDeliveryDate;

  // Vendor
  String vendorId;
  String vendorName;
  String? vendorGst;

  // Reference (if created from received quotation)
  String? againstQuotationId;   // Shared document ID
  String? againstQuotationNumber;

  // Items (same LineItem model as invoices)
  List<LineItem> items;

  // Totals
  double subtotal;
  double cgstAmount;
  double sgstAmount;
  double igstAmount;
  double grandTotal;

  // Status
  String status;  // draft, sent, acknowledged, fulfilled, cancelled

  // B2B Sharing
  bool sentToVendor;
  DateTime? sentAt;

  DateTime createdAt;
}
```

#### What Happens Behind the Scenes
- PO stored in `purchaseOrders` collection
- When sent to vendor, creates entry in `sharedDocuments`
- Vendor sees it in their "Received" POs
- **No accounting entries yet** - PO is just an order, not a financial transaction

---

### Phase 3: Accounting Foundation (Detailed)

#### What We're Building
The invisible backbone - chart of accounts and journal entry infrastructure. User never sees this directly.

#### Why This Comes Now
Before we can track money (payments, receivables, payables), we need the accounting structure. This is pure infrastructure - no new UI for users.

#### What Gets Created

**On User Signup (or Migration for Existing Users):**
```
Automatic Account Creation:
┌─────────────────────────────────────────────────────────────┐
│ ASSETS                                                      │
├─────────────────────────────────────────────────────────────┤
│ ACC001  Cash                        ₹0.00                   │
│ ACC002  Bank - HDFC 1234            ₹0.00  (from profile)   │
│ ACC003  Bank - ICICI 5678           ₹0.00  (from profile)   │
│ ACC004  Accounts Receivable         ₹0.00                   │
│ ACC005  GST Input (CGST)            ₹0.00                   │
│ ACC006  GST Input (SGST)            ₹0.00                   │
│ ACC007  GST Input (IGST)            ₹0.00                   │
├─────────────────────────────────────────────────────────────┤
│ LIABILITIES                                                 │
├─────────────────────────────────────────────────────────────┤
│ ACC008  Accounts Payable            ₹0.00                   │
│ ACC009  GST Output (CGST)           ₹0.00                   │
│ ACC010  GST Output (SGST)           ₹0.00                   │
│ ACC011  GST Output (IGST)           ₹0.00                   │
├─────────────────────────────────────────────────────────────┤
│ INCOME                                                      │
├─────────────────────────────────────────────────────────────┤
│ ACC012  Sales                       ₹0.00                   │
│ ACC013  Sales Return                ₹0.00                   │
│ ACC014  Other Income                ₹0.00                   │
├─────────────────────────────────────────────────────────────┤
│ EXPENSES                                                    │
├─────────────────────────────────────────────────────────────┤
│ ACC015  Purchases                   ₹0.00                   │
│ ACC016  Purchase Return             ₹0.00                   │
│ ACC017  Discount Given              ₹0.00                   │
│ ACC018  Bank Charges                ₹0.00                   │
│ ACC019  Other Expenses              ₹0.00                   │
├─────────────────────────────────────────────────────────────┤
│ EQUITY                                                      │
├─────────────────────────────────────────────────────────────┤
│ ACC020  Owner's Capital             ₹0.00                   │
└─────────────────────────────────────────────────────────────┘
```

#### Journal Entry Structure
```dart
class JournalEntry {
  String? id;
  String userId;
  DateTime date;
  String? narration;         // Description

  // Reference to source document
  String referenceType;      // 'invoice', 'payment', 'credit_note', etc.
  String referenceId;        // Document ID
  String? referenceNumber;   // Human readable (INV/2025/001)

  // The actual entries
  List<JournalLine> entries;

  DateTime createdAt;
}

class JournalLine {
  String accountId;
  String accountName;
  double debit;   // Either debit OR credit is non-zero
  double credit;
}
```

#### Example Journal Entry (for an invoice)
```
┌─────────────────────────────────────────────────────────────┐
│ Journal Entry: JE-2025-0001                                 │
│ Date: 01-Feb-2025                                           │
│ Reference: Invoice TPL/INV/2025-26/001                      │
│ Narration: Sales to Triroop Pvt Ltd                         │
├─────────────────────────────────────────────────────────────┤
│ Account                    Debit         Credit             │
├─────────────────────────────────────────────────────────────┤
│ Accounts Receivable        ₹11,800                          │
│ Sales                                    ₹10,000            │
│ GST Output (CGST)                        ₹900               │
│ GST Output (SGST)                        ₹900               │
├─────────────────────────────────────────────────────────────┤
│ TOTAL                      ₹11,800       ₹11,800  ✓         │
└─────────────────────────────────────────────────────────────┘
```

#### The Service Layer
```dart
class AccountingService {
  // Account Management
  Future<void> initializeAccounts(String userId);
  Future<void> syncBankAccounts(CompanyProfile profile);
  Future<List<Account>> getAccounts();
  Future<Account?> getAccountByType(String type, String subType);

  // Journal Entries
  Future<void> createJournalEntry(JournalEntry entry);
  Future<List<JournalEntry>> getEntriesByReference(String refType, String refId);
  Future<double> getAccountBalance(String accountId);

  // Entry Templates (called by other services)
  Future<void> recordSalesInvoice(Invoice invoice);
  Future<void> recordPaymentReceived(Payment payment);
  Future<void> recordPurchase(ReceivedInvoice bill);
  Future<void> recordPaymentMade(VendorPayment payment);
  Future<void> recordCreditNote(CreditNote creditNote);
  Future<void> recordDebitNote(DebitNote debitNote);
}
```

#### What User Sees
**Nothing new!** This is all infrastructure. Users continue using the app normally. The accounting happens silently.

---

### Phase 4: Invoice Accounting Integration (Detailed)

#### What We're Building
Connecting existing invoice creation to the accounting system. When invoice is created, journal entry is auto-generated.

#### Why This Comes After Phase 3
We need the accounts and journal entry structure first. Now we wire it up.

#### Changes to Invoice

**New Fields Added:**
```dart
class Invoice {
  // ... existing fields ...

  // NEW: Payment Terms
  int creditPeriodDays;     // 0, 7, 15, 30, 45, 60
  DateTime dueDate;         // invoiceDate + creditPeriodDays

  // NEW: Payment Status
  String paymentStatus;     // 'unpaid', 'partial', 'paid'
  double amountPaid;        // Running total of payments
  double amountDue;         // grandTotal - amountPaid
}
```

#### UI Changes

**Create Invoice Form:**
```
┌─────────────────────────────────────────────────────────────┐
│ Payment Terms                                               │
├─────────────────────────────────────────────────────────────┤
│ Credit Period: [30 days ▼]                                  │
│                                                             │
│ Options:                                                    │
│  • Due Immediately                                          │
│  • 7 days                                                   │
│  • 15 days                                                  │
│  • 30 days (default)                                        │
│  • 45 days                                                  │
│  • 60 days                                                  │
│  • Custom: [__] days                                        │
│                                                             │
│ Due Date: 03-Mar-2025 (auto-calculated)                     │
└─────────────────────────────────────────────────────────────┘
```

**Invoice List Screen:**
```
┌─────────────────────────────────────────────────────────────────────────┐
│ Invoice No      Customer     Date        Amount     Status     Payment  │
├─────────────────────────────────────────────────────────────────────────┤
│ TPL/INV/25/001  Triroop      01-Feb-25   ₹11,800    Sent       UNPAID   │
│ TPL/INV/25/002  ABC Corp     28-Jan-25   ₹25,000    Sent       PARTIAL  │
│ TPL/INV/25/003  XYZ Ltd      15-Jan-25   ₹8,500     Sent       PAID ✓   │
└─────────────────────────────────────────────────────────────────────────┘
```

#### What Happens Behind the Scenes

**When Invoice is Created:**
```dart
// In InvoiceService.createInvoice()
Future<String> createInvoice(Invoice invoice) async {
  final batch = _firestore.batch();

  // 1. Save invoice
  final invoiceRef = _firestore.collection('invoices').doc();
  invoice.id = invoiceRef.id;
  invoice.paymentStatus = 'unpaid';
  invoice.amountPaid = 0;
  invoice.amountDue = invoice.grandTotal;
  batch.set(invoiceRef, invoice.toMap());

  // 2. Create journal entry (NEW!)
  final entryRef = _firestore.collection('journalEntries').doc();
  batch.set(entryRef, {
    'userId': invoice.userId,
    'date': invoice.invoiceDate,
    'referenceType': 'invoice',
    'referenceId': invoiceRef.id,
    'referenceNumber': invoice.invoiceNumber,
    'narration': 'Sales to ${invoice.customerName}',
    'entries': [
      {'accountId': 'accounts_receivable', 'debit': invoice.grandTotal, 'credit': 0},
      {'accountId': 'sales', 'debit': 0, 'credit': invoice.subtotal},
      if (invoice.cgstAmount > 0)
        {'accountId': 'gst_output_cgst', 'debit': 0, 'credit': invoice.cgstAmount},
      if (invoice.sgstAmount > 0)
        {'accountId': 'gst_output_sgst', 'debit': 0, 'credit': invoice.sgstAmount},
      if (invoice.igstAmount > 0)
        {'accountId': 'gst_output_igst', 'debit': 0, 'credit': invoice.igstAmount},
    ],
    'createdAt': FieldValue.serverTimestamp(),
  });

  // 3. Update customer outstanding (NEW!)
  final customerRef = _firestore.collection('customers').doc(invoice.customerId);
  batch.update(customerRef, {
    'outstandingBalance': FieldValue.increment(invoice.grandTotal),
  });

  // Atomic commit
  await batch.commit();
  return invoiceRef.id;
}
```

#### Accounting Impact
```
Account                    Before      Change      After
─────────────────────────────────────────────────────────
Accounts Receivable        ₹0          +₹11,800    ₹11,800
Sales                      ₹0          +₹10,000    ₹10,000
GST Output (CGST)          ₹0          +₹900       ₹900
GST Output (SGST)          ₹0          +₹900       ₹900
```

---

### Phase 5: Payment Recording (Detailed)

#### What We're Building
The ability to record payments received from customers - with support for split payments (Cash + Bank).

#### Why This Comes After Phase 4
Payments are recorded **against invoices**. We need invoices to have payment status fields first.

#### User Experience

**Record Payment Button on Invoice:**
```
View Invoice Screen:

Invoice: TPL/INV/2025-26/001
Customer: Triroop Pvt Ltd
Amount: ₹11,800
Status: UNPAID

[Download PDF]  [Send]  [Record Payment]  ← NEW
```

**Record Payment Dialog:**
```
┌─────────────────────────────────────────────────────────────┐
│ Record Payment                                              │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│ Invoice: TPL/INV/2025-26/001                                │
│ Customer: Triroop Pvt Ltd                                   │
│ Invoice Amount: ₹11,800                                     │
│ Already Paid: ₹0                                            │
│ Balance Due: ₹11,800                                        │
│                                                             │
│ ─────────────────────────────────────────────────────────── │
│                                                             │
│ Payment Amount: [₹11,800    ]  [Full Amount]                │
│                                                             │
│ Payment Date: [01-Feb-2025]                                 │
│                                                             │
│ Payment Mode:                                               │
│ ┌─────────────────────────────────────────────────────────┐ │
│ │ Cash                         ₹ [2,000     ]             │ │
│ │ HDFC Bank - 1234             ₹ [9,800     ]             │ │
│ │ ICICI Bank - 5678            ₹ [0         ]             │ │
│ └─────────────────────────────────────────────────────────┘ │
│                                                             │
│ Total: ₹11,800 ✓                                            │
│                                                             │
│ Note: [Customer paid cash + NEFT        ]                   │
│                                                             │
│              [Cancel]        [Save Payment]                 │
└─────────────────────────────────────────────────────────────┘
```

**Partial Payment:**
```
Payment Amount: [₹5,000     ]

After saving:
Invoice Status: PARTIAL
Amount Paid: ₹5,000
Balance Due: ₹6,800
```

**Payment History on Invoice:**
```
View Invoice:

Payment History:
┌─────────────────────────────────────────────────────────────┐
│ Date        Mode              Amount      Balance           │
├─────────────────────────────────────────────────────────────┤
│ 01-Feb-25   Cash: ₹2,000      ₹5,000      ₹6,800           │
│             HDFC: ₹3,000                                    │
│ 05-Feb-25   HDFC: ₹6,800      ₹6,800      ₹0 (PAID)        │
└─────────────────────────────────────────────────────────────┘
```

#### Data Model
```dart
class Payment {
  String? id;
  String userId;
  String paymentNumber;      // TPL/REC/2025-26/001
  DateTime paymentDate;

  // Against which invoice
  String invoiceId;
  String invoiceNumber;
  String customerId;
  String customerName;

  // Amount breakdown
  double totalAmount;
  List<PaymentMode> modes;   // Split across cash/banks

  String? note;
  DateTime createdAt;
}

class PaymentMode {
  String type;          // 'cash' or 'bank'
  String? bankAccountId; // If bank, which account
  String? bankName;
  double amount;
}
```

#### What Happens Behind the Scenes

**When Payment is Saved:**
```dart
Future<void> recordPayment(Payment payment) async {
  final batch = _firestore.batch();

  // 1. Save payment record
  final paymentRef = _firestore.collection('payments').doc();
  batch.set(paymentRef, payment.toMap());

  // 2. Create journal entry
  final entryRef = _firestore.collection('journalEntries').doc();
  final entries = <Map<String, dynamic>>[];

  // Debit each payment mode
  for (final mode in payment.modes) {
    if (mode.amount > 0) {
      entries.add({
        'accountId': mode.type == 'cash' ? 'cash' : mode.bankAccountId,
        'accountName': mode.type == 'cash' ? 'Cash' : mode.bankName,
        'debit': mode.amount,
        'credit': 0,
      });
    }
  }

  // Credit accounts receivable
  entries.add({
    'accountId': 'accounts_receivable',
    'debit': 0,
    'credit': payment.totalAmount,
  });

  batch.set(entryRef, {
    'userId': payment.userId,
    'date': payment.paymentDate,
    'referenceType': 'payment_received',
    'referenceId': paymentRef.id,
    'referenceNumber': payment.paymentNumber,
    'narration': 'Payment from ${payment.customerName}',
    'entries': entries,
  });

  // 3. Update invoice
  final invoiceRef = _firestore.collection('invoices').doc(payment.invoiceId);
  final invoice = await invoiceRef.get();
  final currentPaid = invoice.data()!['amountPaid'] ?? 0.0;
  final grandTotal = invoice.data()!['grandTotal'];
  final newPaid = currentPaid + payment.totalAmount;

  batch.update(invoiceRef, {
    'amountPaid': newPaid,
    'amountDue': grandTotal - newPaid,
    'paymentStatus': newPaid >= grandTotal ? 'paid' : 'partial',
  });

  // 4. Update customer outstanding
  final customerRef = _firestore.collection('customers').doc(payment.customerId);
  batch.update(customerRef, {
    'outstandingBalance': FieldValue.increment(-payment.totalAmount),
  });

  await batch.commit();
}
```

#### Accounting Impact (Split Payment ₹2,000 cash + ₹9,800 bank)
```
Account                    Before      Change      After
─────────────────────────────────────────────────────────
Cash                       ₹0          +₹2,000     ₹2,000
Bank - HDFC 1234           ₹0          +₹9,800     ₹9,800
Accounts Receivable        ₹11,800     -₹11,800    ₹0
```

---

### Phase 6: Purchase Accounting (Detailed)

#### What We're Building
Recording purchases (bills/received invoices) and making payments to vendors.

#### Why This Comes After Phase 5
Same pattern as sales → payment, but reversed. We've established the pattern, now apply it to purchases.

#### User Experience

**Accept/Record Received Invoice:**
```
View Received Invoice:

Invoice from: ABC Suppliers (ABC1234)
Amount: ₹5,900

[Add as Vendor]  [Record Bill]  [Download PDF]
                      ↑
                     NEW
```

**Record Bill Dialog:**
```
┌─────────────────────────────────────────────────────────────┐
│ Record Bill                                                 │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│ This will record this invoice as a purchase bill.          │
│                                                             │
│ Vendor: ABC Suppliers                                       │
│ Invoice: ABC/INV/2025/100                                   │
│ Amount: ₹5,900 (incl. GST)                                  │
│                                                             │
│ Bill Date: [01-Feb-2025]                                    │
│ Due Date: [03-Mar-2025] (based on vendor terms)             │
│                                                             │
│ This will:                                                  │
│ ✓ Add ₹5,900 to your payables                               │
│ ✓ Record ₹5,000 as purchase expense                         │
│ ✓ Claim ₹900 GST input credit                               │
│                                                             │
│              [Cancel]        [Record Bill]                  │
└─────────────────────────────────────────────────────────────┘
```

**Make Payment to Vendor:**
```
View Bill (Recorded):

Bill: ABC/INV/2025/100
Vendor: ABC Suppliers
Amount: ₹5,900
Status: UNPAID

[Make Payment]
```

**Payment to Vendor Dialog:**
```
┌─────────────────────────────────────────────────────────────┐
│ Make Payment                                                │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│ Bill: ABC/INV/2025/100                                      │
│ Vendor: ABC Suppliers                                       │
│ Amount Due: ₹5,900                                          │
│                                                             │
│ Payment Amount: [₹5,900    ]                                │
│                                                             │
│ Pay From:                                                   │
│ ○ Cash                         ₹ [0         ]               │
│ ● HDFC Bank - 1234             ₹ [5,900     ]               │
│ ○ ICICI Bank - 5678            ₹ [0         ]               │
│                                                             │
│ Payment Date: [01-Feb-2025]                                 │
│                                                             │
│              [Cancel]        [Make Payment]                 │
└─────────────────────────────────────────────────────────────┘
```

#### What Happens Behind the Scenes

**When Bill is Recorded:**
```
Journal Entry:
DR: Purchases              ₹5,000
DR: GST Input (CGST)       ₹450
DR: GST Input (SGST)       ₹450
CR: Accounts Payable       ₹5,900

Vendor outstanding: +₹5,900
```

**When Payment is Made:**
```
Journal Entry:
DR: Accounts Payable       ₹5,900
CR: Bank - HDFC 1234       ₹5,900

Vendor outstanding: -₹5,900 (now ₹0)
```

---

### Phase 7: Credit Notes (Detailed)

#### What We're Building
Ability to issue credit notes when customer returns goods or you give a discount after invoice.

#### The Business Scenario
```
You sold ₹10,000 goods → Invoice created
Customer returns ₹2,000 worth → You issue Credit Note
Customer now owes: ₹10,000 - ₹2,000 = ₹8,000
```

#### User Experience

**Create Credit Note:**
```
┌─────────────────────────────────────────────────────────────┐
│ Create Credit Note                                          │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│ Against Invoice: [TPL/INV/2025-26/001 ▼]                    │
│                  Customer: Triroop Pvt Ltd                  │
│                  Invoice Amount: ₹11,800                    │
│                                                             │
│ Reason: [Goods Returned ▼]                                  │
│         • Goods Returned                                    │
│         • Discount Given                                    │
│         • Overcharge Correction                             │
│         • Other                                             │
│                                                             │
│ Items to Credit:                                            │
│ ┌─────────────────────────────────────────────────────────┐ │
│ │ ☑ Product A    Qty: [2]  Rate: ₹500   = ₹1,000         │ │
│ │ ☐ Product B    Qty: 5    Rate: ₹1,600  (not selected)  │ │
│ └─────────────────────────────────────────────────────────┘ │
│                                                             │
│ Credit Amount:                                              │
│   Subtotal: ₹1,000                                          │
│   CGST (9%): ₹90                                            │
│   SGST (9%): ₹90                                            │
│   Total Credit: ₹1,180                                      │
│                                                             │
│ Notes: [Customer returned 2 units damaged    ]              │
│                                                             │
│              [Cancel]        [Create Credit Note]           │
└─────────────────────────────────────────────────────────────┘
```

**Credit Notes List:**
```
Credit Notes                       [+ Create Credit Note]

CN Number       Against Invoice    Customer     Amount    Date
─────────────────────────────────────────────────────────────────
TPL/CN/25/001   TPL/INV/25/001     Triroop      ₹1,180    01-Feb
```

#### What Happens Behind the Scenes

**Journal Entry:**
```
DR: Sales Return           ₹1,000
DR: GST Output (CGST)      ₹90
DR: GST Output (SGST)      ₹90
CR: Accounts Receivable    ₹1,180
```

**Impact:**
- Customer outstanding reduced by ₹1,180
- GST liability reduced by ₹180
- Sales effectively reduced by ₹1,000

**B2B Integration:**
Credit note can be sent to customer via Vyapar ID - they see it in their received documents.

---

### Phase 8: Debit Notes (Detailed)

#### What We're Building
Ability to issue debit notes when you receive damaged goods from vendor or want to claim credit.

#### The Business Scenario
```
Vendor sent ₹5,000 goods → You recorded bill
₹1,000 worth was damaged → You issue Debit Note
You now owe: ₹5,000 - ₹1,000 = ₹4,000
```

#### User Experience

**Create Debit Note:**
```
┌─────────────────────────────────────────────────────────────┐
│ Create Debit Note                                           │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│ Against Bill: [ABC/INV/2025/100 ▼]                          │
│               Vendor: ABC Suppliers                         │
│               Bill Amount: ₹5,900                           │
│                                                             │
│ Reason: [Goods Damaged ▼]                                   │
│         • Goods Damaged                                     │
│         • Short Receipt                                     │
│         • Quality Issue                                     │
│         • Other                                             │
│                                                             │
│ Items to Debit:                                             │
│ ┌─────────────────────────────────────────────────────────┐ │
│ │ ☑ Raw Material   Qty: [10]  Rate: ₹50   = ₹500         │ │
│ └─────────────────────────────────────────────────────────┘ │
│                                                             │
│ Debit Amount:                                               │
│   Subtotal: ₹500                                            │
│   GST: ₹90                                                  │
│   Total Debit: ₹590                                         │
│                                                             │
│              [Cancel]        [Create Debit Note]            │
└─────────────────────────────────────────────────────────────┘
```

#### What Happens Behind the Scenes

**Journal Entry:**
```
DR: Accounts Payable       ₹590
CR: Purchase Return        ₹500
CR: GST Input (CGST)       ₹45
CR: GST Input (SGST)       ₹45
```

**Impact:**
- Your payable to vendor reduced by ₹590
- GST input credit reduced by ₹90 (you can't claim credit for goods you returned)
- Purchase expense effectively reduced by ₹500

**B2B Integration:**
Debit note sent to vendor - they see it and should issue corresponding Credit Note.

---

### Phase 9: Basic Reports (Detailed)

#### Reports in This Phase

**1. Sales Register**
```
┌─────────────────────────────────────────────────────────────────────────────┐
│ SALES REGISTER                                    01-Jan-2025 to 31-Jan-2025│
├─────────────────────────────────────────────────────────────────────────────┤
│ Date       Invoice No       Customer        Taxable    GST       Total      │
├─────────────────────────────────────────────────────────────────────────────┤
│ 05-Jan    TPL/INV/25/001    Triroop         ₹10,000    ₹1,800    ₹11,800   │
│ 12-Jan    TPL/INV/25/002    ABC Corp        ₹25,000    ₹4,500    ₹29,500   │
│ 20-Jan    TPL/INV/25/003    XYZ Ltd         ₹8,000     ₹1,440    ₹9,440    │
├─────────────────────────────────────────────────────────────────────────────┤
│ TOTAL                                        ₹43,000    ₹7,740    ₹50,740   │
└─────────────────────────────────────────────────────────────────────────────┘
```

**2. Outstanding Receivables**
```
┌─────────────────────────────────────────────────────────────────────────────┐
│ OUTSTANDING RECEIVABLES                                    As on 01-Feb-2025│
├─────────────────────────────────────────────────────────────────────────────┤
│ Customer        Total Invoiced    Received    Outstanding    Last Payment   │
├─────────────────────────────────────────────────────────────────────────────┤
│ Triroop Pvt     ₹50,000           ₹35,000     ₹15,000        25-Jan-25     │
│ ABC Corp        ₹29,500           ₹0          ₹29,500        -             │
│ XYZ Ltd         ₹9,440            ₹9,440      ₹0             30-Jan-25     │
├─────────────────────────────────────────────────────────────────────────────┤
│ TOTAL           ₹88,940           ₹44,440     ₹44,500                       │
└─────────────────────────────────────────────────────────────────────────────┘
```

**3. Customer-wise Sales**
```
┌─────────────────────────────────────────────────────────────────────────────┐
│ CUSTOMER-WISE SALES                           01-Jan-2025 to 31-Jan-2025    │
├─────────────────────────────────────────────────────────────────────────────┤
│ Customer        Invoices    Sales Amount    GST         Total               │
├─────────────────────────────────────────────────────────────────────────────┤
│ ABC Corp        5           ₹1,25,000       ₹22,500     ₹1,47,500           │
│ Triroop Pvt     8           ₹80,000         ₹14,400     ₹94,400             │
│ XYZ Ltd         3           ₹45,000         ₹8,100      ₹53,100             │
├─────────────────────────────────────────────────────────────────────────────┤
│ TOTAL           16          ₹2,50,000       ₹45,000     ₹2,95,000           │
└─────────────────────────────────────────────────────────────────────────────┘
```

#### Common Features
- Date range filter (Today, This Week, This Month, This Year, Custom)
- Export to PDF
- Export to Excel
- Print option

---

### Phase 10: Aging Reports (Detailed)

#### Receivables Aging Report
```
┌─────────────────────────────────────────────────────────────────────────────┐
│ RECEIVABLES AGING REPORT                                   As on 01-Feb-2025│
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│ Customer        Total      Current    1-30 Days   31-60 Days   60+ Days    │
│                            (Not Due)   Overdue     Overdue      Overdue    │
├─────────────────────────────────────────────────────────────────────────────┤
│ Triroop Pvt     ₹45,000    ₹20,000    ₹15,000     ₹10,000      ₹0          │
│ ABC Corp        ₹32,000    ₹0         ₹12,000     ₹8,000       ₹12,000 ⚠️  │
│ XYZ Ltd         ₹18,500    ₹18,500    ₹0          ₹0           ₹0          │
│ PQR Industries  ₹55,000    ₹25,000    ₹0          ₹30,000      ₹0          │
├─────────────────────────────────────────────────────────────────────────────┤
│ TOTAL           ₹1,50,500  ₹63,500    ₹27,000     ₹48,000      ₹12,000     │
│                            (42%)      (18%)       (32%)        (8%)        │
└─────────────────────────────────────────────────────────────────────────────┘

⚠️ ABC Corp has ₹12,000 overdue by 60+ days - URGENT FOLLOW-UP NEEDED
```

#### Invoice List Enhancements
```
Invoices List:

Invoice No      Customer     Due Date     Amount     Status    Aging
────────────────────────────────────────────────────────────────────────
TPL/INV/25/001  Triroop      03-Feb-25    ₹11,800    UNPAID    Current
TPL/INV/25/002  ABC Corp     15-Jan-25    ₹25,000    UNPAID    47 days ⚠️
TPL/INV/25/003  XYZ Ltd      01-Jan-25    ₹8,500     UNPAID    31 days
```

---

### Phase 11: GST Reports (Detailed)

#### GST Summary Report
```
┌─────────────────────────────────────────────────────────────────────────────┐
│ GST SUMMARY                                   01-Jan-2025 to 31-Jan-2025    │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│ OUTPUT GST (On Sales)                                                       │
│ ─────────────────────────────────────────────────────────────────           │
│ CGST Collected:                    ₹22,500                                  │
│ SGST Collected:                    ₹22,500                                  │
│ IGST Collected:                    ₹8,100                                   │
│                                    ─────────                                │
│ Total Output:                      ₹53,100                                  │
│                                                                             │
│ INPUT GST (On Purchases)                                                    │
│ ─────────────────────────────────────────────────────────────────           │
│ CGST Paid:                         ₹12,000                                  │
│ SGST Paid:                         ₹12,000                                  │
│ IGST Paid:                         ₹5,400                                   │
│                                    ─────────                                │
│ Total Input:                       ₹29,400                                  │
│                                                                             │
│ NET GST PAYABLE                                                             │
│ ─────────────────────────────────────────────────────────────────           │
│ Output - Input:                    ₹23,700                                  │
│                                                                             │
│ This amount is payable to the government.                                   │
└─────────────────────────────────────────────────────────────────────────────┘
```

#### GSTR-1 Format (Sales)
```
B2B Sales (Business to Business with GSTIN):
┌─────────────────────────────────────────────────────────────────────────────┐
│ Customer GSTIN      Invoice No    Date       Taxable    CGST    SGST  IGST │
├─────────────────────────────────────────────────────────────────────────────┤
│ 27AABCT1234P1ZA    TPL/INV/001   05-Jan     ₹10,000    ₹900    ₹900   -    │
│ 24AABCU5678Q1ZB    TPL/INV/002   12-Jan     ₹25,000     -       -    ₹4,500│
└─────────────────────────────────────────────────────────────────────────────┘

B2C Sales (Business to Consumer without GSTIN):
┌─────────────────────────────────────────────────────────────────────────────┐
│ Total B2C Sales:    ₹15,000      GST: ₹2,700                                │
└─────────────────────────────────────────────────────────────────────────────┘
```

#### HSN-wise Summary
```
┌─────────────────────────────────────────────────────────────────────────────┐
│ HSN-WISE SUMMARY                                                            │
├─────────────────────────────────────────────────────────────────────────────┤
│ HSN Code    Description          Qty      Taxable      GST Rate    GST Amt  │
├─────────────────────────────────────────────────────────────────────────────┤
│ 8471        Computers            50       ₹5,00,000    18%         ₹90,000  │
│ 3926        Plastic Items        200      ₹1,00,000    12%         ₹12,000  │
│ 9403        Furniture            30       ₹3,00,000    18%         ₹54,000  │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

### Phase 12: Financial Statements (Detailed)

#### Ledger Report
```
┌─────────────────────────────────────────────────────────────────────────────┐
│ LEDGER: Accounts Receivable                   01-Jan-2025 to 31-Jan-2025    │
├─────────────────────────────────────────────────────────────────────────────┤
│ Opening Balance:                                              ₹25,000       │
├─────────────────────────────────────────────────────────────────────────────┤
│ Date       Particular              Ref           Debit     Credit   Balance │
├─────────────────────────────────────────────────────────────────────────────┤
│ 05-Jan    Sales - Triroop         INV/001       ₹11,800            ₹36,800 │
│ 10-Jan    Payment - Triroop       REC/001                 ₹11,800  ₹25,000 │
│ 15-Jan    Sales - ABC Corp        INV/002       ₹29,500            ₹54,500 │
│ 20-Jan    Credit Note - ABC       CN/001                  ₹2,950   ₹51,550 │
├─────────────────────────────────────────────────────────────────────────────┤
│ Closing Balance:                                              ₹51,550       │
└─────────────────────────────────────────────────────────────────────────────┘
```

#### Trial Balance
```
┌─────────────────────────────────────────────────────────────────────────────┐
│ TRIAL BALANCE                                          As on 31-Jan-2025    │
├─────────────────────────────────────────────────────────────────────────────┤
│ Account                                          Debit           Credit     │
├─────────────────────────────────────────────────────────────────────────────┤
│ Cash                                             ₹45,000                    │
│ Bank - HDFC 1234                                 ₹2,35,000                  │
│ Accounts Receivable                              ₹51,550                    │
│ GST Input                                        ₹29,400                    │
│ Accounts Payable                                                 ₹42,000   │
│ GST Output                                                       ₹53,100   │
│ Sales                                                            ₹3,50,000 │
│ Sales Return                                     ₹5,000                     │
│ Purchases                                        ₹1,20,000                  │
│ Owner's Capital                                                  ₹40,850   │
├─────────────────────────────────────────────────────────────────────────────┤
│ TOTAL                                            ₹4,85,950       ₹4,85,950 │
│                                                              ✓ BALANCED     │
└─────────────────────────────────────────────────────────────────────────────┘
```

#### Profit & Loss Statement
```
┌─────────────────────────────────────────────────────────────────────────────┐
│ PROFIT & LOSS STATEMENT                       01-Jan-2025 to 31-Jan-2025    │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│ INCOME                                                                      │
│ ─────────────────────────────────────────────────────────────────           │
│ Sales                                                    ₹3,50,000          │
│ Less: Sales Return                                       (₹5,000)           │
│                                                         ───────────         │
│ Net Sales                                                ₹3,45,000          │
│ Other Income                                             ₹2,000             │
│                                                         ───────────         │
│ TOTAL INCOME                                             ₹3,47,000          │
│                                                                             │
│ EXPENSES                                                                    │
│ ─────────────────────────────────────────────────────────────────           │
│ Purchases                                                ₹1,20,000          │
│ Less: Purchase Return                                    (₹3,000)           │
│                                                         ───────────         │
│ Net Purchases                                            ₹1,17,000          │
│ Discount Given                                           ₹5,000             │
│ Bank Charges                                             ₹500               │
│ Other Expenses                                           ₹8,000             │
│                                                         ───────────         │
│ TOTAL EXPENSES                                           ₹1,30,500          │
│                                                                             │
│ ═══════════════════════════════════════════════════════════════════════════ │
│ NET PROFIT                                               ₹2,16,500          │
│ ═══════════════════════════════════════════════════════════════════════════ │
└─────────────────────────────────────────────────────────────────────────────┘
```

#### Balance Sheet
```
┌─────────────────────────────────────────────────────────────────────────────┐
│ BALANCE SHEET                                          As on 31-Jan-2025    │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│ ASSETS                                 │ LIABILITIES & EQUITY               │
│ ──────────────────────────────────────│────────────────────────────────────│
│                                        │                                    │
│ Current Assets:                        │ Current Liabilities:               │
│   Cash              ₹45,000            │   Accounts Payable    ₹42,000     │
│   Bank              ₹2,35,000          │   GST Payable         ₹23,700     │
│   Receivables       ₹51,550            │                                    │
│   GST Input         ₹29,400            │                       ───────────  │
│                     ───────────        │ Total Liabilities     ₹65,700     │
│ Total Assets        ₹3,60,950          │                                    │
│                                        │ Equity:                            │
│                                        │   Owner's Capital     ₹40,850     │
│                                        │   Retained Earnings   ₹2,54,400   │
│                                        │                       ───────────  │
│                                        │ Total Equity          ₹2,95,250   │
│                                        │                                    │
├────────────────────────────────────────┼────────────────────────────────────┤
│ TOTAL               ₹3,60,950          │ TOTAL                 ₹3,60,950   │
│                                   ✓ BALANCED                                │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

### Phase 13: Dashboard Enhancement (Detailed)

#### Dashboard Design
```
┌─────────────────────────────────────────────────────────────────────────────┐
│ Dashboard                                     Welcome, Rahul! (TPL1234)     │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│ ┌─────────────────────┐ ┌─────────────────────┐ ┌─────────────────────┐    │
│ │ Today's Sales       │ │ This Month          │ │ Outstanding         │    │
│ │                     │ │                     │ │ Receivables         │    │
│ │ ₹15,800            │ │ ₹3,45,000          │ │ ₹1,50,500          │    │
│ │ 2 invoices          │ │ 16 invoices         │ │ 12 invoices         │    │
│ └─────────────────────┘ └─────────────────────┘ └─────────────────────┘    │
│                                                                             │
│ ┌─────────────────────┐ ┌─────────────────────┐ ┌─────────────────────┐    │
│ │ Outstanding         │ │ GST Liability       │ │ Net Profit          │    │
│ │ Payables            │ │ (This Month)        │ │ (This Month)        │    │
│ │ ₹42,000            │ │ ₹23,700            │ │ ₹2,16,500          │    │
│ │ 5 bills             │ │ Due: 20-Feb-25      │ │ ↑ 12% from last     │    │
│ └─────────────────────┘ └─────────────────────┘ └─────────────────────┘    │
│                                                                             │
│ ┌─────────────────────────────────────┐ ┌─────────────────────────────────┐│
│ │ Aging Alert                    ⚠️   │ │ Quick Actions                   ││
│ │                                     │ │                                 ││
│ │ 3 invoices overdue > 30 days        │ │ [+ New Invoice]                 ││
│ │ Total: ₹45,000                      │ │ [+ New Quotation]               ││
│ │                                     │ │ [+ Add Customer]                ││
│ │ [View Aging Report]                 │ │ [Record Payment]                ││
│ └─────────────────────────────────────┘ └─────────────────────────────────┘│
│                                                                             │
│ ┌───────────────────────────────────────────────────────────────────────┐  │
│ │ Recent Activity                                                        │  │
│ ├───────────────────────────────────────────────────────────────────────┤  │
│ │ Today    Invoice TPL/INV/25/016 created - Triroop - ₹11,800           │  │
│ │ Today    Payment received - ABC Corp - ₹25,000                         │  │
│ │ Ystrdy   Quotation sent - XYZ Ltd - ₹50,000                           │  │
│ │ Ystrdy   PO received from PQR Industries                               │  │
│ └───────────────────────────────────────────────────────────────────────┘  │
│                                                                             │
│ ┌───────────────────────────────────────────────────────────────────────┐  │
│ │ Sales Trend (Last 6 Months)                                            │  │
│ │                                                     ┌───┐              │  │
│ │                                           ┌───┐     │   │              │  │
│ │                               ┌───┐       │   │     │   │              │  │
│ │                   ┌───┐       │   │       │   │     │   │              │  │
│ │       ┌───┐       │   │       │   │       │   │     │   │              │  │
│ │       │   │       │   │       │   │       │   │     │   │              │  │
│ │ ──────┴───┴───────┴───┴───────┴───┴───────┴───┴─────┴───┴──────────   │  │
│ │       Aug         Sep         Oct         Nov         Dec    Jan       │  │
│ └───────────────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────────┘
```

#### Dashboard Widgets Summary

| Widget | Data Source | Purpose |
|--------|-------------|---------|
| Today's Sales | Invoices (today) | Quick daily check |
| This Month Sales | Invoices (month) | Monthly progress |
| Outstanding Receivables | Unpaid invoices | Cash to collect |
| Outstanding Payables | Unpaid bills | Cash to pay |
| GST Liability | GST Output - Input | Tax planning |
| Net Profit | P&L calculation | Business health |
| Aging Alert | Overdue invoices | Follow-up priority |
| Quick Actions | Navigation shortcuts | Productivity |
| Recent Activity | All transactions | Audit trail |
| Sales Trend | Monthly aggregates | Growth visualization |

---

### Implementation Summary

| Phase | What User Gets | Business Value |
|-------|----------------|----------------|
| 1 | Vendor management | Know who you buy from |
| 2 | Purchase orders | Formal buying process |
| 3 | (Infrastructure) | Foundation for accounting |
| 4 | Invoice tracking | Know what's owed to you |
| 5 | Payment recording | Track money received |
| 6 | Bill management | Track what you owe |
| 7 | Credit notes | Handle returns properly |
| 8 | Debit notes | Claim vendor credits |
| 9 | Basic reports | See business performance |
| 10 | Aging reports | Manage cash flow |
| 11 | GST reports | File taxes easily |
| 12 | Financial statements | Complete books |
| 13 | Dashboard | Business at a glance |

Each phase builds on the previous. By Phase 13, VyaparBook is a complete accounting + B2B ecosystem platform.
