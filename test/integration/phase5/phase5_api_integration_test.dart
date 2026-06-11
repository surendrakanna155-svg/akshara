import 'package:akshara_erp/core/repositories/api/phase5/api_phase5_repositories.dart';
import 'package:akshara_erp/core/repositories/api/phase5/phase5_remote_datasource.dart';
import 'package:akshara_erp/core/repositories/mock/mock_phase5_repositories.dart';
import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_dio_interceptor.dart';

const kQuery = RepositoryQuery.demo;

void main() {
  group('Phase 5 API integration', () {
    late MockParentExperienceRepository mockParent;
    late MockSchoolMemoriesRepository mockMemories;
    late MockAchievementPromotionRepository mockPromotion;
    late Map<String, dynamic> Function(RequestOptions options) responseForRequest;

    setUp(() async {
      mockParent = MockParentExperienceRepository();
      mockMemories = MockSchoolMemoriesRepository();
      mockPromotion = MockAchievementPromotionRepository();

      final hub = await mockParent.getHub(query: kQuery, studentId: 'student_1');
      final events = await mockMemories.listEvents(query: kQuery);
      final event = await mockMemories.getEvent(query: kQuery, eventId: 'evt_1');
      final promotions = await mockPromotion.listPromotions(query: kQuery);
      final created = await mockPromotion.createPromotion(
        query: kQuery,
        achievementType: 'gold_medal',
        title: 'Integration Medal',
      );
      final generated = await mockPromotion.generateAssets(
        query: kQuery,
        promotionId: created.id,
      );
      final presign = await mockMemories.presignUpload(
        query: kQuery,
        eventId: 'evt_1',
        filename: 'photo.jpg',
      );
      final confirm = await mockMemories.confirmUpload(
        query: kQuery,
        eventId: 'evt_1',
        albumId: presign.albumId,
        storagePath: presign.path,
        title: 'Stage photo',
      );

      responseForRequest = (options) {
        final path = options.path;
        if (options.method == 'POST') {
          if (path == '/parent/experience/acknowledge') return {'data': {}};
          if (path == '/promotions') {
            return {
              'data': {
                'id': created.id,
                'achievementType': created.achievementType,
                'title': created.title,
                'status': created.status,
                'assets': created.assets,
                'analytics': created.analytics,
              },
            };
          }
          if (path == '/memories/events/evt_1/upload/presign') {
            return {
              'data': {
                'albumId': presign.albumId,
                'signedUrl': presign.signedUrl,
                'path': presign.path,
                'mediaType': presign.mediaType,
              },
            };
          }
          if (path == '/memories/events/evt_1/upload/confirm') {
            return {
              'data': {
                'id': confirm.mediaId,
                'shareToken': confirm.shareToken,
                'downloadUrl': confirm.downloadUrl,
              },
            };
          }
          if (path.endsWith('/generate')) {
            return {
              'data': {
                'id': generated.id,
                'achievementType': generated.achievementType,
                'title': generated.title,
                'status': generated.status,
                'assets': generated.assets,
                'analytics': generated.analytics,
              },
            };
          }
          if (path == '/promotions/promo_1/track') return {'data': {'tracked': 'views'}};
          return {'data': {}};
        }
        return switch (path) {
          '/parent/experience/hub' => {
              'data': {
                'studentId': hub.studentId,
                'overview': {
                  'childName': hub.overview.childName,
                  'classLabel': hub.overview.classLabel,
                  'riskLevel': hub.overview.riskLevel,
                  'riskScore': hub.overview.riskScore,
                  'pendingInventoryAcks': hub.overview.pendingInventoryAcks,
                  'pendingPaymentRequests': hub.overview.pendingPaymentRequests,
                },
                'academics': {
                  'homeworkSubmitted': hub.academics.homeworkSubmitted,
                  'homeworkTotal': hub.academics.homeworkTotal,
                  'recentExams': [],
                },
                'attendance': {
                  'present': hub.attendance.present,
                  'absent': hub.attendance.absent,
                  'total': hub.attendance.total,
                  'pct': hub.attendance.pct,
                },
                'inventory': {
                  'issued': hub.inventory.issued,
                  'pending': hub.inventory.pending,
                  'items': [],
                },
                'communication': {
                  'recentCount': hub.communication.recentCount,
                  'lastMessageAt': hub.communication.lastMessageAt,
                },
                'guidance': {
                  'available': hub.guidance.available,
                  'summary': hub.guidance.summary,
                  'reports': [
                    for (final r in hub.guidance.reports)
                      {'mode': r.mode, 'summary': r.summary, 'createdAt': r.createdAt},
                  ],
                },
                'homeworkIntelligence': {
                  'weakTopics': hub.homeworkIntelligence.weakTopics,
                  'suggestedRevision': hub.homeworkIntelligence.suggestedRevision,
                  'teacherRecommendations': hub.homeworkIntelligence.teacherRecommendations,
                },
              },
            },
          '/memories/events' => {
              'data': {
                'items': [
                  for (final e in events)
                    {
                      'id': e.id,
                      'title': e.title,
                      'category': e.category,
                      'eventDate': e.eventDate,
                      'status': e.status,
                    },
                ],
              },
            },
          '/memories/events/evt_1' => {
              'data': {
                'id': event.id,
                'title': event.title,
                'category': event.category,
                'eventDate': event.eventDate,
                'status': event.status,
                'albums': [
                  for (final a in event.albums)
                    {
                      'id': a.id,
                      'title': a.title,
                      'mediaCount': a.mediaCount,
                      'media': [
                        for (final m in a.media)
                          {
                            'id': m.id,
                            'title': m.title,
                            'mediaType': m.mediaType,
                            'storageUrl': m.storageUrl,
                          },
                      ],
                    },
                ],
              },
            },
          '/memories/media/med_1/download' => {
              'data': {'downloadUrl': 'https://storage.test/med_1'},
            },
          '/memories/share/share_demo_1' => {
              'data': {
                'mediaId': 'med_1',
                'eventId': 'evt_1',
                'downloadUrl': 'https://storage.test/share',
              },
            },
          '/promotions' => {
              'data': {
                'items': [
                  for (final p in promotions)
                    {
                      'id': p.id,
                      'achievementType': p.achievementType,
                      'title': p.title,
                      'status': p.status,
                      'assets': p.assets,
                      'analytics': p.analytics,
                    },
                ],
              },
            },
          _ => {'data': {}},
        };
      };
    });

    test('parent experience hub remote parity', () async {
      final remote = Phase5RemoteDataSource(createFakeDio(responseForRequest));
      final repo = ApiParentExperienceRepository(remote: remote);
      final hub = await repo.getHub(query: kQuery, studentId: 'student_1');
      expect(hub.guidance.reports.length, greaterThanOrEqualTo(3));
      expect(hub.homeworkIntelligence.weakTopics, isNotEmpty);
    });

    test('memories upload and download remote parity', () async {
      final remote = Phase5RemoteDataSource(createFakeDio(responseForRequest));
      final repo = ApiSchoolMemoriesRepository(remote: remote);
      final presign = await repo.presignUpload(
        query: kQuery,
        eventId: 'evt_1',
        filename: 'photo.jpg',
      );
      expect(presign.signedUrl, isNotEmpty);
      final confirm = await repo.confirmUpload(
        query: kQuery,
        eventId: 'evt_1',
        albumId: presign.albumId,
        storagePath: presign.path,
        title: 'Stage photo',
      );
      expect(confirm.shareToken, isNotEmpty);
      final url = await repo.getDownloadUrl(query: kQuery, mediaId: 'med_1');
      expect(url, contains('storage'));
      final share = await repo.resolveShareLink(query: kQuery, shareToken: 'share_demo_1');
      expect(share.eventId, 'evt_1');
    });

    test('promotion generate and track remote parity', () async {
      final remote = Phase5RemoteDataSource(createFakeDio(responseForRequest));
      final repo = ApiAchievementPromotionRepository(remote: remote);
      final created = await repo.createPromotion(
        query: kQuery,
        achievementType: 'gold_medal',
        title: 'Integration Medal',
      );
      expect(created.status, 'draft');
      final generated = await repo.generateAssets(
        query: kQuery,
        promotionId: created.id,
      );
      expect(generated.status, 'pending_approval');
      await repo.trackMetric(
        query: kQuery,
        promotionId: 'promo_1',
        metric: 'views',
      );
    });
  });
}
