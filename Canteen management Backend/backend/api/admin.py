from django.contrib import admin
from .models import User, Hostel, AllowedUser, OTP, Item, Combo, Booking, BookingMeal, Feedback, MealSlot


admin.site.register(User)
admin.site.register(Hostel)
admin.site.register(AllowedUser)

admin.site.register(OTP)
admin.site.register(Item)
admin.site.register(Combo)

admin.site.register(MealSlot)   # 🔥 ADD THIS LINE

admin.site.register(Booking)
admin.site.register(BookingMeal)
admin.site.register(Feedback)