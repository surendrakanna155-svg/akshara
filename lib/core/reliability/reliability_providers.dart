import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/dio_provider.dart';
import 'connectivity/connectivity_service.dart';
import 'connectivity/connectivity_service_impl.dart';
import 'policy/operation_policy_registry.dart';
import 'reliable_writer.dart';
import 'store/in_memory_reliability_store.dart';
import 'store/reliability_store.dart';
import 'sync/dio_mutation_executor.dart';
import 'sync/mutation_executor.dart';
import 'sync/mutation_gateway.dart';
import 'sync/sync_engine.dart';
import 'sync_center/sync_center_controller.dart';

/// Durable local store for drafts + outbox.
///
/// Defaults to in-memory so the platform is inert-but-safe before bootstrap.
/// Production wiring overrides this at app start with the encrypted SQLite
/// store: `reliabilityStoreProvider.overrideWithValue(await SqfliteReliabilityStore.open())`.
final Provider<ReliabilityStore> reliabilityStoreProvider =
    Provider<ReliabilityStore>((ref) => InMemoryReliabilityStore());

/// REL-8 — true when the durable encrypted store failed to open and the app
/// fell back to a NON-DURABLE in-memory store this session (drafts + queued
/// writes will not survive a restart). Defaults to healthy; `main.dart`
/// overrides it from the boot-time [openReliabilityStore] result so the Sync
/// Center / telemetry can surface the downgrade instead of it being silent.
final Provider<bool> reliabilityStoreDegradedProvider =
    Provider<bool>((ref) => false);

/// The single, centralized declaration of every operation's reliability
/// behaviour (refinement R4). New modules add one entry here — no offline code.
final Provider<OperationPolicyRegistry> operationPolicyRegistryProvider =
    Provider<OperationPolicyRegistry>(
        (ref) => OperationPolicyRegistry.withDefaults());

final Provider<ConnectivityService> connectivityServiceProvider =
    Provider<ConnectivityService>((ref) {
  final ConnectivityServiceImpl service = ConnectivityServiceImpl();
  ref.onDispose(service.dispose);
  return service;
});

final Provider<MutationExecutor> mutationExecutorProvider =
    Provider<MutationExecutor>(
        (ref) => DioMutationExecutor(ref.watch(dioProvider)));

/// The universal write choke point. Every queueable write goes through this.
final Provider<MutationGateway> mutationGatewayProvider =
    Provider<MutationGateway>((ref) {
  return MutationGateway(
    registry: ref.watch(operationPolicyRegistryProvider),
    executor: ref.watch(mutationExecutorProvider),
    store: ref.watch(reliabilityStoreProvider),
    connectivity: ref.watch(connectivityServiceProvider),
  );
});

final Provider<SyncEngine> syncEngineProvider = Provider<SyncEngine>((ref) {
  final SyncEngine engine = SyncEngine(
    store: ref.watch(reliabilityStoreProvider),
    executor: ref.watch(mutationExecutorProvider),
    connectivity: ref.watch(connectivityServiceProvider),
    registry: ref.watch(operationPolicyRegistryProvider),
  );
  engine.start();
  ref.onDispose(engine.dispose);
  return engine;
});

/// The seam repositories/notifiers call to perform a write through the platform.
final Provider<ReliableWriter> reliableWriterProvider =
    Provider<ReliableWriter>((ref) => ReliableWriter(ref.watch(mutationGatewayProvider)));

final ChangeNotifierProvider<SyncCenterController> syncCenterControllerProvider =
    ChangeNotifierProvider<SyncCenterController>((ref) {
  return SyncCenterController(
    store: ref.watch(reliabilityStoreProvider),
    connectivity: ref.watch(connectivityServiceProvider),
    engine: ref.watch(syncEngineProvider),
    durabilityDegraded: ref.watch(reliabilityStoreDegradedProvider),
  );
});
