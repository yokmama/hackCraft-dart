import 'dart:async';
import 'dart:convert';
import 'package:logging/logging.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:synchronized/synchronized.dart';

// --- Utility Functions and Classes ---

final _logger = Logger('MinecraftClient'); // General logger for the library

/// Converts a string to a boolean value.
///
/// Args:
///   s (String): "true" or "false" (case-insensitive).
///
/// Returns:
///   bool: True if "true", False if "false".
///
/// Throws:
///   ArgumentError: If the string is not a valid boolean representation.
bool strToBool(String s) {
  if (s.toLowerCase() == 'true') {
    return true;
  } else if (s.toLowerCase() == 'false') {
    return false;
  } else {
    throw ArgumentError("Cannot convert '$s' to a boolean.");
  }
}

/// Custom exception for uninitialized WebSocketClient.
class UninitializedClientError extends Error {
  final String message;
  UninitializedClientError(this.message);
  @override
  String toString() => "UninitializedClientError: $message";
}

/// Custom error for WebSocket messages of type 'error'.
class WebSocketMessageError extends Error {
  final String type;
  final dynamic data;
  WebSocketMessageError(this.type, this.data);

  @override
  String toString() {
    return 'WebSocketMessageError: type="$type", data="$data"';
  }
}

// --- Coordinate System ---

/// Defines Minecraft coordinate types.
class CoordinateType {
  static const String absolute = "";
  static const String relative = "~";
  static const String local = "^";
}

/// Represents coordinate data with a type.
class CoordinateData {
  final int x;
  final int y;
  final int z;
  final String type;

  CoordinateData(this.x, this.y, this.z, this.type);
}

/// Helper class for creating [CoordinateData].
class Coordinates {
  static CoordinateData absolute(int x, int y, int z) {
    return CoordinateData(x, y, z, CoordinateType.absolute);
  }

  static CoordinateData relative(int x, int y, int z) {
    return CoordinateData(x, y, z, CoordinateType.relative);
  }

  static CoordinateData local(int x, int y, int z) {
    return CoordinateData(x, y, z, CoordinateType.local);
  }
}

/// Represents block placement sides.
class Side {
  static const String right = "Right";
  static const String left = "Left";
  static const String front = "Front";
  static const String back = "Back";
  static const String top = "Top";
  static const String bottom = "Bottom";
}

// --- Data Classes (Models) ---

/// Represents a location in the Minecraft world.
class Location {
  final int x;
  final int y;
  final int z;
  final String world;

  Location({
    required this.x,
    required this.y,
    required this.z,
    this.world = "world",
  });

  factory Location.fromJson(Map<String, dynamic> json) {
    return Location(
      x: json['x'] as int,
      y: json['y'] as int,
      z: json['z'] as int,
      world: json['world'] as String? ?? 'world',
    );
  }

  Map<String, dynamic> toJson() => {
        'x': x,
        'y': y,
        'z': z,
        'world': world,
      };
}

/// Represents an interaction event.
class InteractEvent {
  final String action;
  final String player;
  final String playerUuid;
  final String event;
  final String name;
  final String type;
  final int data;
  final String world;
  final int x;
  final int y;
  final int z;

  InteractEvent({
    required this.action,
    required this.player,
    required this.playerUuid,
    required this.event,
    required this.name,
    required this.type,
    this.data = 0,
    this.world = "world",
    this.x = 0,
    this.y = 0,
    this.z = 0,
  });

  factory InteractEvent.fromJson(Map<String, dynamic> json) {
    return InteractEvent(
      action: json['action'] as String,
      player: json['player'] as String,
      playerUuid: json['player_uuid'] as String,
      event: json['event'] as String,
      name: json['name'] as String,
      type: json['type'] as String,
      data: json['data'] as int? ?? 0,
      world: json['world'] as String? ?? "world",
      x: json['x'] as int? ?? 0,
      y: json['y'] as int? ?? 0,
      z: json['z'] as int? ?? 0,
    );
  }
}

/// Represents a custom event message.
class EventMessage {
  final String entityUuid;
  final String sender;
  final String uuid;
  final String message;

  EventMessage({
    required this.entityUuid,
    required this.sender,
    required this.uuid,
    required this.message,
  });

  factory EventMessage.fromJson(Map<String, dynamic> json) {
    return EventMessage(
      entityUuid: json['entityUuid'] as String,
      sender: json['sender'] as String,
      uuid: json['uuid'] as String,
      message: json['message'] as String,
    );
  }
}

/// Represents a chat message from a player.
class ChatMessage {
  final String player;
  final String uuid;
  final String entityUuid;
  final String message;

  ChatMessage({
    required this.player,
    required this.uuid,
    required this.entityUuid,
    required this.message,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      player: json['player'] as String,
      uuid: json['uuid'] as String,
      entityUuid: json['entityUuid'] as String,
      message: json['message'] as String,
    );
  }
}

/// Represents a change in Redstone power.
class RedstonePower {
  final String entityUuid;
  final int oldCurrent;
  final int newCurrent;

  RedstonePower({
    required this.entityUuid,
    required this.oldCurrent,
    required this.newCurrent,
  });

