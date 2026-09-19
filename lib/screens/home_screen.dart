import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:animate_do/animate_do.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:async'; // NEW
import 'league_table_screen.dart';
import 'league_teams.dart';
import 'league_fixtures_screen.dart';
import 'about_league_screen.dart';
import 'login_screen.dart';

class HomeScreen extends StatefulWidget { // CHANGED TO STATEFUL
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final db = FirebaseFirestore.instance;
  final PageController _pageController = PageController(); // NEW
  Timer? _timer; // NEW
  Timer? _fixtureExpiryTimer;

  @override
  void initState() {
    super.initState();

    // Refresh the home screen periodically so a fixture is removed
    // automatically once 120 minutes have passed.
    _fixtureExpiryTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _fixtureExpiryTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _startAutoSlide(int itemCount) { // NEW
    _timer?.cancel();
    if(itemCount <= 1) return;
    _timer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if(_pageController.hasClients){
        int nextPage = _pageController.page!.round() + 1;
        if(nextPage >= itemCount) nextPage = 0;
        _pageController.animateToPage(nextPage,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('HIGHFIELDS ZONE LEAGUE', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1, color: Colors.white)),
        backgroundColor: const Color(0xFF1A237E),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      drawer: Drawer(
        child: Column(
          children: [
            UserAccountsDrawerHeader(
              decoration: const BoxDecoration(
                color: Color(0xFF1A237E),
                image: DecorationImage(
                  image: NetworkImage('https://picsum.photos/400/200'),
                  fit: BoxFit.cover,
                  opacity: 0.3,
                ),
              ),
              accountName: const Text('HZL 2026', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
              accountEmail: const Text('Harare Zone League', style: TextStyle(color: Colors.white)),
            ),
            _tile(context, 'Home', Icons.home, () => Navigator.pop(context)),
            _tile(context, 'Table', Icons.leaderboard, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LeagueTableScreen()))),
            _tile(context, 'Teams', Icons.groups, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LeagueTeams()))),
            _tile(context, 'Fixtures', Icons.calendar_today, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LeagueFixturesScreen()))),
            _tile(context, 'About', Icons.info, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AboutLeagueScreen()))),
            const Divider(),
            _tile(context, 'Admin', Icons.admin_panel_settings, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen()))),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // TOP 4 TABLE
          FadeInDown(
            child: _SectionHeader(title: 'League Table Top 4', icon: Icons.emoji_events),
          ),
          const SizedBox(height: 12),
          StreamBuilder(
            stream: db.collection('teams').orderBy('points', descending: true).limit(4).snapshots(),
            builder: (c, s) {
              if(s.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator()); // BETTER CHECK
              if(!s.hasData || s.data!.docs.isEmpty) {
                return const _EmptyStateCard(
                  icon: Icons.groups_outlined,
                  title: 'No teams yet',
                  message: 'League teams will appear here once they are added.',
                );
              }
              return Column(
                children: List.generate(s.data!.docs.length, (i) {
                  var d = s.data!.docs[i].data() as Map<String, dynamic>;
                  return FadeInRight(
                    delay: Duration(milliseconds: i * 150),
                    child: _Top4Card(data: d, position: i + 1),
                  );
                }),
              );
            }
          ),

          const SizedBox(height: 24),

          // UPCOMING FIXTURES - NOW CAROUSEL
          FadeInDown(
            child: _SectionHeader(title: 'Upcoming Fixtures', icon: Icons.schedule),
          ),
          const SizedBox(height: 12),
        
        StreamBuilder(
          stream: db.collection('fixtures').orderBy('date').snapshots(),
          builder: (c, s) {
            if(s.connectionState == ConnectionState.waiting) {
              return const SizedBox(
                height: 180,
                child: Center(child: CircularProgressIndicator()),
              );
            }

            if(!s.hasData || s.data!.docs.isEmpty) {
              WidgetsBinding.instance.addPostFrameCallback((_) => _startAutoSlide(0));
              return const _EmptyStateCard(
                icon: Icons.event_available_outlined,
                title: 'No upcoming fixtures',
                message: 'Fixtures will appear here when they are scheduled.',
              );
            }

            final now = DateTime.now();

            // A fixture remains visible until 120 minutes after its
            // scheduled date/time. After that it is removed from this card.
            final docs = s.data!.docs.where((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final rawDate = data['date'];

              if(rawDate is! Timestamp) return false;

              final fixtureDate = rawDate.toDate();
              final expiryTime = fixtureDate.add(const Duration(minutes: 120));

              return now.isBefore(expiryTime);
            }).toList();

            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (_pageController.hasClients && docs.isNotEmpty) {
                final currentPage = _pageController.page?.round() ?? 0;
                if (currentPage >= docs.length) {
                  _pageController.jumpToPage(0);
                }
              }
              _startAutoSlide(docs.length);
            });

            if(docs.isEmpty) {
              return const _EmptyStateCard(
                icon: Icons.event_available_outlined,
                title: 'No upcoming fixtures',
                message: 'There are no fixtures currently scheduled to be shown.',
              );
            }

            return FadeInUp(
              delay: const Duration(milliseconds: 1500),
              child: SizedBox(
                height: 200,
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: docs.length,
                  itemBuilder: (context, i) {
                    var d = docs[i];
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: _FixtureHomeCard(
                        data: d.data() as Map<String, dynamic>,
                        docId: d.id,
                      ),
                    );
                  },
                ),
              ),
            );
          }
        ),


          const SizedBox(height: 24),

          // TOP SCORERS
          FadeInDown(
            child: _SectionHeader(title: 'Top Scorers', icon: Icons.sports_soccer),
          ),
          const SizedBox(height: 12),
          StreamBuilder(
            stream: db.collection('players').orderBy('goals', descending: true).limit(5).snapshots(),
            builder: (c, s) {
              if(s.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator()); // BETTER CHECK
              if(!s.hasData || s.data!.docs.isEmpty) {
                return const _EmptyStateCard(
                  icon: Icons.sports_soccer_outlined,
                  title: 'No goals recorded yet',
                  message: 'Top scorers will appear here as goals are recorded.',
                );
              }
              return Card(
                elevation: 3,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Column(
                  children: List.generate(s.data!.docs.length, (i) {
                    var d = s.data!.docs[i].data() as Map<String, dynamic>;
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: const Color(0xFF3949AB).withOpacity(0.1),
                        backgroundImage: (d['faceUrl']?? '').toString().isNotEmpty? CachedNetworkImageProvider(d['faceUrl']) : null,
                        child: (d['faceUrl']?? '').toString().isEmpty? Text('${i+1}', style: TextStyle(color: const Color(0xFF1A237E))) : null,
                      ),
                      title: Text(d['name']?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('Goals: ${d['goals']?? 0}'),
                      trailing: Chip(
                        label: Text('${d['goals']?? 0} ⚽'),
                        backgroundColor: Colors.orange.withOpacity(0.1),
                        labelStyle: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold),
                      ),
                    );
                  }),
                ),
              );
            }
          ),
        ]),
      ),
    );
  }

  ListTile _tile(BuildContext c, String t, IconData i, VoidCallback v) =>
    ListTile(leading: Icon(i, color: const Color(0xFF1A237E)), title: Text(t, style: const TextStyle(color: Colors.black)), onTap: v);
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
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: LinearGradient(
            colors: [
              const Color(0xFF1A237E).withOpacity(0.08),
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
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF1A237E).withOpacity(0.10),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 34,
                color: const Color(0xFF1A237E),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A237E),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[600],
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  const _SectionHeader({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF1A237E)),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1A237E))),
      ],
    );
  }
}

