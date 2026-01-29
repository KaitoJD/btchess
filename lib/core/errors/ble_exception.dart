import 'app_exception.dart';

class BleException extends AppException {
  const BleException(
    super.message,
    {
      super.code,
      super.originalError,
      super.stackTrace,
    }
  );
}

class BleConnectionException extends BleException {
  const BleConnectionException(
    super.message,
    {
      super.code,
      super.originalError,
    }
  );
}

class BleTimeoutException extends BleException {
  const BleTimeoutException(
    super.message,
    {
      required this.timeout,
      super.code,
    }
  );

  final Duration timeout;

  @override
  String toString() => 'BleTimeoutException: $message (timeout: ${timeout.inMilliseconds}ms)';
}

class BleProtocolException extends BleException {
  const BleProtocolException(
    super.message,
    {
      this.errorCode,
      super.code,
    }
  );

  final int? errorCode;

  @override
  String toString() => 'BleProtocolException: $message${errorCode != null ? ' (error: 0x${errorCode!.toRadixString(16)})' : ''}';
}

class BlePermissionException extends BleException {
  const BlePermissionException(
    super.message,
    {
      super.code,
    }
  );
}

class BleNotAvailableException extends BleException {
  const BleNotAvailableException(
    super.message,
    {
      super.code,
    }
  );
}

class BleDisconnectedException extends BleException {
  const BleDisconnectedException(
    super.message,
    {
      super.code,
    }
  );
}

class BleMessageException extends BleException {
  const BleMessageException(
    super.message,
    {
      super.code,
    }
  );
}