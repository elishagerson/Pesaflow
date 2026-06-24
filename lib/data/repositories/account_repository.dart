import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/app_database.dart';
import '../database/daos/account_dao.dart';
import '../database/database_providers.dart';

final accountRepositoryProvider = Provider<AccountRepository>((ref) {
  final dao = ref.watch(accountDaoProvider);
  return AccountRepository(dao);
});

class AccountRepository {
  final AccountDao _accountDao;

  AccountRepository(this._accountDao);

  Stream<List<Account>> watchAllAccounts() => _accountDao.watchAllAccounts();

  Future<List<Account>> getAllAccounts() => _accountDao.getAllAccounts();

  Future<Account?> getAccountById(String id) => _accountDao.getAccountById(id);

  Future<int> createAccount(Account account) => _accountDao.insertAccount(account);

  Future<bool> updateAccount(Account account) => _accountDao.updateAccount(account);

  Future<void> deleteAccount(String id) => _accountDao.deleteAccount(id);
}
