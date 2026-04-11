import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

// Khai báo 2 màn hình kia để bấm nút là chuyển qua được
import 'cart_screen.dart';
import 'add_product_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<List<dynamic>> _productsFuture;
  List<Map<String, dynamic>> cart = [];

  @override
  void initState() {
    super.initState();
    _productsFuture = fetchProducts();
  }

  Future<List<dynamic>> fetchProducts() async {
    final response = await http.get(Uri.parse('http://10.0.2.2:8080/api/products'));
    if (response.statusCode == 200) {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } else {
      throw Exception('Lỗi không thể tải dữ liệu');
    }
  }

  void addToCart(dynamic product) {
    setState(() {
      int existingIndex = cart.indexWhere((item) => item['id'] == product['id']);
      if (existingIndex != -1) {
        cart[existingIndex]['quantity']++;
      } else {
        cart.add({
          'id': product['id'],
          'name': product['name'],
          'price': product['price'],
          'quantity': 1,
        });
      }
    });

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Đã thêm ${product['name']} vào giỏ'),
        duration: const Duration(seconds: 1),
        backgroundColor: Colors.teal,
      ),
    );
  }

  void openCartScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CartScreen(cart: cart),
      ),
    ).then((_) {
      setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    int totalItems = cart.fold(0, (sum, item) => sum + (item['quantity'] as int));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Máy Tính Tiền POS', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.shopping_cart, size: 28),
                onPressed: openCartScreen,
              ),
              if (totalItems > 0)
                Positioned(
                  right: 6,
                  top: 6,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '$totalItems',
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                )
            ],
          ),
          const SizedBox(width: 10),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add_box, size: 30),
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddProductScreen()),
          );
          if (result == true) {
            setState(() {
              _productsFuture = fetchProducts();
            });
          }
        },
      ),
      body: FutureBuilder<List<dynamic>>(
        future: _productsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Lỗi kết nối: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('Chưa có mặt hàng nào.'));
          }

          final products = snapshot.data!;
          return GridView.builder(
            padding: const EdgeInsets.all(10),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.85,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemCount: products.length,
            itemBuilder: (context, index) {
              final item = products[index];
              return Card(
                elevation: 3,
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.inventory_2, size: 50, color: Colors.teal),
                      const SizedBox(height: 10),
                      Text(
                        item['name'] ?? 'Chưa có tên',
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        '${item['price']} đ',
                        style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      ElevatedButton.icon(
                        onPressed: () => addToCart(item),
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Thêm'),
                      )
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}