  factory RedstonePower.fromJson(Map<String, dynamic> json) {
    return RedstonePower(
      entityUuid: json['entityUuid'] as String,
      oldCurrent: json['oldCurrent'] as int,
      newCurrent: json['newCurrent'] as int,
    );
  }
}

/// Represents a block in the Minecraft world.
class Block {
  final String name;
  final String type;
  final int data;
  final bool isLiquid;
  final bool isAir;
  final bool isBurnable;
  final bool isFuel;
  final bool isOccluding;
  final bool isSolid;
  final bool isPassable;
  final int x;
  final int y;
  final int z;
  final String world;

  Block({
    required this.name,
    this.type = "block",
    this.data = 0,
    this.isLiquid = false,
    this.isAir = false,
    this.isBurnable = false,
    this.isFuel = false,
    this.isOccluding = false,
    this.isSolid = false,
    this.isPassable = false,
    this.x = 0,
    this.y = 0,
    this.z = 0,
    this.world = "world",
  });

  factory Block.fromJson(Map<String, dynamic> json) {
    return Block(
      name: json['name'] as String,
      type: json['type'] as String? ?? "block",
      data: json['data'] as int? ?? 0,
      isLiquid: json['isLiquid'] as bool? ?? false,
      isAir: json['isAir'] as bool? ?? false,
      isBurnable: json['isBurnable'] as bool? ?? false,
      isFuel: json['isFuel'] as bool? ?? false,
      isOccluding: json['isOccluding'] as bool? ?? false,
      isSolid: json['isSolid'] as bool? ?? false,
      isPassable: json['isPassable'] as bool? ?? false,
      x: json['x'] as int? ?? 0,
      y: json['y'] as int? ?? 0,
      z: json['z'] as int? ?? 0,
      world: json['world'] as String? ?? "world",
    );
  }
}

/// Represents an item stack in an inventory.
class ItemStack {
  final int slot;
  final String name;
  final int amount;

  ItemStack({
    this.slot = 0,
    this.name = "air",
    this.amount = 0,
  });

  factory ItemStack.fromJson(Map<String, dynamic> json) {
    return ItemStack(
      slot: json['slot'] as int? ?? 0,
      name: json['name'] as String? ?? "air",
      amount: json['amount'] as int? ?? 0,
    );
  }
}

// --- WebSocket Client ---
typedef _MessageCallback = void Function(Map<String, dynamic> jsonData);

class _WebSocketClient {
  final _lock = Lock();
  bool _connected = false;
  Completer<dynamic>? _responseCompleter;
  final Map<String, List<_MessageCallback>> _callbacks = {};

  WebSocketChannel? _channel;
  StreamSubscription? _listener;

  String? _host;
  int? _port;
  String? _url;

  dynamic _internalResult;
  dynamic _internalError;

  bool get isConnected => _connected;

  Future<void> connect(String host, int port) async {
    _host = host;
    _port = port;
    _url = "ws://$host:$port/ws";
    _logger.info("Attempting to connect to WebSocket server at '$_url'");
    _connected = false; // Reset connection state

    try {
      _logger.fine("Creating WebSocket channel...");
      _channel = WebSocketChannel.connect(Uri.parse(_url!));
      _logger.fine("WebSocket channel created. Setting up stream listener...");

      // 接続完了を待つCompleter
      final connectionCompleter = Completer<void>();

      // WebSocket接続が確立されたら即座に完了とする
      _connected = true;
      _logger.info("WebSocket connection established.");
      connectionCompleter.complete();

      _listener = _channel!.stream.listen(
        (message) {
          _logger.fine("Received message: $message");
          _onMessage(message);
        },
        onError: (error) {
          _logger.warning("WebSocket stream error: $error");
          _onError(error);
        },
        onDone: () {
          _logger.info("WebSocket stream closed");
          _onClose(_channel?.closeCode,
              _channel?.closeReason ?? "WebSocket connection closed");
        },
        cancelOnError: false,
      );

      _logger.fine("Stream listener set up. Connection is ready.");

      // 接続完了を待つ（タイムアウト付き）
      try {
        await connectionCompleter.future.timeout(
          Duration(seconds: 5),
          onTimeout: () {
            _logger
                .severe("Connection establishment timed out after 5 seconds");
            throw TimeoutException(
                "Connection establishment timed out after 5 seconds");
          },
        );
        _logger.info("Connection establishment completed successfully");
      } catch (e) {
        _logger.severe("Connection establishment failed: $e");
        _connected = false;
        await close();
        rethrow;
      }
    } catch (e) {
      _logger.severe("Failed to create WebSocket channel: $e");
      _connected = false;
      await close(); // Ensure resources are cleaned up if connect fails
      rethrow;
    }
  }

  Future<void> disconnect() async {
    _logger.info("Disconnecting WebSocket client...");
    // Set connected to false immediately, actual cleanup in close()
    final wasConnected = _connected;
    _connected = false;
    _host = null;
    _port = null;
    await close(); // Handles actual closing of channel and listener
    if (wasConnected) {
      _logger.info("WebSocket client disconnected.");
    } else {
      _logger
          .info("WebSocket client was not connected or already disconnected.");
    }
  }

