import 'package:flutter/material.dart';

class CartScreen extends StatefulWidget {
  final List<Map<String, dynamic>> cart;

  const CartScreen({super.key, required this.cart});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  @override
  Widget build(BuildContext context) {
    double totalMoney = widget.cart.fold(0, (sum, item) => sum + (item['price'] * item['quantity']));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Thanh Toán Hóa Đơn'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: widget.cart.isEmpty
          ? const Center(child: Text('Giỏ hàng trống! Hãy chọn hàng trước.', style: TextStyle(fontSize: 18)))
          : Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: widget.cart.length,
              itemBuilder: (context, index) {
                final item = widget.cart[index];
                return ListTile(
                  leading: const Icon(Icons.check_box, color: Colors.teal),
                  title: Text(item['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('${item['price']} đ  x  ${item['quantity']}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${item['price'] * item['quantity']} đ',
                        style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.grey),
                        onPressed: () {
                          setState(() {
                            widget.cart.removeAt(index);
                          });
                        },
                      )
                    ],
                  ),
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(color: Colors.grey.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, -5))
              ],
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Tổng cộng:', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    Text('$totalMoney đ', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.red)),
                  ],
                ),
                const SizedBox(height: 15),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
                    // Trong nút ElevatedButton của CartScreen
                    onPressed: () {
                      if (widget.cart.isEmpty) return;

                      // Tạo đối tượng đơn hàng để lưu lịch sử
                      final newOrder = {
                        'id': DateTime.now().millisecondsSinceEpoch.toString(),
                        'time': TimeOfDay.now().format(context),
                        'items': List.from(widget.cart), // Sao chép danh sách giỏ hàng
                        'total': widget.cart.fold(0.0, (sum, item) => sum + (item['price'] * item['quantity'])),
                      };

                      Navigator.pop(context, newOrder);

                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Thanh toán thành công!'), backgroundColor: Colors.green),
                      );
                    },
                    child: const Text('XÁC NHẬN THANH TOÁN', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                )
              ],
            ),
          )
        ],
      ),
    );
  }
}