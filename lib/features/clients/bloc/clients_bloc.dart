import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../models/client.dart';
import '../../../shared/data/appointment_repository.dart';

// --- Events ---
abstract class ClientsEvent {}

class ClientsSubscriptionRequested extends ClientsEvent {}

class ClientsAddClient extends ClientsEvent {
  final Client client;
  ClientsAddClient(this.client);
}

class ClientsUpdateClient extends ClientsEvent {
  final Client client;
  ClientsUpdateClient(this.client);
}

class ClientsDeleteClient extends ClientsEvent {
  final int clientId;
  ClientsDeleteClient(this.clientId);
}

class ClientsImportCsv extends ClientsEvent {}

class ClientsConfirmConflictResolution extends ClientsEvent {
  final List<Client> selectedResolvedClients;
  final List<Client> safeClients;
  ClientsConfirmConflictResolution(this.selectedResolvedClients, this.safeClients);
}

// --- States ---
abstract class ClientsState {}

class ClientsLoading extends ClientsState {}

class ClientsLoaded extends ClientsState {
  final List<Client> clients;
  ClientsLoaded(this.clients);
}

class ClientsOperationSuccess extends ClientsState {
  final String message;
  ClientsOperationSuccess(this.message);
}

class ClientsError extends ClientsState {
  final String message;
  ClientsError(this.message);
}

class ClientsImportConflict extends ClientsState {
  final List<Client> conflictingClients;
  final List<Client> safeClients;
  ClientsImportConflict(this.conflictingClients, this.safeClients);
}

// --- BLoC ---
class ClientsBloc extends Bloc<ClientsEvent, ClientsState> {
  final AppointmentRepository _repository;
  StreamSubscription? _clientSub;

  ClientsBloc({required AppointmentRepository repository})
      : _repository = repository,
        super(ClientsLoading()) {
    on<ClientsSubscriptionRequested>(_onSubscriptionRequested);
    on<ClientsAddClient>(_onAddClient);
    on<ClientsImportCsv>(_onImportCsv);
    on<ClientsConfirmConflictResolution>(_onConfirmConflictResolution);
    on<_ClientsUpdatedList>(_onClientsUpdatedList);
    on<ClientsUpdateClient>(_onUpdateClient);
    on<ClientsDeleteClient>(_onDeleteClient);
  }

  Future<void> _onSubscriptionRequested(
      ClientsSubscriptionRequested event, Emitter<ClientsState> emit) async {
    emit(ClientsLoading());
    await _clientSub?.cancel();
    _clientSub = _repository.getClients().listen((clients) {
      if (!isClosed) {  // Safety check
         add(_ClientsUpdatedList(clients));
      }
    });
  }

  // Internal event to handle stream updates
  Future<void> _onClientsUpdatedList(
      _ClientsUpdatedList event, Emitter<ClientsState> emit) async {
    emit(ClientsLoaded(event.clients));
  }

  Future<void> _onAddClient(
      ClientsAddClient event, Emitter<ClientsState> emit) async {
    try {
      // Validation is handled in UI or Repo. Repo handles uniqueness exception.
      final currentState = state;
      List<Client> currentClients = [];
      if (currentState is ClientsLoaded) {
        currentClients = currentState.clients;
      }

      await _repository.validateEmailUniqueness(event.client.email, currentClients);
      await _repository.addClient(event.client);
      
      emit(ClientsOperationSuccess('Client registered successfully!'));
      
      // Re-emit loaded state after success message (or let stream handle it)
      // We rely on the stream to push the new list, so we don't manually emit Loaded here immediately
      // The validation error should intercept before this.
    } catch (e) {
      emit(ClientsError(e.toString().replaceAll("Exception: ", "")));
      // After showing error, we might want to return to Loaded state or let UI handle the transient error
      if (state is ClientsLoaded) {
         // Optionally maintain the list in the background or just show error
      }
    }
  }

  Future<void> _onImportCsv(
      ClientsImportCsv event, Emitter<ClientsState> emit) async {
    try {
      final result = await _repository.analyzeCsvImport();
      
      if (result.errorMessage != null) {
        emit(ClientsError(result.errorMessage!));
        return;
      }

      if (result.conflictingClients.isNotEmpty) {
        emit(ClientsImportConflict(result.conflictingClients, result.safeClients));
      } else {
         if (result.safeClients.isNotEmpty) {
            await _repository.saveImportedClients(result.safeClients);
            emit(ClientsOperationSuccess('Imported ${result.safeClients.length} clients successfully. ${result.emailDuplicatesSkipped > 0 ? "Skipped ${result.emailDuplicatesSkipped} email duplicates." : ""}'));
         } else {
            emit(ClientsOperationSuccess('No new clients imported. ${result.emailDuplicatesSkipped > 0 ? "Skipped ${result.emailDuplicatesSkipped} email duplicates." : ""}'));
         }
      }
    } catch (e) {
      emit(ClientsError(e.toString()));
    }
  }

  Future<void> _onConfirmConflictResolution(
      ClientsConfirmConflictResolution event, Emitter<ClientsState> emit) async {
    try {
       final allClientsToSave = [...event.safeClients, ...event.selectedResolvedClients];
       if (allClientsToSave.isNotEmpty) {
          await _repository.saveImportedClients(allClientsToSave);
          emit(ClientsOperationSuccess('Imported ${allClientsToSave.length} clients successfully.'));
       } else {
          emit(ClientsOperationSuccess('No clients imported.'));
       }
    } catch (e) {
       emit(ClientsError(e.toString()));
    }
  }

  Future<void> _onUpdateClient(
      ClientsUpdateClient event, Emitter<ClientsState> emit) async {
    try {
      await _repository.updateClient(event.client);
      // Success state removed to prevent UI flickering/emptying. 
      // The stream subscription will update the list automatically.
    } catch (e) {
      emit(ClientsError(e.toString()));
    }
  }

  Future<void> _onDeleteClient(
      ClientsDeleteClient event, Emitter<ClientsState> emit) async {
    try {
      await _repository.deleteClient(event.clientId);
    } catch (e) {
      emit(ClientsError(e.toString()));
    }
  }

  @override
  Future<void> close() {
    _clientSub?.cancel();
    return super.close();
  }

    @override
  void onEvent(ClientsEvent event) {
    if (event is _ClientsUpdatedList) {
       // This hack allows us to use the internal event handler without exposing it publicly
       // But defining specific handlers is cleaner.
    }
    super.onEvent(event);
  }
}

// Internal Helper Event
class _ClientsUpdatedList extends ClientsEvent {
  final List<Client> clients;
  _ClientsUpdatedList(this.clients);
}
