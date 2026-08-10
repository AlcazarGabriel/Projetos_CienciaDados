import joblib
import pytest
from fastapi.testclient import TestClient

from api.main import (
    MODEL_PATH,
    app,
    prepare_model_input,
)


@pytest.fixture(scope="module")
def client():
    """
    Inicializa a API uma única vez para todos os testes
    deste arquivo.
    """

    with TestClient(app) as test_client:
        yield test_client


@pytest.fixture(scope="module")
def model_bundle():
    """
    Carrega o artefato do modelo uma única vez.
    """

    return joblib.load(MODEL_PATH)


def test_root(client):
    response = client.get("/")

    assert response.status_code == 200

    data = response.json()

    assert data["status"] == "online"
    assert data["documentation"] == "/docs"


def test_health(client):
    response = client.get("/health")

    assert response.status_code == 200

    data = response.json()

    assert data["status"] == "healthy"
    assert data["model_loaded"] is True
    assert data["model_name"] == "TF-IDF + LinearSVC"


def test_categories(client):
    response = client.get("/categories")

    assert response.status_code == 200

    data = response.json()

    assert data["quantity"] > 0
    assert len(data["categories"]) == data["quantity"]

    assert "mercado" in data["categories"]
    assert "esporte" in data["categories"]


def test_predict_valid_news(client):
    request_data = {
        "title": ("Banco Central anuncia nova decisão sobre a taxa de juros"),
        "text": (
            "A autoridade monetária divulgou uma "
            "decisão relacionada à inflação, economia "
            "e mercado financeiro."
        ),
    }

    response = client.post(
        "/predict",
        json=request_data,
    )

    categories_response = client.get("/categories")

    assert response.status_code == 200

    data = response.json()

    categories = categories_response.json()["categories"]

    assert data["title"] == request_data["title"]

    assert data["predicted_category"] in categories


def test_predict_without_title_field(client):
    """
    O campo title é obrigatório.
    """

    response = client.post(
        "/predict",
        json={"text": "Conteúdo de uma notícia."},
    )

    assert response.status_code == 422


def test_predict_with_empty_title(client):
    """
    O título não pode ser uma string vazia.
    """

    response = client.post(
        "/predict",
        json={
            "title": "",
            "text": "Conteúdo de uma notícia.",
        },
    )

    assert response.status_code == 422


def test_predict_with_blank_title(client):
    """
    O título não pode conter somente espaços.
    """

    response = client.post(
        "/predict",
        json={
            "title": "     ",
            "text": "Conteúdo de uma notícia.",
        },
    )

    assert response.status_code == 422


def test_predict_without_text(client):
    """
    O conteúdo é opcional. A API deve conseguir
    realizar uma previsão usando somente o título.
    """

    response = client.post(
        "/predict",
        json={"title": ("Final do campeonato acontece neste domingo")},
    )

    assert response.status_code == 200

    data = response.json()

    assert data["predicted_category"]
    assert data["title"]


def test_title_above_limit(client):
    """
    O limite configurado para o título é de
    500 caracteres.
    """

    response = client.post(
        "/predict",
        json={
            "title": "a" * 501,
            "text": "Conteúdo válido.",
        },
    )

    assert response.status_code == 422


def test_text_above_limit(client):
    """
    O limite aceito pela API para o conteúdo é de
    100.000 caracteres.
    """

    response = client.post(
        "/predict",
        json={
            "title": "Título válido",
            "text": "a" * 100_001,
        },
    )

    assert response.status_code == 422


def test_prepare_model_input_normalizes_spaces():
    result = prepare_model_input(
        title="  Banco   Central  ",
        text=("Nova   decisão\n sobre juros."),
        text_char_limit=1_500,
    )

    assert result == ("TITULO: Banco Central TEXTO: Nova decisão sobre juros.")


def test_prepare_model_input_limits_text():
    result = prepare_model_input(
        title="Notícia",
        text="a" * 2_000,
        text_char_limit=1_500,
    )

    text_part = result.split(
        "TEXTO: ",
        maxsplit=1,
    )[1]

    assert len(text_part) == 1_500


def test_response_returns_normalized_title(client):
    response = client.post(
        "/predict",
        json={
            "title": "  Banco   Central  ",
            "text": "Notícia sobre economia.",
        },
    )

    assert response.status_code == 200

    assert response.json()["title"] == ("Banco Central")


def test_model_bundle_integrity(model_bundle):
    """
    Confirma que o arquivo joblib possui todos os
    componentes necessários para a aplicação.
    """

    required_keys = {
        "pipeline",
        "model_name",
        "text_char_limit",
        "input_template",
        "categories",
        "metrics",
    }

    assert required_keys.issubset(model_bundle.keys())

    assert model_bundle["text_char_limit"] == 1_500

    assert len(model_bundle["categories"]) == 29

    assert hasattr(
        model_bundle["pipeline"],
        "predict",
    )


def test_model_categories_match_classifier(
    model_bundle,
):
    """
    Confirma que as categorias salvas no artefato
    são as mesmas conhecidas pelo classificador.
    """

    pipeline = model_bundle["pipeline"]

    classifier = pipeline.named_steps["classifier"]

    saved_categories = set(model_bundle["categories"])

    classifier_categories = set(classifier.classes_)

    assert saved_categories == classifier_categories
