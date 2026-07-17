import 'package:url_launcher/url_launcher.dart';

class MusicService {
  Future<void> openSpotify() async {
    final Uri url = Uri.parse("spotify:");
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      await launchUrl(Uri.parse("https://open.spotify.com"));
    }
  }

  Future<void> openYouTubeMusic() async {
    final Uri url = Uri.parse("youtubemusic:");
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      await launchUrl(Uri.parse("https://music.youtube.com"));
    }
  }
}
