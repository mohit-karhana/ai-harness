from rest_framework import viewsets

from .models import Policy
from .serializers import PolicySerializer


class PolicyViewSet(viewsets.ReadOnlyModelViewSet):
    serializer_class = PolicySerializer

    def get_queryset(self):
        return Policy.objects.select_related("customer").order_by("-starts_on")
