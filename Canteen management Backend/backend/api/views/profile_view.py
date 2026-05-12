from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated
from rest_framework.status import HTTP_200_OK, HTTP_400_BAD_REQUEST
from ..serializers import UserUpdateSerializer


from rest_framework.parsers import MultiPartParser, FormParser

class ProfileView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        try:
            user = request.user

            return Response({
                "first_name": user.first_name,
                "last_name": user.last_name,
                "name": f"{user.first_name or ''} {user.last_name or ''}".strip(),
                "email": user.email,
                "student_id": user.student_id,
                "phone": user.phone,
                "hostel": user.hostel.hostel_name if user.hostel else None,
                "profile_picture": request.build_absolute_uri(user.profile_picture.url) if user.profile_picture else None,
            }, status=HTTP_200_OK)

        except Exception as e:
            return Response(
                {"error": f"Failed to retrieve profile: {str(e)}"},
                status=HTTP_400_BAD_REQUEST
            )

class UpdateProfileView(APIView):
    permission_classes = [IsAuthenticated]
    parser_classes = [MultiPartParser, FormParser]

    def put(self, request):
        serializer = UserUpdateSerializer(request.user, data=request.data, partial=True)
        if serializer.is_valid():
            serializer.save()
            return Response({"message": "Profile updated successfully"}, status=HTTP_200_OK)
        return Response(serializer.errors, status=HTTP_400_BAD_REQUEST)