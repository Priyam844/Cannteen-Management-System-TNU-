from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated
from django.utils.timezone import now
from django.db.models import Avg

from api.models import Booking, BookingMeal, Feedback


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

        # 🧠 Prepare slot data
        hostel_timings = user.hostel.slot_timings or {}
        
        slot_map = {
            "breakfast": {"name": "Breakfast", "time": hostel_timings.get("breakfast", ["08:00", "10:00"]), "total": total_students, "veg": 0, "non_veg": 0, "consumed": 0, "surplus": 0},
            "lunch": {"name": "Lunch", "time": hostel_timings.get("lunch", ["12:00", "14:00"]), "total": total_students, "veg": 0, "non_veg": 0, "consumed": 0, "surplus": 0},
            "snacks": {"name": "Snacks", "time": hostel_timings.get("snacks", ["16:00", "17:00"]), "total": total_students, "veg": 0, "non_veg": 0, "consumed": 0, "surplus": 0},
            "dinner": {"name": "Dinner", "time": hostel_timings.get("dinner", ["19:00", "21:00"]), "total": total_students, "veg": 0, "non_veg": 0, "consumed": 0, "surplus": 0},
        }

        for meal in meals:
            slot = meal.meal_slot.slot  # breakfast/lunch/snacks/dinner

            if slot not in slot_map:
                continue

            if meal.combo.category == "veg":
                slot_map[slot]["veg"] += 1
            else:
                slot_map[slot]["non_veg"] += 1
            
            if meal.status == "consumed":
                slot_map[slot]["consumed"] += 1

        # Calculate surplus for each slot (booked - consumed)
        for key in slot_map:
            booked = slot_map[key]["veg"] + slot_map[key]["non_veg"]
            slot_map[key]["surplus"] = booked - slot_map[key]["consumed"]

        # ⭐ Overall Rating for this hostel
        avg_rating = Feedback.objects.filter(hostel=user.hostel).aggregate(avg=Avg('rating'))['avg'] or 0

        return Response({
            "hostel_name": user.hostel.hostel_name,
            "total_students": total_students,
            "overall_rating": round(float(avg_rating), 1),
            "slots": list(slot_map.values())
        })