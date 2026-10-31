from decimal import Decimal

import pytest
from rest_framework.exceptions import ValidationError

from policies.serializers import PolicySerializer


def test_sum_insured_must_be_positive():
    with pytest.raises(ValidationError, match="positive"):
        PolicySerializer().validate_sum_insured(Decimal("0"))
