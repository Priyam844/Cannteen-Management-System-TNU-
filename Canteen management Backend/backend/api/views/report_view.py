from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated
from django.db.models import Count, Q
from ..models import BookingMeal, Booking
from datetime import timedelta
from django.utils.timezone import now

class ManagerReportsView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        user = request.user
        if user.role != 'manager':
            return Response({"error": "Access denied"}, status=403)
        
        # Last 7 days report
        end_date = now().date()
        start_date = end_date - timedelta(days=7)
        
        days = []
        curr = start_date
        while curr <= end_date:
            day_bookings = Booking.objects.filter(date=curr, user__hostel=user.hostel)
            
            stats = BookingMeal.objects.filter(
                booking__in=day_bookings
            ).exclude(status='cancelled').aggregate(
                total=Count('id'),
                consumed=Count('id', filter=Q(status='consumed')),
                veg=Count('id', filter=Q(combo__category='veg')),
                non_veg=Count('id', filter=Q(combo__category='nonveg'))
            )
            
            days.append({
                "date": curr.strftime("%Y-%m-%d"),
                "total": stats['total'] or 0,
                "consumed": stats['consumed'] or 0,
                "veg": stats['veg'] or 0,
                "non_veg": stats['non_veg'] or 0
            })
            curr += timedelta(days=1)

        return Response({
            "hostel": user.hostel.hostel_name,
            "period": "Last 7 Days",
            "report": days
        })
