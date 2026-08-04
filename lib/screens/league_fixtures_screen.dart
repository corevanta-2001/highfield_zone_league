import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class LeagueFixturesScreen extends StatefulWidget { // CHANGED TO STATEFUL FOR SEARCH
  const LeagueFixturesScreen({super.key});

  @override
  State<LeagueFixturesScreen> createState() => _LeagueFixturesScreenState();
}

class _LeagueFixturesScreenState extends State<LeagueFixturesScreen> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('HZL 2026', style: TextStyle(color: Colors.white)),
          backgroundColor: const Color(0xFF1A237E),
          iconTheme: const IconThemeData(color: Colors.white),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(110),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: TextField( // NEW SEARCH BAR
                    decoration: InputDecoration(
                      hintText: 'Search Team...',
                      prefixIcon: const Icon(Icons.search, color: Colors.white70),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.15),
                      hintStyle: const TextStyle(color: Colors.white70),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                    style: const TextStyle(color: Colors.white),
                    onChanged: (val) => setState(()=> _search = val.toLowerCase()),
                  ),
                ),
                const TabBar(
                  indicatorColor: Colors.white,
                  indicatorWeight: 3,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white70,
                  tabs: [
                    Tab(icon: Icon(Icons.schedule), text: 'Fixtures'),
                    Tab(icon: Icon(Icons.check_circle), text: 'Results'),
                    Tab(icon: Icon(Icons.leaderboard), text: 'Table'),
                  ]
                ),
              ],
            ),
          )
        ),
        body: TabBarView(children: [
          _buildList('Scheduled'),
          _buildList('Completed'),
          const _LeagueTable(),
        ]),
      )
    );
  }

  Widget _buildList(String status) {
    return StreamBuilder(
      stream: FirebaseFirestore.instance.collection('fixtures').orderBy('date').snapshots(),
      builder: (context, snap) {
        if(snap.hasError) return Center(child: Text('Error: ${snap.error}'));
        if(!snap.hasData) return const Center(child: CircularProgressIndicator());

        var allDocs = snap.data!.docs;
        // FILTER BY STATUS + SEARCH
        var filteredDocs = allDocs.where((d) {
          bool matchStatus = d['status'] == status;
          bool matchSearch = d['homeTeamName'].toString().toLowerCase().contains(_search) ||
                             d['awayTeamName'].toString().toLowerCase().contains(_search);
          return matchStatus && (_search.isEmpty || matchSearch);
        }).toList();

        if(filteredDocs.isEmpty) return Center(child: Text('No $status matches', style: TextStyle(color: Colors.grey)));

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: filteredDocs.length,
          itemBuilder: (context, i) {
            var d = filteredDocs[i];
            return _FixtureCard(data: d.data(), docId: d.id, status: status);
          }
        );
      }
    );
  }
}

class _FixtureCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final String docId;
  final String status;
  const _FixtureCard({required this.data, required this.docId, required this.status});

  Future<Map<String, dynamic>> _getTeamData(String id) async {
    final doc = await FirebaseFirestore.instance.collection('teams').doc(id).get();
    return doc.data()?? {'name': 'Team $id', 'logoUrl': ''};
  }

  // NEW: FETCH PLAYER NAMES
  Future<Map<String, String>> _getPlayerNames(List scorers) async {
    Map<String, String> names = {};
    for(var s in scorers){
      var doc = await FirebaseFirestore.instance.collection('players').doc(s['playerId']).get();
      names[s['playerId']] = doc.data()?['name']?? 'Unknown';
    }
    return names;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: Future.wait([
        _getTeamData(data['homeTeamId']),
        _getTeamData(data['awayTeamId'])
      ]),
      builder: (context, AsyncSnapshot<List<Map<String, dynamic>>> teamSnap) {
        if(!teamSnap.hasData) return const Card(child: ListTile(title: Text('Loading...')));

        final home = teamSnap.data![0];
        final away = teamSnap.data![1];
        final date = (data['date'] as Timestamp).toDate();

        return Card(
          elevation: 4,
          margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.all(18),
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: _TeamColumn(data: home, isHome: true)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: status == 'Completed'? const Color(0xFF3949AB) : Colors.orange,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    status == 'Completed'? '${data['homeGoals']} - ${data['awayGoals']}' : 'VS',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ),
                Expanded(child: _TeamColumn(data: away, isHome: false)),
              ],
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Wrap(
                spacing: 12, runSpacing: 6, alignment: WrapAlignment.center,
                children: [
                  _InfoChip(icon: Icons.location_on, label: data['venue']?? 'TBA'),
                  _InfoChip(icon: Icons.person, label: 'Ref: ${data['referee']?? 'TBA'}'),
                  _InfoChip(icon: Icons.calendar_today, label: DateFormat.yMMMd().add_jm().format(date)),
                ],
              ),
            ),
            children: [
              if(status == 'Completed')...[
                const Divider(),
                FutureBuilder( // FETCH NAMES HERE
                  future: Future.wait([
                    _getPlayerNames(List.from(data['homeScorers']?? [])),
                    _getPlayerNames(List.from(data['awayScorers']?? [])),
                  ]),
                  builder: (context, AsyncSnapshot<List<Map<String, String>>> snap){
                    if(!snap.hasData) return const Padding(padding: EdgeInsets.all(12), child: Center(child: CircularProgressIndicator()));
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: _ScorersList(
                            scorers: List.from(data['homeScorers']?? []),
                            names: snap.data![0]
                          )),
                          const SizedBox(width: 20),
                          Expanded(child: _ScorersList(
                            scorers: List.from(data['awayScorers']?? []),
                            names: snap.data![1]
                          )),
                        ],
                      ),
                    );
                  }
                )
              ]
            ],
          ),
        );
      }
    );
  }
}

