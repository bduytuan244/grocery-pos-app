import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:image_picker/image_picker.dart';

class AddProductScreen extends StatefulWidget {
  const AddProductScreen({super.key});

  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _categoryController = TextEditingController();
  final _priceController = TextEditingController();
  final _unitController = TextEditingController();

  bool _isLoading = false;
  File? _selectedImage; // Biến lưu tấm ảnh chọn từ điện thoại
  String _finalImageUrl = ""; // Biến lưu link ảnh sau khi đưa lên ImgBB

  // --- HÀM 1: CHỌN ẢNH VÀ ĐẨY LÊN IMGBB ---
  Future<void> _pickAndUploadImage() async {
    final ImagePicker picker = ImagePicker();
    // Mở thư viện ảnh của điện thoại
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      setState(() {
        _selectedImage = File(image.path);
        _isLoading = true; // Hiện vòng xoay chờ tải ảnh
      });

      try {
        // API KEY CỦA TUẤN ĐÃ ĐƯỢC GẮN VÀO ĐÂY:
        String apiKey = "4f4db14c9c558c9d21817076fd50cc78";

        // Đóng gói ảnh gửi lên ImgBB
        var request = http.MultipartRequest('POST', Uri.parse('https://api.imgbb.com/1/upload?key=$apiKey'));
        request.files.add(await http.MultipartFile.fromPath('image', image.path));

        var response = await request.send();
        var responseData = await response.stream.bytesToString();
        var result = jsonDecode(responseData);

        if (result['success'] == true) {
          setState(() {
            // Lấy link xịn ImgBB trả về
            _finalImageUrl = result['data']['url'];
          });
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tải ảnh lên mạng thành công!'), backgroundColor: Colors.green));
        } else {
          throw Exception("Lỗi từ ImgBB");
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi tải ảnh: $e'), backgroundColor: Colors.red));
        setState(() => _selectedImage = null); // Bỏ chọn ảnh nếu lỗi
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  // --- HÀM 2: LƯU SẢN PHẨM VÀO DATABASE SPRING BOOT ---
  Future<void> _submitProduct() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final newProduct = {
      "name": _nameController.text,
      "category": _categoryController.text.isEmpty ? "Khác" : _categoryController.text,
      "unit": _unitController.text.isEmpty ? "Cái" : _unitController.text,
      "price": double.parse(_priceController.text),
      "imageUrl": _finalImageUrl, // <--- SỬ DỤNG LINK ẢNH XỊN TỪ IMGBB
      "stock": 100,
      "hasVariants": false,
      "keywords": _nameController.text.toLowerCase().split(' ')
    };

    try {
      final response = await http.post(
        Uri.parse('https://grocery-pos-backend-uoyv.onrender.com/api/products'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(newProduct),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã thêm sản phẩm thành công!'), backgroundColor: Colors.green),
        );
        Navigator.pop(context, true);
      } else {
        throw Exception('Lỗi Server Backend');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi kết nối: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Thêm Hàng Vào Kho'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              // --- GIAO DIỆN CHỌN ẢNH MỚI ---
              GestureDetector(
                onTap: _pickAndUploadImage,
                child: Container(
                  height: 180,
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    border: Border.all(color: Colors.teal.withOpacity(0.5), width: 2, style: BorderStyle.solid),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: _isLoading && _selectedImage != null
                      ? const Center(child: CircularProgressIndicator(color: Colors.teal)) // Đang xoay chờ tải
                      : _selectedImage != null
                      ? ClipRRect(borderRadius: BorderRadius.circular(13), child: Image.file(_selectedImage!, fit: BoxFit.cover, width: double.infinity))
                      : const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_photo_alternate_outlined, size: 60, color: Colors.teal),
                      SizedBox(height: 10),
                      Text('Bấm để chọn ảnh từ điện thoại', style: TextStyle(color: Colors.teal, fontWeight: FontWeight.bold, fontSize: 16)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 25),

              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Tên mặt hàng *',
                  hintText: 'VD: Ống nhựa Bình Minh Phi 27',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => value!.isEmpty ? 'Vui lòng nhập tên hàng' : null,
              ),
              const SizedBox(height: 15),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _priceController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Giá bán (VNĐ) *',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) => value!.isEmpty ? 'Vui lòng nhập giá' : null,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 1,
                    child: TextFormField(
                      controller: _unitController,
                      decoration: const InputDecoration(
                        labelText: 'Đơn vị',
                        hintText: 'VD: Mét, Cái',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 15),
              TextFormField(
                controller: _categoryController,
                decoration: const InputDecoration(
                  labelText: 'Danh mục',
                  hintText: 'VD: Đồ kim khí, Ống nước...',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 30),
              SizedBox(
                height: 55,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
                  ),
                  onPressed: _isLoading ? null : _submitProduct,
                  icon: _isLoading
                      ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                      : const Icon(Icons.save_alt, size: 28),
                  label: Text(_isLoading ? 'ĐANG XỬ LÝ...' : 'LƯU SẢN PHẨM', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}