#!/usr/bin/env bash
# HR Digital - ek hi file me poora build (GitHub Actions) - v2 (updated)
set -euo pipefail
trap 'echo "::error title=BUILD FAIL::Line $LINENO me ye command fail hui: $BASH_COMMAND"' ERR

LOG="$PWD/build.log"
: > "$LOG"
run_logged() {
  local label="$1"; shift
  local code
  set +e
  "$@" 2>&1 | tee -a "$LOG"
  code=${PIPESTATUS[0]}
  set -e
  if [ "$code" -ne 0 ]; then
    local summary
    summary=$(grep -iE "error|failed|went wrong|could not|because|solving|not found|exception" "$LOG" | tail -12 | cut -c1-300 | sed 's/%/%25/g' | tr '\r\n' '  ')
    echo "::error title=$label FAIL::$summary"
    exit 1
  fi
}

# 1) Secret check
if [ -z "${GS:-}" ]; then
  echo "::error title=SECRET NAHI HAI::GOOGLE_SERVICES_JSON secret set nahi hai."
  exit 1
fi
if ! printf "%s" "$GS" | python3 -c "import sys,json; json.load(sys.stdin)"; then
  echo "::error title=SECRET GALAT HAI::GOOGLE_SERVICES_JSON valid JSON nahi hai. Poora text { se } tak paste karo."
  exit 1
fi
if ! printf "%s" "$GS" | grep -q "com.hrdigital.hr_digital"; then
  echo "::error title=PACKAGE NAME GALAT::google-services.json me com.hrdigital.hr_digital nahi hai."
  exit 1
fi

# 2) Flutter project banao
rm -rf app
run_logged "FLUTTER CREATE" flutter create --org com.hrdigital --project-name hr_digital --platforms=android app
rm -rf app/lib app/test
mkdir -p app/lib
printf "%s" "$GS" > app/android/app/google-services.json

cat > app/pubspec.yaml <<'PUBSPEC_END'
name: hr_digital
description: HR Digital - Meeting and video calling app for staff.
publish_to: 'none'
version: 1.0.0+1

environment:
  sdk: '>=3.0.0 <4.0.0'

dependencies:
  flutter:
    sdk: flutter
  firebase_core: ^4.2.1
  firebase_auth: ^6.1.2
  cloud_firestore: ^6.1.0
  zego_uikit_prebuilt_video_conference: ^2.10.5

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^4.0.0

flutter:
  uses-material-design: true
PUBSPEC_END
cat > app/lib/main.dart <<'MAIN_END'
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'login_screen.dart';
import 'home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const HRDigitalApp());
}

class HRDigitalApp extends StatelessWidget {
  const HRDigitalApp({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return MaterialApp(
      title: 'HR Digital',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      home: user == null ? const LoginScreen() : HomeScreen(uid: user.uid),
    );
  }
}
MAIN_END
cat > app/lib/login_screen.dart <<'LOGIN_END'
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phoneController = TextEditingController(text: '+91');
  final _otpController = TextEditingController();
  final _nameController = TextEditingController();
  final _areaController = TextEditingController();
  final _workController = TextEditingController();

  String _verificationId = '';
  bool _isOtpSent = false;
  bool _loading = false;

  void _msg(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _sendOTP() async {
    if (_nameController.text.trim().isEmpty ||
        _areaController.text.trim().isEmpty ||
        _workController.text.trim().isEmpty) {
      _msg('Name, Area aur Work bharna zaroori hai');
      return;
    }
    setState(() => _loading = true);
    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: _phoneController.text.trim(),
      timeout: const Duration(seconds: 60),
      verificationCompleted: (PhoneAuthCredential credential) async {
        // Auto-verification (Android)
        await _signIn(credential);
      },
      verificationFailed: (FirebaseAuthException e) {
        setState(() => _loading = false);
        _msg('Verification failed: ${e.message}');
      },
      codeSent: (String verificationId, int? resendToken) {
        setState(() {
          _verificationId = verificationId;
          _isOtpSent = true;
          _loading = false;
        });
      },
      codeAutoRetrievalTimeout: (String verificationId) {
        _verificationId = verificationId;
      },
    );
  }

  Future<void> _verifyOTP() async {
    setState(() => _loading = true);
    final credential = PhoneAuthProvider.credential(
      verificationId: _verificationId,
      smsCode: _otpController.text.trim(),
    );
    await _signIn(credential);
  }

