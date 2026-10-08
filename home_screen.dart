import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'meeting_screen.dart';
import 'login_screen.dart';

class HomeScreen extends StatefulWidget {
  final String uid;
  const HomeScreen({super.key, required this.uid});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _meetingIdController = TextEditingController();
  String _myName = 'Staff';
  String _myPhone = '';

  @override
  void initState() {
    super.initState();
    _loadMe();
  }

  Future<void> _loadMe() async {
    final doc = await FirebaseFirestore.instance.collection('staff').doc(widget.uid).get();
    if (doc.exists && mounted) {
      setState(() {
        _myName = (doc.data()?['name'] ?? 'Staff').toString();
        _myPhone = (doc.data()?['phoneNumber'] ?? '').toString();
      });
    }
  }

  // ZEGO conferenceID me '+' jaise characters allowed nahi hote, isliye sirf digits/letters.
  String _cleanId(String raw) => raw.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');

  void _join(String rawId) {
    final id = _cleanId(rawId);
    if (id.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MeetingScreen(conferenceID: id, userID: widget.uid, userName: _myName),
      ),
    );
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
  }

  @override
  void dispose() {
    _meetingIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('HR Digital Dashboard'),
        actions: [IconButton(icon: const Icon(Icons.logout), onPressed: _logout)],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _meetingIdController,
                    decoration: const InputDecoration(labelText: 'Meeting Code ya Number'),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => _join(_meetingIdController.text),
                  child: const Text('Join'),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.add_call),
                label: const Text('Meri Meeting Start Karo (mera number = code)'),
                onPressed: _myPhone.isEmpty ? null : () => _join(_myPhone),
              ),
            ),
          ),
          const Divider(),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('staff').snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snapshot.data!.docs;
                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final s = docs[index].data() as Map<String, dynamic>;
                    return ListTile(
                      leading: const Icon(Icons.person),
                      title: Text('${s['name'] ?? ''}'),
                      subtitle: Text('Area: ${s['area'] ?? ''} | Work: ${s['work'] ?? ''}'),
                      trailing: IconButton(
                        icon: const Icon(Icons.video_call, color: Colors.green),
                        // Us staff ke number ko meeting code bana kar join
                        onPressed: () => _join('${s['phoneNumber'] ?? ''}'),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