  void setCallback(String eventName, _MessageCallback callbackFunc) {
    _callbacks.putIfAbsent(eventName, () => []).add(callbackFunc);
  }

  void _onMessage(dynamic message) {
    _logger.finer("on_message raw: '$message'");
    try {
      final jsonMessage = jsonDecode(message as String) as Map<String, dynamic>;
      final type = jsonMessage['type'] as String;
      final data = jsonMessage['data'];

      _internalResult = null;
      _internalError = null;

      if (type == 'result') {
        _internalResult = data;
        _responseCompleter?.complete(_internalResult);
      } else if (type == 'error') {
        _internalError = data;
        // Complete with a specific error type for better handling
        _responseCompleter?.completeError(WebSocketMessageError(type, data));
      } else if (type == 'logged') {
        // 'logged' implies connection is fully established from server's perspective
        _connected = true;
        _internalResult = data;
        _responseCompleter?.complete(_internalResult);
      } else if (type == 'attach') {
        _internalResult = data;
        _responseCompleter?.complete(_internalResult);
      } else if (type == 'event') {
        // Event data is expected to be a JSON string itself
        final jsonEvent = jsonDecode(data as String) as Map<String, dynamic>;
        final eventName = jsonEvent['name'] as String;
        final eventData =
            jsonEvent['data']; // This is now a Dart object (Map, List, etc.)

        _logger.fine("on_event: name='$eventName', data='$eventData'");

        bool callbackFired = false;
        if (_callbacks.containsKey(eventName)) {
          final callbacksForEvent = _callbacks[eventName]!;
          if (callbacksForEvent.isNotEmpty) {
            callbackFired = true;
            for (var callback in callbacksForEvent) {
              // Run callbacks asynchronously without awaiting them here
              Future(() => callback(eventData as Map<String, dynamic>));
            }
          }
        }

        // If a specific callback handled it, do not treat as a general response
        if (callbackFired) {
          return;
        }

        // If no specific callback, but event has data, it might be a generic response
        if (eventData != null) {
          _internalResult = eventData;
          if (_responseCompleter != null && !_responseCompleter!.isCompleted) {
            _responseCompleter!.complete(_internalResult);
          }
        }
        return; // End of 'event' type processing
      } else {
        // Default handler for unknown types, treat as a result
        _internalResult = data;
        _responseCompleter?.complete(_internalResult);
      }
    } on FormatException catch (e, s) {
      _logger.severe(
          "JSONDecodeError processing message: '$message'. Error: $e\n$s");
      if (_responseCompleter != null && !_responseCompleter!.isCompleted) {
        // Provide a more specific error to the waiting future
        _responseCompleter!.completeError(
            FormatException("Invalid JSON response: $message", e));
      }
    } catch (e, s) {
      _logger.severe("Error in _onMessage: $e\n$s");
      if (_responseCompleter != null && !_responseCompleter!.isCompleted) {
        _responseCompleter!.completeError(e); // Propagate the error
      }
    }
  }

  void _onError(dynamic error) {
    _logger.warning("on_error: '$error'");
    final wasConnected = _connected;
    _connected = false;
    if (_responseCompleter != null && !_responseCompleter!.isCompleted) {
      _responseCompleter!.completeError(error);
    }
    // Attempt to clean up resources
    _listener?.cancel().catchError((_) {});
    _channel?.sink.close().catchError((_) {});
    _listener = null;
    _channel = null;
    if (wasConnected)
      _logger.info("WebSocket connection dropped due to error.");
  }

  void _onClose(int? closeStatus, String? closeReason) {
    _logger.info("### closed ### Status: $closeStatus, Reason: $closeReason");
    final wasConnected = _connected;
    _connected = false;
    if (_responseCompleter != null && !_responseCompleter!.isCompleted) {
      _responseCompleter!.completeError(StateError(
          "WebSocket connection closed. Code: $closeStatus, Reason: $closeReason"));
    }
    // Resources should be cleaned by listener's onDone or onError already, but ensure:
    _listener = null;
    _channel = null;
    if (wasConnected && closeStatus != null)
      _logger.info("WebSocket connection formally closed.");
  }

  Future<dynamic> send(String message) async {
    _logger.finer("Attempting to send: '$message'");
    if (!_connected) {
      throw UninitializedClientError(
          "Client not connected. Call connect() first.");
    }

    // _lock ensures that `_responseCompleter` is not overwritten by concurrent sends
    // and that `send` operations are serialized for message-response pairing.
    return _lock.synchronized(() async {
      if (!_connected || _channel == null) {
        // Check again after lock acquisition
        throw UninitializedClientError(
            "Client disconnected while message was queued. Cannot send.");
      }
      _responseCompleter = Completer<dynamic>();
      try {
        _logger.finer("Sending to WebSocket: '$message'");
        _channel!.sink.add(message);
        // Wait for the response, with a timeout
        return await _responseCompleter!.future.timeout(Duration(seconds: 30),
            onTimeout: () {
          _logger.warning("Send operation timed out for message: $message");
          if (!_responseCompleter!.isCompleted) {
            _responseCompleter!.completeError(
                TimeoutException("Response timeout for message: $message"));
          }
          throw TimeoutException("Response timeout for message: $message");
        });
      } catch (e) {
        _logger.severe("Error sending message or waiting for response: $e");
        if (!_responseCompleter!.isCompleted) {
          _responseCompleter!.completeError(e);
        }
        rethrow;
      }
    });
  }

