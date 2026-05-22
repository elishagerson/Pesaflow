import 'package:flutter/material.dart';

class TransactionFormScreen extends StatelessWidget {
  final String? transactionId;

  const TransactionFormScreen({super.key, this.transactionId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(transactionId == null ? 'Add Transaction' : 'Edit Transaction'),
      ),
      body: const Center(
        child: Text('Transaction Form Screen'),
      ),
    );
  }
}
