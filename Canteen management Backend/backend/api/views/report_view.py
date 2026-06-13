from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated
from django.db.models import Count, Q, Sum
from api.models import BookingMeal, Booking, BookingItem, Item
from datetime import timedelta
from django.utils import timezone

class AdminAnalyticsView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        if request.user.role not in ['admin', 'manager']:
            return Response({"error": "Access denied"}, status=403)
        
        period = request.query_params.get("period", "weekly")
        hostel_id = request.query_params.get("hostel_id")
        user = request.user
        
        end_date = timezone.localtime().date()
        if period == "today":
            start_date = end_date
        elif period == "weekly":
            start_date = end_date - timedelta(days=7)
        elif period == "15days":
            start_date = end_date - timedelta(days=15)
        elif period == "monthly":
            start_date = end_date - timedelta(days=30)
        elif period == "6months":
            start_date = end_date - timedelta(days=180)
        elif period == "custom":
            try:
                start_date_str = request.query_params.get("start_date")
                end_date_str = request.query_params.get("end_date")
                start_date = timezone.datetime.strptime(start_date_str, "%Y-%m-%d").date()
                end_date = timezone.datetime.strptime(end_date_str, "%Y-%m-%d").date()
            except:
                return Response({"error": "Invalid custom dates. Use YYYY-MM-DD"}, status=400)
        else:
            start_date = end_date - timedelta(days=7)

        query_filter = Q(booking__date__range=[start_date, end_date])
        if user.role == 'manager':
            query_filter &= Q(booking__user__hostel=user.hostel)
        elif hostel_id:
            query_filter &= Q(booking__user__hostel_id=hostel_id)

        # Requirement 14: Total plates ordered vs delivered
        stats = BookingMeal.objects.filter(query_filter).aggregate(
            total_ordered=Count('id'),
            total_delivered=Count('id', filter=Q(status='consumed')),
            total_cancelled=Count('id', filter=Q(status='cancelled'))
        )

        # Requirement 15: Item-wise analytical graphs (Top 10 items by demand)
        # Demand for items within combos
        item_demand_in_combos = BookingMealItem.objects.filter(
            booking_meal__booking__in=Booking.objects.filter(query_filter)
        ).values(
            'item__name'
        ).annotate(
            count=Sum('quantity')
        ).order_by('-count')[:10]

        # Demand for individual items
        item_demand_individual = BookingItem.objects.filter(query_filter).values(
            'item__name'
        ).annotate(
            count=Sum('quantity')
        ).order_by('-count')[:10]

        return Response({
            "period": period,
            "start_date": start_date,
            "end_date": end_date,
            "overview": stats,
            "top_items_in_combos": item_demand_in_combos,
            "top_individual_items": item_demand_individual
        })

class ManagerReportsView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        user = request.user
        if user.role != 'manager':
            return Response({"error": "Access denied"}, status=403)
        
        # Last 7 days report
        local_now = timezone.localtime()
        end_date = local_now.date()
        start_date = end_date - timedelta(days=7)
        
        days = []
        curr = start_date
        while curr <= end_date:
            day_bookings = Booking.objects.filter(date=curr, user__hostel=user.hostel)
            
            stats = BookingMeal.objects.filter(
                booking__in=day_bookings
            ).exclude(status='cancelled').aggregate(
                total=Count('id'),
                consumed=Count('id', filter=Q(status='consumed'))
            )
            
            days.append({
                "date": curr.strftime("%Y-%m-%d"),
                "total": stats['total'] or 0,
                "consumed": stats['consumed'] or 0
            })
            curr += timedelta(days=1)

        return Response({
            "hostel": user.hostel.hostel_name,
            "period": "Last 7 Days",
            "report": days
        })

class NextDayBookingView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        user = request.user
        if user.role not in ['admin', 'manager']:
            return Response({"error": "Access denied"}, status=403)

        # 🌍 Target date from params or default to tomorrow
        date_str = request.query_params.get("date")
        today = timezone.localtime().date()
        
        if date_str:
            try:
                target_date = timezone.datetime.strptime(date_str, "%Y-%m-%d").date()
            except ValueError:
                return Response({"error": "Invalid date format. Use YYYY-MM-DD"}, status=400)
        else:
            target_date = today + timedelta(days=1)
        
        # 🏢 Hostel Filtering
        hostel_id = request.query_params.get("hostel_id")
        query_filter = Q(booking__date=target_date, status='booked')
        
        hostel = None
        if user.role == 'manager':
            if not user.hostel:
                return Response({"error": "Manager has no hostel assigned"}, status=400)
            query_filter &= Q(booking__user__hostel=user.hostel)
            hostel = user.hostel
        else: # Admin
            if hostel_id:
                query_filter &= Q(booking__user__hostel_id=hostel_id)
                try:
                    hostel = Hostel.objects.get(id=hostel_id)
                except:
                    hostel = None

        # 🕒 Cutoff check
        is_past_cutoff = False
        cutoff_time_str = "N/A"
        if target_date == today + timedelta(days=1) and hostel:
            cutoff = hostel.booking_cutoff_time
            is_past_cutoff = timezone.localtime().time() >= cutoff
            cutoff_time_str = cutoff.strftime("%I:%M %p")

        meals = BookingMeal.objects.filter(query_filter).select_related('meal_slot', 'combo').prefetch_related('meal_items__item')
        individual_items = BookingItem.objects.filter(query_filter).select_related('meal_slot', 'item')

        # Group by slot
        slots_data = {}
        for m in meals:
            s_name = m.meal_slot.slot
            if s_name not in slots_data:
                slots_data[s_name] = {"slot": s_name, "total": 0, "combos": {}, "items": {}}
            
            slots_data[s_name]["total"] += 1
            c_name = m.combo.name
            slots_data[s_name]["combos"][c_name] = slots_data[s_name]["combos"].get(c_name, 0) + 1

            for mi in m.meal_items.all():
                it_name = mi.item.name
                slots_data[s_name]["items"][it_name] = slots_data[s_name]["items"].get(it_name, 0) + mi.quantity

        for i in individual_items:
            s_name = i.meal_slot.slot
            if s_name not in slots_data:
                slots_data[s_name] = {"slot": s_name, "total": 0, "combos": {}, "items": {}}
            
            it_name = i.item.name
            slots_data[s_name]["items"][it_name] = slots_data[s_name]["items"].get(it_name, 0) + i.quantity

        return Response({
            "date": str(target_date),
            "hostel": hostel.hostel_name if hostel else "All Hostels",
            "is_past_cutoff": is_past_cutoff,
            "cutoff_time": cutoff_time_str,
            "stats": list(slots_data.values())
        })
