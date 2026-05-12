from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated
from django.utils.timezone import now
from datetime import timedelta
from django.db.models import Avg
from api.models import User, Hostel, Booking, BookingMeal, Feedback

class AdminDashboardView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        if request.user.role != 'admin':
            return Response({"error": "Access denied"}, status=403)

        today = now().date()
        
        # Site-wide stats
        total_students = User.objects.filter(role='student').count()
        total_hostels = Hostel.objects.count()
        today_bookings = Booking.objects.filter(date=today).count()
        total_feedback = Feedback.objects.count()

        # ⭐ Overall Institution Rating
        overall_avg = Feedback.objects.aggregate(avg=Avg('rating'))['avg'] or 0

        # Stats per hostel
        hostels_stats = []
        hostels = Hostel.objects.all()
        for hostel in hostels:
            # Surplus calculation for today
            h_booked = BookingMeal.objects.filter(
                booking__date=today, 
                booking__user__hostel=hostel
            ).exclude(status='cancelled').count()
            
            h_consumed = BookingMeal.objects.filter(
                booking__date=today, 
                booking__user__hostel=hostel,
                status='consumed'
            ).count()
            
            surplus = h_booked - h_consumed
            
            # Rating per hostel
            h_rating = Feedback.objects.filter(hostel=hostel).aggregate(avg=Avg('rating'))['avg'] or 0

            hostels_stats.append({
                "name": hostel.hostel_name,
                "students": hostel.users.count(),
                "bookings_today": h_booked,
                "consumed_today": h_consumed,
                "surplus_today": max(0, surplus),
                "avg_rating": round(float(h_rating), 1)
            })

        # Recent feedback
        recent_feedback = Feedback.objects.order_by('-created_at')[:5]
        feedback_data = []
        for fb in recent_feedback:
            slot_key = fb.booking_meal.meal_slot.slot.lower()
            timing = fb.hostel.slot_timings.get(slot_key, ["N/A", "N/A"])
            
            feedback_data.append({
                "id": fb.id,
                "rating": fb.rating,
                "comment": fb.comment,
                "hostel": fb.hostel.hostel_name,
                "meal_slot": fb.booking_meal.meal_slot.slot,
                "meal_time": f"{timing[0]} - {timing[1]}",
                "combo_name": fb.combo.name,
                "date": fb.created_at.date()
            })

        return Response({
            "total_students": total_students,
            "total_hostels": total_hostels,
            "today_bookings": today_bookings,
            "total_feedback": total_feedback,
            "overall_rating": round(float(overall_avg), 1),
            "hostels": hostels_stats,
            "recent_feedback": feedback_data
        })

class AdminManagementView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        if request.user.role != 'admin':
            return Response({"error": "Access denied"}, status=403)
        
        managers = User.objects.filter(role='manager')
        data = [{
            "id": m.id,
            "first_name": m.first_name,
            "last_name": m.last_name,
            "email": m.email,
            "hostel": m.hostel.hostel_name if m.hostel else "None",
            "hostel_id": m.hostel.id if m.hostel else None
        } for m in managers]
        
        hostels = Hostel.objects.all()
        hostel_data = [{
            "id": h.id, 
            "name": h.hostel_name,
            "cutoff_time": h.booking_cutoff_time.strftime("%H:%M"),
            "slot_timings": h.slot_timings
        } for h in hostels]
        
        return Response({
            "managers": data,
            "hostels": hostel_data
        })

    def put(self, request):
        if request.user.role != 'admin':
            return Response({"error": "Access denied"}, status=403)
            
        hostel_id = request.data.get("hostel_id")
        cutoff_time = request.data.get("cutoff_time") # HH:MM
        slot_timings = request.data.get("slot_timings")
        
        if not hostel_id:
            return Response({"error": "Hostel ID required"}, status=400)
            
        try:
            hostel = Hostel.objects.get(id=hostel_id)
            if cutoff_time:
                hostel.booking_cutoff_time = cutoff_time
            if slot_timings:
                hostel.slot_timings = slot_timings
            hostel.save()
            return Response({"message": "Hostel settings updated successfully"})
        except Exception as e:
            return Response({"error": str(e)}, status=400)

    def post(self, request):
        if request.user.role != 'admin':
            return Response({"error": "Access denied"}, status=403)
        
        email = request.data.get("email")
        password = request.data.get("password")
        first_name = request.data.get("first_name")
        last_name = request.data.get("last_name")
        hostel_id = request.data.get("hostel_id")
        
        if not all([email, password, first_name, last_name, hostel_id]):
            return Response({"error": "All fields required"}, status=400)
        
        if User.objects.filter(email=email).exists():
            return Response({"error": "Email already exists"}, status=400)
            
        try:
            hostel = Hostel.objects.get(id=hostel_id)
            user = User.objects.create_user(
                email=email,
                password=password,
                first_name=first_name,
                last_name=last_name,
                role='manager',
                hostel=hostel
            )
            return Response({"message": "Manager created successfully"}, status=201)
        except Exception as e:
            return Response({"error": str(e)}, status=400)

    def delete(self, request):
        if request.user.role != 'admin':
            return Response({"error": "Access denied"}, status=403)
        
        manager_id = request.query_params.get("id")
        try:
            manager = User.objects.get(id=manager_id, role='manager')
            manager.delete()
            return Response({"message": "Manager deleted"})
        except User.DoesNotExist:
            return Response({"error": "Manager not found"}, status=404)

class AdminReportsView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        if request.user.role != 'admin':
            return Response({"error": "Access denied"}, status=403)
            
        period = request.query_params.get("period", "weekly") # weekly, monthly, 6months
        
        end_date = now().date()
        if period == "weekly":
            start_date = end_date - timedelta(days=7)
        elif period == "monthly":
            start_date = end_date - timedelta(days=30)
        elif period == "6months":
            start_date = end_date - timedelta(days=180)
        else:
            start_date = end_date - timedelta(days=7)

        # Aggregate stats sitewide
        total_meals = BookingMeal.objects.filter(
            booking__date__range=[start_date, end_date],
            status='consumed'
        ).count()
        
        veg_meals = BookingMeal.objects.filter(
            booking__date__range=[start_date, end_date],
            status='consumed',
            combo__category='veg'
        ).count()
        
        nonveg_meals = BookingMeal.objects.filter(
            booking__date__range=[start_date, end_date],
            status='consumed',
            combo__category='nonveg'
        ).count()

        # Stats per hostel
        hostel_reports = []
        hostels = Hostel.objects.all()
        for h in hostels:
            h_total = BookingMeal.objects.filter(
                booking__date__range=[start_date, end_date],
                status='consumed',
                booking__user__hostel=h
            ).count()
            hostel_reports.append({
                "hostel": h.hostel_name,
                "total_consumed": h_total
            })

        return Response({
            "period": period,
            "start_date": start_date,
            "end_date": end_date,
            "total_consumed": total_meals,
            "veg_consumed": veg_meals,
            "nonveg_consumed": nonveg_meals,
            "hostel_breakdown": hostel_reports
        })
