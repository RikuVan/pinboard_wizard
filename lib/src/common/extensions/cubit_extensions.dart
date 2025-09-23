import 'package:flutter_bloc/flutter_bloc.dart';

/// Extension on Cubit to provide safe state emission
///
/// This prevents the "Cannot emit new states after calling close" error
/// that can occur when async operations complete after a cubit has been disposed.
extension CubitX<T> on Cubit<T> {
  /// Safely emit a new state, only if the cubit hasn't been closed
  void safeEmit(T state) {
    if (isClosed) return;
    emit(state);
  }
}