  Future<void> close() async {
    // This method ensures that listener and channel are properly closed.
    // It can be called multiple times; subsequent calls should be no-ops.
    if (_listener != null) {
      await _listener!.cancel().catchError((e) {
        _logger.warning("Error cancelling listener during close: $e");
      });
      _listener = null;
    }
    if (_channel != null) {
      await _channel!.sink.close().catchError((e) {
        _logger.warning("Error closing channel sink during close: $e");
      });
      _channel = null;
    }
    _connected = false; // Ensure state reflects closure
    _logger.fine("WebSocket client resources have been requested to close.");
  }

  Future<dynamic> _sendStructured(Map<String, dynamic> messagePayload) async {
    return await send(jsonEncode(messagePayload));
  }

  Future<dynamic> waitFor(String entityUuid, String eventName,
      {Map<String, dynamic>? args}) async {
    Map<String, dynamic> data = {"entity": entityUuid, "name": eventName};
    if (args != null) {
      data['args'] = args;
    }
    Map<String, dynamic> message = {"type": "hook", "data": data};
    return await _sendStructured(message);
  }

  Future<dynamic> sendCall(String entityUuid, String name,
      [List<dynamic>? args]) async {
    Map<String, dynamic> data = {"entity": entityUuid, "name": name};
    if (args != null) {
      data['args'] = args;
    }
    Map<String, dynamic> message = {"type": "call", "data": data};
    return await _sendStructured(message);
  }
}

// --- Player Class ---
class Player {
  final String name;
  final _WebSocketClient _client;

  String? uuid;
  String? world;

  Player(this.name, {_WebSocketClient? client})
      : _client = client ?? _WebSocketClient();

  Future<Player> login(String host, int port) async {
    await _client.connect(host, port);

    final loginPayload = {
      "type": "login",
      "data": {"player": name}
    };
    final result = await _client.send(jsonEncode(loginPayload));

    _logger.fine("Login result for $name: '$result'");

    if (result is Map<String, dynamic>) {
      uuid = result['playerUUID'] as String?;
      world = result['world'] as String?;
      if (uuid == null || world == null) {
        throw StateError("Login response missing playerUUID or world: $result");
      }
    } else {
      throw StateError(
          "Login failed or returned unexpected data type: $result. Expected Map.");
    }
    _logger.info("Player $name (UUID: $uuid) logged in to world $world.");
    return this;
  }

  Future<void> logout() async {
    _logger.info("Player $name logging out...");
    await _client.disconnect();
    uuid = null;
    world = null;
    _logger.info("Player $name logged out.");
  }

  Future<Entity> getEntity(String entityName) async {
    if (!_client.isConnected || world == null) {
      throw UninitializedClientError(
          "Client is not connected or world is unknown. Cannot get entity.");
    }

    final message = {
      "type": "attach",
      "data": {"entity": entityName}
    };
    final result = await _client.send(jsonEncode(message));

    if (result == null) {
      throw ArgumentError(
          "Entity '$entityName' not found or attach failed (received null result).");
    }

    String entityUuidValue;
    if (result is String && result.isNotEmpty) {
      entityUuidValue = result;
    } else if (result is Map<String, dynamic> && result.containsKey('uuid')) {
      entityUuidValue = result['uuid'] as String;
    } else {
      // Fallback if Python code was passing the whole result map as UUID (which is likely a bug there)
      _logger.warning(
          "Attach response for '$entityName' did not directly provide a UUID string or a map with a 'uuid' key. Full response: $result. This might lead to issues.");
      // This case is tricky. If the server expects a string UUID, this will fail later.
      // For robustness, we could throw here or attempt to use result.toString() if server is very flexible.
      throw ArgumentError(
          "Attach response data for '$entityName' does not conform to expected UUID structure. Result: $result");
    }
    _logger
        .fine("Attached to entity '$entityName' with UUID '$entityUuidValue'.");

    final entity = Entity(_client, world!, entityUuidValue);

    // This is a direct send, not sendCall, matching Python's structure for "start"
    await _client.send(jsonEncode({
      "type": "start",
      "data": {"entity": entity.uuid}
    }));
    _logger.fine("Sent 'start' signal for entity ${entity.uuid}.");

    return entity;
  }
}

// --- Inventory Class ---
class Inventory {
  final _WebSocketClient _client;
  final String _entityUuid;
  final Location location;
  final int size;
  final List<ItemStack> items;

  Inventory({
    required _WebSocketClient client,
    required String entityUuid,
    required this.location,
    required this.size,
    required this.items,
  })  : _client = client,
        _entityUuid = entityUuid;

