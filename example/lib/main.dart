import 'dart:io';

import 'package:desktop_webview_window/desktop_webview_window.dart';
import 'package:example/localstorage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get_it/get_it.dart';
import 'package:hetu_script/hetu_script.dart';
import 'package:hetu_spotube_plugin/hetu_spotube_plugin.dart';
import 'package:hetu_std/hetu_std.dart';
import 'package:shared_preferences/shared_preferences.dart';

final getIt = GetIt.instance;

class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;
  }
}

void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  if (runWebViewTitleBarWidget(args)) {
    return;
  }

  HttpOverrides.global = MyHttpOverrides();

  final hetu = Hetu();
  getIt.registerSingleton<Hetu>(hetu);
  getIt.registerSingleton<SharedPreferences>(
    await SharedPreferences.getInstance(),
  );

  hetu.init();
  HetuStdLoader.loadBindings(hetu);

  await HetuStdLoader.loadBytecodeFlutter(hetu);
  await HetuSpotubePluginLoader.loadBytecodeFlutter(hetu);
  final byteCode = await rootBundle.load("assets/bytecode/plugin.out");
  await hetu.loadBytecode(
    bytes: byteCode.buffer.asUint8List(),
    moduleName: "plugin",
  );

  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(home: Scaffold(body: MyHome()));
  }
}

class MyHome extends StatefulWidget {
  const MyHome({super.key});

  @override
  State<MyHome> createState() => _MyHomeState();
}

