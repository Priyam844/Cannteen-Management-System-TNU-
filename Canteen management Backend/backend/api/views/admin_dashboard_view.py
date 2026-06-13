import csv
from django.http import HttpResponse
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated
from django.utils import timezone
from datetime import timedelta
from django.db.models import Avg, Count, Q
from django.core.mail import send_mail
from django.conf import settings
from api.models import User, Hostel, Booking, BookingMeal, Feedback, BookingItem, InstitutionalEvent, EventPass

class AdminDashboardView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        if request.user.role != 'admin':
            return Response({"error": "Access denied"}, status=403)

        today = timezone.localtime().date()
        
        # Site-wide stats
        total_students = User.objects.filter(role__in=['student', 'faculty', 'staff']).count()
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
            # Safely get slot and timing
            meal_slot = None
            if fb.booking_meal:
                meal_slot = fb.booking_meal.meal_slot.slot
            elif fb.booking_item:
                meal_slot = fb.booking_item.meal_slot.slot
            
            slot_key = meal_slot.lower() if meal_slot else "unknown"
            timing = fb.hostel.slot_timings.get(slot_key, ["N/A", "N/A"])
            
            feedback_data.append({
                "id": fb.id,
                "rating": fb.rating,
                "comment": fb.comment,
                "hostel": fb.hostel.hostel_name,
                "meal_slot": meal_slot or "Other",
                "meal_time": f"{timing[0]} - {timing[1]}",
                "combo_name": fb.combo.name if fb.combo else "Individual Items",
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
            "cancellation_cutoff_time": h.cancellation_cutoff_time.strftime("%H:%M"),
            "late_booking_lead_time": h.late_booking_lead_time_hours,
            "excluded_for_faculty": h.excluded_for_faculty,
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
        cancellation_cutoff = request.data.get("cancellation_cutoff_time")
        late_lead = request.data.get("late_booking_lead_time")
        excluded_for_faculty = request.data.get("excluded_for_faculty")
        slot_timings = request.data.get("slot_timings")

        if not hostel_id:
            return Response({"error": "Hostel ID required"}, status=400)

        try:
            hostel = Hostel.objects.get(id=hostel_id)
            if cutoff_time:
                hostel.booking_cutoff_time = cutoff_time
            if cancellation_cutoff:
                hostel.cancellation_cutoff_time = cancellation_cutoff
            if late_lead is not None:
                hostel.late_booking_lead_time_hours = int(late_lead)
            if excluded_for_faculty is not None:
                hostel.excluded_for_faculty = bool(excluded_for_faculty)
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
            
        period = request.query_params.get("period", "weekly") # today, weekly, 15days, monthly, 6months, custom
        
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

        # Aggregate stats sitewide
        consumed_meals = BookingMeal.objects.filter(
            booking__date__range=[start_date, end_date],
            status='consumed'
        )
        total_meals = consumed_meals.count()

        # Calculate Veg/Non-Veg
        veg_count = 0
        nonveg_count = 0
        for meal in consumed_meals:
            if meal.combo.items.filter(is_veg=False).exists():
                nonveg_count += 1
            else:
                veg_count += 1

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
            "veg_consumed": veg_count,
            "nonveg_consumed": nonveg_count,
            "hostel_breakdown": hostel_reports
        })

from api.serializers import (
    TransactionSerializer, InstitutionalEventSerializer, EventPassSerializer
)

class InstitutionalEventView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        if request.user.role != 'admin':
            return Response({"error": "Access denied"}, status=403)
        events = InstitutionalEvent.objects.all()
        serializer = InstitutionalEventSerializer(events, many=True)
        return Response(serializer.data)

    def post(self, request):
        if request.user.role != 'admin':
            return Response({"error": "Access denied"}, status=403)
        serializer = InstitutionalEventSerializer(data=request.data)
        if serializer.is_valid():
            serializer.save()
            return Response(serializer.data, status=201)
        return Response(serializer.errors, status=400)