  factory Inventory.fromJson(Map<String, dynamic> json, _WebSocketClient client,
      String entityUuid, String entityWorld) {
    var rawItems = json['items'] as List<dynamic>? ?? [];
    List<ItemStack> parsedItems = rawItems
        .map((itemJson) => ItemStack.fromJson(itemJson as Map<String, dynamic>))
        .toList();

    return Inventory(
      client: client,
      entityUuid: entityUuid,
      location: Location(
        x: json['x'] as int,
        y: json['y'] as int,
        z: json['z'] as int,
        world: json['world'] as String? ??
            entityWorld, // Use inventory's world or entity's as fallback
      ),
      size: json['size'] as int,
      items: parsedItems,
    );
  }

  Future<ItemStack> getItem(int slot) async {
    final result = await _client.sendCall(_entityUuid, "getInventoryItem",
        [location.x, location.y, location.z, slot]);
    // Server might send JSON string or already parsed object (if _WebSocketClient's _onMessage parses it before completing)
    if (result is Map<String, dynamic>) {
      return ItemStack.fromJson(result);
    } else if (result is String && result.isNotEmpty) {
      try {
        return ItemStack.fromJson(jsonDecode(result) as Map<String, dynamic>);
      } catch (e) {
        throw Exception(
            "Failed to get item: result string is not valid JSON. String: '$result', Error: $e");
      }
    }
    throw Exception(
        "Failed to get item, unexpected result type for getItem: $result");
  }

  Future<List<ItemStack>> getAllItems() async {
    List<ItemStack> allItems = [];
    for (int slot = 0; slot < size; slot++) {
      ItemStack item = await getItem(slot);
      if (item.name.toLowerCase() != "air") {
        allItems.add(item);
      }
    }
    return allItems;
  }

  Future<void> swapItems(int slot1, int slot2) async {
    await _client.sendCall(_entityUuid, "swapInventoryItem",
        [location.x, location.y, location.z, slot1, slot2]);
  }

  Future<void> moveItem(int fromSlot, int toSlot) async {
    await _client.sendCall(_entityUuid, "moveInventoryItem",
        [location.x, location.y, location.z, fromSlot, toSlot]);
  }

  Future<void> retrieveFromSelf(int fromChestSlot, int toPlayerSlot) async {
    await _client.sendCall(_entityUuid, "retrieveInventoryItem",
        [location.x, location.y, location.z, toPlayerSlot, fromChestSlot]);
  }

  Future<void> storeToSelf(int fromPlayerSlot, int toChestSlot) async {
    await _client.sendCall(_entityUuid, "storeInventoryItem",
        [location.x, location.y, location.z, fromPlayerSlot, toChestSlot]);
  }
}

// --- Volume Class ---
class Volume {
  final CoordinateData pos1;
  final CoordinateData pos2;

  Volume._(this.pos1, this.pos2);

  factory Volume(
      int x1, int y1, int z1, int x2, int y2, int z2, String coordType) {
    return Volume._(CoordinateData(x1, y1, z1, coordType),
        CoordinateData(x2, y2, z2, coordType));
  }

  static Volume absolute(int x1, int y1, int z1, int x2, int y2, int z2) {
    return Volume(x1, y1, z1, x2, y2, z2, CoordinateType.absolute);
  }

  static Volume relative(int x1, int y1, int z1, int x2, int y2, int z2) {
    return Volume(x1, y1, z1, x2, y2, z2, CoordinateType.relative);
  }

  static Volume local(int x1, int y1, int z1, int x2, int y2, int z2) {
    return Volume(x1, y1, z1, x2, y2, z2, CoordinateType.local);
  }
}

// --- Entity Class ---
typedef EntityEventCallback = void Function(Entity entity, EventMessage event);

class Entity {
  final _WebSocketClient _client;
  final String world;
  final String uuid;

  final List<Location> _positions = [];

  Entity(this._client, this.world, this.uuid);

  Future<void> reset() async {
    await _client.sendCall(uuid, "restoreArea");
  }

  Future<ChatMessage> waitForPlayerChat() async {
    final result = await _client.waitFor(uuid, "onPlayerChat");
    if (result is Map<String, dynamic>) {
      return ChatMessage.fromJson(result);
    }
    throw Exception(
        "waitForPlayerChat received unexpected data type: $result. Expected Map.");
  }

  Future<RedstonePower> waitForRedstoneChange() async {
    final result = await _client.waitFor(uuid, "onEntityRedstone");
    if (result is Map<String, dynamic>) {
      return RedstonePower.fromJson(result);
    }
    throw Exception(
        "waitForRedstoneChange received unexpected data type: $result. Expected Map.");
  }

  Future<Block> waitForBlockBreak() async {
    final result = await _client.waitFor(uuid, "onBlockBreak");
    if (result is Map<String, dynamic>) {
      return Block.fromJson(result);
    }
    throw Exception(
        "waitForBlockBreak received unexpected data type: $result. Expected Map.");
  }

  Future<dynamic> getEventMessage() async {
    final result = await _client.sendCall(uuid, "getEventMessage");
    // Result might be a JSON string or an already parsed object (if server sends complex JSON)
    if (result is String) {
      try {
        return jsonDecode(result); // Attempt to parse if it's a string
      } catch (_) {
        return result; // If not valid JSON, return as raw string
      }
    }
    return result; // If already a Map/List, return as is
  }

