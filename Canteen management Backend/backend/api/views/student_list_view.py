from rest_framework import generics, permissions
from rest_framework.response import Response
from ..models import User

class StudentListView(generics.ListAPIView):
    permission_classes = [permissions.IsAuthenticated]
    
    def get_queryset(self):
        user = self.request.user
        if user.role == 'manager':
            return User.objects.filter(hostel=user.hostel, role='student')
        elif user.role == 'admin':
            return User.objects.filter(role='student')
        return User.objects.none()

    def list(self, request, *args, **kwargs):
        queryset = self.get_queryset()
        data = [{
            "id": u.id,
            "name": f"{u.first_name} {u.last_name}".strip(),
            "email": u.email,
            "student_id": u.student_id,
            "phone": u.phone,
            "hostel": u.hostel.hostel_name if u.hostel else "No Hostel"
        } for u in queryset]
        return Response(data)
