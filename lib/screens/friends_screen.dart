import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/firebase_service.dart';
import '../models/player_model.dart';

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<PlayerModel> _searchResults = [];
  bool _isSearching = false;
  bool _isLoading = false;

  Future<void> _performSearch(String query, FirebaseService firebaseService) async {
    if (query.trim().isEmpty) {
      setState(() {
        _isSearching = false;
        _searchResults = [];
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _isSearching = true;
    });

    try {
      final results = await firebaseService.searchPlayers(query.trim());
      if (!mounted) return;
      setState(() {
        _searchResults = results;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("SEARCH ERROR: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final firebaseService = Provider.of<FirebaseService>(context);
    final user = firebaseService.currentUser;
    final colorScheme = Theme.of(context).colorScheme;

    if (user == null) return const Scaffold(body: Center(child: Text("NOT AUTHENTICATED")));

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: Text("NETWORK", style: TextStyle(fontFamily: 'Orbitron', letterSpacing: 2, color: colorScheme.onSurface)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: colorScheme.onSurface),
        actions: [
          if (_isSearching)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () {
                setState(() {
                  _isSearching = false;
                  _searchController.clear();
                  _searchResults = [];
                });
              },
            )
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              style: TextStyle(color: colorScheme.onSurface),
              decoration: InputDecoration(
                hintText: "SEARCH OPERATIVE ID OR NAME...",
                hintStyle: TextStyle(color: colorScheme.onSurfaceVariant),
                prefixIcon: Icon(Icons.search, color: colorScheme.primary),
                filled: true,
                fillColor: colorScheme.surfaceContainerHighest,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
              ),
              onSubmitted: (value) => _performSearch(value, firebaseService),
            ),
          ),
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator(color: colorScheme.primary))
                : _isSearching
                    ? _buildSearchResults(firebaseService, user.uid, colorScheme)
                    : _buildFriendsList(firebaseService, user.uid, colorScheme),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults(FirebaseService firebaseService, String currentUid, ColorScheme colorScheme) {
    if (_searchResults.isEmpty) {
      return Center(
        child: Text("NO OPERATIVES FOUND", style: TextStyle(color: colorScheme.onSurfaceVariant, fontFamily: 'Orbitron')),
      );
    }

    return ListView.builder(
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final player = _searchResults[index];
        if (player.uid == currentUid) return const SizedBox.shrink();

        return ListTile(
          leading: CircleAvatar(
            backgroundColor: colorScheme.secondaryContainer,
            backgroundImage: player.avatar.isNotEmpty ? NetworkImage(player.avatar) : null,
            child: player.avatar.isEmpty ? Text(player.name[0], style: TextStyle(color: colorScheme.onSecondaryContainer)) : null,
          ),
          title: Text(player.name, style: TextStyle(color: colorScheme.onSurface, fontWeight: FontWeight.bold)),
          subtitle: Text("LVL ${player.level}", style: TextStyle(color: colorScheme.primary, fontSize: 12)),
          trailing: StreamBuilder<PlayerModel?>(
            stream: firebaseService.getPlayerStream(currentUid),
            builder: (context, snapshot) {
              final isFriend = snapshot.data?.friends.contains(player.uid) ?? false;
              return ElevatedButton(
                onPressed: isFriend
                    ? null
                    : () async {
                        await firebaseService.addFriend(currentUid, player.uid);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("CONNECTION ESTABLISHED")),
                          );
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: isFriend ? colorScheme.surfaceContainer : colorScheme.primary,
                  foregroundColor: isFriend ? colorScheme.onSurfaceVariant : colorScheme.onPrimary,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
                child: Text(isFriend ? "CONNECTED" : "CONNECT"),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildFriendsList(FirebaseService firebaseService, String currentUid, ColorScheme colorScheme) {
    return StreamBuilder<PlayerModel?>(
      stream: firebaseService.getPlayerStream(currentUid),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return Center(child: CircularProgressIndicator(color: colorScheme.primary));
        final player = snapshot.data!;
        final friends = player.friends;

        if (friends.isEmpty) {
          return Center(
            child: Text(
              "NO ACTIVE CONNECTIONS FOUND",
              style: TextStyle(color: colorScheme.onSurfaceVariant, fontFamily: 'Orbitron'),
            ),
          );
        }

        return ListView.builder(
          itemCount: friends.length,
          itemBuilder: (context, index) {
            return FutureBuilder<PlayerModel?>(
              future: firebaseService.getPlayer(friends[index]),
              builder: (context, fSnap) {
                if (!fSnap.hasData) return const SizedBox.shrink();
                final friend = fSnap.data!;

                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: colorScheme.tertiaryContainer,
                    backgroundImage: friend.avatar.isNotEmpty ? NetworkImage(friend.avatar) : null,
                    child: friend.avatar.isEmpty ? Text(friend.name[0], style: TextStyle(color: colorScheme.onTertiaryContainer)) : null,
                  ),
                  title: Text(friend.name, style: TextStyle(color: colorScheme.onSurface, fontWeight: FontWeight.bold)),
                  subtitle: Text("LVL ${friend.level} | ${friend.totalSteps} STEPS", style: TextStyle(color: colorScheme.secondary, fontSize: 12)),
                  trailing: IconButton(
                    icon: Icon(Icons.person_remove_outlined, color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
                    onPressed: () => _confirmRemoveFriend(firebaseService, currentUid, friend.uid, friend.name, colorScheme),
                  ),
                  onTap: () {
                    // TODO: View friend profile
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  void _confirmRemoveFriend(FirebaseService firebaseService, String currentUid, String friendId, String friendName, ColorScheme colorScheme) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: colorScheme.surfaceContainer,
        title: Text("TERMINATE CONNECTION?", style: TextStyle(color: colorScheme.onSurface, fontFamily: 'Orbitron')),
        content: Text("Are you sure you want to remove $friendName from your network?", style: TextStyle(color: colorScheme.onSurfaceVariant)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCEL")),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await firebaseService.removeFriend(currentUid, friendId);
            },
            child: Text("TERMINATE", style: TextStyle(color: colorScheme.error)),
          ),
        ],
      ),
    );
  }

}
