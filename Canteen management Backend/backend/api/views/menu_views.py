from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated
from api.models import MealSlot, Combo, Item, DailyMenu, Hostel
from api.serializers import ItemSerializer, ComboSerializer
from django.utils import timezone
from datetime import timedelta


class WeeklyMenuView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        try:
            user = request.user
            hostel_id = request.query_params.get("hostel_id")
            
            # Requirement 12: Inter-hostel booking - allow viewing menu of other hostels
            if hostel_id:
                target_hostel = Hostel.objects.filter(id=hostel_id).first()
            else:
                target_hostel = user.hostel

            if not target_hostel:
                return Response({
                    "status": "error",
                    "message": "Hostel not found"
                }, status=400)

            # We'll return menu for next 14 days
            current_date = timezone.localtime().date()
            dates = [current_date + timedelta(days=i) for i in range(14)]
            
            result = []
            slot_order = {'breakfast': 1, 'lunch': 2, 'snacks': 3, 'dinner': 4}

            for d in dates:
                day_name = d.strftime('%A')
                day_data = {
                    "date": str(d),
                    "day": day_name,
                    "slots": []
                }

                # Get regular slots for this day
                slots = MealSlot.objects.filter(hostel=target_hostel, day=day_name).prefetch_related('combos__items')
                
                for s in sorted(slots, key=lambda x: slot_order.get(x.slot.lower(), 99)):
                    slot_info = {
                        "id": s.id,
                        "slot": s.slot,
                        "combos": [],
                        "items": []
                    }

                    # Check for DailyMenu override
                    daily_override = DailyMenu.objects.filter(hostel=target_hostel, date=d, slot=s.slot).first()
                    
                    if daily_override:
                        combos = daily_override.combos.filter(is_active=True)
                        items = daily_override.items.filter(is_active=True)
                    else:
                        combos = s.combos.filter(is_active=True)
                        items = s.items.filter(is_active=True)

                    for combo in combos:
                        slot_info["combos"].append({
                            "id": combo.id,
                            "name": combo.name,
                            "price": float(combo.price),
                            "faculty_price": float(combo.faculty_price),
                            "staff_price": float(combo.staff_price),
                            "guest_price": float(combo.guest_price),
                            "description": combo.description,
                            "items_text": ", ".join([it.name for it in combo.items.all()]),
                            "items_list": [
                                {
                                    "id": it.id, 
                                    "name": it.name, 
                                    "price": float(it.price),
                                    "faculty_price": float(it.faculty_price),
                                    "staff_price": float(it.staff_price),
                                    "guest_price": float(it.guest_price),
                                    "is_veg": it.is_veg
                                }
                                for it in combo.items.all()
                            ]
                        })
                    
                    for item in items:
                        slot_info["items"].append({
                            "id": item.id,
                            "name": item.name,
                            "price": float(item.price),
                            "faculty_price": float(item.faculty_price),
                            "staff_price": float(item.staff_price),
                            "guest_price": float(item.guest_price),
                            "is_veg": item.is_veg,
                            "description": item.description
                        })
                    
                    # If no override, maybe we want to allow ordering ANY active item?
                    # Requirement 10: order any menu item multiple times.
                    # We can include a general list of available items if requested, 
                    # but for now, we'll just include items specifically assigned to the slot.
                    
                    day_data["slots"].append(slot_info)
                
                result.append(day_data)

            return Response({
                "status": "success",
                "hostel_timings": target_hostel.slot_timings,
                "booking_cutoff_time": target_hostel.booking_cutoff_time.strftime("%H:%M") if target_hostel.booking_cutoff_time else "14:00",
                "cancellation_cutoff_time": target_hostel.cancellation_cutoff_time.strftime("%H:%M") if target_hostel.cancellation_cutoff_time else "16:00",
                "late_booking_lead_time_hours": target_hostel.late_booking_lead_time_hours,
                "data": result
            })

        except Exception as e:
            return Response({
                "status": "error",
                "message": str(e)
            }, status=500)

class DailyMenuCRUDView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        if request.user.role != 'manager':
            return Response({"error": "Access denied"}, status=403)
        
        hostel = request.user.hostel
        date_str = request.data.get("date")
        slot = request.data.get("slot")
        combo_ids = request.data.get("combo_ids", [])
        item_ids = request.data.get("item_ids", [])

        if not date_str or not slot:
            return Response({"error": "date and slot required"}, status=400)

        try:
            daily_menu, _ = DailyMenu.objects.update_or_create(
                hostel=hostel,
                date=date_str,
                slot=slot
            )
            daily_menu.combos.set(combo_ids)
            daily_menu.items.set(item_ids)
            return Response({"message": "Daily menu updated successfully"})
        except Exception as e:
            return Response({"error": str(e)}, status=400)


