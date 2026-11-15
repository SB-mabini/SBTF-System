import 'form_request.dart';
import 'franchise_application.dart';
import 'franchise_record.dart';

/// Everything a renewal can reuse from the driver's own records.
///
/// A renewal is filed through the same two screens as a new franchise: the
/// request form (letter data, CTC, OR/CR, signature) and the application
/// wizard. Both screens call this class so the wording and the fallback order
/// stay identical: the newest available value wins, starting with the previous
/// application, then the request that produced it, then the franchise record.
///
/// It is deliberately read-only and side-effect free: prefill is a convenience,
/// never a source of truth. The driver edits anything that changed, and the
/// server still validates the submitted values.
class RenewalPrefill {
  const RenewalPrefill({
    required this.record,
    this.application,
    this.request,
  });

  /// The franchise being renewed.
  final FranchiseRecord record;

  /// The application that created [record], when it could be read.
  final FranchiseApplication? application;

  /// The approved request that produced [application], when it could be read.
  final FormRequest? request;

  String get franchiseNumber => record.franchiseNumber;

  /// A ready-to-edit purpose line for the request form.
  String get purpose => 'Renewal of franchise $franchiseNumber';

  String get plateNumber => _firstText(
      [application?.plateNumber, request?.plateNumber, record.plateNumber]);

  String get vehicleMake => _firstText(
      [application?.vehicleMake, request?.vehicleMake, record.vehicleMake]);

  String get vehicleModel => _firstText(
      [application?.vehicleModel, request?.vehicleModel, record.vehicleModel]);

  String get engineNumber =>
      _firstText([application?.engineNumber, request?.engineNumber]);

  String get chassisNumber =>
      _firstText([application?.chassisNumber, request?.chassisNumber]);

  String get crNumber => _firstText([request?.crNumber]);

  String get ctcNumber =>
      _firstText([application?.ctcNumber, request?.ctcNumber]);

  int? get vehicleYear {
    final year = application?.vehicleYear;
    return year != null && year > 0 ? year : record.vehicleYear;
  }

  String get vehicleColor => _firstText([application?.vehicleColor]);

  int? get seatingCapacity => application?.seatingCapacity;

  String get mtopNumber => _firstText([application?.mtopNumber]);

  String get bodyNumber => _firstText([application?.bodyNumber]);

  String get todaId =>
      _firstText([application?.todaId, request?.todaId, record.todaId]);

  String get addressLine => _firstText([application?.operatorAddressLine]);

  String get barangayCode => _firstText([application?.operatorBarangayCode]);

  String get appliedRoute => _firstText([application?.appliedRoute]);

  String get registeredOwner => _firstText([application?.registeredOwner]);

  String get ownershipType {
    final value = _firstText([application?.ownershipType]);
    return value.isEmpty ? 'single_proprietorship' : value;
  }

  String get citizenship {
    final value = _firstText([application?.operatorCitizenship]);
    return value.isEmpty ? 'Filipino' : value;
  }

  /// True when every vehicle-identity field could be recovered. The request
  /// form uses this to decide whether to tell the driver what is still missing.
  bool get hasVehicleIdentity =>
      plateNumber.isNotEmpty &&
      vehicleMake.isNotEmpty &&
      vehicleModel.isNotEmpty &&
      engineNumber.isNotEmpty &&
      chassisNumber.isNotEmpty;
}

String _firstText(List<String?> values) {
  for (final value in values) {
    final text = value?.trim();
    if (text != null && text.isNotEmpty) return text;
  }
  return '';
}
