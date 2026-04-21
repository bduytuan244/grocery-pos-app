import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class CartScreen extends StatefulWidget {
  final List<Map<String, dynamic>> cart;

  const CartScreen({super.key, required this.cart});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  bool _isLoading = false; // Biến để xoay vòng vòng lúc đang gửi đơn

  // Hàm Gửi Hóa Đơn Lên Server
  Future<void> _submitOrder(double total) async {
    if (widget.cart.isEmpty) return;

    setState(() => _isLoading = true);

    // 1. Đóng gói dữ liệu đúng chuẩn Spring Boot đang chờ
    List<Map<String, dynamic>> orderItems = widget.cart.map((item) {
      return {
        "productId": item['id'].toString(),
        "name": item['name'],
        "price": item['price'],
        "quantity": item['quantity']
      };
    }).toList();

    final orderData = {
      "items": orderItems,
      "totalAmount": total
    };

    // 2. Gửi qua mạng
    try {
      final response = await http.post(
        Uri.parse('https://grocery-pos-backend-uoyv.onrender.com/api/orders'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(orderData),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        // Lấy hóa đơn từ server trả về (có kèm ID và thời gian)
        final savedOrder = jsonDecode(utf8.decode(response.bodyBytes));

        // Tạo một object giả lập lại định dạng để truyền về HomeScreen hiển thị Lịch sử
        final displayOrder = {
          'id': savedOrder['id'],
          'time': TimeOfDay.now().format(context), // Lấy giờ hiện tại trên điện thoại
          'items': List.from(widget.cart),
          'total': total,
        };

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Chốt đơn thành công! Đã lưu vào Sổ đỏ.'), backgroundColor: Colors.green),
        );

        // Đóng màn hình giỏ hàng và mang displayOrder về cho HomeScreen
        Navigator.pop(context, displayOrder);
      } else {
        throw Exception('Lỗi Server: Không thể lưu đơn hàng');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Tính tổng tiền
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

                // Bọc Dismissible để tạo hiệu ứng vuốt ngang để xóa
                return Dismissible(
                  key: UniqueKey(), // Cấp key duy nhất để Flutter biết đang vuốt món nào
                  direction: DismissDirection.horizontal, // Vuốt được cả trái và phải
                  background: Container(
                    color: Colors.red,
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.only(left: 20),
                    child: const Icon(Icons.delete_sweep, color: Colors.white, size: 30),
                  ),
                  secondaryBackground: Container(
                    color: Colors.red,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    child: const Icon(Icons.delete_sweep, color: Colors.white, size: 30),
                  ),
                  onDismissed: (direction) {
                    setState(() {
                      widget.cart.removeAt(index);
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Đã xóa ${item['name']}')),
                    );
                  },
                  child: ListTile(
                    leading: const Icon(Icons.check_box, color: Colors.teal),
                    title: Text(item['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('Đơn giá: ${item['price']} đ'),
                    // Cụm nút Cộng - Trừ chuyên nghiệp
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Nút TRỪ (Chỉ trừ số lượng, không xóa món)
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline, color: Colors.orange),
                          onPressed: () {
                            setState(() {
                              if (widget.cart[index]['quantity'] > 1) {
                                widget.cart[index]['quantity']--;
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Vuốt ngang màn hình để xóa hẳn món này!')),
                                );
                              }
                            });
                          },
                        ),
                        // Hiện số lượng
                        Text(
                          '${item['quantity']}',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        // Nút CỘNG
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline, color: Colors.teal),
                          onPressed: () {
                            setState(() {
                              widget.cart[index]['quantity']++;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          // Phần tính tiền ở đáy màn hình
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
                    onPressed: _isLoading ? null : () => _submitOrder(totalMoney),
                    child: _isLoading
                        ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('XÁC NHẬN THANH TOÁN', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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