from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status
from rest_framework.permissions import AllowAny
from django.contrib.auth import authenticate
from rest_framework_simplejwt.tokens import RefreshToken
from django.utils.timezone import now
from datetime import timedelta
from django.db import transaction
from django.core.mail import send_mail
from django.conf import settings
import random

from api.models import User, OTP, AllowedUser
from django.contrib.auth import get_user_model

# =========================
# 🔐 LOGIN
# =========================
User = get_user_model()


class LoginView(APIView):
    permission_classes = [AllowAny]

    def post(self, request):
        email = request.data.get("email", "").strip().lower()
        password = request.data.get("password")
        role = request.data.get("role")

        if not email or not password:
            return Response({"error": "Email and password required"}, status=400)

        # 🔐 Fetch user safely
        try:
            user = User.objects.get(email__iexact=email)
        except User.DoesNotExist:
            return Response({"error": "Invalid credentials"}, status=401)

        # 🔐 Password check
        if not user.check_password(password):
            return Response({"error": "Invalid credentials"}, status=401)

        # 🚫 Active check
        if not user.is_active:
            return Response({"error": "Account disabled"}, status=403)

        # 🔥 Role check
        if role:
            role = role.strip().lower()
            if user.role != role:
                return Response(
                    {"error": f"This account is not a {role}"},
                    status=403
                )

        # 🔑 Token
        refresh = RefreshToken.for_user(user)

        return Response({
            "message": "Login successful",
            "access": str(refresh.access_token),
            "refresh": str(refresh),
            "user": {
                "email": user.email,
                "name": f"{user.first_name} {user.last_name}".strip(),
                "role": user.role,
                "hostel": user.hostel.hostel_name if user.hostel else None,
            }
        }, status=200)
# =========================
# 📧 SEND OTP
# =========================
class SendOTPView(APIView):
    permission_classes = [AllowAny]

    def post(self, request):
        email = request.data.get("email", "").strip().lower()

        if not email:
            return Response({"error": "Email required"}, status=400)

        # Allowed user check
        if not AllowedUser.objects.filter(email__iexact=email).exists():
            return Response({"error": "Email not authorized"}, status=403)

        if User.objects.filter(email__iexact=email).exists():
            return Response({"error": "User already exists"}, status=400)

        if AllowedUser.objects.filter(email__iexact=email, is_used=True).exists():
            return Response({"error": "Email already used"}, status=400)

        # Rate limit
        if OTP.objects.filter(
            email=email,
            created_at__gte=now() - timedelta(seconds=60)
        ).exists():
            return Response({"error": "Wait before retry"}, status=429)

        otp_code = str(random.randint(100000, 999999))

        OTP.objects.create(
            email=email,
            otp_code=otp_code,
            expires_at=now() + timedelta(minutes=10)
        )

        try:
            send_mail(
                subject="OTP Verification",
                message=f"Your OTP is {otp_code}",
                from_email=settings.EMAIL_HOST_USER,
                recipient_list=[email],
            )
            return Response({"message": "OTP sent"}, status=200)

        except Exception as e:
            print(f"EMAIL SENDING ERROR: {e}")
            return Response({"error": f"Email sending failed: {str(e)}"}, status=500)


# =========================
# 🔑 VERIFY OTP
# =========================
class VerifyOTPView(APIView):
    permission_classes = [AllowAny]

    def post(self, request):
        email = request.data.get("email", "").strip().lower()
        otp = request.data.get("otp")

        if not email or not otp:
            return Response({"error": "Email & OTP required"}, status=400)

        otp_obj = OTP.objects.filter(
            email=email,
            otp_code=otp,
            is_verified=False,
            expires_at__gte=now()
        ).order_by("-created_at").first()

        if not otp_obj:
            return Response({"error": "Invalid or expired OTP"}, status=400)

        otp_obj.is_verified = True
        otp_obj.save()

        return Response({"message": "OTP verified"}, status=200)


# =========================
# 📝 REGISTER
# =========================
class RegisterView(APIView):
    permission_classes = [AllowAny]

    def post(self, request):
        email = request.data.get("email", "").strip().lower()
        password = request.data.get("password")
        confirm_password = request.data.get("confirm_password")
        first_name = request.data.get("first_name", "").strip()
        last_name = request.data.get("last_name", "").strip()
        student_id = request.data.get("student_id")

        if not all([email, password, confirm_password, first_name]):
            return Response({"error": "Missing fields"}, status=400)

        if password != confirm_password:
            return Response({"error": "Passwords mismatch"}, status=400)

        if len(password) < 8:
            return Response({"error": "Password too short"}, status=400)

        # OTP must be verified FIRST
        otp_verified = OTP.objects.filter(
            email=email,
            is_verified=True
        ).exists()

        if not otp_verified:
            return Response({"error": "OTP not verified"}, status=403)

        try:
            with transaction.atomic():
                allowed = AllowedUser.objects.select_for_update().get(
                    email__iexact=email,
                    is_used=False
                )

                user = User.objects.create_user(
                    #username=email,
                    email=email,
                    password=password,
                    first_name=first_name,
                    last_name=last_name,
                    student_id=student_id,
                    phone=getattr(allowed, "phone", ""),
                    hostel=allowed.hostel,
                    allowed_user=allowed,
                    role="student"
                )

                allowed.is_used = True
                allowed.save()

                return Response({
                    "message": "Registration successful",
                    "user": {"email": user.email}
                }, status=201)

        except AllowedUser.DoesNotExist:
            return Response({"error": "Not authorized"}, status=403)

        except Exception as e:
            return Response({"error": str(e)}, status=500)