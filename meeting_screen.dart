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
  static const int appID = 0; // TODO: YOUR_APP_ID
  static const String appSign = 'YOUR_ZEGO_APP_SIGN_HERE'; // TODO

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
