# Classificador de notícias

Projeto de Machine Learning desenvolvido para classificar notícias em categorias a partir do título e do conteúdo textual.

O projeto cobre todo o fluxo de construção de um produto de dados:

- análise exploratória e tratamento dos dados;
- comparação de modelos;
- seleção e exportação do modelo;
- disponibilização por API REST;
- testes automatizados;
- padronização de código;
- execução em contêiner Docker.

## Visão geral

O dataset utilizado contém notícias com informações como título, conteúdo, data, categoria, subcategoria e link.

Após a análise de qualidade e o tratamento dos dados, foram utilizados:

- **162.952 registros**;
- **29 categorias**;
- título da notícia;
- primeiros **1.500 caracteres** do conteúdo.

O modelo selecionado foi um pipeline composto por:

- vetorização de texto com **TF-IDF**;
- classificação com **LinearSVC**;
- balanceamento das classes por meio de `class_weight="balanced"`.

## Resultados do modelo

O modelo final apresentou os seguintes resultados no conjunto de teste:

| Métrica | Resultado |
|---|---:|
| Acurácia | 85,53% |
| Acurácia balanceada | 66,30% |
| F1 macro | 67,06% |
| F1 weighted | 85,24% |

O uso do título combinado com parte do conteúdo apresentou uma melhora relevante em comparação com o modelo treinado apenas com o título.

## Estrutura do projeto

```text
Projeto_Teste/
├── api/
│   ├── __init__.py
│   └── main.py
│
├── data/
│   └── artigos.csv
│
├── models/
│   └── news_classifier.joblib
│
├── notebooks/
│   └── 01_analise_e_modelagem.ipynb
│
├── tests/
│   └── test_api.py
│
├── .dockerignore
├── .gitignore
├── Dockerfile
├── README.md
├── requirements.txt
└── requirements-dev.txt
```

### Responsabilidade das pastas

- `api/`: aplicação FastAPI responsável pelas previsões;
- `data/`: dataset utilizado no notebook;
- `models/`: modelo treinado e exportado em formato Joblib;
- `notebooks/`: análise exploratória, experimentos e treinamento;
- `tests/`: testes automatizados da API, processamento e modelo.

## Requisitos

O projeto foi desenvolvido e validado com:

```text
Python 3.14.6
```

Também é possível executar a API utilizando Docker.

## Instalação local

Extraia o arquivo compactado e acesse a pasta do projeto:

```bash
cd Projeto_Teste

```

Crie o ambiente virtual:

```bash
python -m venv .venv
```

No Windows PowerShell, ative com:

```powershell
.venv\Scripts\Activate.ps1
```

No Linux ou macOS:

```bash
source .venv/bin/activate
```

Para instalar somente as dependências necessárias para executar a API:

```bash
python -m pip install -r requirements.txt
```

Para instalar também Jupyter, testes e ferramentas de desenvolvimento:

```bash
python -m pip install -r requirements-dev.txt
```

## Dataset

O arquivo original não é versionado no Git devido ao seu tamanho.

Para executar o notebook, coloque o arquivo com o nome:

```text
artigos.csv
```

dentro da pasta:

```text
data/
```

O modelo já treinado está disponível em:

```text
models/news_classifier.joblib
```

Por isso, não é necessário executar novamente o treinamento para utilizar a API.

## Executando o notebook

Com as dependências de desenvolvimento instaladas, inicie o JupyterLab:

```bash
python -m jupyter lab
```

Abra o arquivo:

```text
notebooks/01_analise_e_modelagem.ipynb
```

O notebook contém:

1. leitura e análise inicial;
2. auditoria da qualidade dos dados;
3. preparação do dataset;
4. separação entre treino, validação e teste;
5. construção do baseline;
6. comparação entre algoritmos;
7. ajuste do LinearSVC;
8. combinação de título e conteúdo;
9. avaliação do modelo;
10. exportação do artefato final.

## Executando a API localmente

Na raiz do projeto, execute:

```bash
python -m uvicorn api.main:app --reload
```

A API ficará disponível em:

```text
http://127.0.0.1:8000
```

A documentação interativa pode ser acessada em:

```text
http://127.0.0.1:8000/docs
```

## Endpoints

### `GET /`

