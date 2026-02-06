import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/bookings/data/booking_repository.dart';
import '../../features/bookings/domain/booking_models.dart';

// My bookings (passenger view)
final myBookingsProvider = FutureProvider<List<Booking>>((ref) async {
  return ref.read(bookingRepositoryProvider).getMyBookings();
});

final upcomingBookingsProvider = FutureProvider<List<Booking>>((ref) async {
  final bookings = await ref.read(bookingRepositoryProvider).getMyBookings();
  return bookings.where((b) => 
    b.status == BookingStatus.pending || 
    b.status == BookingStatus.confirmed
  ).toList();
});

final pastBookingsProvider = FutureProvider<List<Booking>>((ref) async {
  final bookings = await ref.read(bookingRepositoryProvider).getMyBookings();
  return bookings.where((b) => 
    b.status == BookingStatus.completed || 
    b.status == BookingStatus.cancelled
  ).toList();
});

// Driver bookings (reservation requests)
final driverBookingsProvider = FutureProvider<List<Booking>>((ref) async {
  return ref.read(bookingRepositoryProvider).getDriverBookings();
});

final pendingRequestsProvider = FutureProvider<List<Booking>>((ref) async {
  final bookings = await ref.read(bookingRepositoryProvider).getDriverBookings(status: 'pending');
  return bookings;
});

// Single booking detail
final bookingDetailProvider = FutureProvider.family<Booking, String>((ref, id) async {
  return ref.read(bookingRepositoryProvider).getBookingById(id);
});

// Booking actions notifier
class BookingActionsNotifier extends StateNotifier<AsyncValue<void>> {
  final BookingRepository _repository;
  final Ref _ref;

  BookingActionsNotifier(this._repository, this._ref) : super(const AsyncValue.data(null));

  Future<Booking?> createBooking(String tripId, int seatCount) async {
    state = const AsyncValue.loading();
    try {
      final booking = await _repository.createBooking(
        CreateBookingRequest(tripId: tripId, seatCount: seatCount),
      );
      state = const AsyncValue.data(null);
      _ref.invalidate(myBookingsProvider);
      return booking;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  Future<bool> confirmBooking(String id) async {
    state = const AsyncValue.loading();
    try {
      await _repository.confirmBooking(id);
      state = const AsyncValue.data(null);
      _ref.invalidate(driverBookingsProvider);
      _ref.invalidate(pendingRequestsProvider);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<bool> rejectBooking(String id, {String? reason}) async {
    state = const AsyncValue.loading();
    try {
      await _repository.rejectBooking(id, reason: reason);
      state = const AsyncValue.data(null);
      _ref.invalidate(driverBookingsProvider);
      _ref.invalidate(pendingRequestsProvider);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<bool> cancelBooking(String id) async {
    state = const AsyncValue.loading();
    try {
      await _repository.cancelBooking(id);
      state = const AsyncValue.data(null);
      _ref.invalidate(myBookingsProvider);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<bool> checkIn(String id, String qrCode) async {
    state = const AsyncValue.loading();
    try {
      await _repository.checkIn(id, qrCode);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }
}

final bookingActionsProvider = StateNotifierProvider<BookingActionsNotifier, AsyncValue<void>>((ref) {
  return BookingActionsNotifier(ref.read(bookingRepositoryProvider), ref);
});
