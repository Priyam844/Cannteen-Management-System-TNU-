from django.urls import path

# import from separate files
from .views.auth_views import LoginView, SendOTPView, RegisterView, VerifyOTPView
from .views.booking_views import BookMealsView, MyBookingView, CancelMealView, MyBookingHistoryView
from .views.profile_view import ProfileView, UpdateProfileView
from .views.menu_views import WeeklyMenuView, ItemCRUDView, ComboCRUDView, UpdateMealSlotView  #, ComboDetailsView

# Manager login view
from .views.serv_meals_qrscan import ServeMealQRScanView
from .views.manager_dashboard_view import ManagerDashboardView
from .views.feedback_view import FeedbackCreateView, FeedbackListView
from .views.admin_dashboard_view import AdminDashboardView, AdminManagementView, AdminReportsView
from .views.student_list_view import StudentListView
from .views.allowed_user_view import AllowedUserListView, BulkAuthorizeView
from .views.announcement_view import AnnouncementListCreateView, AnnouncementDetailView
from .views.report_view import ManagerReportsView

urlpatterns = [
    path('send-otp/', SendOTPView.as_view()),
    path('verify-otp/', VerifyOTPView.as_view()),
    path('login/', LoginView.as_view()),
    path('register/', RegisterView.as_view()),
    path('book-meals/', BookMealsView.as_view()),
    path('my-booking/', MyBookingView.as_view()),
    path('cancel-meal/', CancelMealView.as_view()), 
    path('profile/', ProfileView.as_view()),
    path('update-profile/', UpdateProfileView.as_view()),
    path('weekly-menu/', WeeklyMenuView.as_view(), name='weekly-menu'),
  #  path('combo/<int:combo_id>/', ComboDetailsView.as_view(), name='combo-details'),

   path('manager-dashboard/', ManagerDashboardView.as_view()),
   path('admin-dashboard/', AdminDashboardView.as_view()),
   path('admin-management/', AdminManagementView.as_view()),
   path('admin-reports/', AdminReportsView.as_view()),
   path('scan-meal/', ServeMealQRScanView.as_view()),
   path('feedback/', FeedbackCreateView.as_view()),
   path('my-feedback/', FeedbackListView.as_view()),
   path('student-list/', StudentListView.as_view()),
   path('allowed-users/', AllowedUserListView.as_view()),
   path('bulk-authorize/', BulkAuthorizeView.as_view()),
   path('items/', ItemCRUDView.as_view()),
   path('combos/', ComboCRUDView.as_view()),
   path('update-meal-slot/', UpdateMealSlotView.as_view()),
   path('announcements/', AnnouncementListCreateView.as_view()),
   path('announcements/<int:pk>/', AnnouncementDetailView.as_view()),
   path('manager-reports/', ManagerReportsView.as_view()),
]