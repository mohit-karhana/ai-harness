from django.db import models


class Customer(models.Model):
    full_name = models.CharField(max_length=200)
    email = models.EmailField(unique=True)
    created_at = models.DateTimeField(auto_now_add=True)


class Policy(models.Model):
    class Status(models.TextChoices):
        DRAFT = "draft"
        ACTIVE = "active"
        LAPSED = "lapsed"

    customer = models.ForeignKey(Customer, on_delete=models.PROTECT, related_name="policies")
    policy_number = models.CharField(max_length=32, unique=True)
    status = models.CharField(max_length=16, choices=Status.choices, default=Status.DRAFT)
    sum_insured = models.DecimalField(max_digits=12, decimal_places=2)
    starts_on = models.DateField()

    class Meta:
        indexes = [models.Index(fields=["status", "starts_on"])]
