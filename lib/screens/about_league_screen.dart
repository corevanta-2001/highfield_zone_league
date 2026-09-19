import 'package:flutter/material.dart';

class AboutLeagueScreen extends StatelessWidget {
  const AboutLeagueScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('About HZL'),
        backgroundColor: const Color(0xFF1A237E),
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // HEADER BANNER
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF1A237E), Color(0xFF3949AB)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.sports_soccer, size: 60, color: Colors.white),
                  ),
                  const SizedBox(height: 16),
                  Text('Highfields Zone League',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text('Season 2026',
                    style: TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                ],
              ),
            ),

            // CONTENT CARDS
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // ABOUT CARD
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.info_outline, color: Color(0xFF3949AB)),
                              SizedBox(width: 8),
                              Text('About Us', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1A237E))),
                            ],
                          ),
                          const Divider(height: 24),
                          Text(
                            'Community football league based in Highfields, Harare.\n\n'
                            'We bring together local teams to compete, grow talent, and unite the community through the beautiful game.',
                            style: TextStyle(fontSize: 15.5, height: 1.5, color: Colors.grey[800]),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // SEASON CARD
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Color(0xFF3949AB).withOpacity(0.1),
                        child: Icon(Icons.calendar_today, color: Color(0xFF3949AB)),
                      ),
                      title: Text('Current Season', style: TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('Season 2026 - Ongoing'),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // CONTACT CARD
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.green.withOpacity(0.1),
                        child: Icon(Icons.email_outlined, color: Colors.green),
                      ),
                      title: Text('Contact Admin', style: TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('puremundex@gmail.com'),
                      trailing: IconButton(
                        icon: Icon(Icons.copy, size: 20),
                        onPressed: () {
                          // Optional: add clipboard copy later
                        },
                      ),
                    ),
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}