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

class FeedbackListView(generics.ListAPIView):
    serializer_class = FeedbackSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        # Managers can see all feedback for their hostel, students see their own
        user = self.request.user
        if user.role == 'manager':
            return Feedback.objects.filter(hostel=user.hostel)
        return Feedback.objects.filter(user=user)
