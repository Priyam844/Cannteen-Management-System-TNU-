from django.db import models
from django.contrib.auth.models import AbstractUser, BaseUserManager
from django.core.exceptions import ValidationError
import uuid


# 🏢 Hostel
class Hostel(models.Model):
    hostel_name = models.CharField(max_length=50)

    hostel_type = models.CharField(
        max_length=20,
        choices=[
            ('boys', 'Boys'),
            ('girls', 'Girls'),
        ],
        default='boys'
    )

    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['hostel_name']
        verbose_name_plural = "Hostels"

    def __str__(self):
        return self.hostel_name


# 🔧 Custom User Manager
class UserManager(BaseUserManager):
    def create_user(self, email, password=None, **extra_fields):
        if not email:
            raise ValueError("Email is required")

        email = self.normalize_email(email)

        user = self.model(email=email, **extra_fields)
        user.set_password(password)
        user.save(using=self._db)
        return user

    def create_superuser(self, email, password=None, **extra_fields):
        extra_fields.setdefault('is_staff', True)
        extra_fields.setdefault('is_superuser', True)
        extra_fields.setdefault('role', 'admin')

        return self.create_user(email, password, **extra_fields)


# 👤 Custom User
class User(AbstractUser):
    username = None

    email = models.EmailField(unique=True)
    first_name = models.CharField(max_length=100)
    last_name = models.CharField(max_length=100)

    student_id = models.CharField(max_length=20, unique=True)
    phone = models.CharField(max_length=20, unique=True, null=True, blank=True)

    hostel = models.ForeignKey(
        Hostel,
        on_delete=models.CASCADE,
        null=True,
        blank=True,
        related_name='users'
    )

    role = models.CharField(
        max_length=20,
        choices=[
            ('student', 'Student'),
            ('manager', 'Manager'),
            ('admin', 'Admin'),
        ],
        default='student'
    )

    allowed_user = models.OneToOneField(
        'AllowedUser',
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        unique=True
    )

    USERNAME_FIELD = 'email'
    REQUIRED_FIELDS = []

    objects = UserManager()

    def __str__(self):
        return self.email


# 📧 Allowed Users
class AllowedUser(models.Model):
    email = models.EmailField(unique=True)
    phone = models.CharField(max_length=20, unique=True)

    hostel = models.ForeignKey(
        Hostel,
        on_delete=models.CASCADE,
        related_name='allowed_users'
    )

    is_used = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = 'api_allowed_user'

    def __str__(self):
        return self.email


# 🔑 OTP
class OTP(models.Model):
    email = models.EmailField(db_index=True)
    otp_code = models.CharField(max_length=6)

    is_verified = models.BooleanField(default=False)
    expires_at = models.DateTimeField()
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"{self.email} - {self.otp_code}"