class _MyHomeState extends State<MyHome> {
  @override
  void initState() {
    super.initState();
    final hetu = getIt<Hetu>();
    BuildContext? pageContext;
    HetuSpotubePluginLoader.loadBindings(
      hetu,
      localStorageImpl: SharedPreferencesLocalStorage(
        getIt<SharedPreferences>(),
      ),
      onNavigatorPush: (route) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) {
              pageContext = context;
              return Scaffold(
                appBar: AppBar(title: const Text('WebView')),
                body: route,
              );
            },
          ),
        );
      },
      onNavigatorPop: () {
        if (pageContext == null) {
          return;
        }
        Navigator.pop(pageContext!);
      },
      onShowForm: (title, fields) async {
        return [];
      },
    );

    hetu.eval(r"""
    import "module:plugin" as plugin;

    var AppleMusicMetadataProviderPlugin = plugin.AppleMusicMetadataProviderPlugin;
    var metadata = AppleMusicMetadataProviderPlugin()
    """);
  }

  // Example Apple Music catalog ids (US storefront).
  static const songId = '1440890708'; // "Mr. Brightside" – The Killers
  static const albumId = '1440889648'; // "Hot Fuss" – The Killers
  static const artistId = '486420565'; // The Killers
  static const playlistId =
      'pl.f4d106fed2bd41149aaacabb233eb5eb'; // Apple's "Today's Hits"

  Future<void> _run(String expr) async {
    final result = await getIt<Hetu>().eval(expr);
    debugPrint(result.toString());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListView(
        children: [
          const Text("Auth"),
          Wrap(
            children: [
              ElevatedButton(
                onPressed: () => _run("metadata.auth.authenticate()"),
                child: const Text("Login (Webview)"),
              ),
              ElevatedButton(
                onPressed: () => _run("metadata.auth.logout()"),
                child: const Text("Logout"),
              ),
              ElevatedButton(
                onPressed: () =>
                    _run("metadata.core.checkUpdate({version: '0.0.1'}.toJson())"),
                child: const Text("Check Update"),
              ),
              ElevatedButton(
                onPressed: () => _run("metadata.core.support"),
                child: const Text("Support"),
              ),
            ],
          ),
          const Text("User"),
          Wrap(
            children: [
              ElevatedButton(
                onPressed: () => _run("metadata.user.me()"),
                child: const Text("Get Me"),
              ),
              ElevatedButton(
                onPressed: () => _run("metadata.user.savedTracks()"),
                child: const Text("Saved Tracks"),
              ),
              ElevatedButton(
                onPressed: () => _run("metadata.user.savedPlaylists()"),
                child: const Text("Saved Playlists"),
              ),
              ElevatedButton(
                onPressed: () => _run("metadata.user.savedAlbums()"),
                child: const Text("Saved Albums"),
              ),
              ElevatedButton(
                onPressed: () => _run("metadata.user.savedArtists()"),
                child: const Text("Saved Artists"),
              ),
              ElevatedButton(
                onPressed: () =>
                    _run("metadata.user.isSavedTracks(['$songId'])"),
                child: const Text("Is track saved?"),
              ),
            ],
          ),
          const Text("Tracks"),
          Wrap(
            children: [
              ElevatedButton(
                onPressed: () => _run("metadata.track.getTrack('$songId')"),
                child: const Text("Get Track"),
              ),
              ElevatedButton(
                onPressed: () => _run("metadata.track.radio('$songId')"),
                child: const Text("Track Radio"),
              ),
              ElevatedButton(
                onPressed: () => _run("metadata.track.save(['$songId'])"),
                child: const Text("Save Track"),
              ),
              ElevatedButton(
                onPressed: () => _run("metadata.track.unsave(['$songId'])"),
                child: const Text("Unsave Track"),
              ),
            ],
          ),
          const Text("Albums"),
          Wrap(
            children: [
              ElevatedButton(
                onPressed: () => _run("metadata.album.getAlbum('$albumId')"),
                child: const Text("Get Album"),
              ),
              ElevatedButton(
                onPressed: () => _run("metadata.album.tracks('$albumId')"),
                child: const Text("Album Tracks"),
              ),
              ElevatedButton(
                onPressed: () => _run("metadata.album.releases()"),
                child: const Text("Releases"),
              ),
              ElevatedButton(
                onPressed: () => _run("metadata.album.save(['$albumId'])"),
                child: const Text("Save Album"),
              ),
            ],
          ),
          const Text("Artists"),
          Wrap(
            children: [
              ElevatedButton(
                onPressed: () => _run("metadata.artist.getArtist('$artistId')"),
                child: const Text("Get Artist"),
              ),
              ElevatedButton(
                onPressed: () => _run("metadata.artist.topTracks('$artistId')"),
                child: const Text("Top Tracks"),
              ),
              ElevatedButton(
                onPressed: () => _run("metadata.artist.albums('$artistId')"),
                child: const Text("Artist Albums"),
              ),
              ElevatedButton(
                onPressed: () => _run("metadata.artist.related('$artistId')"),
                child: const Text("Related Artists"),
              ),
            ],
          ),
          const Text("Playlists"),
          Wrap(
            children: [
              ElevatedButton(
                onPressed: () =>
                    _run("metadata.playlist.getPlaylist('$playlistId')"),
                child: const Text("Get Playlist"),
              ),
              ElevatedButton(
                onPressed: () =>
                    _run("metadata.playlist.tracks('$playlistId')"),
                child: const Text("Playlist Tracks"),
              ),
            ],
          ),
          const Text("Search"),
          Wrap(
            children: [
              ElevatedButton(
                onPressed: () => _run("metadata.search.all('The Killers')"),
                child: const Text("Search All"),
              ),
              ElevatedButton(
                onPressed: () => _run("metadata.search.tracks('The Killers')"),
                child: const Text("Search Tracks"),
              ),
              ElevatedButton(
                onPressed: () => _run("metadata.search.albums('The Killers')"),
                child: const Text("Search Albums"),
              ),
              ElevatedButton(
                onPressed: () => _run("metadata.search.artists('The Killers')"),
                child: const Text("Search Artists"),
              ),
              ElevatedButton(
                onPressed: () => _run("metadata.search.playlists('rock')"),
                child: const Text("Search Playlists"),
              ),
            ],
          ),
          const Text("Browse"),
          Wrap(
            children: [
              ElevatedButton(
                onPressed: () => _run("metadata.browse.sections()"),
                child: const Text("Browse Sections"),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
