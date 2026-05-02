import 'package:dio/dio.dart';
import 'sanlam_api_service.dart';
import 'api_service.dart';

/// Pulls the full institution list from the Sanlam Member API and pushes
/// it into the local backend (`POST /api/institutions/sanlam-sync`),
/// where it is upserted into the `hospitals` / `pharmacies` tables.
///
/// Returns the backend's sync summary (counts).
class InstitutionSyncService {
  Future<Map<String, dynamic>> syncFromSanlam() async {
    final list = await sanlamApi.searchInstitution();
    if (list.isEmpty) {
      return {'received': 0, 'hospitals_upserted': 0, 'pharmacies_upserted': 0};
    }
    final resp = await dio.post(
      '/institutions/sanlam-sync',
      data: {'institutions': list},
      options: Options(receiveTimeout: const Duration(seconds: 60)),
    );
    return Map<String, dynamic>.from(resp.data as Map);
  }
}

final institutionSyncService = InstitutionSyncService();
