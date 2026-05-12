from rest_framework import serializers
from .models import Booking, BookingMeal, Combo, Item, MealSlot, Feedback, User, Announcement


class BookingMealInputSerializer(serializers.Serializer):
    combo_id = serializers.IntegerField()
    slot = serializers.CharField()


class BookingSerializer(serializers.ModelSerializer):
    class Meta:
        model = Booking
        fields = ['qr_uuid', 'date']


class BookingMealSerializer(serializers.ModelSerializer):
    combo = serializers.CharField(source='combo.name')

    class Meta:
        model = BookingMeal
        fields = ['combo', 'slot', 'status']


# Weekly Menu Serializers
class ItemSerializer(serializers.ModelSerializer):
    class Meta:
        model = Item
        fields = ['id', 'name', 'is_veg', 'description', 'is_active', 'created_at']
        read_only_fields = ['id', 'created_at']


class ComboSerializer(serializers.ModelSerializer):
    items = ItemSerializer(many=True, read_only=True)
    item_ids = serializers.ListField(
        child=serializers.IntegerField(),
        write_only=True,
        required=False
    )

    class Meta:
        model = Combo
        fields = ['id', 'name', 'meal_type', 'category', 'price', 'description', 'items', 'item_ids', 'is_active', 'hostel']
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
        fields = ['id', 'day', 'slot', 'capacity', 'combos']


class WeeklyMenuSerializer(serializers.Serializer):
    day = serializers.CharField()
    meals = serializers.ListField(child=serializers.DictField())


class FeedbackSerializer(serializers.ModelSerializer):
    class Meta:
        model = Feedback
        fields = ['id', 'booking_meal', 'rating', 'comment', 'created_at']
        read_only_fields = ['id', 'created_at']

    def validate(self, data):
        user = self.context['request'].user
        booking_meal = data['booking_meal']

        if booking_meal.booking.user != user:
            raise serializers.ValidationError("You can only provide feedback for your own meals.")

        if booking_meal.status != 'consumed':
            raise serializers.ValidationError("You can only provide feedback for consumed meals.")

        return data

    def create(self, validated_data):
        booking_meal = validated_data['booking_meal']
        validated_data['user'] = self.context['request'].user
        validated_data['combo'] = booking_meal.combo
        validated_data['hostel'] = booking_meal.combo.hostel
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