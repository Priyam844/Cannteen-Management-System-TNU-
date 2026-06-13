from rest_framework import generics, permissions, status
from rest_framework.views import APIView
from rest_framework.parsers import MultiPartParser, FormParser
from rest_framework.response import Response
import csv
import openpyxl
import io
from ..models import AllowedUser, Hostel

class AllowedUserListView(generics.ListCreateAPIView):
    permission_classes = [permissions.IsAuthenticated]
    
    def get_queryset(self):
        user = self.request.user
        if user.role == 'manager':
            return AllowedUser.objects.filter(hostel=user.hostel)
        elif user.role == 'admin':
            return AllowedUser.objects.all()
        return AllowedUser.objects.none()

    def list(self, request, *args, **kwargs):
        queryset = self.get_queryset()
        data = [{
            "id": a.id,
            "email": a.email,
            "phone": a.phone,
            "role": a.role,
            "is_used": a.is_used,
            "created_at": a.created_at
        } for a in queryset]
        return Response(data)

    def post(self, request, *args, **kwargs):
        user = self.request.user
        if user.role not in ['manager', 'admin']:
            return Response({"error": "Access denied"}, status=403)
        
        email = request.data.get("email")
        phone = request.data.get("phone")
        role = request.data.get("role", "student") # Default to student
        
        if not email or not phone:
            return Response({"error": "Email and phone required"}, status=400)
            
        hostel = user.hostel if user.role == 'manager' else None
        if user.role == 'admin':
             # Admin must provide hostel_id
             hostel_id = request.data.get("hostel_id")
             if hostel_id:
                 from ..models import Hostel
                 hostel = Hostel.objects.filter(id=hostel_id).first()

        if not hostel:
             return Response({"error": "Hostel required"}, status=400)

        allowed, created = AllowedUser.objects.get_or_create(
            email=email,
            defaults={"phone": phone, "hostel": hostel, "role": role}
        )
        
        if not created:
            return Response({"error": "Email already authorized"}, status=400)
            
        return Response({"message": "User authorized successfully"}, status=201)


class BulkAuthorizeView(APIView):
    permission_classes = [permissions.IsAuthenticated]
    parser_classes = [MultiPartParser, FormParser]

    def post(self, request):
        if request.user.role != 'admin':
            return Response({"error": "Access denied"}, status=403)

        file_obj = request.data.get('file')
        hostel_id = request.data.get('hostel_id')

        if not file_obj or not hostel_id:
            return Response({"error": "File and Hostel ID are required"}, status=400)

        try:
            hostel = Hostel.objects.get(id=hostel_id)
        except Hostel.DoesNotExist:
            return Response({"error": "Hostel not found"}, status=404)

        students_to_add = []
        filename = file_obj.name

        try:
            if filename.endswith('.csv'):
                decoded_file = file_obj.read().decode('utf-8')
                io_string = io.StringIO(decoded_file)
                reader = csv.DictReader(io_string)
                for row in reader:
                    email = row.get('email', '').strip()
                    phone = row.get('phone', '').strip()
                    if email and phone:
                        students_to_add.append((email, phone))

            elif filename.endswith('.xlsx'):
                wb = openpyxl.load_workbook(file_obj)
                sheet = wb.active
                # Assume headers in first row: email, phone
                # row index starts at 1, so row 2 is index 2
                for row in sheet.iter_rows(min_row=2, values_only=True):
                    if len(row) >= 2:
                        email = str(row[0]).strip() if row[0] else ''
                        phone = str(row[1]).strip() if row[1] else ''
                        if email and phone:
                            students_to_add.append((email, phone))
            else:
                return Response({"error": "Unsupported file format. Use .csv or .xlsx"}, status=400)

            success_count = 0
            errors = []

            for email, phone in students_to_add:
                if AllowedUser.objects.filter(email=email).exists():
                    errors.append(f"{email}: Already exists")
                    continue
                
                try:
                    AllowedUser.objects.create(email=email, phone=phone, hostel=hostel)
                    success_count += 1
                except Exception as e:
                    errors.append(f"{email}: {str(e)}")

            return Response({
                "message": f"Successfully added {success_count} students.",
                "errors": errors
            }, status=200)

        except Exception as e:
            return Response({"error": f"Error parsing file: {str(e)}"}, status=400)