class EventPassView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        if request.user.role != 'admin':
            return Response({"error": "Access denied"}, status=403)
        event_id = request.query_params.get("event_id")
        if not event_id:
            return Response({"error": "event_id required"}, status=400)
        passes = EventPass.objects.filter(event_id=event_id)
        serializer = EventPassSerializer(passes, many=True)
        return Response(serializer.data)

    def post(self, request):
        if request.user.role != 'admin':
            return Response({"error": "Access denied"}, status=403)
        
        event_id = request.data.get("event_id")
        guest_names = request.data.get("guest_names", []) # Legacy support
        guests = request.data.get("guests", []) # New format: [{"name": "", "email": "", "meal_slots": []}]
        
        if not event_id or (not guest_names and not guests):
            return Response({"error": "event_id and guest names/data required"}, status=400)
            
        try:
            event = InstitutionalEvent.objects.get(id=event_id)
            passes = []
            
            # Process legacy guest_names
            for name in guest_names:
                p = EventPass.objects.create(
                    event=event,
                    guest_name=name,
                    valid_from=request.data.get("valid_from"),
                    valid_until=request.data.get("valid_until")
                )
                passes.append(p)

            # Process enhanced guest data
            for g in guests:
                name = g.get("name")
                email = g.get("email")
                meal_slots = g.get("meal_slots", [])
                
                p = EventPass.objects.create(
                    event=event,
                    guest_name=name,
                    email=email,
                    meal_slots=meal_slots,
                    valid_from=g.get("valid_from", request.data.get("valid_from")),
                    valid_until=g.get("valid_until", request.data.get("valid_until"))
                )
                passes.append(p)

                # 📧 Send QR Code Email (HTML)
                if email:
                    try:
                        qr_url = f"https://api.qrserver.com/v1/create-qr-code/?size=250x250&data={p.qr_uuid}"
                        subject = f"Your Guest Pass: {event.name}"
                        
                        slots_str = ", ".join([s.capitalize() for s in meal_slots]) if meal_slots else "All Meal Slots"
                        
                        html_message = f"""
                        <div style="font-family: Arial, sans-serif; max-width: 600px; margin: auto; border: 1px solid #ddd; border-radius: 10px; padding: 20px;">
                            <h2 style="color: #981D44; text-align: center;">Institutional Event Guest Pass</h2>
                            <p>Hello <strong>{name}</strong>,</p>
                            <p>Your guest pass for the event <strong>{event.name}</strong> has been generated successfully.</p>
                            
                            <div style="background-color: #f9f9f9; padding: 15px; border-radius: 8px; margin: 20px 0;">
                                <p><strong>Event:</strong> {event.name}</p>
                                <p><strong>Allowed Meals:</strong> {slots_str}</p>
                                <p><strong>Validity:</strong> {event.start_date} to {event.end_date}</p>
                            </div>

                            <div style="text-align: center; margin: 30px 0;">
                                <p style="font-size: 14px; color: #666;">Scan this QR code at the canteen counter</p>
                                <img src="{qr_url}" alt="QR Code" style="border: 5px solid #fff; box-shadow: 0 0 10px rgba(0,0,0,0.1); width: 200px; height: 200px;" />
                                <p style="font-family: monospace; font-size: 12px; color: #999; margin-top: 10px;">ID: {p.qr_uuid}</p>
                            </div>

                            <p style="font-size: 13px; color: #888; text-align: center;">This pass is valid for standard institutional meals during the event period.</p>
                        </div>
                        """
                        
                        send_mail(
                            subject,
                            "", # Plain text version
                            settings.EMAIL_HOST_USER,
                            [email],
                            fail_silently=True,
                            html_message=html_message
                        )
                    except Exception as e:
                        print(f"Email Error: {e}")
            
            serializer = EventPassSerializer(passes, many=True)
            return Response(serializer.data, status=201)
        except InstitutionalEvent.DoesNotExist:
            return Response({"error": "Event not found"}, status=404)
        except Exception as e:
            return Response({"error": str(e)}, status=400)

    def delete(self, request):
        if request.user.role != 'admin':
            return Response({"error": "Access denied"}, status=403)
        
        pass_id = request.query_params.get("id")
        if not pass_id:
            return Response({"error": "id required"}, status=400)
            
        try:
            event_pass = EventPass.objects.get(id=pass_id)
            event_pass.delete()
            return Response({"message": "Guest pass deleted successfully"})
        except EventPass.DoesNotExist:
            return Response({"error": "Pass not found"}, status=404)
        except Exception as e:
            return Response({"error": str(e)}, status=400)
        except InstitutionalEvent.DoesNotExist:
            return Response({"error": "Event not found"}, status=404)
        except Exception as e:
            return Response({"error": str(e)}, status=400)

