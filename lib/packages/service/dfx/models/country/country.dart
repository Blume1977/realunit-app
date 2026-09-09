import 'package:equatable/equatable.dart';
import 'package:realunit_wallet/packages/service/dfx/models/country/dto/dfx_country_dto.dart';

class Country extends Equatable {
  final int id;
  final String symbol;
  final String name;
  final String? foreignName;
  // Whether the backend accepts this country as a KYC address/residence
  // country (DTO alias `kycAllowed`, backed by `dfxEnable`). A non-allowed
  // address country is rejected with HTTP 400 on registration submit.
  final bool kycAllowed;
  // Nested wire flag `realunit.taxEnable`. Backend rejects tax residence when
  // this is false; null/true remain selectable in the tax picker.
  final bool? taxEnable;

  const Country({
    required this.id,
    required this.symbol,
    required this.name,
    required this.kycAllowed,
    this.foreignName,
    this.taxEnable,
  });

  @override
  // Deliberately id-keyed: dropdown seeding matches a Country fetched in one
  // epoch against the items list of another, tolerating field drift.
  List<Object?> get props => [id];
}

extension DfxCountryDtoMapper on DfxCountryDto {
  Country toCountry() {
    return Country(
      id: id,
      symbol: symbol,
      name: name,
      foreignName: foreignName,
      kycAllowed: kycAllowed,
      taxEnable: taxEnable,
    );
  }
}
