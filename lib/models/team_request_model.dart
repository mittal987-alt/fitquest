class TeamRequestModel {
  final String requestId;
  final String playerId;
  final String playerName;
  final String teamId;
  final String teamName;
  final String status;

  TeamRequestModel({
    required this.requestId,
    required this.playerId,
    required this.playerName,
    required this.teamId,
    required this.teamName,
    required this.status,
  });

  Map<String, dynamic> toMap() {
    return {
      "requestId": requestId,
      "playerId": playerId,
      "playerName": playerName,
      "teamId": teamId,
      "teamName": teamName,
      "status": status,
    };
  }

  // FIX: every field used to be read straight off the map with no fallback
  // (e.g. `requestId: map["requestId"]`). Every other model in this app
  // guards against missing/null Firestore fields with `?? ''`; this one
  // didn't, so a single request document missing any field (e.g. an older
  // doc written before a field was added) would throw "type 'Null' is not a
  // subtype of type 'String'" and take down the whole getTeamRequests()
  // stream — not just that one request, all of them, since the crash happens
  // inside snapshot.docs.map(...).
  factory TeamRequestModel.fromMap(Map<String, dynamic> map) {
    return TeamRequestModel(
      requestId: map["requestId"]?.toString() ?? "",
      playerId: map["playerId"]?.toString() ?? "",
      playerName: map["playerName"]?.toString() ?? "Unknown",
      teamId: map["teamId"]?.toString() ?? "",
      teamName: map["teamName"]?.toString() ?? "Unknown Team",
      status: map["status"]?.toString() ?? "pending",
    );
  }
}