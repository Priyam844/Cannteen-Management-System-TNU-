from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated
from django.utils.timezone import now
from django.db.models import Avg

from api.models import Booking, BookingMeal, Feedback, BookingItem


class ManagerDashboardView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        user = request.user

        # 🔒 Only manager allowed
        if user.role != "manager":
            return Response({"error": "Access denied"}, status=403)

        if not user.hostel:
            return Response({"error": "Manager has no hostel assigned"}, status=400)

        today = now().date()

        # 📊 Total students in hostel
        total_students = user.hostel.users.count()

        # 📋 Today's bookings for this hostel
        bookings = Booking.objects.filter(
            date=today,
            user__hostel=user.hostel
        )

        meals = BookingMeal.objects.filter(
            booking__in=bookings
        ).exclude(status='cancelled').select_related("meal_slot", "combo")

        items = BookingItem.objects.filter(
            booking__in=bookings
        ).exclude(status='cancelled').select_related("meal_slot", "item")

        # 🧠 Prepare slot data
        hostel_timings = user.hostel.slot_timings or {}
        
        slot_map = {
            "breakfast": {"name": "Breakfast", "time": hostel_timings.get("breakfast", ["08:00", "10:00"]), "total_booked": 0, "consumed": 0, "surplus": 0},
            "lunch": {"name": "Lunch", "time": hostel_timings.get("lunch", ["12:00", "14:00"]), "total_booked": 0, "consumed": 0, "surplus": 0},
            "snacks": {"name": "Snacks", "time": hostel_timings.get("snacks", ["16:00", "17:00"]), "total_booked": 0, "consumed": 0, "surplus": 0},
            "dinner": {"name": "Dinner", "time": hostel_timings.get("dinner", ["19:00", "21:00"]), "total_booked": 0, "consumed": 0, "surplus": 0},
        }

        for meal in meals:
            slot = meal.meal_slot.slot.lower()
            if slot not in slot_map: continue

            slot_map[slot]["total_booked"] += 1
            
            if meal.status == "consumed":
                slot_map[slot]["consumed"] += 1

        for item in items:
            slot = item.meal_slot.slot.lower()
            if slot not in slot_map: continue

            slot_map[slot]["total_booked"] += item.quantity
            
            if item.status == "consumed":
                slot_map[slot]["consumed"] += item.quantity

        # Calculate surplus for each slot (booked - consumed)
        for key in slot_map:
            slot_map[key]["surplus"] = slot_map[key]["total_booked"] - slot_map[key]["consumed"]

        # ⭐ Overall Rating for this hostel
        avg_rating = Feedback.objects.filter(hostel=user.hostel).aggregate(avg=Avg('rating'))['avg'] or 0

        return Response({
            "hostel_name": user.hostel.hostel_name,
            "total_students": total_students,
            "overall_rating": round(float(avg_rating), 1),
            "slots": list(slot_map.values())
        })