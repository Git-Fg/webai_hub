// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'automation_state_provider.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$AutomationStateData {
  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType && other is AutomationStateData);
  }

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() {
    return 'AutomationStateData()';
  }
}

/// @nodoc
class $AutomationStateDataCopyWith<$Res> {
  $AutomationStateDataCopyWith(
      AutomationStateData _, $Res Function(AutomationStateData) __);
}

/// Adds pattern-matching-related methods to [AutomationStateData].
extension AutomationStateDataPatterns on AutomationStateData {
  /// A variant of `map` that fallback to returning `orElse`.
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case final Subclass value:
  ///     return ...;
  ///   case _:
  ///     return orElse();
  /// }
  /// ```

  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(_Idle value)? idle,
    TResult Function(_Sending value)? sending,
    TResult Function(_Observing value)? observing,
    TResult Function(_Refining value)? refining,
    TResult Function(_Failed value)? failed,
    TResult Function(_NeedsLogin value)? needsLogin,
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _Idle() when idle != null:
        return idle(_that);
      case _Sending() when sending != null:
        return sending(_that);
      case _Observing() when observing != null:
        return observing(_that);
      case _Refining() when refining != null:
        return refining(_that);
      case _Failed() when failed != null:
        return failed(_that);
      case _NeedsLogin() when needsLogin != null:
        return needsLogin(_that);
      case _:
        return orElse();
    }
  }

  /// A `switch`-like method, using callbacks.
  ///
  /// Callbacks receives the raw object, upcasted.
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case final Subclass value:
  ///     return ...;
  ///   case final Subclass2 value:
  ///     return ...;
  /// }
  /// ```

  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(_Idle value) idle,
    required TResult Function(_Sending value) sending,
    required TResult Function(_Observing value) observing,
    required TResult Function(_Refining value) refining,
    required TResult Function(_Failed value) failed,
    required TResult Function(_NeedsLogin value) needsLogin,
  }) {
    final _that = this;
    switch (_that) {
      case _Idle():
        return idle(_that);
      case _Sending():
        return sending(_that);
      case _Observing():
        return observing(_that);
      case _Refining():
        return refining(_that);
      case _Failed():
        return failed(_that);
      case _NeedsLogin():
        return needsLogin(_that);
    }
  }

  /// A variant of `map` that fallback to returning `null`.
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case final Subclass value:
  ///     return ...;
  ///   case _:
  ///     return null;
  /// }
  /// ```

  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(_Idle value)? idle,
    TResult? Function(_Sending value)? sending,
    TResult? Function(_Observing value)? observing,
    TResult? Function(_Refining value)? refining,
    TResult? Function(_Failed value)? failed,
    TResult? Function(_NeedsLogin value)? needsLogin,
  }) {
    final _that = this;
    switch (_that) {
      case _Idle() when idle != null:
        return idle(_that);
      case _Sending() when sending != null:
        return sending(_that);
      case _Observing() when observing != null:
        return observing(_that);
      case _Refining() when refining != null:
        return refining(_that);
      case _Failed() when failed != null:
        return failed(_that);
      case _NeedsLogin() when needsLogin != null:
        return needsLogin(_that);
      case _:
        return null;
    }
  }

  /// A variant of `when` that fallback to an `orElse` callback.
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case Subclass(:final field):
  ///     return ...;
  ///   case _:
  ///     return orElse();
  /// }
  /// ```

  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function()? idle,
    TResult Function()? sending,
    TResult Function()? observing,
    TResult Function(int messageCount)? refining,
    TResult Function()? failed,
    TResult Function()? needsLogin,
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _Idle() when idle != null:
        return idle();
      case _Sending() when sending != null:
        return sending();
      case _Observing() when observing != null:
        return observing();
      case _Refining() when refining != null:
        return refining(_that.messageCount);
      case _Failed() when failed != null:
        return failed();
      case _NeedsLogin() when needsLogin != null:
        return needsLogin();
      case _:
        return orElse();
    }
  }

  /// A `switch`-like method, using callbacks.
  ///
  /// As opposed to `map`, this offers destructuring.
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case Subclass(:final field):
  ///     return ...;
  ///   case Subclass2(:final field2):
  ///     return ...;
  /// }
  /// ```

  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function() idle,
    required TResult Function() sending,
    required TResult Function() observing,
    required TResult Function(int messageCount) refining,
    required TResult Function() failed,
    required TResult Function() needsLogin,
  }) {
    final _that = this;
    switch (_that) {
      case _Idle():
        return idle();
      case _Sending():
        return sending();
      case _Observing():
        return observing();
      case _Refining():
        return refining(_that.messageCount);
      case _Failed():
        return failed();
      case _NeedsLogin():
        return needsLogin();
    }
  }

  /// A variant of `when` that fallback to returning `null`
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case Subclass(:final field):
  ///     return ...;
  ///   case _:
  ///     return null;
  /// }
  /// ```

  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function()? idle,
    TResult? Function()? sending,
    TResult? Function()? observing,
    TResult? Function(int messageCount)? refining,
    TResult? Function()? failed,
    TResult? Function()? needsLogin,
  }) {
    final _that = this;
    switch (_that) {
      case _Idle() when idle != null:
        return idle();
      case _Sending() when sending != null:
        return sending();
      case _Observing() when observing != null:
        return observing();
      case _Refining() when refining != null:
        return refining(_that.messageCount);
      case _Failed() when failed != null:
        return failed();
      case _NeedsLogin() when needsLogin != null:
        return needsLogin();
      case _:
        return null;
    }
  }
}

