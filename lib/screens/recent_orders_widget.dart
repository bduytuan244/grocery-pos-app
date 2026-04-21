import 'package:flutter/material.dart';

class RecentOrdersWidget extends StatelessWidget {
  final List<Map<String, dynamic>> orders;

  const RecentOrdersWidget({super.key, required this.orders});

  @override
  Widget build(BuildContext context) {
    // Nếu chưa có đơn nào, ẩn luôn toàn bộ khu vực này cho tiết kiệm diện tích
    if (orders.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ExpansionTile(
        initiallyExpanded: false, // Mặc định thu gọn
        leading: const Icon(Icons.history, color: Colors.teal),
        title: const Text(
          'Lịch sử 5 đơn vừa xong',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal),
        ),
        children: [
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: orders.length,
            itemBuilder: (context, index) {
              final order = orders[index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.teal.shade100,
                  child: Text('${index + 1}', style: const TextStyle(color: Colors.teal)),
                ),
                title: Text('Tổng: ${order['total']} đ', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                subtitle: Text('Lúc: ${order['time']} - ${order['items'].length} món'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () => _showOrderDetails(context, order),
              );
            },
          ),
        ],
      ),
    );
  }

  void _showOrderDetails(BuildContext context, Map<String, dynamic> order) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Chi tiết đơn lúc ${order['time']}'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: (order['items'] as List).length,
            itemBuilder: (context, i) {
              final item = order['items'][i];
              return Text('• ${item['name']} x${item['quantity']}');
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Đóng'))
        ],
      ),
    );
  }
}