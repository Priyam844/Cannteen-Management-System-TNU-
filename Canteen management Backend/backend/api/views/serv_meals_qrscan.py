from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated
from django.utils.timezone import now
from django.utils import timezone
from datetime import datetime

from api.models import Booking, BookingMeal


class ServeMealQRScanView(APIView):
    permission_classes = [IsAuthenticated]

    # Auto slot detection
    def get_current_slot(self, hostel):
        if not hostel:
            return None

        timings = hostel.slot_timings or {}
        current_time = timezone.localtime().time()

        for slot, time_range in timings.items():
            try:
                if not isinstance(time_range, list) or len(time_range) != 2:
                    continue

                start = datetime.strptime(time_range[0], "%H:%M").time()
                end = datetime.strptime(time_range[1], "%H:%M").time()

                if start <= current_time <= end:
                    return slot

            except Exception:
                continue

        return None

    def post(self, request):
        user = request.user

        # Only manager allowed
        if user.role != "manager":
            return Response({"error": "Access denied"}, status=403)

        if not user.hostel:
            return Response(
                {"error": "Manager has no hostel assigned"},
                status=400
            )

        qr_uuid = request.data.get("qr_uuid")

        if not qr_uuid:
            return Response({"error": "QR is required"}, status=400)

        # Detect slot
        slot = self.get_current_slot(user.hostel)

        if not slot:
            return Response(
                {"error": "No active meal slot right now"},
                status=400
            )

        # Get booking
        try:
            booking = Booking.objects.select_related("user").get(qr_uuid=qr_uuid)
        except Booking.DoesNotExist:
            return Response({"error": "Invalid QR code"}, status=404)

        # Hostel validation
        if not booking.user.hostel or booking.user.hostel != user.hostel:
            return Response(
                {"error": "QR does not belong to your hostel"},
                status=403
            )

        # Date validation
        if booking.date != now().date():
            return Response(
                {"error": "QR is not valid for today"},
                status=400
            )

        # IMPORTANT FIX: match slot + booking day
        booking_day = booking.date.strftime("%A")

        # Get meal
        try:
            meal = BookingMeal.objects.select_related(
                "meal_slot",
                "combo",
                "booking__user"
            ).get(
                booking=booking,
                meal_slot__slot=slot,
                meal_slot__day=booking_day
            )
        except BookingMeal.DoesNotExist:
            return Response(
                {"error": f"No booking found for {slot}"},
                status=404
            )

        # Status checks
        if meal.status == "cancelled":
            return Response(
                {"error": f"{slot.capitalize()} meal was cancelled"},
                status=400
            )

        if meal.status == "consumed":
            return Response(
                {"error": f"{slot.capitalize()} already served"},
                status=400
            )

        if meal.status == "expired":
            return Response(
                {"error": f"{slot.capitalize()} meal expired"},
                status=400
            )

        # Mark consumed
        meal.status = "consumed"
        meal.save()

        return Response({
            "message": f"{slot.capitalize()} meal served successfully",
            "student": {
                "email": booking.user.email,
                "name": f"{booking.user.first_name} {booking.user.last_name}".strip()
            },
            "meal": {
                "slot": slot,
                "combo": meal.combo.name,
                "type": meal.combo.category
            }
        }, status=200)