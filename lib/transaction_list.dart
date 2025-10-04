import 'package:flutter/material.dart';

class TransactionList extends StatelessWidget {
  final List<Map<String, String>> transactions = [
    {"title": "Sent to John", "amount": "-₦500", "date": "March 25"},
    {"title": "Received from Alice", "amount": "+₦1,200", "date": "March 24"},
    {"title": "Bought NergCoin", "amount": "-₦2,000", "date": "March 23"},
  ];

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: transactions.length,
      itemBuilder: (context, index) {
        var transaction = transactions[index];
        return ListTile(
          leading: Icon(
            transaction["amount"]!.contains("+") ? Icons.arrow_downward : Icons.arrow_upward,
            color: transaction["amount"]!.contains("+") ? Colors.green : Colors.red,
          ),
          title: Text(transaction["title"]!, style: TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text(transaction["date"]!),
          trailing: Text(transaction["amount"]!, style: TextStyle(fontSize: 16)),
        );
      },
    );
  }
}
