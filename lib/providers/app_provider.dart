import 'package:flutter/foundation.dart';
import '../models/device.dart';
import '../services/api_service.dart';

class AppProvider extends ChangeNotifier {
  final ApiService api = ApiService();

  bool isLoading = false;
  String? error;
  List<Device> devices = [];
  Device? selectedDevice;
  Map<String, dynamic>? userData;
  List<Map<String, dynamic>> events = [];
  List<Map<String, dynamic>> alerts = [];
  List<Map<String, dynamic>> geofences = [];
  Map<String, dynamic>? historyData;

  // Dashboard stats
  int totalVehicles = 0;
  int onlineCount = 0;
  int offlineCount = 0;
  int idleCount = 0;
  int alertsCount = 0;

  Future<void> init() async {
    await api.init();
  }

  Future<bool> login(String email, String password) async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      await api.login(email, password);
      await loadDashboard();
      isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      error = e.toString().replaceAll('Exception: ', '');
      isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    await api.logout();
    devices = [];
    selectedDevice = null;
    userData = null;
    events = [];
    notifyListeners();
  }

  Future<void> loadDashboard() async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      final groups = await api.getDevices();
      final flat = api.flattenDevices(groups);
      devices = flat.map((e) => Device.fromJson(e)).toList();

      totalVehicles = devices.length;
      onlineCount = devices.where((d) => d.isOnline).length;
      offlineCount = devices.where((d) => !d.isOnline).length;
      idleCount = devices.where((d) => d.isOnline && !d.isMoving).length;

      try {
        userData = await api.getUserData();
      } catch (_) {}

      try {
        final eventsRes = await api.getEvents(limit: 30);
        if (eventsRes['items'] != null && eventsRes['items']['data'] is List) {
          events = List<Map<String, dynamic>>.from(eventsRes['items']['data']);
          alertsCount = events.length;
        }
      } catch (_) {}

      isLoading = false;
      notifyListeners();
    } catch (e) {
      error = e.toString();
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refreshDevices() async {
    try {
      final groups = await api.getDevices();
      final flat = api.flattenDevices(groups);
      devices = flat.map((e) => Device.fromJson(e)).toList();
      totalVehicles = devices.length;
      onlineCount = devices.where((d) => d.isOnline).length;
      offlineCount = devices.where((d) => !d.isOnline).length;
      idleCount = devices.where((d) => d.isOnline && !d.isMoving).length;
      notifyListeners();
    } catch (e) {
      error = e.toString();
      notifyListeners();
    }
  }

  void selectDevice(Device device) {
    selectedDevice = device;
    notifyListeners();
  }

  Future<void> loadGeofences() async {
    try {
      final res = await api.getGeofences();
      if (res['items'] != null && res['items']['geofences'] is List) {
        geofences = List<Map<String, dynamic>>.from(res['items']['geofences']);
      }
      notifyListeners();
    } catch (e) {
      error = e.toString();
      notifyListeners();
    }
  }

  Future<void> loadHistory({
    required int deviceId,
    required String fromDate,
    required String fromTime,
    required String toDate,
    required String toTime,
  }) async {
    isLoading = true;
    notifyListeners();
    try {
      historyData = await api.getHistory(
        deviceId: deviceId,
        fromDate: fromDate,
        fromTime: fromTime,
        toDate: toDate,
        toTime: toTime,
      );
      isLoading = false;
      notifyListeners();
    } catch (e) {
      error = e.toString();
      isLoading = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>?> loadCommandData() async {
    try {
      return await api.getSendCommandData();
    } catch (e) {
      error = e.toString();
      notifyListeners();
      return null;
    }
  }

  Future<bool> sendCommand({
    required int deviceId,
    required String type,
    String? message,
    int? templateId,
  }) async {
    try {
      await api.sendCommand(
        deviceId: deviceId,
        type: type,
        message: message,
        templateId: templateId,
      );
      return true;
    } catch (e) {
      error = e.toString();
      notifyListeners();
      return false;
    }
  }
}
