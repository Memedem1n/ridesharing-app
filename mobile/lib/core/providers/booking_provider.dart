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
    b.status == BookingStatus.awaitingPayment ||
    b.status == BookingStatus.confirmed ||
    b.status == BookingStatus.checkedIn
  ).toList();
});

final pastBookingsProvider = FutureProvider<List<Booking>>((ref) async {
  final bookings = await ref.read(bookingRepositoryProvider).getMyBookings();
  return bookings.where((b) => 
    b.status == BookingStatus.completed || 
    b.status == BookingStatus.disputed ||
    b.status == BookingStatus.cancelled
  ).toList();
});

final recentBookingsProvider = FutureProvider<List<Booking>>((ref) async {
  final bookings = await ref.read(bookingRepositoryProvider).getMyBookings();
  final withTrip = bookings.where((b) => b.trip != null).toList();
  withTrip.sort((a, b) {
    final aDate = a.trip?.departureTime ?? a.createdAt;
    final bDate = b.trip?.departureTime ?? b.createdAt;
    return bDate.compareTo(aDate);
  });
  return withTrip.take(3).toList();
});

// Driver bookings (reservation requests)
final driverBookingsProvider = FutureProvider.family<List<Booking>, String>((ref, tripId) async {
  return ref.read(bookingRepositoryProvider).getDriverBookings(tripId);
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

  Future<Booking?> createBooking(
    String tripId,
    int seatCount, {
    String? requestedFrom,
    String? requestedTo,
  }) async {
    state = const AsyncValue.loading();
    try {
      final booking = await _repository.createBooking(
        CreateBookingRequest(
          tripId: tripId,
          seatCount: seatCount,
          requestedFrom: requestedFrom,
          requestedTo: requestedTo,
        ),
      );
      state = const AsyncValue.data(null);
      _ref.invalidate(myBookingsProvider);
      return booking;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
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

  Future<bool> checkIn(String qrCode) async {
    state = const AsyncValue.loading();
    try {
      await _repository.checkIn(qrCode);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<bool> processPayment(String bookingId) async {
    state = const AsyncValue.loading();
    try {
      await _repository.processPayment(bookingId);
      state = const AsyncValue.data(null);
      _ref.invalidate(myBookingsProvider);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<bool> acceptBooking(String bookingId) async {
    state = const AsyncValue.loading();
    try {
      await _repository.acceptBooking(bookingId);
      state = const AsyncValue.data(null);
      _ref.invalidate(myBookingsProvider);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<bool> rejectBooking(String bookingId, {String? reason}) async {
    state = const AsyncValue.loading();
    try {
      await _repository.rejectBooking(bookingId, reason: reason);
      state = const AsyncValue.data(null);
      _ref.invalidate(myBookingsProvider);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<bool> completeBooking(String bookingId) async {
    state = const AsyncValue.loading();
    try {
      await _repository.completeBooking(bookingId);
      state = const AsyncValue.data(null);
      _ref.invalidate(myBookingsProvider);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<bool> raiseDispute(String bookingId, String reason) async {
    state = const AsyncValue.loading();
    try {
      await _repository.raiseDispute(bookingId, reason);
      state = const AsyncValue.data(null);
      _ref.invalidate(myBookingsProvider);
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
