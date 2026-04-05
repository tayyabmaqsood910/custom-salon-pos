enum LicenseGateState {
  notActivated,
  active,
  expired,
  deactivated,
  onlineCheckRequired,
}

class LocalLicense {
  const LocalLicense({
    required this.shopId,
    required this.activationKey,
    required this.clientName,
    required this.clientPhone,
    required this.expiryDate,
    required this.status,
    required this.lastOnlineCheck,
  });

  final String shopId;
  final String activationKey;
  final String clientName;
  final String clientPhone;
  final DateTime expiryDate;
  final String status;
  final DateTime? lastOnlineCheck;

  bool get isActiveStatus => status.toLowerCase() == 'active';
}

class LicenseGateResult {
  const LicenseGateResult({
    required this.state,
    this.license,
    this.message,
  });

  final LicenseGateState state;
  final LocalLicense? license;
  final String? message;
}
