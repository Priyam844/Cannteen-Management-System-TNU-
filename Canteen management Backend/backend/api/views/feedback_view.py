from rest_framework import generics, permissions, status
from rest_framework.response import Response
from ..models import Feedback, BookingMeal
from ..serializers import FeedbackSerializer

class FeedbackCreateView(generics.CreateAPIView):
    queryset = Feedback.objects.all()
    serializer_class = FeedbackSerializer
    permission_classes = [permissions.IsAuthenticated]

    def create(self, request, *args, **kwargs):
        user = request.user
        booking_meal_id = request.data.get('booking_meal')
        
        try:
            booking_meal = BookingMeal.objects.get(id=booking_meal_id)
            
            # 🚨 Check if the meal is consumed
            if booking_meal.status != 'consumed':
                return Response(
                    {"error": "You can only provide feedback for consumed meals."},
                    status=status.HTTP_400_BAD_REQUEST
                )
            
            # 🚨 Optional: Check if the user is the owner of the booking
            if booking_meal.booking.user != user:
                return Response(
                    {"error": "This booking does not belong to you."},
                    status=status.HTTP_403_FORBIDDEN
                )

        except BookingMeal.DoesNotExist:
            return Response(
                {"error": "Meal slot not found."},
                status=status.HTTP_404_NOT_FOUND
            )

        return super().create(request, *args, **kwargs)

    def perform_create(self, serializer):
        serializer.save()

from django.utils import timezone
from datetime import timedelta

class FeedbackListView(generics.ListAPIView):
    serializer_class = FeedbackSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        user = self.request.user
        hostel_id = self.request.query_params.get('hostel_id')
        period = self.request.query_params.get('period', 'all')

        if user.role == 'admin':
            queryset = Feedback.objects.all()
            if hostel_id:
                queryset = queryset.filter(hostel_id=hostel_id)
            
            # 📅 Admin Filtering
            end_date = timezone.now()
            if period == 'today':
                queryset = queryset.filter(created_at__date=end_date.date())
            elif period == '3days':
                queryset = queryset.filter(created_at__gte=end_date - timedelta(days=3))
            elif period == '7days':
                queryset = queryset.filter(created_at__gte=end_date - timedelta(days=7))
            elif period == '15days':
                queryset = queryset.filter(created_at__gte=end_date - timedelta(days=15))
            elif period == '30days':
                queryset = queryset.filter(created_at__gte=end_date - timedelta(days=30))
            elif period == '6months':
                queryset = queryset.filter(created_at__gte=end_date - timedelta(days=180))
            elif period == 'custom':
                start_date_str = self.request.query_params.get('start_date')
                end_date_str = self.request.query_params.get('end_date')
                if start_date_str and end_date_str:
                    queryset = queryset.filter(created_at__date__range=[start_date_str, end_date_str])
            
            return queryset.order_by('-created_at')

        elif user.role == 'manager' or user.role == 'student':
            if user.hostel:
                # 🛡️ Hide feedback older than 7 days for non-admins
                seven_days_ago = timezone.now() - timedelta(days=7)
                return Feedback.objects.filter(
                    hostel=user.hostel,
                    created_at__gte=seven_days_ago
                ).order_by('-created_at')
            return Feedback.objects.none()
        
        return Feedback.objects.none()
