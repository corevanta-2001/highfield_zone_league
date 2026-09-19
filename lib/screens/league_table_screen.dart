import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';

class LeagueTableScreen extends StatelessWidget {
  const LeagueTableScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('League Table'),
        backgroundColor: const Color(0xFF1A237E),
        elevation: 2,
      ),
      body: StreamBuilder(
        stream: FirebaseFirestore.instance.collection('teams').orderBy('points', descending: true).snapshots(),
        builder: (context, snap) {
          if(!snap.hasData) return const Center(child: CircularProgressIndicator());
          var teams = snap.data!.docs;

          if(teams.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: _EmptyStateCard(
                  icon: Icons.leaderboard_outlined,
                  title: 'League table is empty',
                  message: 'The table will appear here when teams are added and results are recorded.',
                ),
              ),
            );
          }

          return Container(
            color: Colors.grey[50],
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: DataTable(
                    headingRowColor: MaterialStatePropertyAll(const Color(0xFF1A237E)),
                    headingTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    columnSpacing: 24,
                    dataRowMinHeight: 60,
                    dataRowMaxHeight: 60,
                    columns: const [
                      DataColumn(label: Text('Pos')),
                      DataColumn(label: Text('Club')),
                      DataColumn(label: Text('P'), numeric: true),
                      DataColumn(label: Text('W'), numeric: true),
                      DataColumn(label: Text('D'), numeric: true),
                      DataColumn(label: Text('L'), numeric: true),
                      DataColumn(label: Text('GF'), numeric: true),
                      DataColumn(label: Text('GA'), numeric: true),
                      DataColumn(label: Text('GD'), numeric: true),
                      DataColumn(label: Text('Pts'), numeric: true),
                    ],
                    rows: List.generate(teams.length, (i) {
                      var t = teams[i].data() as Map<String, dynamic>;

                      // UCL + Relegation colors
                      Color? rowColor;
                      if (i < 4) {
                        rowColor = Colors.green.withOpacity(0.08); // UCL
                      } else if (i >= teams.length - 4) {
                        rowColor = Colors.red.withOpacity(0.08); // Relegation
                      }

                      return DataRow(
                        color: MaterialStatePropertyAll(rowColor),
                        cells: [
                          DataCell(_PositionCell(pos: i + 1)),
                          DataCell(
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 16,
                                  backgroundColor: Colors.grey[200],
                                  backgroundImage: (t['logoUrl']?? '').isNotEmpty
                                   ? CachedNetworkImageProvider(t['logoUrl'])
                                    : null,
                                  child: (t['logoUrl']?? '').isEmpty
                                   ? const Icon(Icons.shield, size: 16, color: Color(0xFF3949AB))
                                    : null,
                                ),
                                const SizedBox(width: 12),
                                Text(t['name']?? 'Team', style: const TextStyle(fontWeight: FontWeight.bold)),
                              ],
                            )
                          ),
                          DataCell(Text('${t['played']?? 0}')),
                          DataCell(Text('${t['won']?? 0}')),
                          DataCell(Text('${t['drawn']?? 0}')),
                          DataCell(Text('${t['lost']?? 0}')),
                          DataCell(Text('${t['gf']?? 0}')),
                          DataCell(Text('${t['ga']?? 0}')),
                          DataCell(Text('${t['gd']?? 0}', style: TextStyle(color: (t['gd']?? 0) >= 0? Colors.green : Colors.red, fontWeight: FontWeight.bold))),
                          DataCell(Text('${t['points']?? 0}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
                        ],
                      );
                    }),
                  ),
                ),
              ),
            ),
          );
        }
      ),
    );
  }
}

class _EmptyStateCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _EmptyStateCard({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: LinearGradient(
            colors: [
              const Color(0xFF1A237E).withOpacity(0.09),
              Colors.white,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: const Color(0xFF1A237E).withOpacity(0.10),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 38, color: const Color(0xFF1A237E)),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A237E),
              ),
            ),
            const SizedBox(height: 7),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PositionCell extends StatelessWidget {
  final int pos;
  const _PositionCell({required this.pos});

  @override
  Widget build(BuildContext context) {
    Color bg = Colors.grey;
    if (pos <= 4) bg = Colors.blue; // UCL
    if (pos >= 17) bg = Colors.red; // Relegation - assuming 20 teams

    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: bg.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Center(
        child: Text('$pos', style: TextStyle(fontWeight: FontWeight.bold, color: bg)),
      ),
    );
  }
}