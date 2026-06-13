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

    # 🔥 Operational Settings
    slot_timings = models.JSONField(default=dict, blank=True)
    booking_cutoff_time = models.TimeField(default="14:00:00", help_text="Time two days prior after which regular booking closes")
    cancellation_cutoff_time = models.TimeField(default="16:00:00", help_text="Time two days prior after which cancellation closes")
    late_booking_lead_time_hours = models.PositiveIntegerField(default=2, help_text="Hours before meal slot during which today's booking is allowed")
    excluded_for_faculty = models.BooleanField(default=False, help_text="If true, faculty cannot book in this hostel")

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

    student_id = models.CharField(max_length=20, unique=True, null=True, blank=True)
    phone = models.CharField(max_length=20, unique=True, null=True, blank=True)

    profile_picture = models.ImageField(upload_to='profile_pics/', null=True, blank=True)

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
            ('faculty', 'Faculty'),
            ('staff', 'Staff'),
            ('manager', 'Manager'),
            ('admin', 'Admin'),
        ],
        default='student'
    )

    wallet_balance = models.DecimalField(max_digits=10, decimal_places=2, default=0.00)

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

    role = models.CharField(
        max_length=20,
        choices=[
            ('student', 'Student'),
            ('faculty', 'Faculty'),
            ('staff', 'Staff'),
        ],
        default='student'
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
    
    # 💰 Multi-tier Pricing
    price = models.DecimalField(max_digits=8, decimal_places=2, default=0.00, help_text="Student Price")
    faculty_price = models.DecimalField(max_digits=8, decimal_places=2, default=0.00)
    staff_price = models.DecimalField(max_digits=8, decimal_places=2, default=0.00)
    guest_price = models.DecimalField(max_digits=8, decimal_places=2, default=0.00)

    is_veg = models.BooleanField(default=True)
    description = models.TextField(blank=True)
    is_active = models.BooleanField(default=True)
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

    hostel = models.ForeignKey(
        Hostel,
        on_delete=models.CASCADE,
        related_name='combos'
    )

    name = models.CharField(max_length=100)
    meal_type = models.CharField(max_length=20, choices=MEAL_TYPE_CHOICES)

    # 💰 Multi-tier Pricing
    price = models.DecimalField(max_digits=8, decimal_places=2, help_text="Student Price")
    faculty_price = models.DecimalField(max_digits=8, decimal_places=2, default=0.00)
    staff_price = models.DecimalField(max_digits=8, decimal_places=2, default=0.00)
    guest_price = models.DecimalField(max_digits=8, decimal_places=2, default=0.00)

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
   # date = models.DateField(null=True, blank=True)

    combos = models.ManyToManyField(Combo, related_name='meal_slots')
    items = models.ManyToManyField(Item, related_name='meal_slots', blank=True)

    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        unique_together = [['hostel', 'day', 'slot']]
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


# 📅 DailyMenu (Overrides Weekly Menu for a specific date)
class DailyMenu(models.Model):
    hostel = models.ForeignKey(
        Hostel,
        on_delete=models.CASCADE,
        related_name='daily_menus'
    )
    date = models.DateField()
    slot = models.CharField(max_length=10, choices=MealSlot.SLOT_CHOICES)

    combos = models.ManyToManyField(Combo, related_name='daily_menus')
    items = models.ManyToManyField(Item, related_name='daily_menus', blank=True)

    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        unique_together = [['hostel', 'date', 'slot']]
        ordering = ['date', 'slot']
        verbose_name_plural = "Daily Menus"

    def __str__(self):
        return f"{self.hostel} - {self.date} - {self.slot}"


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

    # Tracks specific items chosen within the combo
    selected_items = models.ManyToManyField(Item, blank=True)

    quantity = models.PositiveIntegerField(default=1)
    
    # 👨‍👩‍👧‍👦 Guest Support
    guest_quantity = models.PositiveIntegerField(default=0)
    
    total_price = models.DecimalField(max_digits=8, decimal_places=2, default=0.00)
    is_late_booking = models.BooleanField(default=False)

    status = models.CharField(max_length=10, choices=STATUS_CHOICES, default='booked')

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        unique_together = [['booking', 'meal_slot', 'combo']]
        ordering = ['-created_at']
        verbose_name_plural = "Booking Meals"

    def __str__(self):
        return f"{self.booking} - {self.combo.name} ({self.meal_slot})"


# 🍴 BookingMealItem (Stores quantities for items within a combo)
class BookingMealItem(models.Model):
    booking_meal = models.ForeignKey(
        BookingMeal,
        on_delete=models.CASCADE,
        related_name='meal_items'
    )
    item = models.ForeignKey(Item, on_delete=models.CASCADE)
    quantity = models.PositiveIntegerField(default=1)

    def __str__(self):
        return f"{self.item.name} x{self.quantity} in {self.booking_meal}"


# 🛍️ BookingItem (Individual items ordered outside combos)
class BookingItem(models.Model):
    booking = models.ForeignKey(
        Booking,
        on_delete=models.CASCADE,
        related_name='items'
    )

    meal_slot = models.ForeignKey(
        MealSlot,
        on_delete=models.CASCADE,
        related_name='item_bookings'
    )

    item = models.ForeignKey(
        Item,
        on_delete=models.CASCADE,
        related_name='bookings'
    )

    quantity = models.PositiveIntegerField(default=1)
    
    # 👨‍👩‍👧‍👦 Guest Support
    guest_quantity = models.PositiveIntegerField(default=0)
    
    price = models.DecimalField(max_digits=8, decimal_places=2)
    total_price = models.DecimalField(max_digits=8, decimal_places=2, default=0.00)

    status = models.CharField(
        max_length=10,
        choices=BookingMeal.STATUS_CHOICES,
        default='booked'
    )

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['-created_at']
        verbose_name_plural = "Booking Items"

    def save(self, *args, **kwargs):
        super().save(*args, **kwargs)

    def __str__(self):
        return f"{self.booking} - {self.item.name} x{self.quantity}"


# ⭐ Feedback
class Feedback(models.Model):
    RATING_CHOICES = [(i, str(i)) for i in range(1, 6)]

    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='feedback')
    booking_meal = models.ForeignKey(BookingMeal, on_delete=models.CASCADE, null=True, blank=True, related_name='feedback')
    booking_item = models.ForeignKey(BookingItem, on_delete=models.CASCADE, null=True, blank=True, related_name='feedback')
    combo = models.ForeignKey(Combo, on_delete=models.CASCADE, null=True, blank=True, related_name='feedback')
    hostel = models.ForeignKey(Hostel, on_delete=models.CASCADE, related_name='feedback')

    rating = models.IntegerField(choices=RATING_CHOICES)
    comment = models.TextField(blank=True)

    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-created_at']
        verbose_name_plural = "Feedback"

    def clean(self):
        if self.combo and self.combo.hostel != self.hostel:
            raise ValidationError("Combo does not belong to this hostel")

    def __str__(self):
        return f"⭐ {self.rating} by {self.user.email}"


