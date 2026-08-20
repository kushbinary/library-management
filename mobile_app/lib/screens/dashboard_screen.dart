import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:ui';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Force a deep navy background for the dashboard to match the strict dark mode aesthetic
    final bgGradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [const Color(0xFF0F172A), const Color(0xFF1E1B4B)],
    );

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Container(
        decoration: BoxDecoration(gradient: bgGradient),
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTopAppBar(),
                const SizedBox(height: 30),
                _buildGreetingSection(),
                const SizedBox(height: 24),
                _buildMetricsRow(),
                const SizedBox(height: 28),
                _buildMainAnalyticsChart(),
                const SizedBox(height: 28),
                _buildListView(),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopAppBar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'LibroHub',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
              ),
            ),
            Text(
              'Library Dashboard',
              style: TextStyle(
                color: Colors.grey.shade400,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        Row(
          children: [
            Stack(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                  ),
                  child: const Icon(Icons.notifications_none_rounded, color: Colors.white, size: 22),
                ),
                Positioned(
                  right: 10,
                  top: 10,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.redAccent,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 14),
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF818CF8), width: 2),
                image: const DecorationImage(
                  image: NetworkImage('https://i.pravatar.cc/150?u=sarah'),
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildGreetingSection() {
    return const Text(
      'Welcome back, Admin Sarah!',
      style: TextStyle(
        color: Colors.white,
        fontSize: 22,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildMetricsRow() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      clipBehavior: Clip.none,
      child: Row(
        children: [
          _buildMetricCard(
            title: 'Total Income',
            value: '₹14,850',
            trend: '+3.2% this month',
            isPositive: true,
            icon: Icons.account_balance_wallet_rounded,
            iconColor: Colors.amber,
            chartData: [2, 3, 2, 4, 3, 5, 4, 6],
            chartColor: Colors.white,
            isBarChart: false,
          ),
          const SizedBox(width: 16),
          _buildMetricCard(
            title: 'Active Members',
            value: '2,315',
            trend: '+1.8% this week',
            isPositive: true,
            icon: Icons.people_alt_rounded,
            iconColor: const Color(0xFF818CF8),
            chartData: [5, 4, 6, 5, 7, 6, 8, 9],
            chartColor: const Color(0xFF818CF8),
            isBarChart: false,
          ),
          const SizedBox(width: 16),
          _buildMetricCard(
            title: 'Recent Returns',
            value: '84',
            trend: '-0.5% today',
            isPositive: false,
            icon: Icons.assignment_return_rounded,
            iconColor: Colors.redAccent,
            chartData: [8, 7, 5, 6, 4, 5, 3],
            chartColor: Colors.white,
            isBarChart: true,
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String trend,
    required bool isPositive,
    required IconData icon,
    required Color iconColor,
    required List<double> chartData,
    required Color chartColor,
    required bool isBarChart,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          width: 180,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: iconColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: iconColor, size: 20),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(title, style: TextStyle(color: Colors.grey.shade400, fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(value, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(isPositive ? Icons.trending_up : Icons.trending_down,
                      color: isPositive ? Colors.greenAccent : Colors.redAccent, size: 14),
                  const SizedBox(width: 4),
                  Text(trend, style: TextStyle(color: isPositive ? Colors.greenAccent : Colors.redAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 40,
                width: double.infinity,
                child: isBarChart ? _buildMiniBarChart(chartData, chartColor) : _buildMiniLineChart(chartData, chartColor),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMiniLineChart(List<double> data, Color color) {
    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: false),
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: data.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value)).toList(),
            isCurved: true,
            color: color,
            barWidth: 2.5,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [color.withValues(alpha: 0.3), Colors.transparent],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniBarChart(List<double> data, Color color) {
    return BarChart(
      BarChartData(
        gridData: const FlGridData(show: false),
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        barGroups: data.asMap().entries.map((e) {
          return BarChartGroupData(
            x: e.key,
            barRods: [
              BarChartRodData(
                toY: e.value,
                color: color.withValues(alpha: 0.8),
                width: 6,
                borderRadius: BorderRadius.circular(2),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMainAnalyticsChart() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Circulation Overview', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  Text('(Last 30 Days)', style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 180,
                child: LineChart(
                  LineChartData(
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      horizontalInterval: 10,
                      getDrawingHorizontalLine: (value) => FlLine(color: Colors.white.withValues(alpha: 0.05), strokeWidth: 1),
                    ),
                    titlesData: FlTitlesData(
                      show: true,
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 22,
                          interval: 1,
                          getTitlesWidget: (value, meta) {
                            const style = TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 10);
                            String text = '';
                            switch (value.toInt()) {
                              case 0: text = 'Week 1'; break;
                              case 2: text = 'Week 2'; break;
                              case 4: text = 'Week 3'; break;
                              case 6: text = 'Week 4'; break;
                            }
                            return SideTitleWidget(meta: meta, space: 6, child: Text(text, style: style));
                          },
                        ),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          interval: 20,
                          reservedSize: 28,
                          getTitlesWidget: (value, meta) {
                            return Text(value.toInt().toString(), style: const TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold));
                          },
                        ),
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    minX: 0,
                    maxX: 6,
                    minY: 0,
                    maxY: 60,
                    lineBarsData: [
                      LineChartBarData(
                        spots: const [FlSpot(0, 10), FlSpot(1, 24), FlSpot(2, 18), FlSpot(3, 40), FlSpot(4, 32), FlSpot(5, 50), FlSpot(6, 42)],
                        isCurved: true,
                        color: Colors.white,
                        barWidth: 3,
                        isStrokeCapRound: true,
                        dotData: const FlDotData(show: false),
                        belowBarData: BarAreaData(
                          show: true,
                          gradient: LinearGradient(
                            colors: [Colors.white.withValues(alpha: 0.2), Colors.transparent],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ),
                      LineChartBarData(
                        spots: const [FlSpot(0, 20), FlSpot(1, 15), FlSpot(2, 35), FlSpot(3, 28), FlSpot(4, 45), FlSpot(5, 38), FlSpot(6, 55)],
                        isCurved: true,
                        color: const Color(0xFF818CF8),
                        barWidth: 3,
                        isStrokeCapRound: true,
                        dotData: const FlDotData(show: false),
                        belowBarData: BarAreaData(
                          show: true,
                          gradient: LinearGradient(
                            colors: [const Color(0xFF818CF8).withValues(alpha: 0.2), Colors.transparent],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildLegend(Colors.white, 'Issues'),
                  const SizedBox(width: 24),
                  _buildLegend(const Color(0xFF818CF8), 'Returns'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLegend(Color color, String text) {
    return Row(
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
        const SizedBox(width: 6),
        Text(text, style: TextStyle(color: Colors.grey.shade400, fontSize: 12, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildListView() {
    final returns = [
      {'title': 'Dune', 'author': 'Frank Herbert', 'time': 'Today, 10:45 AM', 'img': 'https://covers.openlibrary.org/b/id/10419220-M.jpg'},
      {'title': '1984', 'author': 'George Orwell', 'time': 'Today, 09:15 AM', 'img': 'https://covers.openlibrary.org/b/id/153224-M.jpg'},
      {'title': 'The Hobbit', 'author': 'J.R.R. Tolkien', 'time': 'Yesterday, 04:30 PM', 'img': 'https://covers.openlibrary.org/b/id/8357493-M.jpg'},
    ];

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Recent Returns', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              ...returns.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.network(
                        item['img']!,
                        width: 48,
                        height: 48,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          width: 48,
                          height: 48,
                          color: const Color(0xFF334155),
                          child: const Icon(Icons.book, color: Colors.white),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item['title']!, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                          Text(item['author']!, style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(color: const Color(0xFF818CF8).withValues(alpha: 0.2), shape: BoxShape.circle),
                          child: const Icon(Icons.check, color: Color(0xFF818CF8), size: 14),
                        ),
                        const SizedBox(height: 4),
                        Text(item['time']!, style: TextStyle(color: Colors.grey.shade500, fontSize: 10)),
                      ],
                    ),
                  ],
                ),
              )).toList(),
            ],
          ),
        ),
      ),
    );
  }
}
