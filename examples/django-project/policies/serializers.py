from rest_framework import serializers

from .models import Policy


class PolicySerializer(serializers.ModelSerializer):
    customer_name = serializers.CharField(source="customer.full_name", read_only=True)

    class Meta:
        model = Policy
        fields = ["id", "policy_number", "status", "sum_insured", "starts_on", "customer_name"]

    def validate_sum_insured(self, value):
        if value <= 0:
            raise serializers.ValidationError("Sum insured must be positive.")
        return value
