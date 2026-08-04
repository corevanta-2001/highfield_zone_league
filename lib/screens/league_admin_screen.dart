import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:math';

class LeagueAdminScreen extends StatefulWidget {
  const LeagueAdminScreen({super.key});
  @override
  State<LeagueAdminScreen> createState() => _LeagueAdminScreenState();
}

class _LeagueAdminScreenState extends State<LeagueAdminScreen> with SingleTickerProviderStateMixin {
  final db = FirebaseFirestore.instance;
  final supabase = Supabase.instance.client;
  late TabController _tab;
  final _picker = ImagePicker();
  final _primary = const Color(0xFF1A237E); // Deep Blue
  final _accent = const Color(0xFF3949AB); // Royal Blue

  String _playerSearch = '';
  String _fixtureSearch = '';

  @override
  void initState() { super.initState(); _tab = TabController(length: 3, vsync: this); }

  // 0. RESET LEAGUE STATS - NEW
  Future<void> _resetLeague() async {
    bool confirm = await showDialog(context: context, builder: (_) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Reset Entire League?'),
      content: const Text('This will set all team stats and player goals to 0. This cannot be undone'),
      actions: [
        TextButton(onPressed: ()=>Navigator.pop(context, false), child: Text('Cancel', style: TextStyle(color: _primary))),
        TextButton(onPressed: ()=>Navigator.pop(context, true), child: const Text('Reset', style: TextStyle(color: Colors.orange))),
      ],
    ))?? false;
    if(!confirm) return;

    var batch = db.batch();

    // Reset Teams
    var teamsSnap = await db.collection('teams').get();
    for(var doc in teamsSnap.docs){
      batch.update(doc.reference, {
        'played':0,'won':0,'drawn':0,'lost':0,'gf':0,'ga':0,'gd':0,'points':0
      });
    }

    // Reset Players
    var playersSnap = await db.collection('players').get();
    for(var doc in playersSnap.docs){
      batch.update(doc.reference, {'goals':0});
    }