class _TeamColumn extends StatelessWidget {
  final Map<String, dynamic> data;
  final bool isHome;
  const _TeamColumn({required this.data, required this.isHome});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: isHome? CrossAxisAlignment.start : CrossAxisAlignment.end,
      children: [
        CircleAvatar(
          radius: 24,
          backgroundColor: Colors.grey[200],
          backgroundImage: (data['logoUrl']?? '').isNotEmpty? NetworkImage(data['logoUrl']) : null,
          child: (data['logoUrl']?? '').isEmpty? const Icon(Icons.shield, color: Color(0xFF3949AB)) : null,
        ),
        const SizedBox(height: 6),
        Text(data['name']?? '',
          textAlign: isHome? TextAlign.left : TextAlign.right,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          maxLines: 2, overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

class _ScorersList extends StatelessWidget {
  final List scorers;
  final Map<String, String> names; // NEW
  const _ScorersList({required this.scorers, required this.names});

  @override
  Widget build(BuildContext context) {
    if(scorers.isEmpty) return const Text('No goals', style: TextStyle(color: Colors.grey));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: scorers.map((s) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text('⚽ ${names[s['playerId']]?? 'Unknown'} ${s['goals'] > 1? '(${s['goals']})' : ''}', style: const TextStyle(fontSize: 13)), // FIXED
      )).toList(),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.grey[600]),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[700])),
      ],
    );
  }
}

// NEW: LEAGUE TABLE TAB
class _LeagueTable extends StatelessWidget {
  const _LeagueTable();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: FirebaseFirestore.instance.collection('teams').orderBy('points', descending: true).snapshots(),
      builder: (context, snap) {
        if(!snap.hasData) return const Center(child: CircularProgressIndicator());
        final teams = snap.data!.docs;
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columnSpacing: 20,
            columns: const [
              DataColumn(label: Text('#')),
              DataColumn(label: Text('Team')),
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
              final t = teams[i].data();
              return DataRow(cells: [
                DataCell(Text('${i+1}')),
                DataCell(Row(children: [
                  CircleAvatar(radius: 12, backgroundImage: (t['logoUrl']?? '').isNotEmpty? NetworkImage(t['logoUrl']) : null, child: (t['logoUrl']?? '').isEmpty? const Icon(Icons.shield, size: 14) : null),
                  const SizedBox(width: 8),
                  Text(t['name']?? '')
                ])),
                DataCell(Text('${t['played']?? 0}')),
                DataCell(Text('${t['won']?? 0}')),
                DataCell(Text('${t['drawn']?? 0}')),
                DataCell(Text('${t['lost']?? 0}')),
                DataCell(Text('${t['gf']?? 0}')),
                DataCell(Text('${t['ga']?? 0}')),
                DataCell(Text('${t['gd']?? 0}')),
                DataCell(Text('${t['points']?? 0}', style: const TextStyle(fontWeight: FontWeight.bold))),
              ]);
            }),
          ),
        );
      }
    );
  }
}