// lib/adafruit_mqtt_service.dart
//
// Adafruit IO over MQTT (TLS, port 8883).
//
// Emits the RAW sensor value, not a percentage. The dashboard converts to
// percent at paint time using current calibration, so editing the dry/wet
// endpoints updates the gauge immediately instead of waiting for the sensor
// to publish again -- which matters a lot when you're calibrating.

import 'dart:async';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'app_settings.dart';

enum ConnectionStatus { disconnected, connecting, connected, error }

class AdafruitMqttService {
  final AppSettings settings;
  MqttServerClient? _client;
  bool _disposed = false;

  final _rawController = StreamController<double>.broadcast();
  final _pumpController = StreamController<String>.broadcast();
  final _statusController = StreamController<ConnectionStatus>.broadcast();
  final _errorController = StreamController<String>.broadcast();

  Stream<double> get rawMoistureStream => _rawController.stream;
  Stream<String> get pumpStateStream => _pumpController.stream;
  Stream<ConnectionStatus> get statusStream => _statusController.stream;
  Stream<String> get errorStream => _errorController.stream;

  AdafruitMqttService(this.settings);

  String get _moistureTopic =>
      '${settings.aioUsername}/feeds/${settings.moistureFeedKey}';
  String get _pumpTopic =>
      '${settings.aioUsername}/feeds/${settings.pumpFeedKey}';

  bool get isConnected =>
      _client?.connectionStatus?.state == MqttConnectionState.connected;

  Future<void> connect() async {
    if (_disposed) return;

    if (settings.aioUsername.trim().isEmpty ||
        settings.aioKey.trim().isEmpty) {
      _statusController.add(ConnectionStatus.error);
      _errorController.add(
        'Adafruit username or key is empty. Open Settings to add them.',
      );
      return;
    }

    _statusController.add(ConnectionStatus.connecting);

    // Tear down any previous client before starting a new one, otherwise
    // changing a feed key leaves a zombie subscription alive.
    try {
      _client?.disconnect();
    } catch (_) {}
    _client = null;

    final clientId = 'ms_${DateTime.now().millisecondsSinceEpoch}';
    final client = MqttServerClient.withPort(
      'io.adafruit.com',
      clientId,
      8883,
    );
    client.secure = true;
    client.keepAlivePeriod = 30;
    client.autoReconnect = true;
    client.logging(on: false);

    client.onConnected = () {
      if (_disposed) return;
      _statusController.add(ConnectionStatus.connected);
    };
    client.onDisconnected = () {
      if (_disposed) return;
      _statusController.add(ConnectionStatus.disconnected);
    };
    client.onAutoReconnect = () {
      if (_disposed) return;
      _statusController.add(ConnectionStatus.connecting);
    };
    client.onAutoReconnected = () {
      if (_disposed) return;
      _statusController.add(ConnectionStatus.connected);
      _subscribe(client);
    };

    client.connectionMessage = MqttConnectMessage()
        .authenticateAs(settings.aioUsername.trim(), settings.aioKey.trim())
        .withClientIdentifier(clientId)
        .startClean();

    _client = client;

    try {
      await client.connect(
        settings.aioUsername.trim(),
        settings.aioKey.trim(),
      );
    } catch (e) {
      if (_disposed) return;
      _statusController.add(ConnectionStatus.error);
      _errorController.add('Connection failed: $e');
      try {
        client.disconnect();
      } catch (_) {}
      return;
    }

    if (_disposed) return;

    if (client.connectionStatus?.state == MqttConnectionState.connected) {
      _statusController.add(ConnectionStatus.connected);
      _subscribe(client);
      _listen(client);
    } else {
      _statusController.add(ConnectionStatus.error);
      _errorController.add(
        'Broker refused the connection. Check your AIO key.',
      );
    }
  }

  void _subscribe(MqttServerClient client) {
    client.subscribe(_moistureTopic, MqttQos.atMostOnce);
    client.subscribe(_pumpTopic, MqttQos.atMostOnce);
  }

  void _listen(MqttServerClient client) {
    client.updates?.listen((events) {
      if (_disposed || events.isEmpty) return;
      final msg = events.first;
      final pub = msg.payload;
      if (pub is! MqttPublishMessage) return;

      final payload =
          MqttPublishPayload.bytesToStringAsString(pub.payload.message).trim();

      if (msg.topic == _moistureTopic) {
        final v = double.tryParse(payload);
        if (v != null) _rawController.add(v);
      } else if (msg.topic == _pumpTopic) {
        _pumpController.add(payload);
      }
    });
  }

  void publishPumpState(String value) {
    final client = _client;
    if (client == null ||
        client.connectionStatus?.state != MqttConnectionState.connected) {
      _errorController.add('Not connected -- cannot send pump command.');
      return;
    }
    final builder = MqttClientPayloadBuilder()..addString(value);
    client.publishMessage(_pumpTopic, MqttQos.atLeastOnce, builder.payload!);
  }

  Future<void> reconnect() => connect();

  void dispose() {
    _disposed = true;
    try {
      _client?.disconnect();
    } catch (_) {}
    _rawController.close();
    _pumpController.close();
    _statusController.close();
    _errorController.close();
  }
}
