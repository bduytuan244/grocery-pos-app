import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  late Future<List<dynamic>> _productsFuture;

  @override
  void initState() {
    super.initState();
    _productsFuture = fetchProducts();
  }

  // Hàm tải dữ liệu
  Future<List<dynamic>> fetchProducts() async {
    final response = await http.get(Uri.parse('https://grocery-pos-backend-uoyv.onrender.com/api/products'));
    if (response.statusCode == 200) {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } else {
      throw Exception('Lỗi Server');
    }
  }

  // Hàm Xóa sản phẩm
  Future<void> _deleteProduct(String id, String name) async {
    try {
      final response = await http.delete(Uri.parse('https://grocery-pos-backend-uoyv.onrender.com/api/products/$id'));
      if (response.statusCode == 200 || response.statusCode == 204) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Đã xóa $name'), backgroundColor: Colors.red));
        setState(() { _productsFuture = fetchProducts(); }); // Tải lại danh sách
      } else {
        throw Exception('Chưa có API Delete ở Backend');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
    }
  }

  // Hàm hiển thị Bảng Sửa sản phẩm
  void _showEditDialog(Map<String, dynamic> product) {
    final nameController = TextEditingController(text: product['name']);
    final priceController = TextEditingController(text: product['price'].toString());
    // THÊM: Biến lưu trữ link ảnh hiện tại (nếu có)
    final imageController = TextEditingController(text: product['imageUrl'] ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sửa Thông Tin', style: TextStyle(color: Colors.teal, fontWeight: FontWeight.bold)),
        // Bọc SingleChildScrollView để tránh lỗi bàn phím đè lên form
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Tên mặt hàng'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: priceController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Giá bán (VNĐ)'),
              ),
              const SizedBox(height: 10),
              // THÊM: Ô nhập link ảnh
              TextField(
                controller: imageController,
                decoration: const InputDecoration(
                    labelText: 'Link ảnh (URL)',
                    hintText: 'Dán link ảnh từ mạng vào đây'
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
            onPressed: () async {
              // Gọi API cập nhật (PUT)
              try {
                final response = await http.put(
                  Uri.parse('https://grocery-pos-backend-uoyv.onrender.com/api/products/${product['id']}'),
                  headers: {"Content-Type": "application/json"},
                  body: jsonEncode({
                    "name": nameController.text,
                    "price": double.parse(priceController.text),
                    "imageUrl": imageController.text // Gửi thêm link ảnh mới lên server
                  }),
                );

                if (response.statusCode == 200) {
                  if (!mounted) return;
                  Navigator.pop(context); // Đóng bảng
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã cập nhật!'), backgroundColor: Colors.green));
                  setState(() { _productsFuture = fetchProducts(); }); // Tải lại danh sách
                } else {
                  throw Exception('Chưa có API Put ở Backend');
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
              }
            },
            child: const Text('Lưu Thay Đổi'),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản Lý Kho Hàng'),
        backgroundColor: Colors.blueGrey,
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder<List<dynamic>>(
        future: _productsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError) return Center(child: Text('Lỗi: ${snapshot.error}'));
          if (!snapshot.hasData || snapshot.data!.isEmpty) return const Center(child: Text('Kho trống!'));

          final products = snapshot.data!;
          return ListView.separated(
            padding: const EdgeInsets.all(10),
            itemCount: products.length,
            separatorBuilder: (context, index) => const Divider(),
            itemBuilder: (context, index) {
              final item = products[index];
              return ListTile(
                // HIỂN THỊ ẢNH THU NHỎ TRONG KHO
                leading: SizedBox(
                  width: 50,
                  height: 50,
                  child: (item['imageUrl'] != null && item['imageUrl'].toString().isNotEmpty)
                      ? ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.network(
                      item['imageUrl'],
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => const Icon(Icons.image_not_supported, color: Colors.grey),
                    ),
                  )
                      : const Icon(Icons.inventory, color: Colors.blueGrey, size: 40),
                ),
                title: Text(item['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('${item['price']} đ', style: const TextStyle(color: Colors.red)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // NÚT SỬA
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.blue),
                      onPressed: () => _showEditDialog(item),
                    ),
                    // NÚT XÓA
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () {
                        // Xác nhận trước khi xóa
                        showDialog(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Xóa sản phẩm?'),
                              content: Text('Bạn có chắc muốn xóa "${item['name']}" không?'),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
                                TextButton(
                                  onPressed: () {
                                    Navigator.pop(ctx);
                                    _deleteProduct(item['id'].toString(), item['name']);
                                  },
                                  child: const Text('Xóa', style: TextStyle(color: Colors.red)),
                                )
                              ],
                            )
                        );
                      },
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}