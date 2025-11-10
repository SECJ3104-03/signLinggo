class ProgressManager {
  static final ProgressManager _instance = ProgressManager._internal();
  factory ProgressManager() => _instance;
  ProgressManager._internal();

  final Set<String> _watchedSigns = {};

  void markAsWatched(String signTitle) {
    _watchedSigns.add(signTitle);
  }

  bool isWatched(String signTitle) {
    return _watchedSigns.contains(signTitle);
  }

  int get totalWatched => _watchedSigns.length;

  Set<String> get watchedSigns => _watchedSigns;
}
