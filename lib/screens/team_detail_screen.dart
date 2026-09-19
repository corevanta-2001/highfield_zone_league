import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';

class TeamDetailScreen extends StatelessWidget {
  final String teamId;
  const TeamDetailScreen({super.key, required this.teamId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder(
        stream: FirebaseFirestore.instance.collection('teams').doc(teamId).snapshots(),
        builder: (context, teamSnap) {
          if(!teamSnap.hasData) return const Center(child: CircularProgressIndicator());
          var team = teamSnap.data!;
          var t = team.data() as Map<String, dynamic>;

          return CustomScrollView(
            slivers: [
              // HEADER WITH LOGO
              SliverAppBar(
                expandedHeight: 220,
                pinned: true,
                backgroundColor: const Color(0xFF1A237E),
                iconTheme: const IconThemeData(color: Colors.white), // WHITE BACK
                flexibleSpace: FlexibleSpaceBar(
                  title: Text(t['name']?? 'Team', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)), // WHITE TEXT
                  background: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF1A237E), Color(0xFF3949AB)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(height: 40),
                          CircleAvatar(
                            radius: 50,
                            backgroundColor: Colors.white,
                            child: CachedNetworkImage(
                              imageUrl: t['logoUrl']?? '',
                              height: 80,
                              placeholder: (c, u) => const CircularProgressIndicator(),
                              errorWidget: (c, u, e) => const Icon(Icons.shield, size: 50, color: Color(0xFF3949AB)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // STATS CARDS
                      Row(
                        children: [
                          Expanded(child: _StatCard(label: 'Played', value: '${t['played']?? 0}')),
                          Expanded(child: _StatCard(label: 'Points', value: '${t['points']?? 0}', color: const Color(0xFF3949AB))),
                          Expanded(child: _StatCard(label: 'GD', value: '${t['gd']?? 0}')),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: ListTile(
                          leading: CircleAvatar(backgroundColor: const Color(0xFF3949AB).withOpacity(0.1), child: const Icon(Icons.person, color: Color(0xFF3949AB))),
                          title: const Text('Manager'),
                          subtitle: Text(t['manager']?? 'TBA', style: const TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // SQUAD SECTION
                      _SectionTitle(title: 'Squad'),
                      StreamBuilder(
                        stream: FirebaseFirestore.instance.collection('players').where('teamId', isEqualTo: teamId).snapshots(),
                        builder: (c, pSnap) {
                          if(!pSnap.hasData) return const Center(child: CircularProgressIndicator());
                          if(pSnap.data!.docs.isEmpty) {
                            return const _EmptyStateCard(
                              icon: Icons.person_search_outlined,
                              title: 'No players yet',
                              message: 'Players will appear here once they are added to this squad.',
                            );
                          }
                          return ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: pSnap.data!.docs.length,
                            itemBuilder: (context, i) {
                              var p = pSnap.data!.docs[i].data();
                              return Card(
                                margin: const EdgeInsets.only(bottom: 10),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: Colors.grey[200],
                                    backgroundImage: (p['faceUrl']?? '').isNotEmpty? CachedNetworkImageProvider(p['faceUrl']) : null,
                                    child: (p['faceUrl']?? '').isEmpty? Text('${p['jersey']}') : null,
                                  ),
                                  title: Text(p['name']?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                                  subtitle: Text('${p['position']}'),
                                  trailing: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text('#${p['jersey']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                      Text('${p['goals']?? 0} ⚽', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                                    ],
                                  ),
                                ),
                              );
                            }
                          );
                        }
                      ),

                      const SizedBox(height: 20),

                      // FIXTURES SECTION - UPDATED TO SHOW ALL
                      _SectionTitle(title: 'Fixtures'),
                      _AllTeamFixtures(teamId: teamId), // NEW WIDGET
                    ],
                  ),
                ),
              )
            ],
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

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;
  const _StatCard({required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          children: [
            Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color?? Colors.black)),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1A237E))),
    );
  }
}

// NEW: SHOWS HOME + AWAY FIXTURES MERGED
class _AllTeamFixtures extends StatelessWidget {
  final String teamId;
  const _AllTeamFixtures({required this.teamId});

  @override
  Widget build(BuildContext context) {
    final db = FirebaseFirestore.instance;

    return StreamBuilder(
      stream: db.collection('fixtures').where('homeTeamId', isEqualTo: teamId).snapshots(),
      builder: (context, homeSnap) {
        if(!homeSnap.hasData) return const Center(child: CircularProgressIndicator());

        return StreamBuilder(
          stream: db.collection('fixtures').where('awayTeamId', isEqualTo: teamId).snapshots(),
          builder: (context, awaySnap) {
            if(!awaySnap.hasData) return const Center(child: CircularProgressIndicator());

            var allDocs = [...homeSnap.data!.docs,...awaySnap.data!.docs];
            // Sort by date in Dart
            allDocs.sort((a,b) => (a['date'] as Timestamp).compareTo(b['date'] as Timestamp));

            if(allDocs.isEmpty) {
              return const _EmptyStateCard(
                icon: Icons.event_available_outlined,
                title: 'No fixtures yet',
                message: 'This team has no fixtures available to display.',
              );
            }

            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: allDocs.length,
              itemBuilder: (context, i) {
                var d = allDocs[i].data();
                return _FixtureTile(data: d);
              }
            );
          }
        );
      }
    );
  }
}

class _FixtureTile extends StatelessWidget {
  final Map<String, dynamic> data;
  const _FixtureTile({required this.data});

  Future<Map<String, String>> _getTeamNames() async {
    final home = await FirebaseFirestore.instance.collection('teams').doc(data['homeTeamId']).get();
    final away = await FirebaseFirestore.instance.collection('teams').doc(data['awayTeamId']).get();
    return {
      'home': home.data()?['name']?? data['homeTeamId'],
      'away': away.data()?['name']?? data['awayTeamId'],
    };
  }

  @override
  Widget build(BuildContext context) {
    final date = data['date']!= null? DateFormat.yMMMd().add_jm().format((data['date'] as Timestamp).toDate()) : 'TBA';

    return FutureBuilder(
      future: _getTeamNames(),
      builder: (context, snap) {
        final homeName = snap.data?['home']?? 'Loading...';
        final awayName = snap.data?['away']?? 'Loading...';
        final isCompleted = data['status'] == 'Completed';

        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: isCompleted? const Color(0xFF3949AB) : Colors.orange,
              child: Text(isCompleted? '${data['homeGoals']}-${data['awayGoals']}' : 'VS', style: const TextStyle(color: Colors.white, fontSize: 12)),
            ),
            title: Text('$homeName vs $awayName', style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('$date | ${data['venue']?? 'TBA'} | Leg ${data['leg']?? 1}'),
            trailing: Chip(
              label: Text(data['status']?? 'Scheduled'),
              backgroundColor: isCompleted? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
              labelStyle: TextStyle(color: isCompleted? Colors.green : Colors.orange),
            ),
          ),
        );
      }
    );
  }
}