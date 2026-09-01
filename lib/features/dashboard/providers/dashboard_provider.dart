import 'package:flutter_riverpod/flutter_riverpod.dart';

// Placeholder for dashboard state management
class DashboardState {
  final bool isLoading;
  final String? error;
  final Map<String, dynamic>? userData;

  const DashboardState({this.isLoading = false, this.error, this.userData});

  DashboardState copyWith({
    bool? isLoading,
    String? error,
    Map<String, dynamic>? userData,
  }) {
    return DashboardState(
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
      userData: userData ?? this.userData,
    );
  }
}

class DashboardNotifier extends StateNotifier<DashboardState> {
  DashboardNotifier() : super(const DashboardState());

  void loadUserData(Map<String, dynamic>? userData) {
    state = state.copyWith(userData: userData);
  }

  void setLoading(bool loading) {
    state = state.copyWith(isLoading: loading);
  }

  void setError(String? error) {
    state = state.copyWith(error: error);
  }
}

final dashboardProvider =
    StateNotifierProvider<DashboardNotifier, DashboardState>(
      (ref) => DashboardNotifier(),
    );
