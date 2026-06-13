from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated


from django.utils import timezone
from django.db import transaction
from datetime import timedelta, datetime, time
from uuid import uuid4

from api.models import (
    Booking, BookingMeal, BookingMealItem, BookingItem, Combo, 
    MealSlot, Item, DailyMenu, Hostel, Transaction
)

def get_price_for_role(obj, role):
    if role == 'faculty':
        return obj.faculty_price
    elif role == 'staff':
        return obj.staff_price
    else:
        return obj.price

class BookMealsView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        user = request.user
        current_time = timezone.localtime()
        
        booking_date_str = request.data.get('date')
        if not booking_date_str:
             return Response({"error": "Date is required (YYYY-MM-DD)"}, status=400)
        
        try:
            booking_date = datetime.strptime(booking_date_str, '%Y-%m-%d').date()
        except ValueError:
            return Response({"error": "Invalid date format. Use YYYY-MM-DD"}, status=400)

        # Restricted Windows
        max_advance = current_time.date() + timedelta(days=2)
        if booking_date > max_advance:
             return Response({"error": "You can only book up to 2 days in advance"}, status=400)
        
        if booking_date < current_time.date():
             return Response({"error": "Cannot book for past dates"}, status=400)

        # 🚫 Block Tomorrow (Day 1) as per new requirement
        if booking_date == current_time.date() + timedelta(days=1):
            return Response({"error": "Booking for tomorrow is not allowed."}, status=400)

        # 👥 Guest booking restricted to Today only
        selected_meals = request.data.get('meals', [])
        selected_items = request.data.get('items', [])
        
        has_guests = any(int(m.get("guest_quantity", 0)) > 0 for m in selected_meals) or \
                     any(int(i.get("guest_quantity", 0)) > 0 for i in selected_items)
        
        if has_guests and booking_date != current_time.date():
            return Response({"error": "Guest booking is only allowed for today."}, status=400)

        # Normal window: Up to 2 days prior at cutoff time
        is_late_global = False
        if booking_date == current_time.date() + timedelta(days=2):
            if user.hostel:
                cutoff = user.hostel.booking_cutoff_time
                if current_time.time() >= cutoff:
                    is_late_global = True
        elif booking_date == current_time.date():
            is_late_global = True

        selected_meals = request.data.get('meals', [])
        selected_items = request.data.get('items', [])

        if not selected_meals and not selected_items:
            return Response({"error": "No items selected"}, status=400)

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

                total_cost = 0
                processed_meals = []
                processed_items = []

                # Handle Combos
                for m in selected_meals:
                    combo_id = m.get("combo_id")
                    meal_slot_id = m.get("meal_slot_id")
                    
                    # Force quantity to 1 for combos as per requirement
                    quantity = 1 
                    
                    guest_quantity = int(m.get("guest_quantity", 0))
                    combo_items_data = m.get("combo_items", [])

                    if not combo_id or not meal_slot_id:
                        raise Exception("Invalid meal payload")

                    combo = Combo.objects.get(id=combo_id)
                    meal_slot = MealSlot.objects.get(id=meal_slot_id)
                    
                    # 🏠 Hostel Restrictions
                    if user.role == 'student':
                        if not user.hostel or meal_slot.hostel != user.hostel:
                            raise Exception(f"Students can only book in their assigned hostel: {user.hostel.hostel_name if user.hostel else 'N/A'}")
                    elif user.role == 'faculty':
                        if meal_slot.hostel.excluded_for_faculty:
                            raise Exception(f"Faculty is not allowed to book in {meal_slot.hostel.hostel_name}")

                    other_combo_booking = BookingMeal.objects.filter(
                        booking=booking, 
                        meal_slot=meal_slot
                    ).exclude(combo=combo).first()
                    
                    if other_combo_booking and other_combo_booking.status == 'booked':
                        raise Exception(f"You have already booked '{other_combo_booking.combo.name}' for {meal_slot.slot}.")

                    is_late = is_late_global
                    if is_late:
                        if meal_slot.hostel.slot_timings:
                            hostel_timings = meal_slot.hostel.slot_timings.get(meal_slot.slot.lower())
                            if hostel_timings:
                                start_time = datetime.strptime(hostel_timings[0], "%H:%M").time()
                                start_datetime = timezone.make_aware(datetime.combine(booking_date, start_time))
                                lead_hours = meal_slot.hostel.late_booking_lead_time_hours
                                if current_time > start_datetime - timedelta(hours=lead_hours):
                                    raise Exception(f"Too late to book {meal_slot.slot}.")

                    # Pricing Logic - Dynamic based on items
                    self_unit_price = 0
                    guest_unit_price = 0
                    
                    if combo_items_data:
                        for ci in combo_items_data:
                            try:
                                item_obj = Item.objects.get(id=ci["id"])
                                self_unit_price += get_price_for_role(item_obj, user.role) * int(ci["qty"])
                                guest_unit_price += item_obj.guest_price * int(ci["qty"])
                            except Item.DoesNotExist:
                                continue
                    else:
                        for item_obj in combo.items.all():
                            self_unit_price += get_price_for_role(item_obj, user.role)
                            guest_unit_price += item_obj.guest_price

                    meal_total = (self_unit_price * quantity) + (guest_unit_price * guest_quantity)
                    
                    existing_meal = BookingMeal.objects.filter(booking=booking, meal_slot=meal_slot, combo=combo).first()
                    if existing_meal:
                        # Refund old price ONLY if it was actually deducted (status == 'booked')
                        if existing_meal.status == 'booked':
                            user.wallet_balance += existing_meal.total_price
                        
                        existing_meal.quantity = quantity
                        existing_meal.guest_quantity = guest_quantity
                        existing_meal.total_price = meal_total
                        existing_meal.is_late_booking = is_late
                        existing_meal.status = "booked"
                        existing_meal.save()
                        
                        # Update items for re-booking
                        existing_meal.meal_items.all().delete()
                        if combo_items_data:
                            for ci in combo_items_data:
                                qty_in_combo = int(ci.get("qty", 0))
                                if qty_in_combo > 0:
                                    BookingMealItem.objects.create(booking_meal=existing_meal, item_id=ci["id"], quantity=qty_in_combo)
                        else:
                            for item_obj in combo.items.all():
                                BookingMealItem.objects.create(booking_meal=existing_meal, item=item_obj, quantity=1)
                    else:
                        bm = BookingMeal.objects.create(
                            booking=booking,
                            meal_slot=meal_slot,
                            combo=combo,
                            quantity=quantity,
                            guest_quantity=guest_quantity,
                            total_price=meal_total,
                            is_late_booking=is_late,
                            status="booked"
                        )
                        # Setup items
                        if combo_items_data:
                            for ci in combo_items_data:
                                qty_in_combo = int(ci.get("qty", 0))
                                if qty_in_combo > 0:
                                    BookingMealItem.objects.create(booking_meal=bm, item_id=ci["id"], quantity=qty_in_combo)
                        else:
                            for item_obj in combo.items.all():
                                BookingMealItem.objects.create(booking_meal=bm, item=item_obj, quantity=1)
                    
                    total_cost += meal_total
                    processed_meals.append({"slot": meal_slot.slot, "combo": combo.name, "qty": quantity, "guests": guest_quantity})

                # Handle individual items
                for i in selected_items:
                    item_id = i.get("item_id")
                    meal_slot_id = i.get("meal_slot_id")
                    quantity = int(i.get("quantity", 1))
                    guest_quantity = int(i.get("guest_quantity", 0))

                    if not item_id or not meal_slot_id:
                        continue

                    item = Item.objects.get(id=item_id)
                    meal_slot = MealSlot.objects.get(id=meal_slot_id)

                    # 🏠 Hostel Restrictions
                    if user.role == 'student':
                        if not user.hostel or meal_slot.hostel != user.hostel:
                            raise Exception(f"Students can only book items in their assigned hostel.")
                    elif user.role == 'faculty':
                        if meal_slot.hostel.excluded_for_faculty:
                            raise Exception(f"Faculty is not allowed to book items in {meal_slot.hostel.hostel_name}")

                    self_unit_price = get_price_for_role(item, user.role)
                    guest_unit_price = item.guest_price
                    item_total = (self_unit_price * quantity) + (guest_unit_price * guest_quantity)
                    
                    existing_item = BookingItem.objects.filter(booking=booking, meal_slot=meal_slot, item=item).first()
                    if existing_item:
                        # Refund old price ONLY if it was actually deducted
                        if existing_item.status == 'booked':
                            user.wallet_balance += existing_item.total_price
                        
                        existing_item.quantity = quantity
                        existing_item.guest_quantity = guest_quantity
                        existing_item.price = self_unit_price
                        existing_item.total_price = item_total
                        existing_item.status = "booked"
                        existing_item.save()
                    else:
                        BookingItem.objects.create(
                            booking=booking,
                            meal_slot=meal_slot,
                            item=item,
                            quantity=quantity,
                            guest_quantity=guest_quantity,
                            price=self_unit_price,
                            total_price=item_total,
                            status="booked"
                        )
                    total_cost += item_total
                    processed_items.append({"slot": meal_slot.slot, "item": item.name, "qty": quantity})

                if user.wallet_balance < total_cost:
                    raise Exception(f"Insufficient wallet balance. Need: {total_cost}")

                user.wallet_balance -= total_cost
                user.save()

                Transaction.objects.create(
                    user=user,
                    amount=total_cost,
                    transaction_type='debit',
                    description=f"Meal booking for {booking_date}",
                    booking=booking
                )

                return Response({
                    "message": "Booking successful",
                    "total_cost": float(total_cost),
                    "updated_balance": float(user.wallet_balance),
                    "qr_uuid": str(booking.qr_uuid),
                    "date": str(booking.date)
                })

        except Exception as e:
            return Response({"error": str(e)}, status=400)