  Future<void> _signIn(PhoneAuthCredential credential) async {
    try {
      final cred = await FirebaseAuth.instance.signInWithCredential(credential);
      final user = cred.user;
      if (user == null) return;

      final ref = FirebaseFirestore.instance.collection('staff').doc(user.uid);
      final doc = await ref.get();
      if (!doc.exists) {
        await ref.set({
          'uid': user.uid,
          'phoneNumber': _phoneController.text.trim(),
          'name': _nameController.text.trim(),
          'area': _areaController.text.trim(),
          'work': _workController.text.trim(),
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => HomeScreen(uid: user.uid)),
      );
    } on FirebaseAuthException catch (e) {
      _msg('Login failed: ${e.message}');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    _nameController.dispose();
    _areaController.dispose();
    _workController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('HR Digital - Login')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (!_isOtpSent) ...[
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Mobile Number (+91...)'),
              ),
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Staff Full Name'),
              ),
              TextField(
                controller: _areaController,
                decoration: const InputDecoration(labelText: 'Area / Location'),
              ),
              TextField(
                controller: _workController,
                decoration: const InputDecoration(labelText: 'Work / Role'),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _loading ? null : _sendOTP,
                child: Text(_loading ? 'Please wait...' : 'Send OTP'),
              ),
            ] else ...[
              TextField(
                controller: _otpController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: const InputDecoration(labelText: 'Enter 6-Digit OTP'),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _loading ? null : _verifyOTP,
                child: Text(_loading ? 'Please wait...' : 'Verify & Login'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
LOGIN_END
cat > app/lib/home_screen.dart <<'HOME_END'
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
HOME_END
cat > app/lib/meeting_screen.dart <<'MEETING_END'
import 'package:flutter/material.dart';
import 'package:zego_uikit_prebuilt_video_conference/zego_uikit_prebuilt_video_conference.dart';

class MeetingScreen extends StatelessWidget {
  final String conferenceID;
  final String userID;
  final String userName;

  const MeetingScreen({
    super.key,
    required this.conferenceID,
    required this.userID,
    required this.userName,
  });

  // ZEGOCLOUD console se apni asli values yahan daalein
  static const int appID = 1648765019;
  static const String appSign = '51fe23994007430baeaa9ff3891da5322bcc0ecb5910edb08204990ca6196c4c';

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ZegoUIKitPrebuiltVideoConference(
        appID: appID,
        appSign: appSign,
        userID: userID,
        userName: userName,
        conferenceID: conferenceID,
        config: ZegoUIKitPrebuiltVideoConferenceConfig(
          turnOnCameraWhenJoining: true,
          turnOnMicrophoneWhenJoining: true,
          useSpeakerWhenJoining: true,
          bottomMenuBarConfig: ZegoBottomMenuBarConfig(
            buttons: [
              ZegoMenuBarButtonName.toggleCameraButton,
              ZegoMenuBarButtonName.toggleMicrophoneButton,
              ZegoMenuBarButtonName.switchAudioOutputButton,
              ZegoMenuBarButtonName.leaveButton,
              ZegoMenuBarButtonName.switchCameraButton,
              ZegoMenuBarButtonName.toggleScreenSharingButton,
              ZegoMenuBarButtonName.chatButton,
            ],
          ),
        ),
      ),
    );
  }
}
MEETING_END

# 3) Android config patch
python3 - <<'PYEND'
import re, pathlib
a = pathlib.Path('app/android')
s = a/'settings.gradle.kts'
t = s.read_text()
t2 = re.sub(r'(\n[ \t]*id\("com\.android\.application"\)[^\n]*\n)',
            r'\1    id("com.google.gms.google-services") version "4.4.2" apply false\n', t, count=1)
if t2 == t:
    raise SystemExit("settings.gradle.kts me plugin line nahi mili")
s.write_text(t2)
b = a/'app'/'build.gradle.kts'
t = b.read_text()
t2 = re.sub(r'(\n[ \t]*id\("com\.android\.application"\)[^\n]*\n)',
            r'\1    id("com.google.gms.google-services")\n', t, count=1)
if t2 == t:
    raise SystemExit("app/build.gradle.kts me plugin line nahi mili")
t2 = t2.replace('minSdk = flutter.minSdkVersion', 'minSdk = 23')
t2 = t2.replace('signingConfig = signingConfigs.getByName("debug")',
                'signingConfig = signingConfigs.getByName("debug")\n            isMinifyEnabled = false\n            isShrinkResources = false')
b.write_text(t2)
m = a/'app'/'src'/'main'/'AndroidManifest.xml'
t = m.read_text()
names = ['INTERNET','ACCESS_NETWORK_STATE','CAMERA','RECORD_AUDIO','MODIFY_AUDIO_SETTINGS',
         'BLUETOOTH','FOREGROUND_SERVICE','FOREGROUND_SERVICE_MEDIA_PROJECTION']
perms = ''.join('    <uses-permission android:name="android.permission.%s" />\n' % p for p in names)
if '<application' not in t:
    raise SystemExit("AndroidManifest me <application nahi mila")
m.write_text(t.replace('<application', perms + '    <application', 1))
print("Android patch OK")
PYEND

# 4) Fixed signing key (SHA-1 hamesha same)
mkdir -p ~/.android
echo "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" | base64 -d > ~/.android/debug.keystore
keytool -list -v -keystore ~/.android/debug.keystore -storepass android -alias androiddebugkey | grep -E "SHA1|SHA256" || true

# 5) Build
cd app
flutter --version
run_logged "PUB GET" flutter pub get
run_logged "APK BUILD" flutter build apk --release
echo "APK READY"
ls -la build/app/outputs/flutter-apk/ || true