  Future<bool> isEventArea(CoordinateData coords) async {
    final result = await _client.sendCall(
        uuid, "isEventArea", [coords.x, coords.y, coords.z, coords.type]);
    return strToBool(result.toString());
  }

  Future<bool> setEventArea(Volume volume) async {
    final pos1 = volume.pos1;
    final pos2 = volume.pos2;
    final result = await _client.sendCall(uuid, "setEventArea",
        [pos1.x, pos1.y, pos1.z, pos2.x, pos2.y, pos2.z, pos1.type]);
    return strToBool(result.toString());
  }

  /// Sets a callback for custom events targeted at this entity.
  void setOnMessage(EntityEventCallback callbackFunc) {
    void callbackWrapper(Map<String, dynamic> data) {
      _logger.finer(
          "Entity $uuid received custom event data via wrapper: '$data'");
      // Ensure the event is for this specific entity instance
      if (data['entityUuid'] == uuid) {
        try {
          final event = EventMessage.fromJson(data);
          callbackFunc(this, event); // Call the user-provided function
        } catch (e, s) {
          _logger.severe(
              "Error processing event message for entity $uuid in callbackWrapper: $e\n$s");
        }
      } else {
        _logger.finer(
            "Custom event data for ${data['entityUuid']}, not for this entity $uuid. Skipping.");
      }
    }

    _client.setCallback('onCustomEvent', callbackWrapper);
  }

  Future<void> sendMessage(String targetEntityName, String message) async {
    await _client.sendCall(uuid, "sendEvent", [targetEntityName, message]);
  }

  Future<void> executeCommand(String command) async {
    await _client.sendCall(uuid, "executeCommand", [command]);
  }

  Future<Inventory> openInventory(int x, int y, int z) async {
    final result = await _client.sendCall(uuid, "openInventory", [x, y, z]);
    Map<String, dynamic> inventoryJson;
    if (result is String && result.isNotEmpty) {
      inventoryJson = jsonDecode(result) as Map<String, dynamic>;
    } else if (result is Map<String, dynamic>) {
      inventoryJson = result;
    } else {
      throw Exception(
          "openInventory received unexpected or empty data: $result");
    }
    return Inventory.fromJson(inventoryJson, _client, uuid, world);
  }

  Future<bool> push() async {
    Location pos = await getLocation();
    _positions.add(pos);
    _logger.finer("Pushed location for $uuid: ${pos.toJson()}");
    return true;
  }

  Future<bool> pop() async {
    if (_positions.isNotEmpty) {
      Location pos = _positions.removeLast();
      _logger.finer("Popping location for $uuid to: ${pos.toJson()}");
      await teleport(pos);
      return true;
    } else {
      _logger
          .warning("Attempted to pop location for $uuid, but stack is empty.");
      return false;
    }
  }

  // Helper for commands that return a boolean
  Future<bool> _simpleBoolCall(String commandName,
      [List<dynamic>? args]) async {
    final result = await _client.sendCall(uuid, commandName, args);
    return strToBool(result.toString());
  }

  // Helper for commands that don't have a specific return value (void)
  Future<void> _simpleVoidCall(String commandName,
      [List<dynamic>? args]) async {
    await _client.sendCall(uuid, commandName, args);
  }

  // Helper for commands that return a parsed object (e.g. Block, ItemStack, Location)
  Future<T> _parsedObjectCall<T>(String commandName, List<dynamic>? args,
      T Function(Map<String, dynamic>) fromJsonFactory) async {
    final result = await _client.sendCall(uuid, commandName, args);
    if (result is Map<String, dynamic>) {
      return fromJsonFactory(result);
    } else if (result is String && result.isNotEmpty) {
      try {
        return fromJsonFactory(jsonDecode(result) as Map<String, dynamic>);
      } catch (e) {
        throw Exception(
            "Command '$commandName' for entity $uuid: result string is not valid JSON. String: '$result', Error: $e");
      }
    }
    throw Exception(
        "Command '$commandName' for entity $uuid received unexpected data type: $result. Expected Map or JSON string.");
  }

  Future<bool> forward({int n = 1}) => _simpleBoolCall("forward", [n]);
  Future<bool> back({int n = 1}) => _simpleBoolCall("back", [n]);
  Future<bool> up({int n = 1}) => _simpleBoolCall("up", [n]);
  Future<bool> down({int n = 1}) => _simpleBoolCall("down", [n]);
  Future<bool> stepLeft({int n = 1}) => _simpleBoolCall("stepLeft", [n]);
  Future<bool> stepRight({int n = 1}) => _simpleBoolCall("stepRight", [n]);

  Future<void> turnLeft() => _simpleVoidCall("turnLeft");
  Future<void> turnRight() => _simpleVoidCall("turnRight");

  Future<bool> makeSound() => _simpleBoolCall("sound");
  Future<bool> addForce(double x, double y, double z) =>
      _simpleBoolCall("addForce", [x, y, z]);
  Future<void> jump() => _simpleVoidCall("jump");
  Future<void> turn(int degrees) => _simpleVoidCall("turn", [degrees]);
  Future<void> facing(int angle) => _simpleVoidCall("facing", [angle]);

