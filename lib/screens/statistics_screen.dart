import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:fl_chart/fl_chart.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  late Future<List<dynamic>> _dataFuture;

  @override
  void initState() {
    super.initState();
    _dataFuture = fetchProducts();
  }

  Future<List<dynamic>> fetchProducts() async {
    final response = await http.get(Uri.parse('https://grocery-pos-backend-uoyv.onrender.com/api/products'));
    if (response.statusCode == 200) {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } else {
      throw Exception('Lỗi Server');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Báo Cáo & Nhập Hàng'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder<List<dynamic>>(
        future: _dataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError) return Center(child: Text('Lỗi: ${snapshot.error}'));
          if (!snapshot.hasData || snapshot.data!.isEmpty) return const Center(child: Text('Chưa có dữ liệu thống kê.'));

          List<dynamic> allProducts = snapshot.data!;

          // 1. Lọc TOP 5 BÁN CHẠY NHẤT (Sắp xếp theo soldCount giảm dần)
          allProducts.sort((a, b) => (b['soldCount'] ?? 0).compareTo(a['soldCount'] ?? 0));
          List<dynamic> top5Sold = allProducts.take(5).toList();

          // 2. Lọc CẢNH BÁO HẾT HÀNG (Tồn kho < 10)
          List<dynamic> lowStock = allProducts.where((p) => (p['stock'] ?? 0) < 10).toList();

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- PHẦN 1: BIỂU ĐỒ DOANH SỐ ---
                const Padding(
                  padding: EdgeInsets.all(15.0),
                  child: Text('🔥 Top 5 Bán Chạy Nhất', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.indigo)),
                ),
                Container(
                  height: 300,
                  padding: const EdgeInsets.symmetric(horizontal: 15),
                  child: top5Sold.isEmpty || (top5Sold[0]['soldCount'] ?? 0) == 0
                      ? const Center(child: Text('Chưa có dữ liệu bán hàng để vẽ biểu đồ.'))
                      : BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      maxY: ((top5Sold[0]['soldCount'] ?? 0) as int).toDouble() + 5, // Trục Y cao hơn top 1 một chút
                      barTouchData: BarTouchData(enabled: true),
                      titlesData: FlTitlesData(
                        show: true,
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (double value, TitleMeta meta) {
                              int index = value.toInt();
                              if (index >= 0 && index < top5Sold.length) {
                                // Chỉ lấy 10 chữ cái đầu của tên sản phẩm để biểu đồ không bị rối
                                String name = top5Sold[index]['name'];
                                String shortName = name.length > 10 ? '${name.substring(0, 8)}..' : name;
                                return Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: Text(shortName, style: const TextStyle(fontSize: 10)),
                                );
                              }
                              return const Text('');
                            },
                          ),
                        ),
                      ),
                      barGroups: top5Sold.asMap().entries.map((entry) {
                        int index = entry.key;
                        var item = entry.value;
                        int sold = item['soldCount'] ?? 0;
                        return BarChartGroupData(
                          x: index,
                          barRods: [
                            BarChartRodData(
                              toY: sold.toDouble(),
                              color: Colors.indigoAccent,
                              width: 20,
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(5)),
                            )
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ),

                const Divider(thickness: 2, height: 40),

                // --- PHẦN 2: CẢNH BÁO NHẬP HÀNG ---
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 15.0),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
                      const SizedBox(width: 10),
                      Text('Cần Nhập Hàng Gấp (${lowStock.length})', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red)),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                lowStock.isEmpty
                    ? const Padding(
                  padding: EdgeInsets.all(15.0),
                  child: Text('Kho đang đầy đủ, chưa cần nhập thêm!', style: TextStyle(color: Colors.green, fontSize: 16)),
                )
                    : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: lowStock.length,
                  itemBuilder: (context, index) {
                    final item = lowStock[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
                      child: ListTile(
                        leading: const Icon(Icons.inventory_2, color: Colors.orange),
                        title: Text(item['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('Đã bán: ${item['soldCount'] ?? 0} cái'),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text('Tồn kho', style: TextStyle(fontSize: 12)),
                            Text('${item['stock'] ?? 0}', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 18)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 30),
              ],
            ),
          );
        },
      ),
    );
  }
}