class CancelMealView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        user = request.user
        current_time = timezone.localtime()
        
        meal_id = request.data.get("meal_id")
        item_id = request.data.get("item_id")

        try:
            with transaction.atomic():
                refund_amount = 0
                desc = ""
                booking = None
                
                if meal_id:
                    meal = BookingMeal.objects.get(id=meal_id, booking__user=user)
                    if meal.status != "booked":
                        return Response({"error": f"Meal is {meal.status}"}, status=400)
                    
                    # Window check
                    if meal.booking.date <= current_time.date() + timedelta(days=1):
                         return Response({"error": "Cancellation window closed."}, status=400)
                    
                    meal.status = "cancelled"
                    meal.save()
                    refund_amount = meal.total_price
                    desc = f"Refund for {meal.combo.name} ({meal.booking.date})"
                    booking = meal.booking

                elif item_id:
                    item = BookingItem.objects.get(id=item_id, booking__user=user)
                    if item.status != "booked":
                         return Response({"error": "Item not booked"}, status=400)
                    
                    item.status = "cancelled"
                    item.save()
                    refund_amount = item.total_price
                    desc = f"Refund for {item.item.name} ({item.booking.date})"
                    booking = item.booking

                user.wallet_balance += refund_amount
                user.save()

                Transaction.objects.create(
                    user=user,
                    amount=refund_amount,
                    transaction_type='refund',
                    description=desc,
                    booking=booking
                )

                return Response({
                    "message": "Cancelled successfully",
                    "refund_amount": float(refund_amount),
                    "updated_balance": float(user.wallet_balance)
                })

        except Exception as e:
            return Response({"error": str(e)}, status=400)