Verifica se a API está online.

Exemplo de resposta:

```json
{
  "message": "API de classificação de notícias",
  "status": "online",
  "documentation": "/docs"
}
```

### `GET /health`

Verifica se o modelo foi carregado corretamente.

Exemplo:

```json
{
  "status": "healthy",
  "model_loaded": true,
  "model_name": "TF-IDF + LinearSVC"
}
```

### `GET /categories`

Retorna todas as categorias conhecidas pelo modelo.

Exemplo:

```json
{
  "quantity": 29,
  "categories": [
    "ambiente",
    "ciencia",
    "esporte",
    "mercado"
  ]
}
```

### `POST /predict`

Recebe o título e, opcionalmente, o conteúdo da notícia.

Exemplo de requisição:

```json
{
  "title": "Banco Central anuncia nova decisão sobre a taxa de juros",
  "text": "A autoridade monetária divulgou uma nova decisão relacionada à inflação e ao mercado financeiro."
}
```

Exemplo de resposta:

```json
{
  "predicted_category": "mercado",
  "title": "Banco Central anuncia nova decisão sobre a taxa de juros"
}
```

O campo `title` é obrigatório. O campo `text` é opcional.

## Executando com Docker

Construa a imagem:

```bash
docker build -t news-classifier-api .
```

Execute o contêiner:

```bash
docker run --rm -p 8000:8000 news-classifier-api
```

Depois, acesse:

```text
http://localhost:8000/docs
```

Para verificar a saúde da aplicação:

```text
http://localhost:8000/health
```

## Testes automatizados

Execute:

```bash
python -m pytest -v
```

A suíte possui **15 testes**, cobrindo:

- endpoints principais;
- carregamento do modelo;
- previsão válida;
- título obrigatório;
- título vazio ou composto apenas por espaços;
- texto opcional;
- limites de caracteres;
- normalização textual;
- truncamento do conteúdo;
- integridade do arquivo Joblib;
- compatibilidade entre as categorias salvas e o classificador.

Resultado validado:

```text
15 passed
```

Alguns avisos de depreciação podem ser exibidos por dependências externas, principalmente Starlette, Joblib e NumPy. Eles não representam falhas nos testes da aplicação.

## Qualidade do código

Verifique o código com Ruff:

```bash
python -m ruff check .
```

Verifique a formatação:

```bash
python -m ruff format --check .
```

Resultado esperado:

```text
All checks passed!
```

## Decisões técnicas

### LinearSVC

O LinearSVC apresentou melhor equilíbrio entre desempenho, tempo de treinamento, custo de inferência e simplicidade de implantação.

### Título e conteúdo

Utilizar apenas o título gerou bons resultados, mas a inclusão dos primeiros 1.500 caracteres do conteúdo aumentou o contexto disponível para o modelo.

### Pipeline completo

O vetorizador TF-IDF e o classificador foram exportados juntos. Isso garante que a API utilize exatamente o mesmo processamento aplicado durante o treinamento.

### Carregamento do modelo

O modelo é carregado uma única vez durante a inicialização da API, evitando a leitura do arquivo em todas as requisições.

### Dependências separadas

O projeto possui dois arquivos:

- `requirements.txt`: execução da API;
- `requirements-dev.txt`: notebook, testes e ferramentas de desenvolvimento.

## Limitações

O dataset apresenta desbalanceamento entre as categorias, o que afeta principalmente as classes com menor quantidade de registros.

O mesmo conjunto de teste foi utilizado durante parte da comparação experimental. Embora os registros de teste não tenham participado diretamente do treinamento, algumas decisões podem ter sido indiretamente influenciadas pelas métricas observadas.

Em uma evolução do projeto, seria possível:

- manter o conjunto de teste reservado exclusivamente para a avaliação final;
- aplicar validação cruzada;
- acompanhar o desempenho do modelo em produção;
- adicionar probabilidades ou medidas de confiança;
- implementar versionamento e monitoramento do modelo.

## Tecnologias utilizadas

- Python;
- Pandas;
- scikit-learn;
- TF-IDF;
- LinearSVC;
- FastAPI;
- Pydantic;
- Joblib;
- Pytest;
- Ruff;
- Docker;
- JupyterLab.