class _Top4Card extends StatelessWidget {
  final Map<String, dynamic> data;
  final int position;
  const _Top4Card({required this.data, required this.position});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: position <= 4? Colors.green : Colors.grey,
          child: Text('$position', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
        title: Text(data['name']?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
        trailing: Text('${data['points']?? 0} pts', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      ),
    );
  }
}

class _FixtureHomeCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final String docId;
  const _FixtureHomeCard({required this.data, required this.docId});

  Future<Map<String, Map<String, String>>> _getTeamData() async {
    final home = await FirebaseFirestore.instance.collection('teams').doc(data['homeTeamId']).get();
    final away = await FirebaseFirestore.instance.collection('teams').doc(data['awayTeamId']).get();
    return {
      'home': {'name': home.data()?['name']?? '', 'logoUrl': home.data()?['logoUrl']?? ''},
      'away': {'name': away.data()?['name']?? '', 'logoUrl': away.data()?['logoUrl']?? ''},
    };
  }

  @override
  Widget build(BuildContext context) {
    final date = (data['date'] as Timestamp).toDate();
    return FutureBuilder(
      future: _getTeamData(),
      builder: (context, snap) {
        final home = snap.data?['home']?? {'name': 'Loading...', 'logoUrl': ''};
        final away = snap.data?['away']?? {'name': 'Loading...', 'logoUrl': ''};

        return Card(
          elevation: 4, // SLIGHTLY HIGHER FOR CAROUSEL
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(child: _TeamLogoName(data: home)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(color: Colors.orange, borderRadius: BorderRadius.circular(8)),
                      child: const Text('VS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                    Expanded(child: _TeamLogoName(data: away, alignEnd: true)),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(children: [const Icon(Icons.location_on, size: 14), const SizedBox(width: 4), Text(data['venue']?? 'TBA', style: const TextStyle(fontSize: 12))]),
                    Row(children: [const Icon(Icons.calendar_today, size: 14), const SizedBox(width: 4), Text(DateFormat.yMMMd().add_jm().format(date), style: const TextStyle(fontSize: 12))]),
                  ],
                )
              ],
            ),
          ),
        );
      }
    );
  }
}

class _TeamLogoName extends StatelessWidget {
  final Map<String, String> data;
  final bool alignEnd;
  const _TeamLogoName({required this.data, this.alignEnd = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: alignEnd? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 20,
          backgroundColor: Colors.grey[200],
          backgroundImage: data['logoUrl']!.isNotEmpty? CachedNetworkImageProvider(data['logoUrl']!) : null,
          child: data['logoUrl']!.isEmpty? const Icon(Icons.shield, size: 20) : null,
        ),
        const SizedBox(height: 4),
        Text(data['name']!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
      ],
    );
  }
}
