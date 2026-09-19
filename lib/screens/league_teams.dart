import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'team_detail_screen.dart';

class LeagueTeams extends StatelessWidget {
  const LeagueTeams({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Teams'),
        backgroundColor: const Color(0xFF1A237E),
        elevation: 0,
      ),
      body: StreamBuilder(
        stream: FirebaseFirestore.instance.collection('teams').orderBy('points', descending: true).snapshots(),
        builder: (context, snap) {
          if(!snap.hasData) return const Center(child: CircularProgressIndicator());
          if(snap.data!.docs.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: _EmptyStateCard(
                  icon: Icons.groups_outlined,
                  title: 'No teams yet',
                  message: 'Teams will appear here once they are added to the league.',
                ),
              ),
            );
          }

          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 0.85,
            ),
            itemCount: snap.data!.docs.length,
            itemBuilder: (context, i) {
              var d = snap.data!.docs[i];
              var data = d.data() as Map<String, dynamic>;
              return _TeamCard(teamId: d.id, data: data);
            }
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

class _TeamCard extends StatelessWidget {
  final String teamId;
  final Map<String, dynamic> data;
  const _TeamCard({required this.teamId, required this.data});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TeamDetailScreen(teamId: teamId))),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // LOGO
              CircleAvatar(
                radius: 40,
                backgroundColor: Colors.grey[100],
                child: ClipOval(
                  child: CachedNetworkImage(
                    imageUrl: data['logoUrl']?? '',
                    height: 80, width: 80, fit: BoxFit.cover,
                    placeholder: (_,__)=> const CircularProgressIndicator(),
                    errorWidget: (_,__,___)=> const Icon(Icons.shield, size: 40, color: Color(0xFF3949AB)),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(data['name']?? 'Team',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                textAlign: TextAlign.center,
                maxLines: 2, overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              Text('Pts: ${data['points']?? 0}', style: TextStyle(color: Colors.grey[600], fontSize: 12)),

              const Spacer(),

              // TOP 3 PLAYERS FACES FROM BUCKET
              StreamBuilder(
                stream: FirebaseFirestore.instance.collection('players').where('teamId', isEqualTo: teamId).limit(3).snapshots(),
                builder: (context, pSnap) {
                  if(!pSnap.hasData) return const SizedBox(height: 24);
                  final players = pSnap.data!.docs;
                  return SizedBox(
                    height: 24,
                    child: Stack(
                      children: List.generate(players.length, (i) {
                        var p = players[i].data();
                        return Positioned(
                          left: i * 18,
                          child: CircleAvatar(
                            radius: 12,
                            backgroundColor: Colors.white,
                            child: CircleAvatar(
                              radius: 10,
                              backgroundImage: (p['faceUrl']?? '').isNotEmpty
                                 ? CachedNetworkImageProvider(p['faceUrl'])
                                  : null,
                              child: (p['faceUrl']?? '').isEmpty? Text('${p['jersey']}', style: const TextStyle(fontSize: 8)) : null,
                            ),
                          ),
                        );
                      }),
                    ),
                  );
                }
              )
            ],
          ),
        ),
      ),
    );
  }
}