  // Filter out null `side` argument before sending
  List<dynamic> _buildPlaceArgs(List<dynamic> baseArgs, String? side) {
    if (side != null) return [...baseArgs, side];
    return baseArgs;
  }

  Future<bool> placeAt(CoordinateData coords, {String? side}) =>
      _simpleBoolCall("placeX",
          _buildPlaceArgs([coords.x, coords.y, coords.z, coords.type], side));

  Future<bool> placeHere(int x, int y, int z, {String? side}) =>
      _simpleBoolCall(
          "placeX", _buildPlaceArgs([x, y, z, CoordinateType.local], side));

  Future<bool> place({String? side}) =>
      _simpleBoolCall("placeFront", side != null ? [side] : null);
  Future<bool> placeUp({String? side}) =>
      _simpleBoolCall("placeUp", side != null ? [side] : null);
  Future<bool> placeDown({String? side}) =>
      _simpleBoolCall("placeDown", side != null ? [side] : null);

  Future<bool> useItemAt(CoordinateData coords) =>
      _simpleBoolCall("useItemX", [coords.x, coords.y, coords.z, coords.type]);

  Future<bool> useItemHere(int x, int y, int z) =>
      _simpleBoolCall("useItemX", [x, y, z, CoordinateType.local]);

  Future<bool> useItem() => _simpleBoolCall("useItemFront");
  Future<bool> useItemUp() => _simpleBoolCall("useItemUp");
  Future<bool> useItemDown() => _simpleBoolCall("useItemDown");

  Future<bool> harvest() =>
      _simpleBoolCall("digX", [0, 0, 0, CoordinateType.local]);
  Future<bool> dig() =>
      _simpleBoolCall("digX", [0, 0, 1, CoordinateType.local]);
  Future<bool> digUp() =>
      _simpleBoolCall("digX", [0, 1, 0, CoordinateType.local]);
  Future<bool> digDown() =>
      _simpleBoolCall("digX", [0, -1, 0, CoordinateType.local]);

  Future<bool> attack() => _simpleBoolCall("attack");

  Future<bool> plantAt(CoordinateData coords) =>
      _simpleBoolCall("plantX", [coords.x, coords.y, coords.z, coords.type]);
  Future<bool> tillAt(CoordinateData coords) =>
      _simpleBoolCall("tillX", [coords.x, coords.y, coords.z, coords.type]);
  Future<bool> flattenAt(CoordinateData coords) =>
      _simpleBoolCall("flattenX", [coords.x, coords.y, coords.z, coords.type]);
  Future<bool> digAt(CoordinateData coords) =>
      _simpleBoolCall("digX", [coords.x, coords.y, coords.z, coords.type]);

  Future<int> pickupItemsAt(CoordinateData coords) async {
    final result = await _client.sendCall(
        uuid, "pickupItemsX", [coords.x, coords.y, coords.z, coords.type]);
    return int.parse(result.toString());
  }

  Future<bool> action() => _simpleBoolCall("actionFront");
  Future<bool> actionUp() => _simpleBoolCall("actionUp");
  Future<bool> actionDown() => _simpleBoolCall("actionDown");

  Future<bool> setItem(int slot, String blockName) =>
      _simpleBoolCall("setItem", [slot, blockName]);

  Future<ItemStack> getItem(int slot) =>
      _parsedObjectCall("getItem", [slot], ItemStack.fromJson);

  Future<bool> swapItem(int slot1, int slot2) =>
      _simpleBoolCall("swapItem", [slot1, slot2]);
  Future<bool> moveItemInInventory(int slot1, int slot2) =>
      _simpleBoolCall("moveItem", [slot1, slot2]);
  Future<bool> dropItem(int slot) => _simpleBoolCall("dropItem", [slot]);
  Future<bool> selectItem(int slot) => _simpleBoolCall("grabItem", [slot]);

  Future<void> say(String message) => _simpleVoidCall("sendChat", [message]);

  Future<Block?> findNearbyBlockAt(
      CoordinateData coords, String blockIdentifier, int maxDepth) async {
    final result = await _client.sendCall(uuid, "findNearbyBlockX",
        [coords.x, coords.y, coords.z, coords.type, blockIdentifier, maxDepth]);
    _logger.finer('findNearbyBlockAt for $uuid received: $result');

    if (result == null) return null; // Explicit null from server

    Map<String, dynamic>? blockJson;
    if (result is Map<String, dynamic>) {
      if (result.isEmpty) return null; // Empty map signifies not found
      blockJson = result;
    } else if (result is String) {
      if (result.isEmpty || result.toLowerCase() == "null")
        return null; // Empty string or "null" string
      try {
        final decoded = jsonDecode(result);
        if (decoded is Map<String, dynamic>) {
          if (decoded.isEmpty) return null; // Decoded to empty map
          blockJson = decoded;
        } else {
          _logger.warning(
              "findNearbyBlockAt for $uuid: decoded string is not a map. Decoded: $decoded");
          return null;
        }
      } on FormatException {
        _logger.warning(
            "findNearbyBlockAt for $uuid received non-JSON string: '$result'");
        return null;
      }
    } else {
      _logger.warning(
          "findNearbyBlockAt for $uuid received unexpected data type: $result");
      return null;
    }
    return Block.fromJson(blockJson);
  }