/// @nodoc

class _Idle implements AutomationStateData {
  const _Idle();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType && other is _Idle);
  }

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() {
    return 'AutomationStateData.idle()';
  }
}

/// @nodoc

class _Sending implements AutomationStateData {
  const _Sending();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType && other is _Sending);
  }

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() {
    return 'AutomationStateData.sending()';
  }
}

/// @nodoc

class _Observing implements AutomationStateData {
  const _Observing();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType && other is _Observing);
  }

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() {
    return 'AutomationStateData.observing()';
  }
}

/// @nodoc

class _Refining implements AutomationStateData {
  const _Refining({required this.messageCount});

  final int messageCount;

  /// Create a copy of AutomationStateData
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$RefiningCopyWith<_Refining> get copyWith =>
      __$RefiningCopyWithImpl<_Refining>(this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _Refining &&
            (identical(other.messageCount, messageCount) ||
                other.messageCount == messageCount));
  }

  @override
  int get hashCode => Object.hash(runtimeType, messageCount);

  @override
  String toString() {
    return 'AutomationStateData.refining(messageCount: $messageCount)';
  }
}

/// @nodoc
abstract mixin class _$RefiningCopyWith<$Res>
    implements $AutomationStateDataCopyWith<$Res> {
  factory _$RefiningCopyWith(_Refining value, $Res Function(_Refining) _then) =
      __$RefiningCopyWithImpl;
  @useResult
  $Res call({int messageCount});
}

/// @nodoc
class __$RefiningCopyWithImpl<$Res> implements _$RefiningCopyWith<$Res> {
  __$RefiningCopyWithImpl(this._self, this._then);

  final _Refining _self;
  final $Res Function(_Refining) _then;

  /// Create a copy of AutomationStateData
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  $Res call({
    Object? messageCount = null,
  }) {
    return _then(_Refining(
      messageCount: null == messageCount
          ? _self.messageCount
          : messageCount // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

/// @nodoc

class _Failed implements AutomationStateData {
  const _Failed();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType && other is _Failed);
  }

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() {
    return 'AutomationStateData.failed()';
  }
}

/// @nodoc

class _NeedsLogin implements AutomationStateData {
  const _NeedsLogin();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType && other is _NeedsLogin);
  }

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() {
    return 'AutomationStateData.needsLogin()';
  }
}

// dart format on
