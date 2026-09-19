import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:momentum/blocs/session_state.dart';

/// Owns jwtToken/userId — everything outside TaskBloc that used to read
/// db.jwtToken/db.userId directly reads this instead. Set once per login
/// (from TaskBloc.setSession, called as part of TaskSessionStarted) and
/// cleared once per logout (from TaskBloc's TaskDataCleared handler).
class SessionCubit extends Cubit<SessionState> {
  SessionCubit() : super(const SessionState());

  void setSession({required String jwtToken, required String userId}) {
    emit(SessionState(jwtToken: jwtToken, userId: userId));
  }

  void clear() {
    emit(const SessionState());
  }
}
