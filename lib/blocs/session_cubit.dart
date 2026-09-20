import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:momentum/blocs/session_state.dart';

/// Owns jwtToken/userId, set once per login and cleared once per logout.
class SessionCubit extends Cubit<SessionState> {
  SessionCubit() : super(const SessionState());

  void setSession({required String jwtToken, required String userId}) {
    emit(SessionState(jwtToken: jwtToken, userId: userId));
  }

  void clear() {
    emit(const SessionState());
  }
}
