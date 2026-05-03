import 'package:flutter/material.dart';

class StatsScreen extends StatelessWidget {
  final Map<String, dynamic> status;

  const StatsScreen({super.key, required this.status});

  Widget _buildRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(fontSize: 16, color: Colors.grey)),
          Text(value,
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF4CAF50)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('System Stats',
            style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(icon: const Icon(Icons.notifications_outlined), onPressed: () {}),
          IconButton(icon: const Icon(Icons.menu), onPressed: () {}),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  _buildRow('System :', status['system'] ? 'Active' : 'Inactive'),
                  const Divider(),
                  _buildRow('Gas Status :',
                      status['gasDetected'] ? 'Gas detected' : 'Normal'),
                  const Divider(),
                  _buildRow('Temperature :',
                      '${status['temperature']} C'),
                  const Divider(),
                  _buildRow('LED s :', status['led2'] ? 'ON' : 'OFF'),
                  const Divider(),
                  _buildRow('Humidity :', '${status['humidity']}%'),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4CAF50),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                ),
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.refresh, color: Colors.white),
                label: const Text('Refresh',
                    style: TextStyle(color: Colors.white, fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}