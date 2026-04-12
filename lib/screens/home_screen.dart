import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'cart_screen.dart';
import 'add_product_screen.dart';
import 'recent_orders_widget.dart'; // Đã import file Lịch sử

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<List<dynamic>> _productsFuture;
  List<Map<String, dynamic>> cart = [];

  // Các biến tìm kiếm
  String _searchQuery = '';
  String _selectedCategory = 'Tất cả';

  // Danh sách lưu 5 đơn gần nhất
  List<Map<String, dynamic>> recentOrders = [];

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

  void openCartScreen() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CartScreen(cart: cart),
      ),
    );

    // Xử lý khi nhận được đơn hàng trả về từ màn hình Thanh toán
    if (result != null && result is Map<String, dynamic>) {
      setState(() {
        recentOrders.insert(0, result);
        if (recentOrders.length > 5) {
          recentOrders.removeLast();
        }
        cart.clear(); // Xóa giỏ hàng
      });
    } else {
      setState(() {});
    }
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

          final allProducts = snapshot.data!;

          List<String> categories = ['Tất cả'];
          categories.addAll(allProducts.map((p) => p['category'].toString()).toSet().toList());

          final filteredProducts = allProducts.where((product) {
            final matchesSearch = product['name'].toString().toLowerCase().contains(_searchQuery.toLowerCase());
            final matchesCategory = _selectedCategory == 'Tất cả' || product['category'] == _selectedCategory;
            return matchesSearch && matchesCategory;
          }).toList();

          return Column(
            children: [
              // 1. THANH TÌM KIẾM
              Padding(
                padding: const EdgeInsets.all(10.0),
                child: TextField(
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                  decoration: InputDecoration(
                    hintText: 'Tìm ống nhựa, đinh vít, búa...',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: Colors.grey[200],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),

              // 2. THANH DANH MỤC
              SizedBox(
                height: 50,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  itemCount: categories.length,
                  itemBuilder: (context, index) {
                    final category = categories[index];
                    final isSelected = category == _selectedCategory;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: ChoiceChip(
                        label: Text(category),
                        selected: isSelected,
                        onSelected: (selected) {
                          setState(() {
                            _selectedCategory = category;
                          });
                        },
                        selectedColor: Colors.teal.shade200,
                        backgroundColor: Colors.grey[200],
                      ),
                    );
                  },
                ),
              ),

              RecentOrdersWidget(orders: recentOrders),

              Expanded(
                child: filteredProducts.isEmpty
                    ? const Center(child: Text('Không tìm thấy mặt hàng này!', style: TextStyle(color: Colors.grey, fontSize: 16)))
                    : GridView.builder(
                  padding: const EdgeInsets.all(10),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.85,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  itemCount: filteredProducts.length,
                  itemBuilder: (context, index) {
                    final item = filteredProducts[index];
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
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}