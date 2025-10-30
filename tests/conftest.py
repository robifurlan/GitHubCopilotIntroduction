from fastapi.testclient import TestClient
import pytest

from src.app import app


@pytest.fixture
def client():
    """Provide a TestClient for the FastAPI app."""
    with TestClient(app) as c:
        yield c