# 🍽 Item
class Item(models.Model):
    name = models.CharField(max_length=100)
    is_veg = models.BooleanField(default=True)
    description = models.TextField(blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['name']
        verbose_name_plural = "Items"

    def __str__(self):
        return self.name


# 🍱 Combo (✅ NOW HOSTEL-SPECIFIC)
class Combo(models.Model):
    MEAL_TYPE_CHOICES = [
        ('breakfast', 'Breakfast'),
        ('lunch', 'Lunch'),
        ('snacks', 'Snacks'),
        ('dinner', 'Dinner'),
    ]

    CATEGORY_CHOICES = [
        ('veg', 'Veg'),
        ('nonveg', 'Non-Veg'),
    ]

    hostel = models.ForeignKey(
        Hostel,
        on_delete=models.CASCADE,
        related_name='combos'
    )

    name = models.CharField(max_length=100)
    meal_type = models.CharField(max_length=20, choices=MEAL_TYPE_CHOICES)
    category = models.CharField(max_length=20, choices=CATEGORY_CHOICES)

    price = models.DecimalField(max_digits=8, decimal_places=2)
    description = models.TextField(blank=True)

    is_active = models.BooleanField(default=True)

    items = models.ManyToManyField(Item, related_name='combos')

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['-created_at']
        verbose_name_plural = "Combos"

    def __str__(self):
        return f"{self.name} ({self.hostel})"


# ⏰ MealSlot (✅ NOW HOSTEL-SPECIFIC)
class MealSlot(models.Model):
    DAY_CHOICES = [
        ('Monday', 'Monday'),
        ('Tuesday', 'Tuesday'),
        ('Wednesday', 'Wednesday'),
        ('Thursday', 'Thursday'),
        ('Friday', 'Friday'),
        ('Saturday', 'Saturday'),
        ('Sunday', 'Sunday'),
    ]

    SLOT_CHOICES = [
        ('breakfast', 'Breakfast'),
        ('lunch', 'Lunch'),
        ('snacks', 'Snacks'),
        ('dinner', 'Dinner'),
    ]

    hostel = models.ForeignKey(
        Hostel,
        on_delete=models.CASCADE,
        related_name='meal_slots'
    )

    day = models.CharField(max_length=20, choices=DAY_CHOICES)
    slot = models.CharField(max_length=10, choices=SLOT_CHOICES)
    date = models.DateField(null=True, blank=True)

    combos = models.ManyToManyField(Combo, related_name='meal_slots')

    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        unique_together = [['hostel', 'day', 'slot', 'date']]
        ordering = ['day', 'slot']
        verbose_name_plural = "Meal Slots"

    def clean(self):
        if self.pk:
            if self.combos.count() > 2:
                raise ValidationError("Max 2 combos allowed per meal slot")

            for combo in self.combos.all():
                if combo.hostel != self.hostel:
                    raise ValidationError("Combo does not belong to this hostel")

    def __str__(self):
        return f"{self.hostel} - {self.day} - {self.slot}"


# 📋 Booking
class Booking(models.Model):
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='bookings')
    date = models.DateField()

    qr_uuid = models.UUIDField(default=uuid.uuid4, unique=True, editable=False)
    is_active = models.BooleanField(default=True)

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        unique_together = [['user', 'date']]
        ordering = ['-created_at']
        verbose_name_plural = "Bookings"

    def __str__(self):
        return f"{self.user.email} - {self.date}"


# 🍴 BookingMeal
class BookingMeal(models.Model):
    STATUS_CHOICES = [
        ('booked', 'Booked'),
        ('cancelled', 'Cancelled'),
        ('consumed', 'Consumed'),
        ('expired', 'Expired'),
    ]

    booking = models.ForeignKey(Booking, on_delete=models.CASCADE, related_name='meals')

    meal_slot = models.ForeignKey(
        MealSlot,
        on_delete=models.CASCADE,
        related_name='bookings'
    )

    combo = models.ForeignKey(
        Combo,
        on_delete=models.CASCADE,
        related_name='bookings'
    )

    status = models.CharField(max_length=10, choices=STATUS_CHOICES, default='booked')

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        unique_together = [['booking', 'meal_slot']]
        ordering = ['-created_at']
        verbose_name_plural = "Booking Meals"

    def clean(self):
        if self.combo not in self.meal_slot.combos.all():
            raise ValidationError("Combo not available in this meal slot")

        if self.combo.hostel != self.meal_slot.hostel:
            raise ValidationError("Hostel mismatch")

    def __str__(self):
        return f"{self.booking} - {self.combo.name} ({self.meal_slot})"


# ⭐ Feedback
class Feedback(models.Model):
    RATING_CHOICES = [(i, str(i)) for i in range(1, 6)]

    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='feedback')
    booking_meal = models.ForeignKey(BookingMeal, on_delete=models.CASCADE, related_name='feedback')
    combo = models.ForeignKey(Combo, on_delete=models.CASCADE, related_name='feedback')
    hostel = models.ForeignKey(Hostel, on_delete=models.CASCADE, related_name='feedback')

    rating = models.IntegerField(choices=RATING_CHOICES)
    comment = models.TextField(blank=True)

    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        unique_together = [['user', 'booking_meal']]
        ordering = ['-created_at']
        verbose_name_plural = "Feedback"

    def clean(self):
        if self.combo.hostel != self.hostel:
            raise ValidationError("Combo does not belong to this hostel")

    def __str__(self):
        return f"⭐ {self.rating} - {self.combo.name} by {self.user.email}"