  Future<Block> inspectAt(CoordinateData coords) => _parsedObjectCall(
      "inspect", [coords.x, coords.y, coords.z, coords.type], Block.fromJson);
  Future<Block> inspectHere(int x, int y, int z) => _parsedObjectCall(
      "inspect", [x, y, z, CoordinateType.local], Block.fromJson);
  Future<Block> inspect() => _parsedObjectCall(
      "inspect", [0, 0, 1, CoordinateType.local], Block.fromJson);
  Future<Block> inspectUp() => _parsedObjectCall(
      "inspect", [0, 1, 0, CoordinateType.local], Block.fromJson);
  Future<Block> inspectDown() => _parsedObjectCall(
      "inspect", [0, -1, 0, CoordinateType.local], Block.fromJson);

  Future<Location> getLocation() =>
      _parsedObjectCall("getPosition", null, Location.fromJson);

  Future<void> teleport(Location location) async {
    await _client.sendCall(
        uuid, "teleport", [location.x, location.y, location.z, location.world]);
  }

  Future<bool> isBlocked() => _simpleBoolCall("isBlockedFront");
  Future<bool> isBlockedUp() => _simpleBoolCall("isBlockedUp");
  Future<bool> isBlockedDown() => _simpleBoolCall("isBlockedDown");

  Future<bool> canDig() => _simpleBoolCall("isCanDigFront");
  Future<bool> canDigUp() => _simpleBoolCall("isCanDigUp");
  Future<bool> canDigDown() => _simpleBoolCall("isCanDigDown");

  Future<double> _getDistanceInternal(String commandName,
      [List<dynamic>? args]) async {
    final result = await _client.sendCall(uuid, commandName, args);
    return double.parse(result.toString());
  }

  Future<double> getDistance() =>
      _getDistanceInternal("getTargetDistanceFront");
  Future<double> getDistanceUp() => _getDistanceInternal("getTargetDistanceUp");
  Future<double> getDistanceDown() =>
      _getDistanceInternal("getTargetDistanceDown");
  Future<double> getDistanceToTarget(String targetUuid) =>
      _getDistanceInternal("getTargetDistance", [targetUuid]);

  Future<Block> getBlockByColor(String hexColor) =>
      _parsedObjectCall("blockColor", [hexColor], Block.fromJson);
}

// --- Example Usage (commented out) ---
/*
void setupLogging() {
  Logger.root.level = Level.ALL; // Adjust level: OFF, SEVERE, WARNING, INFO, CONFIG, FINE, FINER, FINEST, ALL
  Logger.root.onRecord.listen((record) {
    print('${record.time} [${record.level.name}] ${record.loggerName}: ${record.message}');
    if (record.error != null) {
      print('  Error: ${record.error}');
    }
    if (record.stackTrace != null) {
      print('  StackTrace: ${record.stackTrace}');
    }
  });
}

Future<void> main() async {
  setupLogging();
  _logger.info("Starting Dart Minecraft Client example...");

  // Replace with your actual WebSocket server details
  const String serverHost = "localhost"; 
  const int serverPort = 3000; // Default port for some WebSocket servers

  final player = Player("MyDartPlayer");
  try {
    _logger.info("Attempting to log in player: ${player.name} to $serverHost:$serverPort");
    await player.login(serverHost, serverPort);
    _logger.info("Player ${player.name} successfully logged in. UUID: ${player.uuid}, World: ${player.world}");

    // Example: Get an entity (e.g., an agent)
    // Replace "MyAgent" with the actual name of an entity expected by your server
    Entity agent = await player.getEntity("MyAgent"); 
    _logger.info("Successfully got entity '${agent.uuid}' in world '${agent.world}'.");

    Location currentPos = await agent.getLocation();
    _logger.info("Agent '${agent.uuid}' current location: X=${currentPos.x}, Y=${currentPos.y}, Z=${currentPos.z}, World=${currentPos.world}");

    // Example: Make the agent move forward
    bool moved = await agent.forward(n: 2);
    _logger.info("Agent forward(2) command sent. Success: $moved");
    
    Location newPos = await agent.getLocation();
    _logger.info("Agent new location: X=${newPos.x}, Y=${newPos.y}, Z=${newPos.z}");

    // Example: Inspect block in front
    Block blockInFront = await agent.inspect();
    _logger.info("Block in front of agent: Name=${blockInFront.name}, Type=${blockInFront.type}, Solid=${blockInFront.isSolid}");

    // Example of using setOnMessage for custom events
    agent.setOnMessage((entity, event) {
      _logger.info("CUSTOM EVENT for ${entity.uuid}: '${event.message}' from sender '${event.sender}' (UUID: ${event.uuid})");
    });
    _logger.info("Registered onMessage callback for agent. (To test, another entity needs to send a message).");
    // agent.sendMessage("OtherAgentName", "Hello from Dart!"); // Example of sending a message

  } catch (e, s) {
    _logger.severe("An error occurred in the main example: $e", e, s);
  } finally {
    _logger.info("Attempting to log out player: ${player.name}");
    await player.logout();
    _logger.info("Player ${player.name} logged out. Program finished.");
  }
}
*/
