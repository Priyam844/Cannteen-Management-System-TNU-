from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated
from api.models import MealSlot, Combo, Item
from api.serializers import ItemSerializer, ComboSerializer


class WeeklyMenuView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        try:
            user = request.user

            if not user.hostel:
                return Response({
                    "status": "error",
                    "message": "User is not assigned to any hostel"
                }, status=400)

            meal_slots = MealSlot.objects.filter(
                hostel=user.hostel
            ).prefetch_related('combos__items').order_by('day')

            weekly_menu = {}

            days_order = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday']
            slot_order = {'breakfast': 1, 'lunch': 2, 'snacks': 3, 'dinner': 4}

            for slot in meal_slots:
                day = slot.day

                if day not in weekly_menu:
                    weekly_menu[day] = {
                        'day': day,
                        'slots': {}
                    }

                if slot.slot not in weekly_menu[day]['slots']:
                    weekly_menu[day]['slots'][slot.slot] = {
                        'id': slot.id,      # ← the fix
                        'slot': slot.slot,
                        'combos': []
                    }

                combos = slot.combos.filter(is_active=True)

                for combo in combos:
                    items = combo.items.all()

                    weekly_menu[day]['slots'][slot.slot]['combos'].append({
                        "id": combo.id,
                        "name": combo.name,
                        "price": float(combo.price),
                        "category": combo.category,
                        "description": combo.description,
                        "items": [
                            {
                                "id": item.id,
                                "name": item.name,
                                "is_veg": item.is_veg
                            }
                            for item in items
                        ],
                        "items_text": ", ".join([item.name for item in items])
                    })

            result = []

            for day in days_order:
                if day in weekly_menu:
                    day_data = weekly_menu[day]
                    day_data['slots'] = sorted(
                        day_data['slots'].values(),
                        key=lambda x: slot_order.get(x['slot'], 99)
                    )
                    result.append(day_data)

            return Response({
                "status": "success",
                "data": result
            })

        except Exception as e:
            return Response({
                "status": "error",
                "message": str(e)
            }, status=500)


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
        combo_ids = request.data.get("combo_ids", []) # List of IDs

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

            slot.combos.set(combos)
            return Response({"message": "Menu updated successfully"})

        except MealSlot.DoesNotExist:
            return Response({"error": "Slot not found"}, status=404)
        except Exception as e:
            return Response({"error": str(e)}, status=400)