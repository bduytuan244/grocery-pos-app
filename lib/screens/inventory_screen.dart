import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:typed_data'; // <--- DÙNG THƯ VIỆN NÀY THAY CHO dart:io
import 'package:image_picker/image_picker.dart';

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
            panEnabled: true,
            boundaryMargin: const EdgeInsets.all(20),
            minScale: 0.5,
            maxScale: 4,
            child: Image.network(
              imageUrl,
              fit: BoxFit.contain,
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

  void _showEditDialog(Map<String, dynamic> product) {
    final nameController = TextEditingController(text: product['name']);
    final priceController = TextEditingController(text: product['price'].toString());

    String finalImageUrl = product['imageUrl'] ?? '';

    // === THAY ĐỔI LỚN Ở ĐÂY: DÙNG Uint8List THAY CHO File ===
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
                  // Đọc file thành cục dữ liệu Bytes (Chạy được trên Web)
                  final bytes = await image.readAsBytes();

                  setStateDialog(() {
                    selectedImageBytes = bytes;
                    isUploading = true;
                  });

                  try {
                    String apiKey = "4f4db14c9c558c9d21817076fd50cc78";
                    var request = http.MultipartRequest('POST', Uri.parse('https://api.imgbb.com/1/upload?key=$apiKey'));

                    // Nén cục Bytes đó gửi lên mạng, bỏ qua đường dẫn ảo của Web
                    request.files.add(http.MultipartFile.fromBytes(
                        'image',
                        bytes,
                        filename: image.name
                    ));

                    var response = await request.send();
                    var responseData = await response.stream.bytesToString();
                    var result = jsonDecode(responseData);

                    if (result['success'] == true) {
                      setStateDialog(() {
                        finalImageUrl = result['data']['url'];
                      });
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đổi ảnh thành công!'), backgroundColor: Colors.green));
                    } else {
                      throw Exception("Lỗi từ ImgBB");
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
                    children: [
                      GestureDetector(
                        onTap: pickAndUploadImage,
                        child: Container(
                          height: 120,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.teal, width: 1),
                          ),
                          child: isUploading
                              ? const Center(child: CircularProgressIndicator(color: Colors.teal))
                              : selectedImageBytes != null
                          // Thay Image.file bằng Image.memory
                              ? ClipRRect(borderRadius: BorderRadius.circular(9), child: Image.memory(selectedImageBytes!, fit: BoxFit.cover))
                              : finalImageUrl.isNotEmpty
                              ? ClipRRect(borderRadius: BorderRadius.circular(9), child: Image.network(finalImageUrl, fit: BoxFit.cover, errorBuilder: (c, e, s) => const Icon(Icons.image_not_supported)))
                              : const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_photo_alternate, size: 40, color: Colors.teal),
                              Text('Bấm để đổi ảnh', style: TextStyle(color: Colors.teal)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 15),

                      TextField(
                        controller: nameController,
                        decoration: const InputDecoration(labelText: 'Tên mặt hàng', border: OutlineInputBorder()),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: priceController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Giá bán (VNĐ)', border: OutlineInputBorder()),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy', style: TextStyle(color: Colors.grey))),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
                    onPressed: isUploading ? null : () async {
                      try {
                        Map<String, dynamic> updatedProduct = Map<String, dynamic>.from(product);
                        updatedProduct['name'] = nameController.text;
                        updatedProduct['price'] = double.parse(priceController.text);
                        updatedProduct['imageUrl'] = finalImageUrl;

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

          final products = snapshot.data!;
          return ListView.separated(
            padding: const EdgeInsets.all(10),
            itemCount: products.length,
            separatorBuilder: (context, index) => const Divider(),
            itemBuilder: (context, index) {
              final item = products[index];
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
                subtitle: Text('${item['price']} đ', style: const TextStyle(color: Colors.red)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.blue),
                      onPressed: () => _showEditDialog(item),
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
          );
        },
      ),
    );
  }
}