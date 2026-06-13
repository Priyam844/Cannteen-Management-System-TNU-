from django.contrib import admin
from .models import User, Hostel, AllowedUser, OTP, Item, Combo, Booking, BookingMeal, Feedback, MealSlot


@admin.register(Hostel)
class HostelAdmin(admin.ModelAdmin):
    list_display = ('hostel_name', 'hostel_type', 'excluded_for_faculty', 'created_at')
    list_filter = ('hostel_type', 'excluded_for_faculty')
    search_fields = ('hostel_name',)

admin.site.register(User)
admin.site.register(AllowedUser)

admin.site.register(OTP)
admin.site.register(Item)
admin.site.register(Combo)

admin.site.register(MealSlot)   # 🔥 ADD THIS LINE

admin.site.register(Booking)
admin.site.register(BookingMeal)
admin.site.register(Feedback)