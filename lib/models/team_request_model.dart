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

  factory TeamRequestModel.fromMap(
      Map<String, dynamic> map) {

    return TeamRequestModel(

      requestId: map["requestId"],

      playerId: map["playerId"],

      playerName: map["playerName"],

      teamId: map["teamId"],

      teamName: map["teamName"],

      status: map["status"],
    );
  }
}