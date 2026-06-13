from rest_framework import serializers
from .models import (
    Booking, BookingMeal, Combo, Item, MealSlot, Feedback, User, 
    Announcement, DailyMenu, Transaction, InstitutionalEvent, EventPass
)


class BookingMealInputSerializer(serializers.Serializer):
    combo_id = serializers.IntegerField()
    slot = serializers.CharField()
    guest_quantity = serializers.IntegerField(default=0)


class BookingSerializer(serializers.ModelSerializer):
    class Meta:
        model = Booking
        fields = ['qr_uuid', 'date']


class BookingMealSerializer(serializers.ModelSerializer):
    combo = serializers.CharField(source='combo.name')
    slot = serializers.CharField(source='meal_slot.slot')

    class Meta:
        model = BookingMeal
        fields = ['combo', 'slot', 'status', 'quantity', 'guest_quantity', 'total_price']


# Weekly Menu Serializers
class ItemSerializer(serializers.ModelSerializer):
    class Meta:
        model = Item
        fields = [
            'id', 'name', 'price', 'faculty_price', 'staff_price', 'guest_price',
            'is_veg', 'description', 'is_active', 'created_at'
        ]
        read_only_fields = ['id', 'created_at']


class DailyMenuSerializer(serializers.ModelSerializer):
    class Meta:
        model = DailyMenu
        fields = '__all__'


class ComboSerializer(serializers.ModelSerializer):
    items = ItemSerializer(many=True, read_only=True)
    item_ids = serializers.ListField(
        child=serializers.IntegerField(),
        write_only=True,
        required=False
    )
    # Price depends on who is viewing it, but for listing we show all tiers
    class Meta:
        model = Combo
        fields = [
            'id', 'name', 'meal_type', 'price', 'faculty_price', 'staff_price', 'guest_price',
            'description', 'items', 'item_ids', 'is_active', 'hostel'
        ]
        read_only_fields = ['id', 'items', 'hostel']

    def create(self, validated_data):
        item_ids = validated_data.pop('item_ids', [])
        combo = Combo.objects.create(**validated_data)
        if item_ids:
            combo.items.set(item_ids)
        return combo

    def update(self, instance, validated_data):
        item_ids = validated_data.pop('item_ids', None)
        instance = super().update(instance, validated_data)
        if item_ids is not None:
            instance.items.set(item_ids)
        return instance


class MealSlotSerializer(serializers.ModelSerializer):
    combos = ComboSerializer(many=True, read_only=True)

    class Meta:
        model = MealSlot
        fields = ['id', 'day', 'slot', 'combos']


class WeeklyMenuSerializer(serializers.Serializer):
    day = serializers.CharField()
    meals = serializers.ListField(child=serializers.DictField())


class FeedbackSerializer(serializers.ModelSerializer):
    meal_slot = serializers.CharField(source='booking_meal.meal_slot.slot', read_only=True, required=False)
    combo_name = serializers.CharField(source='combo.name', read_only=True, required=False)
    hostel_name = serializers.CharField(source='hostel.hostel_name', read_only=True, required=False)

    class Meta:
        model = Feedback
        fields = [
            'id', 'booking_meal', 'booking_item', 'rating', 'comment', 
            'meal_slot', 'combo_name', 'hostel_name', 'created_at'
        ]
        read_only_fields = ['id', 'created_at', 'meal_slot', 'combo_name', 'hostel_name']

    def validate(self, data):
        user = self.context['request'].user
        booking_meal = data.get('booking_meal')
        booking_item = data.get('booking_item')

        if not booking_meal and not booking_item:
            raise serializers.ValidationError("Feedback must be linked to a meal or an item.")

        if booking_meal:
            if booking_meal.booking.user != user:
                raise serializers.ValidationError("You can only provide feedback for your own meals.")
            if booking_meal.status != 'consumed':
                raise serializers.ValidationError("You can only provide feedback for consumed meals.")
        
        if booking_item:
            if booking_item.booking.user != user:
                raise serializers.ValidationError("You can only provide feedback for your own items.")
            if booking_item.status != 'consumed':
                raise serializers.ValidationError("You can only provide feedback for consumed items.")

        return data

    def create(self, validated_data):
        booking_meal = validated_data.get('booking_meal')
        booking_item = validated_data.get('booking_item')
        
        validated_data['user'] = self.context['request'].user
        
        if booking_meal:
            validated_data['combo'] = booking_meal.combo
            validated_data['hostel'] = booking_meal.combo.hostel
        elif booking_item:
            validated_data['hostel'] = booking_item.booking.user.hostel # Safe assumption
            
        return super().create(validated_data)


class UserUpdateSerializer(serializers.ModelSerializer):
    class Meta:
        model = User
        fields = ['first_name', 'last_name', 'phone', 'profile_picture']


class AnnouncementSerializer(serializers.ModelSerializer):
    author_name = serializers.CharField(source='created_by.first_name', read_only=True)
    hostel_name = serializers.CharField(source='hostel.hostel_name', read_only=True)

    class Meta:
        model = Announcement
        fields = ['id', 'title', 'content', 'hostel', 'hostel_name', 'author_name', 'created_at', 'is_active']
        read_only_fields = ['id', 'created_at', 'author_name', 'hostel_name']


class TransactionSerializer(serializers.ModelSerializer):
    class Meta:
        model = Transaction
        fields = '__all__'


class InstitutionalEventSerializer(serializers.ModelSerializer):
    class Meta:
        model = InstitutionalEvent
        fields = '__all__'


class EventPassSerializer(serializers.ModelSerializer):
    event_name = serializers.CharField(source='event.name', read_only=True)
    
    class Meta:
        model = EventPass
        fields = '__all__'
        read_only_fields = ['qr_uuid', 'created_at']
