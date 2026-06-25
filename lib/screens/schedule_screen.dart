import 'package:flutter/material.dart';
import '../theme.dart';

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CommutasColors.backgroundGray,
      appBar: AppBar(
        title: const Text('Route Schedules'),
        backgroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: CommutasColors.emeraldGreen,
          labelColor: CommutasColors.emeraldGreen,
          unselectedLabelColor: CommutasColors.primaryNavy.withOpacity(0.5),
          indicatorWeight: 3,
          tabs: const [
            Tab(text: 'Morning Sessions'),
            Tab(text: 'Evening Sessions'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildMorningSchedule(),
          _buildEveningSchedule(),
        ],
      ),
    );
  }

  Widget _buildMorningSchedule() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildScheduleCard(
          'Route 01',
          'Main Campus → PMA Road → Dhamtor Campus',
          '08:00 AM',
          '08:40 AM',
          '40 Minutes',
          isFirst: true,
        ),
        const SizedBox(height: 12),
        _buildScheduleCard(
          'Route 02',
          'Main Campus → Fawara Chowk → Dhamtor Campus',
          '08:00 AM',
          '08:40 AM',
          '40 Minutes',
        ),
        const SizedBox(height: 12),
        _buildScheduleCard(
          'Route 03',
          'Main Campus → Murree Road → Dhamtor Campus',
          '08:00 AM',
          '08:40 AM',
          '40 Minutes',
        ),
      ],
    );
  }

  Widget _buildEveningSchedule() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildScheduleCard(
          'Route 01',
          'Dhamtor Campus → PMA Road → Main Campus',
          '01:30 PM',
          '02:10 PM',
          '40 Minutes',
          isFirst: true,
        ),
        const SizedBox(height: 12),
        _buildScheduleCard(
          'Route 02',
          'Dhamtor Campus → Fawara Chowk → Main Campus',
          '04:30 PM',
          '05:10 PM',
          '40 Minutes',
        ),
      ],
    );
  }

  Widget _buildScheduleCard(String route, String path, String dep, String arr, String dur, {bool isFirst = false}) {
    return Container(
      decoration: CommutasShapes.cardDecoration.copyWith(
        border: Border.all(
          color: isFirst ? CommutasColors.emeraldGreen.withOpacity(0.5) : CommutasColors.lineBorder,
          width: isFirst ? 1.5 : 1,
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isFirst ? CommutasColors.lightGreenBg : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(CommutasShapes.borderRadius)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: CommutasColors.primaryNavy,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        route,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Icon(Icons.directions_bus_filled, color: CommutasColors.emeraldGreen, size: 18),
                  ],
                ),
                if (isFirst)
                  const Text('RECOMMENDED', style: TextStyle(color: CommutasColors.emeraldGreen, fontSize: 8, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const Divider(height: 1, color: CommutasColors.lineBorder),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(path, style: CommutasTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildTimeInfo('DEPARTURE', dep),
                    _buildTimeInfo('ARRIVAL', arr),
                    _buildTimeInfo('DURATION', dur),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeInfo(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: CommutasTextStyles.labelBold.copyWith(fontSize: 8, color: CommutasColors.slateMuted)),
        const SizedBox(height: 4),
        Text(value, style: CommutasTextStyles.labelBold.copyWith(fontSize: 12, color: CommutasColors.primaryNavy)),
      ],
    );
  }
}
