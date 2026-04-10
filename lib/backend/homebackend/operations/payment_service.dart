import 'package:intl/intl.dart';
import 'package:loom/backend/homebackend/customer/bcustomerlist_in_purchaing.dart';
import 'package:loom/backend/homebackend/vendor/bvendername.dart';
import 'package:loom/backend/homebackend/operations/khisab.dart';
import 'package:loom/backend/homebackend/operations/split_payment_db.dart';
import 'package:loom/backend/homebackend/customer/bcustomer.dart';
import 'package:loom/backend/homebackend/vendor/bvendor.dart';

class PaymentService {
  static final PaymentService getInstance = PaymentService._();
  PaymentService._();

  static const String TYPE_CUSTOMER = "Customer";
  static const String TYPE_VENDOR = "Vendor";

  /// Process a payment (Receipt or Paid) for either a Customer or Vendor.
  /// 
  /// [personType]: "Customer" or "Vendor"
  /// [personId]: UID for Customer or Name for Vendor (Standardized across app hooks)
  /// [amount]: Amount of the payment
  /// [isPaymentReceived]: True if we are receiving cash (Income). False if we are paying cash (Expense).
  /// [description]: Note for the transaction
  Future<bool> processLedgerPayment({
    required String personType,
    required String personId,
    required String personName,
    required double amount,
    required bool isPaymentReceived,
    String? description,
  }) async {
    final String currentDate = DateFormat('dd-MM-yyyy').format(DateTime.now());
    final String manualId = "PAY_${DateTime.now().millisecondsSinceEpoch}";
    final String personNote = description ?? (isPaymentReceived ? "Payment Received" : "Payment Paid");

    try {
      if (personType == TYPE_CUSTOMER) {
        // --- CUSTOMER LOGIC ---
        // 1. Fetch current running balance
        double lastBalance = 0;
        final prevTransactions = await BCustomerLedgerDB.getInstance.getTransactions(personId);
        if (prevTransactions.isNotEmpty) {
          lastBalance = double.tryParse(prevTransactions.first[BCustomerLedgerDB.C_credit]?.toString() ?? '0') ?? 0;
        }

        // 2. Calculate New Balance (Receiving reduces Udhaar/increases Jamah, Charging reduces Jamah/increases Udhaar)
        // Standard code in lcustomer: isReceived ? lastBalance + amount : lastBalance - amount
        double newBalance = isPaymentReceived ? lastBalance + amount : lastBalance - amount;

        // 3. Update Customer Ledger
        await BCustomerLedgerDB.getInstance.addTransaction(personId, {
          BCustomerLedgerDB.C_invoice_id: manualId,
          BCustomerLedgerDB.C_item: personNote,
          BCustomerLedgerDB.C_meter: "N/A",
          BCustomerLedgerDB.C_than: "N/A",
          BCustomerLedgerDB.C_total: !isPaymentReceived ? amount.toString() : "0",
          BCustomerLedgerDB.C_paid: isPaymentReceived ? amount.toString() : "0",
          BCustomerLedgerDB.C_type: "Manual",
          BCustomerLedgerDB.C_date: currentDate,
          BCustomerLedgerDB.C_credit: newBalance.toString(),
        });

        // 4. Update Main Customer Balance
        await BCustomer.getInstance.updateCustomerBalance(personId, newBalance.toString());

      } else {
        // --- VENDOR LOGIC ---
        // 1. Fetch current running balance
        double previousVendorBalance = await Bvendername.getInstance.getRunningBalance(personName);
        
        // 2. Calculate New Balance (Paying increases Jamah/reduces Udhaar, Charging reduces Jamah/increases Udhaar)
        // Standard check: Paying cash means we have more advance (Positive)
        double vendorBillImpact = isPaymentReceived ? -amount : amount; // Usually vendor is Paid, but if we receive Hafta back...
        // Actually, for vendor payments, usually we PAY them (Expense). 
        // If we are paying a vendor: cash+=amount, balance+=amount.
        double newVendorRunningBalance = previousVendorBalance + (isPaymentReceived ? -amount : amount);

        // 3. Update Vendor Ledger
        await Bvendername.getInstance.addLedgerEntry(personName, {
          'name': personNote,
          'uid': manualId,
          'date': currentDate,
          'totalmeter': 0.0,
          'total_price': !isPaymentReceived ? 0.0 : amount, // If we pay, bill impact is 0 but cash increases
          'per_meter': 0.0,
          'debit': newVendorRunningBalance,
          'cash': !isPaymentReceived ? amount : 0, 
        });

        // 4. Update Main Vendor Balance (UID needed)
        // We'll search for the UID by name if not provided
        final allVendors = await Bvendor.getInstance.getAllVendors();
        final found = allVendors.firstWhere((v) => v['name'] == personName, orElse: () => {});
        if (found.isNotEmpty) {
          await Bvendor.getInstance.updateVendorBalance(found['uid'], newVendorRunningBalance.toString());
        }
      }

      // --- COMMON LOGGING ---
      // 5. Add to General Book-keeping (KHisab)
      await KHisabDB.getInstance.addHisab(
        name: personName,
        description: "$personNote ($manualId)",
        amount: amount,
        condition: isPaymentReceived ? 'income' : 'expense',
      );

      // 6. Add to Split Payment Log (DB-Synced for accuracy)
      if (personType == TYPE_CUSTOMER) {
        final List<Map<String, dynamic>> latestTx = await BCustomerLedgerDB.getInstance.getTransactions(personId);
        if (latestTx.isNotEmpty) {
          final dbRecord = latestTx.first;
          final double finalTotal = double.tryParse(dbRecord[BCustomerLedgerDB.C_total]?.toString() ?? '0') ?? 0;
          final double finalPaid = double.tryParse(dbRecord[BCustomerLedgerDB.C_paid]?.toString() ?? '0') ?? 0;
          final double finalDebit = double.tryParse(dbRecord[BCustomerLedgerDB.C_credit]?.toString() ?? '0') ?? 0;

          await SplitPaymentDB.getInstance.addSplitRecord(
            name: personName,
            suid: manualId,
            debit: finalDebit,
            cash: finalPaid,
            total: finalTotal,
            tableName: personType.toLowerCase(),
            date: currentDate,
          );
        }
      } else {
        final List<Map<String, dynamic>> latestTx = await Bvendername.getInstance.getLedgerEntries(personName);
        if (latestTx.isNotEmpty) {
          final dbRecord = latestTx.first;
          final double finalTotal = (dbRecord['total_price'] as num?)?.toDouble() ?? 0;
          final double finalPaid = (dbRecord['cash'] as num?)?.toDouble() ?? 0;
          final double finalDebit = (dbRecord['debit'] as num?)?.toDouble() ?? 0;

          await SplitPaymentDB.getInstance.addSplitRecord(
            name: personName,
            suid: manualId,
            debit: finalDebit,
            cash: finalPaid,
            total: finalTotal,
            tableName: personType.toLowerCase(),
            date: currentDate,
          );
        } else {
          // Fallback to direct provided amount
          await SplitPaymentDB.getInstance.addSplitRecord(
            name: personName,
            suid: manualId,
            debit: 0.0,
            cash: amount,
            total: amount,
            tableName: personType.toLowerCase(),
            date: currentDate,
          );
        }
      }

      return true;
    } catch (e) {
      print("Error in processLedgerPayment: $e");
      return false;
    }
  }
}
