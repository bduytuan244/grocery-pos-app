import 'package:flutter/material.dart';

class RecentOrdersWidget extends StatelessWidget {
  final List<Map<String, dynamic>> orders;

  const RecentOrdersWidget({super.key, required this.orders});

  @override
  Widget build(BuildContext context) {
    if (orders.isEmpty) {
      return const Center(
        child: Text('Chưa có đơn hàng nào vừa xong.', style: TextStyle(color: Colors.grey)),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.all(10),
          child: Text(
            '5 ĐƠN HÀNG VỪA XONG',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal),
          ),
        ),
        // Sử dụng ListView.builder để vẽ danh sách
        ListView.builder(
          shrinkWrap: true, // Quan trọng: Để ListView nằm gọn trong Column
          physics: const NeverScrollableScrollPhysics(), // Để cuộn theo màn hình chính
          itemCount: orders.length,
          itemBuilder: (context, index) {
            final order = orders[index];
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.teal.shade100,
                  child: Text('${index + 1}', style: const TextStyle(color: Colors.teal)),
                ),
                title: Text('Tổng: ${order['total']} đ', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                subtitle: Text('Lúc: ${order['time']} - ${order['items'].length} món'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  // Hiển thị chi tiết các món trong đơn này khi mẹ bạn bấm vào
                  _showOrderDetails(context, order);
                },
              ),
            );
          },
        ),
      ],
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