class ItemCRUDView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        items = Item.objects.all()
        serializer = ItemSerializer(items, many=True)
        return Response(serializer.data)

    def post(self, request):
        if request.user.role != 'manager':
            return Response({"error": "Access denied"}, status=403)
        serializer = ItemSerializer(data=request.data)
        if serializer.is_valid():
            serializer.save()
            return Response(serializer.data, status=201)
        return Response(serializer.errors, status=400)

    def put(self, request):
        if request.user.role != 'manager':
            return Response({"error": "Access denied"}, status=403)
        item_id = request.data.get("id")
        try:
            item = Item.objects.get(id=item_id)
            serializer = ItemSerializer(item, data=request.data, partial=True)
            if serializer.is_valid():
                serializer.save()
                return Response(serializer.data)
            return Response(serializer.errors, status=400)
        except Item.DoesNotExist:
            return Response({"error": "Item not found"}, status=404)

    def delete(self, request):
        if request.user.role != 'manager':
            return Response({"error": "Access denied"}, status=403)
        item_id = request.query_params.get("id")
        try:
            item = Item.objects.get(id=item_id)
            item.is_active = not item.is_active
            item.save()
            status_msg = "deactivated" if not item.is_active else "activated"
            return Response({"message": f"Item {status_msg}"})
        except Item.DoesNotExist:
            return Response({"error": "Item not found"}, status=404)


class ComboCRUDView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        user = request.user
        combos = Combo.objects.filter(hostel=user.hostel, is_active=True)
        serializer = ComboSerializer(combos, many=True)
        return Response(serializer.data)

    def post(self, request):
        user = request.user
        if user.role != 'manager':
            return Response({"error": "Access denied"}, status=403)
        
        data = request.data.copy()
        data['hostel'] = user.hostel.id
        serializer = ComboSerializer(data=data)
        if serializer.is_valid():
            serializer.save(hostel=user.hostel)
            return Response(serializer.data, status=201)
        return Response(serializer.errors, status=400)

    def put(self, request):
        user = request.user
        if user.role != 'manager':
            return Response({"error": "Access denied"}, status=403)
        
        combo_id = request.data.get("id")
        try:
            combo = Combo.objects.get(id=combo_id, hostel=user.hostel)
            serializer = ComboSerializer(combo, data=request.data, partial=True)
            if serializer.is_valid():
                serializer.save()
                return Response(serializer.data)
            return Response(serializer.errors, status=400)
        except Combo.DoesNotExist:
            return Response({"error": "Combo not found"}, status=404)

    def delete(self, request):
        user = request.user
        if user.role != 'manager':
            return Response({"error": "Access denied"}, status=403)
        
        combo_id = request.query_params.get("id")
        try:
            combo = Combo.objects.get(id=combo_id, hostel=user.hostel)
            # Instead of hard delete, we could set is_active=False
            combo.is_active = False
            combo.save()
            return Response({"message": "Combo deactivated"})
        except Combo.DoesNotExist:
            return Response({"error": "Combo not found"}, status=404)

class UpdateMealSlotView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        user = request.user
        if user.role != 'manager':
            return Response({"error": "Access denied"}, status=403)

        slot_id = request.data.get("slot_id")
        combo_ids = request.data.get("combo_ids", []) 
        item_ids = request.data.get("item_ids", [])

        if not slot_id:
            return Response({"error": "slot_id required"}, status=400)

        try:
            slot = MealSlot.objects.get(id=slot_id, hostel=user.hostel)

            if len(combo_ids) > 2:
                return Response({"error": "Max 2 combos allowed"}, status=400)

            # Validate combos belong to hostel
            combos = Combo.objects.filter(id__in=combo_ids, hostel=user.hostel)
            if combos.count() != len(combo_ids):
                return Response({"error": "Invalid combo IDs"}, status=400)

            # Validate items are active
            items = Item.objects.filter(id__in=item_ids, is_active=True)
            if items.count() != len(item_ids):
                 return Response({"error": "Invalid or inactive item IDs"}, status=400)

            slot.combos.set(combos)
            slot.items.set(items)
            return Response({"message": "Menu template updated successfully"})

        except MealSlot.DoesNotExist:
            return Response({"error": "Slot not found"}, status=404)
        except Exception as e:
            return Response({"error": str(e)}, status=400)