class MyBookingView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        user = request.user

        # 🌍 Use local date for IST
        today = timezone.localtime().date()
        tomorrow = today + timedelta(days=1)
        day_after = today + timedelta(days=2)

        bookings = Booking.objects.filter(
            user=user,
            date__in=[today, tomorrow, day_after],
            is_active=True
        ).prefetch_related(
            "meals__meal_slot", "meals__combo", "meals__meal_items__item",
            "items__meal_slot", "items__item"
        )

        result = []
        hostel_timings = user.hostel.slot_timings or {}

        for booking in bookings:
            meals_data = []
            for m in booking.meals.all():
                slot_key = m.meal_slot.slot.lower()
                timing = hostel_timings.get(slot_key, ["N/A", "N/A"])
                
                # Fetch items with their quantities from BookingMealItem
                selected_items = [
                    {"id": mi.item.id, "name": mi.item.name, "price": float(mi.item.price), "quantity": mi.quantity}
                    for mi in m.meal_items.all()
                ]

                meals_data.append({
                    "id": m.id,
                    "type": "combo",
                    "combo_id": m.combo.id,
                    "meal_slot_id": m.meal_slot.id,
                    "meal_slot": m.meal_slot.slot,
                    "meal_time": f"{timing[0]} - {timing[1]}",
                    "name": m.combo.name,
                    "quantity": m.quantity,
                    "total_price": float(m.total_price),
                    "status": m.status,
                    "selected_items": selected_items
                })

            items_data = []
            for i in booking.items.all():
                slot_key = i.meal_slot.slot.lower()
                timing = hostel_timings.get(slot_key, ["N/A", "N/A"])

                items_data.append({
                    "id": i.id,
                    "type": "item",
                    "item_id": i.item.id,
                    "meal_slot_id": i.meal_slot.id,
                    "meal_slot": i.meal_slot.slot,
                    "meal_time": f"{timing[0]} - {timing[1]}",
                    "name": i.item.name,
                    "quantity": i.quantity,
                    "total_price": float(i.total_price),
                    "status": i.status
                })

            result.append({
                "qr_uuid": str(booking.qr_uuid),
                "date": str(booking.date),
                "name": f"{booking.user.first_name} {booking.user.last_name}".strip(),
                "student_id": booking.user.email,
                "meals": meals_data,
                "items": items_data
            })

        return Response({
            "status": "success",
            "cancellation_cutoff_time": user.hostel.cancellation_cutoff_time.strftime("%H:%M") if user.hostel.cancellation_cutoff_time else "16:00",
            "late_booking_lead_time_hours": user.hostel.late_booking_lead_time_hours,
            "data": result
        })

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
