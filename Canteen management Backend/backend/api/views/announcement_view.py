from rest_framework import generics, permissions
from rest_framework.response import Response
from ..models import Announcement
from ..serializers import AnnouncementSerializer

class AnnouncementListCreateView(generics.ListCreateAPIView):
    serializer_class = AnnouncementSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        user = self.request.user
        # Students see active global announcements or announcements for their hostel
        if user.role == 'student':
            return Announcement.objects.filter(
                is_active=True
            ).filter(
                hostel__isnull=True
            ) | Announcement.objects.filter(
                is_active=True, 
                hostel=user.hostel
            )
        
        # Managers see announcements they created or global ones, or hostel ones
        if user.role == 'manager':
            return Announcement.objects.filter(hostel=user.hostel) | Announcement.objects.filter(hostel__isnull=True)
            
        # Admins see everything
        return Announcement.objects.all()

    def perform_create(self, serializer):
        user = self.request.user
        hostel = user.hostel if user.role == 'manager' else serializer.validated_data.get('hostel')
        serializer.save(created_by=user, hostel=hostel)

class AnnouncementDetailView(generics.RetrieveUpdateDestroyAPIView):
    queryset = Announcement.objects.all()
    serializer_class = AnnouncementSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        user = self.request.user
        if user.role == 'manager':
            return Announcement.objects.filter(hostel=user.hostel)
        if user.role == 'admin':
            return Announcement.objects.all()
        return Announcement.objects.filter(is_active=True)
