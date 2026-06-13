from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated
from django.utils.timezone import now
from django.utils import timezone
from datetime import datetime

from api.models import Booking, BookingMeal, BookingItem, EventPass, InstitutionalEvent
from django.db import transaction

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
        if user.role != "manager":
            return Response({"error": "Access denied"}, status=403)

        if not user.hostel:
            return Response({"error": "Manager has no hostel assigned"}, status=400)

        qr_uuid = request.data.get("qr_uuid")
        if not qr_uuid:
            return Response({"error": "QR is required"}, status=400)

        slot = self.get_current_slot(user.hostel)
        if not slot:
            return Response({"error": "No active meal slot right now"}, status=400)

        # 1. Check for Standard Booking
        try:
            booking = Booking.objects.select_related("user").get(qr_uuid=qr_uuid)
            return self._serve_booking(booking, slot, user.hostel)
        except Booking.DoesNotExist:
            pass

        # 2. Check for Event Pass
        try:
            event_pass = EventPass.objects.select_related("event").get(qr_uuid=qr_uuid)
            return self._serve_event_pass(event_pass, slot, user.hostel)
        except EventPass.DoesNotExist:
            pass

        return Response({"error": "Invalid QR code"}, status=404)

    def _serve_booking(self, booking, slot, hostel):
        if booking.date != timezone.now().date():
            return Response({"error": "QR is not valid for today"}, status=400)

        booking_day = booking.date.strftime("%A")
        meals = BookingMeal.objects.filter(
            booking=booking, meal_slot__slot=slot,
            meal_slot__day=booking_day, meal_slot__hostel=hostel
        ).select_related("combo")

        items = BookingItem.objects.filter(
            booking=booking, meal_slot__slot=slot,
            meal_slot__day=booking_day, meal_slot__hostel=hostel
        ).select_related("item")

        if not meals.exists() and not items.exists():
            return Response({"error": f"No items found for {slot} at this hostel"}, status=404)

        if not meals.filter(status='booked').exists() and not items.filter(status='booked').exists():
            return Response({"error": f"All items for {slot} already served or cancelled"}, status=400)

        delivered_list = []
        with transaction.atomic():
            for m in meals:
                if m.status == 'booked':
                    m.status = 'consumed'
                    m.save()
                    
                    # Add combo name
                    delivered_list.append(f"Combo: {m.combo.name} (x{m.quantity})")
                    
                    # Add specific items within this combo
                    for mi in m.meal_items.all():
                        delivered_list.append(f"  - {mi.item.name} (x{mi.quantity})")
                    
                    if m.guest_quantity > 0:
                        delivered_list.append(f"Guest Combo: {m.combo.name} (x{m.guest_quantity})")
                        for mi in m.meal_items.all():
                             delivered_list.append(f"  - {mi.item.name} (x{mi.quantity})")

            for i in items:
                if i.status == 'booked':
                    i.status = 'consumed'
                    i.save()
                    delivered_list.append(f"{i.item.name} (x{i.quantity})")
                    if i.guest_quantity > 0:
                        delivered_list.append(f"Guest: {i.item.name} (x{i.guest_quantity})")

        return Response({
            "message": f"{slot.capitalize()} items served successfully",
            "type": "student",
            "student": {
                "email": booking.user.email,
                "name": f"{booking.user.first_name} {booking.user.last_name}".strip()
            },
            "items": delivered_list
        }, status=200)

    def _serve_event_pass(self, event_pass, slot, hostel):
        if not event_pass.event.is_active:
            return Response({"error": "Event is no longer active"}, status=400)

        # 🍽️ Check if slot is allowed for this pass
        if event_pass.meal_slots and slot.lower() not in [s.lower() for s in event_pass.meal_slots]:
            return Response({"error": f"This pass is not valid for {slot.capitalize()}"}, status=400)

        now = timezone.now()
        if event_pass.valid_from and now < event_pass.valid_from:
            return Response({"error": "Pass is not yet valid"}, status=400)
        if event_pass.valid_until and now > event_pass.valid_until:
            return Response({"error": "Pass has expired"}, status=400)

        if event_pass.is_used:
            return Response({"error": f"Pass already used at {event_pass.consumed_at}"}, status=400)

        with transaction.atomic():
            event_pass.is_used = True
            event_pass.consumed_at = now
            event_pass.save()

        return Response({
            "message": "Guest pass verified successfully",
            "type": "guest",
            "guest": {
                "name": event_pass.guest_name,
                "event": event_pass.event.name
            },
            "items": [f"Standard Event Meal for {slot.capitalize()}"]
        }, status=200)