# 📢 Announcement
class Announcement(models.Model):
    title = models.CharField(max_length=200)
    content = models.TextField()

    hostel = models.ForeignKey(
        Hostel, 
        on_delete=models.CASCADE, 
        related_name='announcements',
        null=True, 
        blank=True,
        help_text="If null, it's a global announcement"
    )

    created_by = models.ForeignKey(User, on_delete=models.CASCADE)
    created_at = models.DateTimeField(auto_now_add=True)
    is_active = models.BooleanField(default=True)

    class Meta:
        ordering = ['-created_at']

    def __str__(self):
        return self.title

# 💳 Wallet Transaction
class Transaction(models.Model):
    TRANSACTION_TYPES = [
        ('credit', 'Credit'),
        ('debit', 'Debit'),
        ('refund', 'Refund'),
    ]

    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='transactions')
    amount = models.DecimalField(max_digits=10, decimal_places=2)
    transaction_type = models.CharField(max_length=10, choices=TRANSACTION_TYPES)
    description = models.CharField(max_length=255)
    
    # Optional link to a booking
    booking = models.ForeignKey(Booking, on_delete=models.SET_NULL, null=True, blank=True)
    
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-created_at']

    def __str__(self):
        return f"{self.user.email} - {self.transaction_type} - {self.amount}"


# 🏆 Institutional Event (Requirement 18)
class InstitutionalEvent(models.Model):
    name = models.CharField(max_length=200)
    description = models.TextField(blank=True)
    start_date = models.DateField()
    end_date = models.DateField()
    
    created_at = models.DateTimeField(auto_now_add=True)
    is_active = models.BooleanField(default=True)

    def __str__(self):
        return self.name


# 🎫 Event Pass (Requirement 18)
class EventPass(models.Model):
    event = models.ForeignKey(InstitutionalEvent, on_delete=models.CASCADE, related_name='passes')
    guest_name = models.CharField(max_length=100)
    email = models.EmailField(null=True, blank=True)
    qr_uuid = models.UUIDField(default=uuid.uuid4, unique=True, editable=False)
    
    # 🍽️ Selected Meals (e.g., ["breakfast", "lunch"])
    meal_slots = models.JSONField(default=list, blank=True)
    
    # Optional specific validity
    valid_from = models.DateTimeField(null=True, blank=True)
    valid_until = models.DateTimeField(null=True, blank=True)
    
    is_used = models.BooleanField(default=False)
    consumed_at = models.DateTimeField(null=True, blank=True)
    
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"{self.guest_name} - {self.event.name}"
