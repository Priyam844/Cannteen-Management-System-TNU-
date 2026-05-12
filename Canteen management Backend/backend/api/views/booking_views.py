from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated


from django.utils.timezone import now
from django.db import transaction
from datetime import timedelta
from uuid import uuid4

from api.models import Booking, BookingMeal, Combo, MealSlot


class BookMealsView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        user = request.user
        
        if not user.hostel:
            return Response({"error": "You are not assigned to a hostel"}, status=400)

        current_time = now()
        
        # Check if booking is before cutoff time
        cutoff_time = user.hostel.booking_cutoff_time
        if current_time.time() >= cutoff_time:
            return Response({
                "error": f"Booking closed! Deadline for tomorrow was {cutoff_time.strftime('%I:%M %p')}"
            }, status=400)

        booking_date = current_time.date() + timedelta(days=1)
        selected_meals = request.data.get('meals', [])

        if not selected_meals:
            return Response({"error": "No meals selected"}, status=400)

        try:
            with transaction.atomic():
                booking, _ = Booking.objects.get_or_create(
                    user=user,
                    date=booking_date,
                    defaults={"is_active": True}
                )

                if not booking.is_active:
                    booking.is_active = True
                    booking.qr_uuid = uuid4()
                    booking.save()

                created_meals = []

                for item in selected_meals:
                    combo_id = item.get("combo_id")
                    meal_slot_id = item.get("meal_slot_id")

                    if not combo_id or not meal_slot_id:
                        raise Exception("Invalid payload")

                    combo = Combo.objects.filter(id=combo_id).first()
                    meal_slot = MealSlot.objects.filter(id=meal_slot_id).first()

                    if not combo or not meal_slot:
                        raise Exception("Invalid combo or meal slot")

                    if combo.hostel != user.hostel:
                        raise Exception("Invalid hostel combo")

                    if not meal_slot.combos.filter(id=combo.id).exists():
                        raise Exception("Combo not available in this slot")

                    already = BookingMeal.objects.filter(
                        booking=booking,
                        meal_slot=meal_slot,
                        status="booked"
                    ).exists()

                    if already:
                        continue

                    BookingMeal.objects.update_or_create(
                        booking=booking,
                        meal_slot=meal_slot,
                        defaults={
                            "combo": combo,
                            "status": "booked"
                        }
                    )

                    created_meals.append({
                        "meal_slot_id": meal_slot.id,
                        "combo_id": combo.id
                    })

                return Response({
                    "message": "Booking successful",
                    "qr_uuid": str(booking.qr_uuid),
                    "date": str(booking.date),
                    "student_id": user.student_id,
                    "name": f"{user.first_name} {user.last_name}",
                    "meals": created_meals
                })

        except Exception as e:
            return Response({"error": str(e)}, status=400)


class CancelMealView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        user = request.user
        meal_slot_id = request.data.get("meal_slot_id")

        if not user.hostel:
            return Response({"error": "You are not assigned to a hostel"}, status=400)

        if not meal_slot_id:
            return Response({"error": "meal_slot_id required"}, status=400)

        current_time = now()
        cutoff_time = user.hostel.booking_cutoff_time

        # 🚨 Enforce the same cutoff window for cancellation
        if current_time.time() >= cutoff_time:
            return Response({
                "error": f"Cancellation window closed! Deadline for tomorrow's meals was {cutoff_time.strftime('%I:%M %p')}"
            }, status=400)

        tomorrow = current_time.date() + timedelta(days=1)

        try:
            with transaction.atomic():
                booking = Booking.objects.get(
                    user=user, date=tomorrow, is_active=True
                )

                meal = BookingMeal.objects.get(
                    booking=booking, meal_slot_id=meal_slot_id
                )

                if meal.status == "cancelled":
                    return Response({"message": "Already cancelled"})

                meal.status = "cancelled"
                meal.save()

                if not booking.meals.filter(status="booked").exists():
                    booking.is_active = False
                    booking.save()

                return Response({"message": "Meal cancelled"})

        except Booking.DoesNotExist:
            return Response({"error": "No active booking"}, status=404)
        except BookingMeal.DoesNotExist:
            return Response({"error": "Meal not found"}, status=404)
        except Exception as e:
            return Response({"error": str(e)}, status=400)


class MyBookingView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        user = request.user

        today = now().date()
        tomorrow = today + timedelta(days=1)

        bookings = Booking.objects.filter(
            user=user,
            date__in=[today, tomorrow],
            is_active=True
        ).prefetch_related("meals__meal_slot", "meals__combo")

        result = []
        hostel_timings = user.hostel.slot_timings or {}

        for booking in bookings:
            meals = booking.meals.all()

            data = []
            for m in meals:
                slot_key = m.meal_slot.slot.lower()
                timing = hostel_timings.get(slot_key, ["N/A", "N/A"])
                
                data.append({
                    "id": m.id,
                    "meal_slot_id": m.meal_slot.id,
                    "meal_slot": m.meal_slot.slot,
                    "meal_time": f"{timing[0]} - {timing[1]}",
                    "day": m.meal_slot.day,
                    "combo": m.combo.name,
                    "combo_id": m.combo.id,
                    "status": m.status
                })

            result.append({
                "qr_uuid": str(booking.qr_uuid),
                "date": str(booking.date),
                "name": f"{booking.user.first_name} {booking.user.last_name}".strip(),
                "student_id": booking.user.email,
                "meals": data
            })

        return Response(result)

class MyBookingHistoryView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        user = request.user
        
        # Get all bookings, ordered by date descending
        bookings = Booking.objects.filter(
            user=user
        ).prefetch_related("meals__meal_slot", "meals__combo").order_by("-date")

        result = []

        for booking in bookings:
            meals = booking.meals.all()
            data = [
                {
                    "meal_slot": m.meal_slot.slot,
                    "combo": m.combo.name,
                    "status": m.status
                }
                for m in meals
            ]

            result.append({
                "date": str(booking.date),
                "meals": data
            })

        return Response(result)
