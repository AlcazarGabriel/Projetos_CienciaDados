from contextlib import asynccontextmanager
import logging
from pathlib import Path
import re
from typing import Any

import joblib
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, Field, field_validator


PROJECT_ROOT = Path(__file__).resolve().parents[1]
MODEL_PATH = PROJECT_ROOT / "models" / "news_classifier.joblib"

REQUIRED_MODEL_KEYS = {
    "pipeline",
    "model_name",
    "text_char_limit",
    "input_template",
    "categories",
    "metrics",
}

logger = logging.getLogger(__name__)


class NewsRequest(BaseModel):
    """Dados recebidos para classificação."""

    title: str = Field(
        ...,
        min_length=1,
        max_length=500,
        description="Título da notícia.",
        examples=["Banco Central anuncia nova decisão sobre a taxa de juros"],
    )

    text: str = Field(
        default="",
        max_length=100_000,
        description="Conteúdo da notícia.",
        examples=[
            (
                "A autoridade monetária divulgou uma nova decisão "
                "relacionada à inflação e ao mercado financeiro."
            )
        ],
    )

    @field_validator("title")
    @classmethod
    def validate_title(cls, value: str) -> str:
        """
        Rejeita títulos vazios ou formados somente por espaços.
        """

        stripped_value = value.strip()

        if not stripped_value:
            raise ValueError("O título não pode estar vazio.")

        return stripped_value


class PredictionResponse(BaseModel):
    """Resposta retornada após a classificação."""

    predicted_category: str
    title: str


def normalize_text(value: str) -> str:
    """
    Remove espaços repetidos, quebras de linha e espaços
    no início e no fim do texto.
    """

    normalized_value = re.sub(
        r"\s+",
        " ",
        value,
    )

    return normalized_value.strip()


def prepare_model_input(
    title: str,
    text: str,
    text_char_limit: int,
    input_template: str = ("TITULO: {title} TEXTO: {text}"),
) -> str:
    """
    Prepara a entrada exatamente no formato utilizado
    durante o treinamento do modelo.
    """

    normalized_title = normalize_text(title)
    normalized_text = normalize_text(text)

    limited_text = normalized_text[:text_char_limit]

    return input_template.format(
        title=normalized_title,
        text=limited_text,
    )


def load_model_bundle(
    model_path: Path,
) -> dict[str, Any]:
    """
    Carrega e valida o artefato do modelo.
    """

    if not model_path.is_file():
        raise RuntimeError(f"Modelo não encontrado em: {model_path}")

    try:
        model_bundle = joblib.load(model_path)

    except Exception as error:
        raise RuntimeError("Não foi possível carregar o arquivo do modelo.") from error

    if not isinstance(model_bundle, dict):
        raise RuntimeError("O artefato do modelo possui formato inválido.")

    missing_keys = REQUIRED_MODEL_KEYS - set(model_bundle.keys())

    if missing_keys:
        missing_keys_text = ", ".join(sorted(missing_keys))

        raise RuntimeError(
            "O artefato do modelo não possui os campos "
            f"obrigatórios: {missing_keys_text}"
        )

    pipeline = model_bundle["pipeline"]

    if not hasattr(pipeline, "predict"):
        raise RuntimeError("O pipeline carregado não possui o método predict.")

    text_char_limit = model_bundle["text_char_limit"]

    if not isinstance(text_char_limit, int) or text_char_limit <= 0:
        raise RuntimeError("O limite de caracteres do modelo é inválido.")

    categories = model_bundle["categories"]

    if not isinstance(categories, list) or not categories:
        raise RuntimeError("A lista de categorias do modelo é inválida.")

    return model_bundle


@asynccontextmanager
async def lifespan(app: FastAPI):
    """
    Carrega o modelo uma única vez durante a inicialização
    da API.
    """

    model_bundle = load_model_bundle(MODEL_PATH)

    app.state.pipeline = model_bundle["pipeline"]

    app.state.text_char_limit = model_bundle["text_char_limit"]

    app.state.input_template = model_bundle["input_template"]

    app.state.model_name = model_bundle["model_name"]

    app.state.categories = model_bundle["categories"]

    app.state.metrics = model_bundle["metrics"]

    logger.info(
        "Modelo carregado com sucesso: %s",
        app.state.model_name,
    )

    yield


app = FastAPI(
    title="API de classificação de notícias",
    description=(
        "API que utiliza um modelo de Machine Learning "
        "para classificar notícias por categoria."
    ),
    version="1.0.0",
    lifespan=lifespan,
)


@app.get(
    "/",
    tags=["Status"],
)
def root():
    return {
        "message": ("API de classificação de notícias"),
        "status": "online",
        "documentation": "/docs",
    }


@app.get(
    "/health",
    tags=["Status"],
)
def health():
    model_loaded = hasattr(
        app.state,
        "pipeline",
    )

    return {
        "status": ("healthy" if model_loaded else "unhealthy"),
        "model_loaded": model_loaded,
        "model_name": getattr(
            app.state,
            "model_name",
            None,
        ),
    }


@app.get(
    "/categories",
    tags=["Modelo"],
)
def get_categories():
    categories = app.state.categories

    return {
        "quantity": len(categories),
        "categories": categories,
    }


@app.post(
    "/predict",
    response_model=PredictionResponse,
    tags=["Predição"],
)
def predict_news(
    news: NewsRequest,
) -> PredictionResponse:
    try:
        model_input = prepare_model_input(
            title=news.title,
            text=news.text,
            text_char_limit=(app.state.text_char_limit),
            input_template=(app.state.input_template),
        )

        prediction = app.state.pipeline.predict([model_input])[0]

        return PredictionResponse(
            predicted_category=str(prediction),
            title=normalize_text(news.title),
        )

    except Exception as error:
        logger.exception("Erro ao classificar a notícia.")

        raise HTTPException(
            status_code=500,
            detail=("Não foi possível realizar a classificação."),
        ) from error
