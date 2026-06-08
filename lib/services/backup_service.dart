import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pesaflow/core/utils/csv_helper.dart';
import 'package:pesaflow/data/database/database_providers.dart';
import 'package:pesaflow/data/repositories/transaction_repository.dart';

final backupServiceProvider = Provider<BackupService>((ref) {
  return BackupService(ref);
});

class BackupService {
  final Ref _ref;

  BackupService(this._ref);

  /// Retrieves the active SQLite database file path.
  Future<File> _getDatabaseFile() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    return File(p.join(dbFolder.path, 'pesaflow.db'));
  }

  /// Exports all transactions to a CSV file and triggers native share.
  Future<void> exportTransactionsToCsv() async {
    final transactions = await _ref
        .read(transactionRepositoryProvider)
        .watchFilteredTransactions()
        .first;

    final csvString = CsvHelper.convertToCsv(transactions);

    final tempDir = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final tempFile = File(p.join(tempDir.path, 'pesaflow_export_$timestamp.csv'));

    await tempFile.writeAsString(csvString);

    await Share.shareXFiles(
      [XFile(tempFile.path)],
      subject: 'PesaFlow Transactions Export',
      text: 'Exported transaction logs from PesaFlow.',
    );
  }

  /// Copies the active local database to a temporary location and triggers sharing.
  Future<void> backupDatabase() async {
    final dbFile = await _getDatabaseFile();
    if (!await dbFile.exists()) {
      throw const FileSystemException('Local database file not found.');
    }

    final tempDir = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final backupFile = File(p.join(tempDir.path, 'pesaflow_backup_$timestamp.db'));

    // Copy DB file securely to temp location
    await dbFile.copy(backupFile.path);

    await Share.shareXFiles(
      [XFile(backupFile.path)],
      subject: 'PesaFlow Database Backup',
      text: 'Encrypted PesaFlow offline database backup.',
    );
  }

  /// Restores a selected database file from file picker.
  /// Returns [true] if restore succeeded and app needs restart.
  Future<bool> restoreDatabase() async {
    final result = await FilePicker.pickFiles(
      type: FileType.any,
    );

    if (result == null || result.files.single.path == null) {
      return false; // User cancelled
    }

    final filePath = result.files.single.path;
    if (filePath == null) return false;
    final pickedFile = File(filePath);

    // Premium check: Verify the picked file is a valid SQLite 3 database file
    final bytes = await pickedFile.openRead(0, 16).first;
    final header = String.fromCharCodes(bytes);
    if (!header.startsWith('SQLite format 3')) {
      throw const FormatException('Selected file is not a valid SQLite database backup.');
    }

    final dbFile = await _getDatabaseFile();

    // Close the current database connection to release locks
    final db = _ref.read(databaseProvider);
    await db.close();

    // Overwrite database file with the selected backup
    await pickedFile.copy(dbFile.path);

    return true;
  }
}