class AdminDownloadReportView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        if request.user.role != 'admin':
            return Response({"error": "Access denied"}, status=403)
            
        period = request.query_params.get("period", "weekly")
        
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
                return Response({"error": "Invalid custom dates"}, status=400)
        else:
            start_date = end_date - timedelta(days=7)

        # Create the HttpResponse object with the appropriate CSV header.
        response = HttpResponse(content_type='text/csv')
        response['Content-Disposition'] = f'attachment; filename="canteen_report_{start_date}_to_{end_date}.csv"'

        writer = csv.writer(response)
        writer.writerow(['Date', 'Student ID', 'Student Name', 'Hostel', 'Slot', 'Combo', 'Items', 'Status'])

        meals = BookingMeal.objects.filter(
            booking__date__range=[start_date, end_date],
            status='consumed'
        ).select_related('booking__user', 'booking__user__hostel', 'meal_slot', 'combo')

        for m in meals:
            items_str = ", ".join([mi.item.name for mi in m.meal_items.all()])
            writer.writerow([
                m.booking.date,
                m.booking.user.student_id,
                f"{m.booking.user.first_name} {m.booking.user.last_name}",
                m.booking.user.hostel.hostel_name if m.booking.user.hostel else "N/A",
                m.meal_slot.slot,
                m.combo.name,
                items_str,
                m.status
            ])

        return response


class AdminAddUserView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        if request.user.role != 'admin':
            return Response({'error': 'Access denied'}, status=403)

        email = request.data.get('email', '').strip().lower()
        password = request.data.get('password')
        first_name = request.data.get('first_name', '').strip()
        last_name = request.data.get('last_name', '').strip()
        role = request.data.get('role', 'student')
        hostel_id = request.data.get('hostel_id')
        phone = request.data.get('phone')
        student_id = request.data.get('student_id')

        if not email or not role:
            return Response({'error': 'Email and role are required'}, status=400)

        if User.objects.filter(email=email).exists():
            return Response({'error': 'User with this email already exists'}, status=400)

        try:
            hostel = None
            if hostel_id:
                hostel = Hostel.objects.get(id=hostel_id)

            if role == 'manager' or password:
                # Direct User Creation (Manager or anyone with a password)
                if not password:
                    return Response({'error': 'Password required for direct account creation'}, status=400)
                
                user = User.objects.create_user(
                    email=email,
                    password=password,
                    first_name=first_name,
                    last_name=last_name,
                    role=role,
                    hostel=hostel,
                    phone=phone,
                    student_id=student_id
                )
                return Response({'message': f'{role.capitalize()} created successfully'}, status=201)
            
            else:
                # Add to AllowedUser (Standard flow for Students/Faculty)
                if not phone or not hostel:
                    return Response({'error': 'Phone and Hostel are required to authorize a student/faculty'}, status=400)
                
                from api.models import AllowedUser
                allowed, created = AllowedUser.objects.get_or_create(
                    email=email,
                    defaults={'phone': phone, 'hostel': hostel, 'role': role}
                )
                if not created:
                    return Response({'error': 'User already authorized'}, status=400)
                
                return Response({'message': f'{role.capitalize()} authorized successfully'}, status=201)

        except Hostel.DoesNotExist:
            return Response({'error': 'Hostel not found'}, status=404)
        except Exception as e:
            return Response({'error': str(e)}, status=500)
