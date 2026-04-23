import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'inventory_screen.dart';
import 'statistics_screen.dart';

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
    final response = await http.get(Uri.parse('https://grocery-pos-backend-uoyv.onrender.com/api/products'));
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

  // Hiển thị ảnh phóng to
  void _showZoomedImageDialog(BuildContext context, String imageUrl) {
    if (imageUrl.isEmpty) return;
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => Theme(
        data: Theme.of(context).copyWith(dialogBackgroundColor: Colors.transparent),
        child: Dialog(
          backgroundColor: Colors.black54, // Nền tối để nổi bật ảnh
          insetPadding: EdgeInsets.zero, // Tràn viền
          child: Stack(
            alignment: Alignment.center,
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context), // Nhấn ra ngoài để đóng
                child: Container(color: Colors.transparent),
              ),
              InteractiveViewer(
                clipBehavior: Clip.none,
                minScale: 0.5,
                maxScale: 5.0, // Zoom x5
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  errorBuilder: (c, e, s) => const Icon(Icons.broken_image, color: Colors.white, size: 100),
                ),
              ),
              Positioned(
                top: 40,
                right: 20,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 30),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    int totalItems = cart.fold(0, (sum, item) => sum + (item['quantity'] as int));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Máy Tính Tiền POS', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          // 1. NÚT VÀO KHO HÀNG (Cài đặt)
          IconButton(
            icon: const Icon(Icons.settings, size: 28),
            onPressed: () async {
              await Navigator.push(context, MaterialPageRoute(builder: (context) => const InventoryScreen()));
              setState(() {
                _productsFuture = fetchProducts();
              });
            },
          ),

          // 2. NÚT XEM THỐNG KÊ (Biểu đồ)
          IconButton(
            icon: const Icon(Icons.bar_chart, size: 28),
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const StatisticsScreen()));
            },
          ),

          // 3. NÚT GIỎ HÀNG
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

          // === CHIẾN THUẬT LAI: ƯU TIÊN CỐ ĐỊNH + QUÉT TỰ ĐỘNG KHO ===
          // 1. Danh sách cứng theo thứ tự ưu tiên
          final List<String> priorityCategories = ['Tất cả', 'Sắt thép', 'Ống nước', 'Đồ điện', 'Đinh - Vít', 'Dụng cụ cầm tay', 'Sơn - Keo', 'Khác'];

          // 2. Quét kho xem có danh mục nào "Lạ" không (VD: sắt hộp)
          Set<String> existingCategories = {};
          for (var p in allProducts) {
            if (p['category'] != null && p['category'].toString().isNotEmpty) {
              existingCategories.add(p['category'].toString());
            }
          }

          // 3. Ghép nối: Lấy danh sách ưu tiên làm gốc, nếu gặp từ lạ thì nhét xuống cuối.
          List<String> finalCategories = List.from(priorityCategories);
          for (String cat in existingCategories) {
            if (!finalCategories.contains(cat)) {
              finalCategories.add(cat);
            }
          }

          // 4. Reset an toàn: Nếu danh mục đang chọn bị xóa sạch khỏi kho thì tự về 'Tất cả'
          if (!finalCategories.contains(_selectedCategory)) {
            _selectedCategory = 'Tất cả';
          }

          // === LỌC VÀ SẮP XẾP SẢN PHẨM ===
          var filteredProducts = allProducts.where((product) {
            final matchesSearch = product['name'].toString().toLowerCase().contains(_searchQuery.toLowerCase());
            final matchesCategory = _selectedCategory == 'Tất cả' || product['category'] == _selectedCategory;
            return matchesSearch && matchesCategory;
          }).toList();

          // Sắp xếp MỚI NHẤT lên đầu (dựa vào ID của MongoDB)
          filteredProducts.sort((a, b) => b['id'].toString().compareTo(a['id'].toString()));

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

              // 2. DROPDOWN LỌC DANH MỤC
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 5.0),
                child: Row(
                  children: [
                    const Icon(Icons.category, color: Colors.teal),
                    const SizedBox(width: 10),
                    const Text('Lọc theo:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedCategory,
                            isExpanded: true,
                            icon: const Icon(Icons.arrow_drop_down, color: Colors.teal),
                            items: finalCategories.map((String category) {
                              return DropdownMenuItem<String>(
                                value: category,
                                child: Text(category, style: const TextStyle(fontSize: 16)),
                              );
                            }).toList(),
                            onChanged: (String? newValue) {
                              if (newValue != null) {
                                setState(() {
                                  _selectedCategory = newValue;
                                });
                              }
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

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
                            GestureDetector(
                              onTap: () {
                                if (item['imageUrl'] != null && item['imageUrl'].toString().isNotEmpty) {
                                  _showZoomedImageDialog(context, item['imageUrl']);
                                }
                              },
                              child: (item['imageUrl'] != null && item['imageUrl'].toString().isNotEmpty)
                                  ? ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  item['imageUrl'],
                                  height: 70,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) => const Icon(Icons.image_not_supported, size: 50, color: Colors.grey),
                                ),
                              )
                                  : const Icon(Icons.inventory_2, size: 60, color: Colors.teal),
                            ),
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