    await batch.commit();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('League Reset Complete'), backgroundColor: _primary));
  }

  // 1. DELETE ALL FIXTURES
  Future<void> _deleteAllFixtures() async {
    bool confirm = await showDialog(context: context, builder: (_) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Delete ALL Fixtures?'),
      content: const Text('This cannot be undone'),
      actions: [
        TextButton(onPressed: ()=>Navigator.pop(context, false), child: Text('Cancel', style: TextStyle(color: _primary))),
        TextButton(onPressed: ()=>Navigator.pop(context, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
      ],
    ))?? false;
    if(!confirm) return;
    var batch = db.batch();
    var snap = await db.collection('fixtures').get();
    for(var doc in snap.docs) batch.delete(doc.reference);
    await batch.commit();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('All Fixtures Deleted'), backgroundColor: _primary));
  }

  // 2. DOUBLE ROUND ROBIN FIXTURES - HOME AND AWAY
  Future<void> _generateFixtures() async {
    var teamsSnap = await db.collection('teams').get();
    var teams = teamsSnap.docs;
    if(teams.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('Add at least 2 teams'), backgroundColor: Colors.red));
      return;
    }

    List teamsList = List.from(teams);
    if(teamsList.length % 2!= 0) teamsList.add(null);

    int rounds = teamsList.length - 1;
    int matchesPerRound = teamsList.length ~/ 2;
    DateTime startDate = DateTime.now().add(const Duration(days: 7));

    // LEG 1
    for(int round = 0; round < rounds; round++) {
      for(int match = 0; match < matchesPerRound; match++) {
        var home = teamsList[match];
        var away = teamsList[rounds - match];
        if(home!= null && away!= null) {
          await db.collection('fixtures').add({
            'homeTeamId': home.id, 'awayTeamId': away.id,
            'homeTeamName': home['name'], 'awayTeamName': away['name'],
            'date': Timestamp.fromDate(startDate.add(Duration(days: round * 7))),
            'venue': 'TBD', 'referee': 'TBD', 'status': 'Scheduled',
            'homeGoals': 0, 'awayGoals': 0, 'isResultSaved': false,
            'homeScorers': [], 'awayScorers': [], 'leg': 1
          });
        }
      }
      teamsList.insert(1, teamsList.removeLast());
    }

    // LEG 2 - SWAP HOME AND AWAY
    teamsList = List.from(teams);
    if(teamsList.length % 2!= 0) teamsList.add(null);
    DateTime leg2Start = startDate.add(Duration(days: rounds * 7 + 7));

    for(int round = 0; round < rounds; round++) {
      for(int match = 0; match < matchesPerRound; match++) {
        var away = teamsList[match];
        var home = teamsList[rounds - match];
        if(home!= null && away!= null) {
          await db.collection('fixtures').add({
            'homeTeamId': home.id, 'awayTeamId': away.id,
            'homeTeamName': home['name'], 'awayTeamName': away['name'],
            'date': Timestamp.fromDate(leg2Start.add(Duration(days: round * 7))),
            'venue': 'TBD', 'referee': 'TBD', 'status': 'Scheduled',
            'homeGoals': 0, 'awayGoals': 0, 'isResultSaved': false,
            'homeScorers': [], 'awayScorers': [], 'leg': 2
          });
        }
      }
      teamsList.insert(1, teamsList.removeLast());
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('Double Round Robin Fixtures Generated'), backgroundColor: _primary));
  }

  // 3. UPDATE STATS + TABLE + PLAYER GOALS - ONLY ONCE
  Future<void> _updateStats(String fixtureId, String homeId, String awayId, int hg, int ag, List homeScorers, List awayScorers) async {
    var fixtureRef = db.collection('fixtures').doc(fixtureId);
    var fixtureSnap = await fixtureRef.get();
    if(fixtureSnap['isResultSaved'] == true) return;

    var batch = db.batch();
    var homeRef = db.collection('teams').doc(homeId);
    var awayRef = db.collection('teams').doc(awayId);

    var homeSnap = await homeRef.get();
    var awaySnap = await awayRef.get();
    if(!homeSnap.exists ||!awaySnap.exists) return;
    var home = homeSnap.data()!;
    var away = awaySnap.data()!;
    int hPts = hg>ag?3:(hg==ag?1:0); int aPts = ag>hg?3:(hg==ag?1:0);

    batch.update(homeRef, {'played':home['played']+1,'gf':home['gf']+hg,'ga':home['ga']+ag,'gd':(home['gf']+hg)-(home['ga']+ag),'points':home['points']+hPts,'won':home['won']+(hg>ag?1:0),'drawn':home['drawn']+(hg==ag?1:0),'lost':home['lost']+(hg<ag?1:0)});
    batch.update(awayRef, {'played':away['played']+1,'gf':away['gf']+ag,'ga':away['ga']+hg,'gd':(away['gf']+ag)-(away['ga']+hg),'points':away['points']+aPts,'won':away['won']+(ag>hg?1:0),'drawn':away['drawn']+(hg==ag?1:0),'lost':away['lost']+(ag<hg?1:0)});

    // UPDATE PLAYER GOALS
    for(var scorer in homeScorers) {
      var playerRef = db.collection('players').doc(scorer['playerId']);
      batch.update(playerRef, {'goals': FieldValue.increment(scorer['goals'])});
    }
    for(var scorer in awayScorers) {
      var playerRef = db.collection('players').doc(scorer['playerId']);
      batch.update(playerRef, {'goals': FieldValue.increment(scorer['goals'])});
    }

    batch.update(fixtureRef, {'isResultSaved': true});
    await batch.commit();
  }

  Future<String?> _uploadImage(String bucket) async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if(image == null) return null;
    final bytes = await image.readAsBytes();
    final fileExt = image.name.split('.').last;
    final fileName = '${DateTime.now().millisecondsSinceEpoch}.$fileExt';
    await supabase.storage.from(bucket).uploadBinary(fileName, bytes);
    return supabase.storage.from(bucket).getPublicUrl(fileName);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: _primary,
        elevation: 0,
        title: const Text('HZL Admin', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1, color: Colors.white)),
        bottom: TabBar(controller: _tab, indicatorColor: Colors.white, indicatorWeight: 3, labelStyle: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white), labelColor: Colors.white, unselectedLabelColor: Colors.white70, tabs: const [
          Tab(icon: Icon(Icons.shield, color: Colors.white), text: 'Teams'),
          Tab(icon: Icon(Icons.person, color: Colors.white), text: 'Players'),
          Tab(icon: Icon(Icons.calendar_today, color: Colors.white), text: 'Fixtures')
        ]),
      ),
      body: TabBarView(controller: _tab, children: [_teamsTab(), _playersTab(), _fixturesTab()]),
    );
  }

  Widget _teamsTab() => StreamBuilder<QuerySnapshot>(
    stream: db.collection('teams').orderBy('points', descending: true).snapshots(),
    builder: (context, snap) => Column(children: [
      Container(
        color: Colors.white,
        padding: const EdgeInsets.all(12.0),
        child: Wrap(spacing: 10, runSpacing: 10, children: [
          ElevatedButton.icon(icon: const Icon(Icons.add), style: ElevatedButton.styleFrom(backgroundColor: _accent, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))), onPressed: _addTeamDialog, label: const Text('Add Team')),
          ElevatedButton.icon(icon: const Icon(Icons.auto_awesome), style: ElevatedButton.styleFrom(backgroundColor: _accent, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))), onPressed: _generateFixtures, label: const Text('Generate Fixtures')),
          ElevatedButton.icon(icon: const Icon(Icons.restart_alt), style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))), onPressed: _resetLeague, label: const Text('Reset League')), // NEW BUTTON
          ElevatedButton.icon(icon: const Icon(Icons.delete_forever), style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))), onPressed: _deleteAllFixtures, label: const Text('Delete All'))
        ]),
      ),
      Expanded(child: snap.hasData
  ? GridView.count(
          padding: const EdgeInsets.all(12),
          crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12,
          children: snap.data!.docs.map((d) => Card(
            elevation: 4, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              d['logoUrl']!= ''? CircleAvatar(backgroundImage: NetworkImage(d['logoUrl']), radius: 32)
              : CircleAvatar(backgroundColor: _accent.withOpacity(0.1), radius: 32, child: Icon(Icons.shield, size: 40, color: _accent)),
              const SizedBox(height: 10),
              Text(d['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              Text('Pts: ${d['points']} | W:${d['won']} D:${d['drawn']} L:${d['lost']}', style: TextStyle(color: Colors.grey[700], fontSize: 12)),
              IconButton(icon: const Icon(Icons.delete, color: Colors.red, size: 20), onPressed: () => _confirmDeleteTeam(d.reference))
            ]),
          )).toList()
        ) : const Center(child: CircularProgressIndicator())),
    ]));

  // PLAYERS GROUPED BY TEAM
  Widget _playersTab() => Column(children: [
    Padding(
      padding: const EdgeInsets.all(12.0),
      child: TextField(
        decoration: InputDecoration(hintText: 'Search Player...', prefixIcon: Icon(Icons.search, color: _primary), filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
        onChanged: (val) => setState(()=> _playerSearch = val.toLowerCase()),
      ),
    ),
    Expanded(child: StreamBuilder<QuerySnapshot>(
      stream: db.collection('teams').orderBy('name').snapshots(),
      builder: (context, teamSnap) => teamSnap.hasData
  ? ListView(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          children: [
        ...teamSnap.data!.docs.map((teamDoc) {
              return StreamBuilder<QuerySnapshot>(
                stream: db.collection('players').where('teamId', isEqualTo: teamDoc.id).snapshots(),
                builder: (context, playerSnap) {
                  if(!playerSnap.hasData) return const SizedBox();
                  var players = playerSnap.data!.docs.where((d) => d['name'].toString().toLowerCase().contains(_playerSearch)).toList();
                  if(players.isEmpty && _playerSearch.isNotEmpty) return const SizedBox();

                  return Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ExpansionTile(
                      leading: teamDoc['logoUrl']!= ''
                  ? CircleAvatar(backgroundImage: NetworkImage(teamDoc['logoUrl']), radius: 20)
                        : CircleAvatar(backgroundColor: _accent.withOpacity(0.1), radius: 20, child: Icon(Icons.shield, color: _accent, size: 20)),
                      title: Text(teamDoc['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('${players.length} Players'),
                      children: [
                    ...players.map((d) => ListTile(
                          leading: d['faceUrl']!= ''
                      ? CircleAvatar(backgroundImage: NetworkImage(d['faceUrl']))
                            : CircleAvatar(backgroundColor: _accent.withOpacity(0.1), child: Text(d['name'][0], style: TextStyle(color: _primary))),
                          title: Text('${d['name']} - #${d['jersey']}', style: const TextStyle(fontWeight: FontWeight.w500)),
                          subtitle: Text('Pos: ${d['position']} | Goals: ${d['goals']??0}'),
                          trailing: IconButton(icon: const Icon(Icons.delete, color: Colors.red, size: 20), onPressed: () => _confirmDelete(d.reference))
                        )).toList(),
                        ListTile(
                          leading: Icon(Icons.person_add, color: _accent),
                          title: Text('Add Player to ${teamDoc['name']}', style: TextStyle(color: _accent)),
                          onTap: () => _addPlayerDialog(preselectedTeamId: teamDoc.id),
                        )
                      ],
                    ),
                  );
                }
              );
            }).toList(),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: ElevatedButton.icon(icon: const Icon(Icons.person_add), style: ElevatedButton.styleFrom(backgroundColor: _accent, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), onPressed: _addPlayerDialog, label: const Text('Add Player to Any Team'))
            )
          ]
        )
        : const Center(child: CircularProgressIndicator())
    ))
  ]);

  Widget _fixturesTab() => Column(children: [
    Padding(
      padding: const EdgeInsets.all(12.0),
      child: TextField(
        decoration: InputDecoration(hintText: 'Search Fixture...', prefixIcon: Icon(Icons.search, color: _primary), filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
        onChanged: (val) => setState(()=> _fixtureSearch = val.toLowerCase()),
      ),
    ),
    Expanded(child: StreamBuilder<QuerySnapshot>(
      stream: db.collection('fixtures').orderBy('date').snapshots(),
      builder: (context, snap) => snap.hasData
  ? ListView(padding: const EdgeInsets.symmetric(horizontal: 12), children: snap.data!.docs.where((d) =>
          d['homeTeamName'].toString().toLowerCase().contains(_fixtureSearch) ||
          d['awayTeamName'].toString().toLowerCase().contains(_fixtureSearch)
        ).map((d) => Card(
          elevation: 3, margin: const EdgeInsets.only(bottom: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('${d['homeTeamName']} ${d['homeGoals']} - ${d['awayGoals']} ${d['awayTeamName']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                subtitle: Text('${d['status']} | Leg ${d['leg']?? 1} | ${DateFormat.yMd().add_jm().format(d['date'].toDate())}\nVenue: ${d['venue']} | Ref: ${d['referee']}'),
              ),
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                if(d['status'] == 'Scheduled')...[
                  ElevatedButton.icon(
                    icon: const Icon(Icons.edit_calendar, size: 18),
                    style: ElevatedButton.styleFrom(backgroundColor: _accent, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                    onPressed: () => _setFixtureDetailsDialog(d),
                    label: const Text('Set Details')
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.sports_score, size: 18),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                    onPressed: () => _setResultDialog(d),
                    label: const Text('Save Result')
                  ),
                ] else
                  const Icon(Icons.check_circle, color: Colors.green),
              ])
            ]),
          )
        )).toList()) : const Center(child: CircularProgressIndicator()))), 
  ]);

  void _addTeamDialog() {
    final name = TextEditingController();
    final manager = TextEditingController();
    String? logoUrl;
    showDialog(context: context, builder: (_) => StatefulBuilder(
      builder: (context, setStateDialog) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Add Team'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: name, decoration: InputDecoration(label: const Text('Team Name'), focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: _primary)))),
          TextField(controller: manager, decoration: InputDecoration(label: const Text('Manager'), focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: _primary)))),
          const SizedBox(height: 10),
          ElevatedButton.icon(
            icon: Icon(Icons.upload, color: _primary),
            style: ElevatedButton.styleFrom(backgroundColor: _primary.withOpacity(0.1)),
            onPressed: () async {
              logoUrl = await _uploadImage('team-logos');
              setStateDialog((){});
              if(logoUrl!=null) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Logo Uploaded'), backgroundColor: _primary, duration: const Duration(seconds: 1)));
            },
            label: Text(logoUrl == null? 'Upload Logo' : 'Logo Selected', style: TextStyle(color: _primary))
          )
        ]),
        actions: [
          TextButton(onPressed: ()=>Navigator.pop(context), child: Text('Cancel', style: TextStyle(color: _primary))),
          TextButton(onPressed: () async {
            if(name.text.isEmpty || manager.text.isEmpty){
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('Please fill all fields'), backgroundColor: Colors.red));
              return;
            }
            await db.collection('teams').add({
              'name': name.text, 'manager': manager.text, 'logoUrl': logoUrl?? '',
              'played':0,'won':0,'drawn':0,'lost':0,'gf':0,'ga':0,'gd':0,'points':0
            });
            Navigator.pop(context);
          }, child: Text('Save', style: TextStyle(color: _primary)))
        ],
      )
    ));
  }

  void _addPlayerDialog({String? preselectedTeamId}) {
    final name = TextEditingController();
    final jersey = TextEditingController();
    final position = TextEditingController();
    String? teamId = preselectedTeamId;
    String? faceUrl;
    showDialog(context: context, builder: (_) => StatefulBuilder(
      builder: (context, setStateDialog) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Add Player'),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: name, decoration: InputDecoration(label: const Text('Name'), focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: _primary)))),
        TextField(controller: jersey, decoration: InputDecoration(label: const Text('Jersey'), focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: _primary))), keyboardType: TextInputType.number),
        TextField(controller: position, decoration: InputDecoration(label: const Text('Position'), focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: _primary)))),
        if(preselectedTeamId == null) StreamBuilder<QuerySnapshot>(
          stream: db.collection('teams').snapshots(),
          builder: (c,s) => s.hasData
      ? DropdownButtonFormField<String>(
              decoration: InputDecoration(label: const Text('Select Team'), focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: _primary))),
              value: teamId,
              items: s.data!.docs.map((d) => DropdownMenuItem(value: d.id, child: Text(d['name']))).toList(),
              onChanged: (v)=> setStateDialog(()=> teamId=v))
            : const CircularProgressIndicator())
        else FutureBuilder<DocumentSnapshot>(
          future: db.collection('teams').doc(preselectedTeamId).get(),
          builder: (c,s) => s.hasData? Text('Team: ${s.data!['name']}', style: TextStyle(fontWeight: FontWeight.bold, color: _primary)) : const SizedBox()),
          const SizedBox(height: 10),
        ElevatedButton.icon(
          icon: Icon(Icons.upload, color: _primary),
          style: ElevatedButton.styleFrom(backgroundColor: _primary.withOpacity(0.1)),
          onPressed: () async {
            faceUrl = await _uploadImage('player-faces');
            setStateDialog((){});
          },
          label: Text(faceUrl == null? 'Upload Player Face' : 'Face Selected', style: TextStyle(color: _primary))
        )
      ])),
      actions: [
        TextButton(onPressed: ()=>Navigator.pop(context), child: Text('Cancel', style: TextStyle(color: _primary))),
        TextButton(onPressed: () async {
          if(name.text.isEmpty || jersey.text.isEmpty || position.text.isEmpty || teamId == null){
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('Please fill all fields and select team'), backgroundColor: Colors.red));
            return;
          }
          await db.collection('players').add({
            'name': name.text, 'jersey': int.tryParse(jersey.text)??0, 'position': position.text,
            'teamId': teamId, 'faceUrl': faceUrl?? '', 'goals': 0, 'assists': 0
          });
          Navigator.pop(context);
        }, child: Text('Save', style: TextStyle(color: _primary)))
      ],
    )));
  }

  void _confirmDeleteTeam(DocumentReference ref) {
    showDialog(context: context, builder: (_) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Delete Team?'),
      content: const Text('This will not delete players or fixtures. Continue?'),
      actions: [TextButton(onPressed: () {ref.delete(); Navigator.pop(context);}, child: const Text('Yes', style: TextStyle(color: Colors.red))), TextButton(onPressed: ()=>Navigator.pop(context), child: Text('No', style: TextStyle(color: _primary)))]
    ));
  }

  void _confirmDelete(DocumentReference ref) {
    showDialog(context: context, builder: (_) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Delete?'),
      actions: [TextButton(onPressed: () {ref.delete(); Navigator.pop(context);}, child: const Text('Yes')), TextButton(onPressed: ()=>Navigator.pop(context), child: Text('No', style: TextStyle(color: _primary)))]
    ));
  }

  void _setFixtureDetailsDialog(QueryDocumentSnapshot d) {
    final venue = TextEditingController(text: d['venue']);
    final ref = TextEditingController(text: d['referee']);
    DateTime date = d['date'].toDate();
    TimeOfDay time = TimeOfDay.fromDateTime(date);

    showDialog(context: context, builder: (_) => StatefulBuilder(builder: (context, setState) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text('Set Details: ${d['homeTeamName']} vs ${d['awayTeamName']}'),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(title: Text('Date: ${DateFormat.yMd().format(date)}'), trailing: IconButton(icon: Icon(Icons.calendar_today, color: _primary), onPressed: () async {
          var picked = await showDatePicker(context: context, initialDate: date, firstDate: DateTime(2024), lastDate: DateTime(2030), builder: (context, child) => Theme(data: ThemeData(primarySwatch: Colors.indigo), child: child!));
          if(picked!= null) setState(()=>date = DateTime(picked.year, picked.month, picked.day, time.hour, time.minute));
        })),
        ListTile(title: Text('Time: ${time.format(context)}'), trailing: IconButton(icon: Icon(Icons.access_time, color: _primary), onPressed: () async {
          var picked = await showTimePicker(context: context, initialTime: time, builder: (context, child) => Theme(data: ThemeData(primarySwatch: Colors.indigo), child: child!));
          if(picked!= null) setState(()=>date = DateTime(date.year, date.month, date.day, picked.hour, picked.minute));
        })),
        TextField(controller: venue, decoration: InputDecoration(label: const Text('Venue'), focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: _primary)))),
        TextField(controller: ref, decoration: InputDecoration(label: const Text('Referee'), focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: _primary)))),
      ])),
      actions: [
        TextButton(onPressed: ()=>Navigator.pop(context), child: Text('Cancel', style: TextStyle(color: _primary))),
        TextButton(onPressed: () async {
          await d.reference.update({'venue': venue.text, 'referee': ref.text, 'date': Timestamp.fromDate(date)});
          Navigator.pop(context);
        }, child: Text('Save Details', style: TextStyle(color: _primary)))
      ],
    )));
  }

  // PICK UNLIMITED GOALS PER PLAYER - TAP TO ADD, LONG PRESS TO REMOVE
  void _setResultDialog(QueryDocumentSnapshot d) async {
    final hg = TextEditingController(text: d['homeGoals'].toString());
    final ag = TextEditingController(text: d['awayGoals'].toString());
    Map<String, int> homeScorersMap = {};
    Map<String, int> awayScorersMap = {};

    for(var s in List.from(d['homeScorers']?? [])) homeScorersMap[s['playerId']] = s['goals'];
    for(var s in List.from(d['awayScorers']?? [])) awayScorersMap[s['playerId']] = s['goals'];

    var homePlayers = await db.collection('players').where('teamId', isEqualTo: d['homeTeamId']).get();
    var awayPlayers = await db.collection('players').where('teamId', isEqualTo: d['awayTeamId']).get();

    showDialog(context: context, builder: (_) => StatefulBuilder(
      builder: (context, setStateDialog) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('${d['homeTeamName']} vs ${d['awayTeamName']}'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: hg, decoration: InputDecoration(label: const Text('Home Goals'), focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: _primary))), keyboardType: TextInputType.number, readOnly: true),
            TextField(controller: ag, decoration: InputDecoration(label: const Text('Away Goals'), focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: _primary))), keyboardType: TextInputType.number, readOnly: true),
            const SizedBox(height: 16),
            const Text('Tap = +1 Goal | Long Press = -1 Goal', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(d['homeTeamName'], style: TextStyle(color: _primary, fontWeight: FontWeight.bold)),
            Wrap(
              spacing: 6,
              children: homePlayers.docs.map<Widget>((p) {
                return GestureDetector(
                  onTap: (){
                    setStateDialog((){
                      homeScorersMap[p.id] = (homeScorersMap[p.id]??0) + 1;
                      hg.text = homeScorersMap.values.fold(0, (a,b)=>a+b).toString();
                    });
                  },
                  onLongPress: (){
                    setStateDialog((){
                      if(homeScorersMap.containsKey(p.id)) {
                        if(homeScorersMap[p.id]! > 1) homeScorersMap[p.id] = homeScorersMap[p.id]! - 1;
                        else homeScorersMap.remove(p.id);
                      }
                      hg.text = homeScorersMap.values.fold(0, (a,b)=>a+b).toString();
                    });
                  },
                  child: Chip(
                    label: Text('${p['name']} ${homeScorersMap[p.id]!=null? "(${homeScorersMap[p.id]})" : ""}'),
                    backgroundColor: homeScorersMap.containsKey(p.id)? _accent.withOpacity(0.3) : Colors.grey[200],
                    labelStyle: TextStyle(color: homeScorersMap.containsKey(p.id)? _primary : Colors.black),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 8),
            Text(d['awayTeamName'], style: TextStyle(color: _primary, fontWeight: FontWeight.bold)),
            Wrap(
              spacing: 6,
              children: awayPlayers.docs.map<Widget>((p) {
                return GestureDetector(
                  onTap: (){
                    setStateDialog((){
                      awayScorersMap[p.id] = (awayScorersMap[p.id]??0) + 1;
                      ag.text = awayScorersMap.values.fold(0, (a,b)=>a+b).toString();
                    });
                  },
                  onLongPress: (){
                    setStateDialog((){
                      if(awayScorersMap.containsKey(p.id)) {
                        if(awayScorersMap[p.id]! > 1) awayScorersMap[p.id] = awayScorersMap[p.id]! - 1;
                        else awayScorersMap.remove(p.id);
                      }
                      ag.text = awayScorersMap.values.fold(0, (a,b)=>a+b).toString();
                    });
                  },
                  child: Chip(
                    label: Text('${p['name']} ${awayScorersMap[p.id]!=null? "(${awayScorersMap[p.id]})" : ""}'),
                    backgroundColor: awayScorersMap.containsKey(p.id)? _accent.withOpacity(0.3) : Colors.grey[200],
                    labelStyle: TextStyle(color: awayScorersMap.containsKey(p.id)? _primary : Colors.black),
                  ),
                );
              }).toList(),
            ),
          ])),
        ),
        actions: [
          TextButton(onPressed: ()=>Navigator.pop(context), child: Text('Cancel', style: TextStyle(color: _primary))),
          TextButton(onPressed: () async {
            int h = int.tryParse(hg.text)??0; int a = int.tryParse(ag.text)??0;
            List homeScorersList = homeScorersMap.entries.map((e)=>{'playerId': e.key, 'goals': e.value}).toList();
            List awayScorersList = awayScorersMap.entries.map((e)=>{'playerId': e.key, 'goals': e.value}).toList();

            await d.reference.update({
              'homeGoals': h, 'awayGoals': a, 'status': 'Completed',
              'homeScorers': homeScorersList, 'awayScorers': awayScorersList
            });
            await _updateStats(d.id, d['homeTeamId'], d['awayTeamId'], h, a, homeScorersList, awayScorersList);
            Navigator.pop(context);
          }, child: Text('Save Result', style: TextStyle(color: _primary)))
        ],
      )
    ));
  }
}