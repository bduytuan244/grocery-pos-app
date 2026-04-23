import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  late Future<List<dynamic>> _productsFuture;

  // Biến tìm kiếm
  String _searchQuery = '';

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
      throw Exception('Lỗi Server');
    }
  }

  Future<void> _deleteProduct(String id, String name) async {
    try {
      final response = await http.delete(Uri.parse('https://grocery-pos-backend-uoyv.onrender.com/api/products/$id'));
      if (response.statusCode == 200 || response.statusCode == 204) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Đã xóa $name'), backgroundColor: Colors.red));
        setState(() { _productsFuture = fetchProducts(); });
      } else {
        throw Exception('Chưa có API Delete ở Backend');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
    }
  }

  void _showZoomedImageDialog(BuildContext context, String imageUrl) {
    if (imageUrl.isEmpty) return;
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(10),
        child: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: InteractiveViewer(
            panEnabled: true, boundaryMargin: const EdgeInsets.all(20), minScale: 0.5, maxScale: 4,
            child: Image.network(
              imageUrl, fit: BoxFit.contain,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return const Center(child: CircularProgressIndicator(color: Colors.white));
              },
              errorBuilder: (context, error, stackTrace) => const Icon(Icons.image_not_supported, color: Colors.white, size: 50),
            ),
          ),
        ),
      ),
    );
  }

  // === CẬP NHẬT TRUYỀN DANH SÁCH DANH MỤC VÀO BẢNG SỬA ===
  void _showEditDialog(Map<String, dynamic> product, List<String> allExistingCategories) {
    final nameController = TextEditingController(text: product['name']);
    final priceController = TextEditingController(text: product['price'].toString());
    final newCategoryController = TextEditingController();

    String currentCategory = product['category'] ?? 'Khác';
    bool isAddingNewCategory = false;

    // Chuẩn bị Dropdown List
    List<String> dropdownItems = List.from(allExistingCategories);
    if (!dropdownItems.contains(currentCategory)) dropdownItems.insert(0, currentCategory);
    dropdownItems.add('➕ Đổi tên danh mục khác...');

    String finalImageUrl = product['imageUrl'] ?? '';
    Uint8List? selectedImageBytes;
    bool isUploading = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
            builder: (context, setStateDialog) {

              Future<void> pickAndUploadImage() async {
                final ImagePicker picker = ImagePicker();
                final XFile? image = await picker.pickImage(source: ImageSource.gallery);

                if (image != null) {
                  final bytes = await image.readAsBytes();
                  setStateDialog(() { selectedImageBytes = bytes; isUploading = true; });

                  try {
                    String apiKey = "4f4db14c9c558c9d21817076fd50cc78";
                    var request = http.MultipartRequest('POST', Uri.parse('https://api.imgbb.com/1/upload?key=$apiKey'));
                    request.files.add(http.MultipartFile.fromBytes('image', bytes, filename: image.name));

                    var response = await request.send();
                    var responseData = await response.stream.bytesToString();
                    var result = jsonDecode(responseData);

                    if (result['success'] == true) {
                      setStateDialog(() { finalImageUrl = result['data']['url']; });
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đổi ảnh thành công!'), backgroundColor: Colors.green));
                    }
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi tải ảnh: $e'), backgroundColor: Colors.red));
                  } finally {
                    setStateDialog(() => isUploading = false);
                  }
                }
              }

              return AlertDialog(
                title: const Text('Sửa Thông Tin', style: TextStyle(color: Colors.teal, fontWeight: FontWeight.bold)),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GestureDetector(
                        onTap: pickAndUploadImage,
                        child: Container(
                          height: 120, width: double.infinity,
                          decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.teal, width: 1)),
                          child: isUploading
                              ? const Center(child: CircularProgressIndicator(color: Colors.teal))
                              : selectedImageBytes != null
                              ? ClipRRect(borderRadius: BorderRadius.circular(9), child: Image.memory(selectedImageBytes!, fit: BoxFit.cover))
                              : finalImageUrl.isNotEmpty
                              ? ClipRRect(borderRadius: BorderRadius.circular(9), child: Image.network(finalImageUrl, fit: BoxFit.cover, errorBuilder: (c, e, s) => const Icon(Icons.image_not_supported)))
                              : const Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.add_photo_alternate, size: 40, color: Colors.teal), Text('Bấm để đổi ảnh', style: TextStyle(color: Colors.teal))]),
                        ),
                      ),
                      const SizedBox(height: 15),

                      TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Tên mặt hàng', border: OutlineInputBorder())),
                      const SizedBox(height: 10),
                      TextField(controller: priceController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Giá bán (VNĐ)', border: OutlineInputBorder())),
                      const SizedBox(height: 10),

                      // === DROPDOWN SỬA DANH MỤC THÔNG MINH ===
                      const Text('Danh mục', style: TextStyle(fontSize: 12, color: Colors.teal)),
                      Container(
                        decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(4)),
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: isAddingNewCategory ? '➕ Đổi tên danh mục khác...' : currentCategory,
                            isExpanded: true,
                            items: dropdownItems.map((cat) => DropdownMenuItem(value: cat, child: Text(cat))).toList(),
                            onChanged: (val) {
                              setStateDialog(() {
                                if (val == '➕ Đổi tên danh mục khác...') {
                                  isAddingNewCategory = true;
                                } else {
                                  isAddingNewCategory = false;
                                  currentCategory = val!;
                                }
                              });
                            },
                          ),
                        ),
                      ),
                      if (isAddingNewCategory)
                        Padding(padding: const EdgeInsets.only(top: 10), child: TextField(controller: newCategoryController, decoration: const InputDecoration(hintText: 'Nhập tên danh mục mới...', border: OutlineInputBorder()))),
                    ],
                  ),
                ),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy', style: TextStyle(color: Colors.grey))),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
                    onPressed: isUploading ? null : () async {
                      try {
                        String finalCat = isAddingNewCategory ? newCategoryController.text.trim() : currentCategory;
                        if (finalCat.isEmpty) finalCat = "Khác";

                        Map<String, dynamic> updatedProduct = Map<String, dynamic>.from(product);
                        updatedProduct['name'] = nameController.text;
                        updatedProduct['price'] = double.parse(priceController.text);
                        updatedProduct['imageUrl'] = finalImageUrl;
                        updatedProduct['category'] = finalCat;

                        final response = await http.put(
                          Uri.parse('https://grocery-pos-backend-uoyv.onrender.com/api/products/${product['id']}'),
                          headers: {"Content-Type": "application/json"},
                          body: jsonEncode(updatedProduct),
                        );

                        if (response.statusCode == 200) {
                          if (!mounted) return;
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã cập nhật!'), backgroundColor: Colors.green));
                          setState(() { _productsFuture = fetchProducts(); });
                        } else {
                          throw Exception('Lỗi Server');
                        }
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
                      }
                    },
                    child: Text(isUploading ? 'Đang up ảnh...' : 'Lưu Thay Đổi'),
                  )
                ],
              );
            }
        );
      },
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

          List<dynamic> allProducts = snapshot.data!;

          // === TẠO DANH SÁCH DANH MỤC CHO DROPDOWN ===
          final List<String> priorityCategories = ['Sắt thép', 'Ống nước', 'Đồ điện', 'Đinh - Vít', 'Dụng cụ cầm tay', 'Sơn - Keo', 'Khác'];
          Set<String> catSet = {};
          for (var p in allProducts) {
            if (p['category'] != null && p['category'].toString().isNotEmpty) catSet.add(p['category'].toString());
          }

          List<String> finalCategories = List.from(priorityCategories);
          for (String cat in catSet) {
            if (!finalCategories.contains(cat)) finalCategories.add(cat);
          }

          // === TÌM KIẾM VÀ SẮP XẾP MỚI NHẤT LÊN ĐẦU ===
          List<dynamic> filteredProducts = allProducts.where((p) => p['name'].toString().toLowerCase().contains(_searchQuery.toLowerCase())).toList();
          filteredProducts.sort((a, b) => b['id'].toString().compareTo(a['id'].toString()));

          return Column(
            children: [
              // --- THANH TÌM KIẾM TRONG KHO ---
              Padding(
                padding: const EdgeInsets.all(10.0),
                child: TextField(
                  onChanged: (value) => setState(() => _searchQuery = value),
                  decoration: InputDecoration(
                    hintText: 'Tìm kiếm hàng trong kho...',
                    prefixIcon: const Icon(Icons.search),
                    filled: true, fillColor: Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              Expanded(
                child: filteredProducts.isEmpty
                    ? const Center(child: Text('Không tìm thấy sản phẩm.'))
                    : ListView.separated(
                  padding: const EdgeInsets.all(10),
                  itemCount: filteredProducts.length,
                  separatorBuilder: (context, index) => const Divider(),
                  itemBuilder: (context, index) {
                    final item = filteredProducts[index];
                    return ListTile(
                      leading: GestureDetector(
                        onTap: () {
                          if (item['imageUrl'] != null && item['imageUrl'].toString().isNotEmpty) {
                            _showZoomedImageDialog(context, item['imageUrl']);
                          }
                        },
                        child: SizedBox(
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
                      ),
                      title: Text(item['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('${item['price']} đ\nDanh mục: ${item['category'] ?? "Khác"}', style: const TextStyle(color: Colors.red)),
                      isThreeLine: true,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.blue),
                            onPressed: () => _showEditDialog(item, finalCategories), // Truyền list danh mục vào đây
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () {
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
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}